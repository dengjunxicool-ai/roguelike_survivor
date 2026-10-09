## 文件用途：根据角色视觉配置与移动、受击和死亡状态驱动玩家动画。
## 使用方式：setup 绑定玩家后 apply_character_config；物理更新调用 update，受击调用 show_hurt。

extends RefCounted
class_name PlayerVisualController


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")

var _owner: Node2D
var _visual_config: Dictionary = {}
var _visual_state: String = ""
var _hurt_timer: float = 0.0


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner


## 作用：应用角色配置。
## 使用：供本模块调用者使用；输入 character（角色）。
func apply_character_config(character: Dictionary) -> void:
	var visual_variant: Variant = character.get("visual", {})
	if not (visual_variant is Dictionary):
		return

	var visual: Dictionary = visual_variant
	_visual_config = visual.duplicate(true)
	play_state("idle", true)


## 作用：显示受击。
## 使用：供本模块调用者使用；输入 duration（持续时间）。
func show_hurt(duration: float = 0.16) -> void:
	_hurt_timer = duration
	play_state("hurt")


## 作用：受击计时结束后按生命值与移动输入选择死亡、行走或待机动画。
## 使用：input_direction/current_health/delta 来自玩家物理更新；受击状态期间保持受击表现。
func update(input_direction: Vector2, current_health: int, delta: float) -> void:
	if _visual_config.is_empty():
		return

	if _hurt_timer > 0.0:
		_hurt_timer = maxf(_hurt_timer - delta, 0.0)
		if _hurt_timer > 0.0:
			return


	## direction.x > 0   # 向右
	## direction.x < 0   # 向左
	## direction.y > 0   # 向下
	## direction.y < 0   # 向上
	## direction == Vector2.ZERO # 没动

	if current_health <= 0:
		play_state("death")
	elif input_direction.length_squared() > 0.001:
		play_state(get_move_animation_name(input_direction))
	else:
		play_state("idle")


## 作用：按主移动轴选择上下左右行走动画，并回退到 walk/idle。
## 使用：direction 为移动向量；纵横幅度相等优先纵向，返回首个可用视觉状态。
func get_move_animation_name(direction: Vector2) -> String:
	var preferred_state: String = "walk"
	if absf(direction.y) >= absf(direction.x):
		preferred_state = "walk_down" if direction.y > 0.0 else "walk_up"
	else:
		preferred_state = "walk_right" if direction.x > 0.0 else "walk_left"
	return _first_available_state([preferred_state, "walk", "idle"])


## 作用：将目标动画状态交给统一视觉配置应用器。
## 使用：重复状态默认跳过；force 可强制刷新，缺 owner 或视觉配置时无操作。
func play_state(state: String, force: bool = false) -> void:
	if _owner == null or _visual_config.is_empty():
		return
	if not force and _visual_state == state:
		return
	_visual_state = state
	VisualConfigApplierScript.play_state(_owner, _visual_config, state, "idle")


## 作用：首个可用状态。
## 使用：本文件由 get_move_animation_name 调用；输入 states（状态组）；返回 String 文本/标识。
func _first_available_state(states: Array[String]) -> String:
	for state: String in states:
		if VisualConfigApplierScript.has_state_visual(_visual_config, state):
			return state
	return states[0] if not states.is_empty() else "idle"
