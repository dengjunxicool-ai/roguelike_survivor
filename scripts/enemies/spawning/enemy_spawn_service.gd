## 文件用途：统一实例化敌人、应用生成倍率、选位和显形预警。
## 使用方式：先 setup 注入场景/owner/RNG，再 spawn；预警中的实体保留在场并暂时关闭行为和碰撞。

extends RefCounted
class_name EnemySpawnService


const EnemySpawnMultipliersScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_multipliers.gd")
const EnemySpawnWarningScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_warning.gd")

var _owner: Node
var _enemy_scene: PackedScene
var _boss_scene: PackedScene
var _target_group: StringName = &"player"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_radius_min: float = 520.0
var _spawn_radius_max: float = 760.0
var _spawn_clearance: float = 56.0
var _visible_spawn_enabled: bool = false
var _visible_spawn_margin: float = 64.0
var _player_safe_radius: float = 120.0
var _spawn_warning_duration: float = 1.5


## 作用：绑定生成 owner、普通/Boss 场景、目标组和随机流。
## 使用：首次生成前调用；若未提供 rng，则随机化本服务独立随机流。
func setup(
	owner: Node,
	enemy_scene: PackedScene,
	boss_scene: PackedScene = null,
	target_group: StringName = &"player",
	rng: RandomNumberGenerator = null
) -> void:
	_owner = owner
	_enemy_scene = enemy_scene
	_boss_scene = boss_scene
	_target_group = target_group
	if rng != null:
		_rng = rng
	else:
		_rng.randomize()


## 作用：设置生成半径范围。
## 使用：供本模块调用者使用；输入 min_radius（下限半径）、max_radius（上限半径）。
func set_spawn_radius_range(min_radius: float, max_radius: float) -> void:
	_spawn_radius_min = maxf(min_radius, 1.0)
	_spawn_radius_max = maxf(max_radius, _spawn_radius_min)


## 作用：设置可见生成规则。
## 使用：供本模块调用者使用；输入 enabled（启用）、viewport_margin（视口边距）、player_safe_radius（玩家safe半径）、warning_duration（预警持续时间）。
func set_visible_spawn_rules(enabled: bool, viewport_margin: float, player_safe_radius: float, warning_duration: float) -> void:
	_visible_spawn_enabled = enabled
	_visible_spawn_margin = maxf(viewport_margin, 0.0)
	_player_safe_radius = maxf(player_safe_radius, 0.0)
	_spawn_warning_duration = maxf(warning_duration, 0.0)


## 作用：实例化敌人并按入树前属性、选位、入树后属性和显形顺序完成生成。
## 使用：request 为生成请求；失败返回 null，成功返回 Node2D；预警中实体已入树并占场。
func spawn(request: Dictionary) -> Node2D:
	var enemy_id: StringName = StringName(String(request.get("enemy_id", "")))
	if enemy_id == &"":
		return null

	var scene_to_spawn: PackedScene = _get_scene(request)
	if scene_to_spawn == null:
		return null

	var enemy: Node2D = scene_to_spawn.instantiate() as Node2D
	if enemy == null:
		return null

	var parent_node: Node = _get_parent_node(request)
	if parent_node == null:
		enemy.queue_free()
		return null

	_apply_pre_ready_values(enemy, enemy_id, request)
	var reveal_enabled: bool = _visible_spawn_enabled and bool(request.get("visible_spawn_warning", false))
	if reveal_enabled:
		_prepare_spawn_reveal(enemy)
	parent_node.add_child(enemy)
	enemy.global_position = _get_position(request, enemy)
	_apply_post_ready_values(enemy, request)
	if reveal_enabled:
		_begin_spawn_reveal(enemy, float(request.get("spawn_warning_duration", _spawn_warning_duration)))
	return enemy


## 作用：获取场景，供当前模块后续逻辑使用。
## 使用：本文件由 spawn 调用；输入 request（请求）；返回 PackedScene 对象/值。
func _get_scene(request: Dictionary) -> PackedScene:
	var scene_override: Variant = request.get("scene", null)
	if scene_override is PackedScene:
		return scene_override
	if bool(request.get("use_boss_scene", false)) and _boss_scene != null:
		return _boss_scene
	if _enemy_scene != null:
		return _enemy_scene
	return load("res://scenes/enemies/enemy.tscn") as PackedScene


## 作用：获取父节点节点，供当前模块后续逻辑使用。
## 使用：本文件由 spawn 调用；输入 request（请求）；返回 Node 对象/值。
func _get_parent_node(request: Dictionary) -> Node:
	var parent_override: Node = request.get("parent", null) as Node
	if parent_override != null:
		return parent_override
	if _owner != null and _owner.get_tree() != null and _owner.get_tree().current_scene != null:
		return _owner.get_tree().current_scene
	return _owner.get_parent() if _owner != null else null


## 作用：在入树前设置 enemy_id、属性倍率、等阶、来源和奖励策略。
## 使用：add_child 前调用，保证 EnemyBase._ready 使用正确初始配置。
func _apply_pre_ready_values(enemy: Node2D, enemy_id: StringName, request: Dictionary) -> void:
	var multipliers: Dictionary = EnemySpawnMultipliersScript.normalize(request.get("multipliers", {}))
	enemy.set("enemy_id", enemy_id)
	enemy.set("health_multiplier", multipliers["hp"])
	enemy.set("damage_multiplier", multipliers["damage"])
	if enemy.get("move_speed_multiplier") != null:
		enemy.set("move_speed_multiplier", multipliers["move_speed"])
	if enemy.get("experience_multiplier") != null:
		enemy.set("experience_multiplier", multipliers["exp"])
	if int(multipliers.get("defense_add", 0)) != 0:
		enemy.set_meta("defense_add", int(multipliers["defense_add"]))

	if request.has("enemy_rank"):
		enemy.set_meta("enemy_rank", String(request["enemy_rank"]))

	enemy.set_meta("spawn_source_type", String(request.get("source_type", "unknown")))
	enemy.set_meta("spawn_source_id", String(request.get("source_id", "")))
	var reward_policy: Dictionary = _get_dictionary(request.get("reward_policy", {}))
	if not reward_policy.is_empty():
		enemy.set_meta("reward_policy", reward_policy)


## 作用：在敌人入树初始化后应用请求中的覆盖属性。
## 使用：post_ready_properties 含血量时补发 health_changed；不会重建配置。
func _apply_post_ready_values(enemy: Node2D, request: Dictionary) -> void:
	var post_ready_properties: Dictionary = _get_dictionary(request.get("post_ready_properties", {}))
	for key: Variant in post_ready_properties.keys():
		enemy.set(String(key), post_ready_properties[key])
	if post_ready_properties.has("current_health") and enemy.has_signal(&"health_changed"):
		enemy.emit_signal(&"health_changed", int(enemy.get("current_health")), int(enemy.get("max_health")))


## 作用：获取位置，供当前模块后续逻辑使用。
## 使用：本文件由 spawn 调用；输入 request（请求）、spawned_enemy（已生成敌人）；返回 Vector2 对象/值。
func _get_position(request: Dictionary, spawned_enemy: Node2D = null) -> Vector2:
	var position_variant: Variant = request.get("position", null)
	if position_variant is Vector2:
		return _find_clear_position(position_variant, request, spawned_enemy, true)

	var target: Node2D = null
	if _owner != null and _owner.get_tree() != null:
		target = _owner.get_tree().get_first_node_in_group(_target_group) as Node2D
	var center: Vector2 = (_owner as Node2D).global_position if _owner is Node2D else Vector2.ZERO
	if target != null:
		center = target.global_position

	return _find_clear_position(center, request, spawned_enemy, false)


## 作用：按尝试预算寻找不与其他敌人过近的生成位置。
## 使用：origin/request 指定中心和规则；所有尝试失败返回最后一个候选点，不丢弃生成预算。
func _find_clear_position(origin: Vector2, request: Dictionary, spawned_enemy: Node2D, around_origin: bool) -> Vector2:
	var attempts: int = maxi(int(request.get("spawn_position_attempts", 10)), 1)
	var clearance: float = maxf(float(request.get("spawn_clearance", _spawn_clearance)), 0.0)
	var last_position: Vector2 = origin
	for attempt: int in range(attempts):
		var candidate: Vector2 = _candidate_position(origin, request, around_origin, attempt)
		last_position = candidate
		if clearance <= 0.0 or _is_position_clear(candidate, clearance, spawned_enemy):
			return candidate
	return last_position


## 作用：候选位置。
## 使用：本文件由 _find_clear_position 调用；输入 origin（来源）、request（请求）、around_origin（周围来源）、attempt（attempt）；返回 Vector2 对象/值。
func _candidate_position(origin: Vector2, request: Dictionary, around_origin: bool, attempt: int) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	if around_origin:
		var radius: float = float(request.get("spawn_position_retry_radius", 72.0)) * (float(attempt + 1) / maxf(float(request.get("spawn_position_attempts", 10)), 1.0))
		return origin + Vector2.RIGHT.rotated(angle) * radius
	if _visible_spawn_enabled and bool(request.get("visible_spawn_warning", false)):
		return _visible_spawn_candidate(origin)
	var radius: float = _rng.randf_range(_spawn_radius_min, _spawn_radius_max)
	return origin + Vector2.RIGHT.rotated(angle) * radius


## 作用：在当前视口内抽样，并优先选择距玩家安全半径外的位置。
## 使用：把屏幕点经逆画布变换为世界坐标；无可用视口时返回 fallback。
func _visible_spawn_candidate(fallback: Vector2) -> Vector2:
	var viewport: Viewport = _owner.get_viewport() if _owner != null and _owner.is_inside_tree() else null
	if viewport == null:
		return fallback
	var screen_rect: Rect2 = viewport.get_visible_rect().grow(-_visible_spawn_margin)
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		return fallback
	var inverse_canvas: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var target: Node2D = viewport.get_tree().get_first_node_in_group(_target_group) as Node2D
	var best_candidate: Vector2 = fallback
	var best_distance_squared: float = -1.0
	for _index: int in range(8):
		var screen_position := Vector2(
			_rng.randf_range(screen_rect.position.x, screen_rect.end.x),
			_rng.randf_range(screen_rect.position.y, screen_rect.end.y)
		)
		var candidate: Vector2 = inverse_canvas * screen_position
		if target == null:
			return candidate
		var distance_squared: float = candidate.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			best_candidate = candidate
			best_distance_squared = distance_squared
		if distance_squared >= _player_safe_radius * _player_safe_radius:
			return candidate
	return best_candidate


## 作用：保存处理模式、碰撞和颜色，关闭行为碰撞并隐藏待显形敌人。
## 使用：敌人入树前调用；设置 spawn_reveal_pending，避免预警阶段攻击。
func _prepare_spawn_reveal(enemy: Node2D) -> void:
	enemy.set_meta("spawn_reveal_pending", true)
	enemy.set_meta("spawn_reveal_process_mode", enemy.process_mode)
	enemy.set_meta("spawn_reveal_collision_layer", enemy.collision_layer)
	enemy.set_meta("spawn_reveal_collision_mask", enemy.collision_mask)
	enemy.set_meta("spawn_reveal_modulate", enemy.modulate)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	var hidden_color: Color = enemy.modulate
	hidden_color.a = 0.0
	enemy.modulate = hidden_color
	enemy.scale *= 0.72


## 作用：创建地面预警并用并行 Tween 渐显敌人。
## 使用：duration 为秒；零时长或无父节点时直接激活。
func _begin_spawn_reveal(enemy: Node2D, duration: float) -> void:
	var parent: Node = enemy.get_parent()
	if parent == null:
		_activate_spawned_enemy(enemy)
		return
	var warning: Node2D = EnemySpawnWarningScript.new()
	warning.z_index = enemy.z_index + 1
	parent.add_child(warning)
	warning.global_position = enemy.global_position
	warning.call("configure", _spawn_clearance * 0.72)
	if duration <= 0.0:
		warning.queue_free()
		_activate_spawned_enemy(enemy)
		return
	var target_color: Color = enemy.get_meta("spawn_reveal_modulate", Color.WHITE)
	var target_scale: Vector2 = enemy.scale / 0.72
	var tween: Tween = parent.create_tween()
	tween.bind_node(warning)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "modulate", target_color, duration)
	tween.tween_property(enemy, "scale", target_scale, duration)
	tween.tween_method(Callable(warning, "set_progress"), 0.0, 1.0, duration)
	tween.chain().tween_callback(Callable(self, "_finish_spawn_reveal").bind(weakref(enemy), weakref(warning)))


## 作用：通过弱引用清理预警并激活仍有效的敌人。
## 使用：显形 Tween 完成回调；已释放或等待删除的敌人不会再次激活。
func _finish_spawn_reveal(enemy_ref: WeakRef, warning_ref: WeakRef) -> void:
	var warning: Node2D = warning_ref.get_ref() as Node2D
	if is_instance_valid(warning):
		warning.queue_free()
	var enemy: Node2D = enemy_ref.get_ref() as Node2D
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		_activate_spawned_enemy(enemy)


## 作用：恢复显形前保存的处理模式、碰撞与颜色并解除待显形标记。
## 使用：仅在预警完成或无需预警时调用。
func _activate_spawned_enemy(enemy: Node2D) -> void:
	enemy.process_mode = int(enemy.get_meta("spawn_reveal_process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
	enemy.collision_layer = int(enemy.get_meta("spawn_reveal_collision_layer", 1))
	enemy.collision_mask = int(enemy.get_meta("spawn_reveal_collision_mask", 0))
	enemy.modulate = enemy.get_meta("spawn_reveal_modulate", Color.WHITE)
	enemy.set_meta("spawn_reveal_pending", false)


## 作用：判断位置清除，返回布尔判断结果。
## 使用：本文件由 _find_clear_position 调用；输入 position（位置）、clearance（clearance）、spawned_enemy（已生成敌人）。
func _is_position_clear(position: Vector2, clearance: float, spawned_enemy: Node2D) -> bool:
	var tree: SceneTree = _owner.get_tree() if _owner != null else null
	if tree == null:
		return true
	var clearance_squared: float = clearance * clearance
	for node: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy == spawned_enemy or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_squared_to(position) < clearance_squared:
			return false
	return true


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _apply_pre_ready_values、_apply_post_ready_values 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}
