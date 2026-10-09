## 文件用途：按状态驱动敌人动画、地面影子、受击闪白及距离显示档位。
## 使用方式：setup 后 apply_enemy_config；update 传入状态快照，远离玩家或离屏时降低动画开销，play_state 显式切换动画。

extends RefCounted
class_name EnemyVisualController


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const FULL_ANIMATION_DISTANCE_SQUARED: float = 900.0 * 900.0
const HIDE_DISTANCE_SQUARED: float = 1800.0 * 1800.0

var _owner: Node2D
var _visual_config: Dictionary = {}
var _visual_state: String = ""
var _last_move_state: String = "move_right"
var _hurt_flash_item: CanvasItem
var _hurt_flash_modulate: Color = Color.WHITE


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner


## 作用：深拷贝敌人 visual 配置并强制切换到 idle 动画。
## 使用：enemy_config 来自已加载定义；visual 类型不符时跳过，不替换已有视觉配置。
func apply_enemy_config(enemy_config: Dictionary) -> void:
	var visual_variant: Variant = enemy_config.get("visual", {})
	if not (visual_variant is Dictionary):
		return

	var visual: Dictionary = visual_variant
	_visual_config = visual.duplicate(true)
	play_state("idle", true)


## 作用：普通敌人或没有视觉配置的敌人受击时闪白，其他敌人播放 hurt 动画。
## 使用：距离档位非 0 时跳过；duration 当前未被读取，闪白恢复由 update 的 is_hurt 状态控制。
func show_hurt(duration: float = 0.12) -> void:
	if _get_lod() != 0:
		return
	if _visual_config.is_empty() or _is_normal_enemy():
		_start_hurt_flash()
		return
	play_state("hurt")


## 作用：根据距离档位、受击、死亡、状态和移动标记选择敌人显示方式。
## 使用：state 为 EnemyStateController 快照；delta 当前未被读取，普通敌人优先用闪白反馈和移动方向动画。
func update(state: Dictionary, delta: float) -> void:
	if _visual_config.is_empty():
		if bool(state.get("is_hurt", false)):
			_start_hurt_flash()
		else:
			_end_hurt_flash()
		return

	if _apply_lod(state):
		return

	if bool(state.get("is_hurt", false)):
		if _is_normal_enemy():
			_start_hurt_flash()
		else:
			play_state("hurt")
			return
	else:
		_end_hurt_flash()

	if bool(state.get("is_dead", false)):
		play_state("death")
		return

	if _is_normal_enemy():
		play_state("attack" if bool(state.get("is_attacking", false)) else _get_move_state(state))
		return

	var status_state: String = String(state.get("status_state", ""))
	if status_state != "":
		play_state(status_state)
		return

	if bool(state.get("is_attacking", false)):
		play_state("attack")
	elif bool(state.get("is_moving", false)):
		play_state(_get_move_state(state))
	else:
		play_state("idle")


## 作用：在视觉配置有效时切换动画并以 idle 为缺失状态回退。
## 使用：state 为视觉状态名；force 为真允许重复应用同一状态，正常调用跳过未变化状态。
func play_state(state: String, force: bool = false) -> void:
	if _owner == null or _visual_config.is_empty():
		return
	if not force and _visual_state == state:
		return
	_visual_state = state
	VisualConfigApplierScript.play_state(_owner, _visual_config, state, "idle")


## 作用：判断普通敌人，返回布尔判断结果。
## 使用：本文件由 show_hurt、update 调用。
func _is_normal_enemy() -> bool:
	return _owner != null and String(_owner.get_meta("enemy_rank", "normal")) == "normal" and String(_owner.get_meta("spawn_source_type", "")) != "boss_minion"


## 作用：保存当前精灵调色并暂时设置为白色。
## 使用：优先 AnimatedSprite2D，其次 Sprite2D；已有闪白引用时不重复覆盖原颜色。
func _start_hurt_flash() -> void:
	if _hurt_flash_item != null and is_instance_valid(_hurt_flash_item):
		return
	_hurt_flash_item = _owner.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if _hurt_flash_item == null:
		_hurt_flash_item = _owner.get_node_or_null("Sprite2D") as CanvasItem
	if _hurt_flash_item == null:
		return
	_hurt_flash_modulate = _hurt_flash_item.modulate
	_hurt_flash_item.modulate = Color.WHITE


## 作用：恢复受击闪白前的精灵调色并清空引用。
## 使用：update 判定不再受击时调用；失效节点仅清空引用。
func _end_hurt_flash() -> void:
	if _hurt_flash_item != null and is_instance_valid(_hurt_flash_item):
		_hurt_flash_item.modulate = _hurt_flash_modulate
	_hurt_flash_item = null


## 作用：获取移动状态，供当前模块后续逻辑使用。
## 使用：本文件由 update、_apply_lod 调用；输入 state（状态）；返回 String 文本/标识。
func _get_move_state(state: Dictionary) -> String:
	var direction: Vector2 = state.get("move_direction", Vector2.ZERO) as Vector2
	if direction.length_squared() <= 0.0001:
		return _last_move_state

	var preferred_state: String = "move_right"
	if absf(direction.y) >= absf(direction.x):
		preferred_state = "move_down" if direction.y > 0.0 else "move_up"
	else:
		preferred_state = "move_right" if direction.x > 0.0 else "move_left"
	_last_move_state = _first_available_state([preferred_state, "move_right", "move_left", "idle"])
	return _last_move_state


## 作用：首个可用状态。
## 使用：本文件由 _get_move_state 调用；输入 states（状态组）；返回 String 文本/标识。
func _first_available_state(states: Array[String]) -> String:
	for state: String in states:
		if VisualConfigApplierScript.has_state_visual(_visual_config, state):
			return state
	return states[0] if not states.is_empty() else "idle"


## 作用：按距离档位隐藏远处敌人或停用中距离动画，近处恢复完整动画。
## 使用：state 提供移动方向；返回 true 表示已由降级显示接管，调用者无需继续切换状态动画。
func _apply_lod(state: Dictionary) -> bool:
	var lod: int = _get_lod()
	if lod == 0:
		_set_ground_shadow_visible(true)
		_resume_animation()
		return false
	if lod == 2:
		_set_visual_visible(false)
		_set_ground_shadow_visible(false)
		_stop_animation()
		_visual_state = ""
		return true
	play_state(_get_move_state(state) if bool(state.get("is_moving", false)) else "idle")
	_set_ground_shadow_visible(true)
	_stop_animation()
	return true


## 作用：按屏幕范围与玩家距离选择完整、停止动画或隐藏显示档位。
## 使用：返回 0/1/2；离屏或距玩家超过 1800 为 2，超过 900 为 1。
func _get_lod() -> int:
	if _owner == null or not _is_on_screen():
		return 2
	var target: Node2D = _owner.get("target") as Node2D
	if target == null:
		return 0
	var distance_squared: float = _owner.global_position.distance_squared_to(target.global_position)
	if distance_squared > HIDE_DISTANCE_SQUARED:
		return 2
	if distance_squared > FULL_ANIMATION_DISTANCE_SQUARED:
		return 1
	return 0


## 作用：判断敌人的画布位置是否位于扩展后的视口可见区域。
## 使用：按 viewport 矩形向外扩展 96 像素；返回是否在范围内，供 _get_lod 分级。
func _is_on_screen() -> bool:
	if _owner == null or _owner.get_viewport() == null:
		return true
	return _owner.get_viewport().get_visible_rect().grow(96.0).has_point(_owner.get_global_transform_with_canvas().origin)


## 作用：设置视觉可见。
## 使用：本文件由 _apply_lod 调用；输入 visible（可见）。
func _set_visual_visible(visible: bool) -> void:
	for name: String in ["Sprite2D", "AnimatedSprite2D"]:
		var node: CanvasItem = _owner.get_node_or_null(name) as CanvasItem
		if node != null:
			node.visible = visible


## 作用：设置地面阴影可见。
## 使用：本文件由 _apply_lod 调用；输入 visible（可见）。
func _set_ground_shadow_visible(visible: bool) -> void:
	var shadow: CanvasItem = _owner.get_node_or_null("GroundShadow") as CanvasItem
	if shadow != null:
		shadow.visible = visible


## 作用：停止动画。
## 使用：本文件由 _apply_lod 调用。
func _stop_animation() -> void:
	var animated_sprite: AnimatedSprite2D = _owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.stop()


## 作用：恢复动画。
## 使用：本文件由 _apply_lod 调用。
func _resume_animation() -> void:
	var animated_sprite: AnimatedSprite2D = _owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null and animated_sprite.visible and not animated_sprite.is_playing():
		animated_sprite.play()
