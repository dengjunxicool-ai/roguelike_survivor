## 文件用途：实现召唤跟随、追逐、返回、超距传送与跟随主人运动方向的分列偏移。
## 使用方式：召唤控制器持有RefCounted组件，setup传移动配置和编队序号；stationary模式禁止移动。
extends RefCounted
class_name SummonMovementComponent


var move_speed: float = 180.0
var follow_distance: float = 80.0
var min_distance: float = 40.0
var leash_distance: float = 360.0
var teleport_distance: float = 720.0
var separation_radius: float = 32.0
var formation_index: int = 0
var movement_mode: String = "follow"

var _has_owner_position: bool = false
var _last_owner_position: Vector2 = Vector2.ZERO
var _follow_direction: Vector2 = Vector2.LEFT


## 作用：读取速度与跟随/牵引/传送距离及横向间距，重置主人运动追踪。
## 使用：index限制非负，传送距离不小于牵引距离。
func setup(config: Dictionary, index: int) -> void:
	movement_mode = String(config.get("movement_mode", movement_mode))
	move_speed = maxf(float(config.get("move_speed", move_speed)), 1.0)
	follow_distance = maxf(float(config.get("follow_distance", follow_distance)), 0.0)
	min_distance = maxf(float(config.get("min_distance", min_distance)), 0.0)
	leash_distance = maxf(float(config.get("leash_distance", leash_distance)), min_distance)
	teleport_distance = maxf(float(config.get("teleport_distance", teleport_distance)), leash_distance)
	separation_radius = maxf(float(config.get("separation_radius", separation_radius)), 0.0)
	formation_index = maxi(index, 0)
	_has_owner_position = false
	_follow_direction = Vector2.LEFT


## 作用：保存主人位置，移动超过1像素时将跟随方向设为其移动反向。
## 使用：owner为空无操作，首帧仅初始化位置。
func update_owner_motion(owner: Node2D) -> void:
	if owner == null:
		return
	if _has_owner_position:
		var owner_delta: Vector2 = owner.global_position - _last_owner_position
		if owner_delta.length_squared() > 1.0:
			_follow_direction = -owner_delta.normalized()
	_last_owner_position = owner.global_position
	_has_owner_position = true


## 作用：判断非固定召唤是否超出主人牵引距离。
## 使用：stationary始终false，缺节点也false。
func is_beyond_leash(summon: Node2D, owner: Node2D) -> bool:
	if is_stationary():
		return false
	return summon != null and owner != null and summon.global_position.distance_to(owner.global_position) > leash_distance


## 作用：判断非固定召唤是否超出传送距离。
## 使用：stationary始终false，返回布尔值。
func is_beyond_teleport(summon: Node2D, owner: Node2D) -> bool:
	if is_stationary():
		return false
	return summon != null and owner != null and summon.global_position.distance_to(owner.global_position) > teleport_distance


## 作用：把召唤世界位置直接设为主人位置加编队偏移。
## 使用：双方须非空，调用方决定何时超距传送。
func teleport_near_owner(summon: Node2D, owner: Node2D) -> void:
	if summon == null or owner == null:
		return
	summon.global_position = owner.global_position + get_follow_offset()


## 作用：朝主人后方编队位置按速度移动，足够接近主人与编队点时停。
## 使用：stationary无动作，delta为秒。
func move_follow(summon: Node2D, owner: Node2D, delta: float) -> void:
	if is_stationary():
		return
	if summon == null or owner == null:
		return
	var desired: Vector2 = owner.global_position + get_follow_offset()
	if summon.global_position.distance_to(owner.global_position) < min_distance and summon.global_position.distance_to(desired) < min_distance:
		return
	summon.global_position = summon.global_position.move_toward(desired, move_speed * delta)


## 作用：按速度朝目标世界位置移动。
## 使用：stationary或缺节点无动作，攻击范围判断由控制器负责。
func move_chase(summon: Node2D, target: Node2D, delta: float) -> void:
	if is_stationary():
		return
	if summon == null or target == null:
		return
	summon.global_position = summon.global_position.move_toward(target.global_position, move_speed * delta)


## 作用：按速度朝主人编队位置返回。
## 使用：stationary无动作，delta为秒。
func move_return(summon: Node2D, owner: Node2D, delta: float) -> void:
	if is_stationary():
		return
	if summon == null or owner == null:
		return
	var desired: Vector2 = owner.global_position + get_follow_offset()
	summon.global_position = summon.global_position.move_toward(desired, move_speed * delta)


## 作用：按主人移动反向和编队序号交替左右排布跟随偏移。
## 使用：第0个居中，其余按separation_radius逐列展开。
func get_follow_offset() -> Vector2:
	var behind: Vector2 = _follow_direction
	if behind.length_squared() <= 0.0001:
		behind = Vector2.LEFT
	behind = behind.normalized()
	var side: Vector2 = Vector2(-behind.y, behind.x)
	var side_step: float = 0.0
	if formation_index > 0:
		var lane: int = int((formation_index + 1) / 2)
		var sign_value: float = -1.0 if formation_index % 2 == 1 else 1.0
		side_step = sign_value * float(lane) * separation_radius
	return behind * follow_distance + side * side_step


## 作用：判断movement_mode是否为stationary。
## 使用：返回布尔值，供移动和超距查询共用。
func is_stationary() -> bool:
	return movement_mode == "stationary"
