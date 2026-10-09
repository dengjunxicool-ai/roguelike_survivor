## 文件用途：提供敌人行为策略共有的目标、移动、避让和动作请求接口。
## 使用方式：具体策略继承本类，setup 注入 enemy 和配置，然后覆盖 tick。

extends RefCounted
class_name EnemyBehavior


var enemy: Node
var config: Dictionary = {}
var _reported_required_action_failures: Dictionary = {}


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node, behavior_config: Dictionary = {}) -> void:
	enemy = owner
	config = behavior_config.duplicate(true)


## 作用：保留 tick 接口，当前实现不执行操作。
## 使用：现有调用不会改变状态；参数暂未被使用。
func tick(_delta: float) -> void:
	pass


## 作用：获取调试状态，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回字典包含 type。
func get_debug_state() -> Dictionary:
	return {
		"type": String(config.get("type", ""))
	}


## 作用：调用敌人。
## 使用：本文件由 _apply_chase_movement、_should_skip_melee_neighbor_logic、_is_target_in_attack_range 调用；输入 method_name（方法名称）、args（args）；返回 Variant 对象/值。
func _call_enemy(method_name: StringName, args: Array = []) -> Variant:
	if enemy == null or not enemy.has_method(method_name):
		return null
	return enemy.callv(method_name, args)


## 作用：主体。
## 使用：本文件由 _set_velocity、_apply_chase_movement、_idle_if_melee_space_blocked 调用；返回 CharacterBody2D 对象/值。
func _body() -> CharacterBody2D:
	return enemy as CharacterBody2D


## 作用：目标。
## 使用：本文件由 _apply_chase_movement、_idle_if_melee_space_blocked 调用；返回 Node2D 对象/值。
func _target() -> Node2D:
	if enemy == null:
		return null
	return enemy.get("target") as Node2D


## 作用：设置速度。
## 使用：本文件由 _apply_chase_movement、_idle_if_melee_space_blocked 调用；输入 value（值）。
func _set_velocity(value: Vector2) -> void:
	var body: CharacterBody2D = _body()
	if body != null:
		body.velocity = value


## 作用：应用追逐移动。
## 使用：本文件由 _apply_melee_chase_movement 调用；输入 extra_direction（extra方向）。
func _apply_chase_movement(extra_direction: Vector2 = Vector2.ZERO) -> void:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or target == null:
		_set_velocity(Vector2.ZERO)
		return

	var direction: Vector2 = (body.global_position.direction_to(target.global_position) + extra_direction).normalized()
	if bool(config.get("zigzag", false)) and direction != Vector2.ZERO:
		var sway_strength: float = float(config.get("zigzag_strength", 0.45))
		var sway_speed: float = float(config.get("zigzag_speed", 6.0))
		var behavior_time: float = float(enemy.get("_behavior_time")) if enemy != null else 0.0
		var perpendicular: Vector2 = direction.orthogonal()
		direction = (direction + perpendicular * sin(behavior_time * sway_speed) * sway_strength).normalized()

	_set_velocity(direction * float(_call_enemy(&"_get_effective_move_speed")))


## 作用：应用近战追逐移动。
## 使用：内部辅助入口。
func _apply_melee_chase_movement() -> void:
	if _should_skip_melee_neighbor_logic():
		_apply_chase_movement()
		return
	if _idle_if_melee_space_blocked():
		return
	_apply_chase_movement(_get_separation_direction() * float(config.get("separation_strength", 0.25)))


## 作用：待机按条件近战空间阻止。
## 使用：本文件由 _apply_melee_chase_movement 调用；返回是否满足条件或执行成功。
func _idle_if_melee_space_blocked() -> bool:
	var body: CharacterBody2D = _body()
	var target: Node2D = _target()
	if body == null or target == null or _is_target_in_attack_range():
		return false

	var radius: float = float(config.get("melee_crowd_radius", 88.0))
	if body.global_position.distance_squared_to(target.global_position) <= radius * radius:
		return false

	var max_nearby: int = int(config.get("melee_crowd_limit", 10))
	var count: int = 0
	for other: Node2D in _nearby_enemies(target.global_position, radius, max_nearby):
		if other.has_method("get_behavior_type") and not _is_melee_behavior(String(other.call("get_behavior_type"))):
			continue
		if other.global_position.distance_squared_to(target.global_position) <= radius * radius:
			count += 1
			if count >= max_nearby:
				_set_velocity(Vector2.ZERO)
				return true
	return false


## 作用：获取分离方向，供当前模块后续逻辑使用。
## 使用：本文件由 _apply_melee_chase_movement 调用；返回 Vector2 对象/值。
func _get_separation_direction() -> Vector2:
	var body: CharacterBody2D = _body()
	if body == null:
		return Vector2.ZERO
	var radius: float = float(config.get("separation_radius", 30.0))
	var max_neighbors: int = 8
	var separation: Vector2 = Vector2.ZERO
	var checked: int = 0
	for other: Node2D in _nearby_enemies(body.global_position, radius, max_neighbors):
		var offset: Vector2 = body.global_position - other.global_position
		var distance_squared: float = offset.length_squared()
		if distance_squared <= 0.01 or distance_squared > radius * radius:
			continue
		separation += offset.normalized() * (1.0 - sqrt(distance_squared) / radius)
		checked += 1
		if checked >= 8:
			break
	return separation.normalized() if separation.length_squared() > 0.01 else Vector2.ZERO


## 作用：判断近战行为，返回布尔判断结果。
## 使用：本文件由 _idle_if_melee_space_blocked 调用；输入 behavior_type（行为类型）。
func _is_melee_behavior(behavior_type: String) -> bool:
	return behavior_type == "chase_player" or behavior_type == "explode_near_player" or behavior_type == "dash_attack"


## 作用：附近敌人组；具体处理委托给 enemy._nearby_enemies。
## 使用：本文件由 _idle_if_melee_space_blocked、_get_separation_direction 调用；输入 center（中心）、radius（半径）、max_results（上限results）；返回 Array 列表。
func _nearby_enemies(center: Vector2, radius: float, max_results: int = 0) -> Array:
	if enemy != null and enemy.has_method("_nearby_enemies"):
		return enemy.call("_nearby_enemies", center, radius, max_results)
	return []


## 作用：是否需要跳过近战邻居逻辑，返回布尔判断结果。
## 使用：本文件由 _apply_melee_chase_movement 调用。
func _should_skip_melee_neighbor_logic() -> bool:
	return bool(_call_enemy(&"_should_skip_melee_neighbor_logic"))


## 作用：判断目标处于攻击范围内，返回布尔判断结果。
## 使用：本文件由 _idle_if_melee_space_blocked 调用；输入 distance（距离）。
func _is_target_in_attack_range(distance: float = -1.0) -> bool:
	return bool(_call_enemy(&"_is_target_in_attack_range", [distance]))


## 作用：判断目标处于行为攻击范围内，返回布尔判断结果。
## 使用：内部辅助入口；输入 distance（距离）。
func _is_target_in_behavior_attack_range(distance: float = -1.0) -> bool:
	return bool(_call_enemy(&"_is_target_in_behavior_attack_range", [distance]))


## 作用：取消远程攻击预警。
## 使用：内部辅助入口。
func _cancel_ranged_attack_warning() -> void:
	_call_enemy(&"_cancel_ranged_attack_warning")


## 作用：应用范围攻击伤害。
## 使用：内部辅助入口。
func _apply_range_attack_damage() -> void:
	_call_enemy(&"_apply_range_attack_damage")


## 作用：执行必需动作。
## 使用：内部辅助入口；输入 action_type（动作类型）、runtime_params（运行时参数）；返回是否满足条件或执行成功。
func _execute_required_action(action_type: String, runtime_params: Dictionary = {}) -> bool:
	if bool(_call_enemy(&"_execute_enemy_skill_action", [action_type, runtime_params])):
		return true
	if not _reported_required_action_failures.has(action_type):
		_reported_required_action_failures[action_type] = true
		var enemy_id: String = String(enemy.get("enemy_id")) if enemy != null else ""
		push_error("[%s] Required enemy skill action '%s' failed for enemy '%s'." % [get_script().resource_path.get_file(), action_type, enemy_id])
	return false


## 作用：浮点属性。
## 使用：内部辅助入口；输入 property_name（属性名称）、fallback（回退）；返回计算或读取的数值。
func _float_property(property_name: StringName, fallback: float = 0.0) -> float:
	if enemy == null:
		return fallback
	var value: Variant = enemy.get(property_name)
	return fallback if value == null else float(value)


## 作用：设置属性。
## 使用：内部辅助入口；输入 property_name（属性名称）、value（值）。
func _set_property(property_name: StringName, value: Variant) -> void:
	if enemy != null:
		enemy.set(property_name, value)
