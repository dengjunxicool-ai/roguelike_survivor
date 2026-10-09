## 文件用途：管理经验晶体的待机、吸附、收集与对象池生命周期。
## 使用方式：挂载经验晶体场景；奖励交由 PickupManager 排队发放，复用节点前后调用池生命周期入口。

extends Area2D
class_name ExpGem

const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const PickupManagerScript: Script = preload("res://scripts/drops/pickup_manager.gd")
const PICKUP_STATE_IDLE: StringName = &"idle"
const PICKUP_STATE_MAGNETIZED: StringName = &"magnetized"
const PICKUP_STATE_COLLECTING: StringName = &"collecting"

@export_range(1, 10000, 1, "or_greater") var experience_amount: int = 25
@export_range(1.0, 1000.0, 1.0, "or_greater") var magnet_radius: float = 180.0
@export_range(1.0, 200.0, 1.0, "or_greater") var pickup_radius: float = 24.0
@export_range(1.0, 2000.0, 10.0, "or_greater") var fly_speed: float = 360.0
@export var target_group: StringName = &"player"

var target: Node2D
var _is_collected: bool = false
var _pickup_state: StringName = PICKUP_STATE_IDLE


## 作用：在节点入树后完成组件初始化与信号登记。
## 使用：由 Godot 自动调用；场景中的配置与依赖应在入树前设置。
func _ready() -> void:
	_prepare_active_state()


## 作用：在节点离树时清理其注册关系。
## 使用：由 Godot 自动调用，避免服务继续持有已移除节点。
func _exit_tree() -> void:
	_unregister_pickup_manager()


## 作用：保留 _physics_process 接口，当前实现不执行操作。
## 使用：现有调用不会改变状态；参数暂未被使用。
func _physics_process(delta: float) -> void:
	pass


## 作用：使用当前缓存目标包装一次主动拾取更新。
## 使用：当前 _physics_process 为 pass，不调用此方法；实际拾取由 PickupManager 的 manager_active_update 调度。
func _physics_process_profiled(delta: float) -> void:
	manager_active_update(delta, target, target.global_position if target != null else global_position, _get_target_pickup_radius())


## 作用：设置经验数量。
## 使用：本文件由 prepare_for_pool_spawn 调用；输入 amount（数量）。
func set_experience_amount(amount: int) -> void:
	experience_amount = maxi(amount, 1)


## 作用：恢复节点可见性、碰撞和待机状态并重新登记拾取服务。
## 使用：amount 可覆盖经验量；复用对象在池生成后调用。
func prepare_for_pool_spawn(amount: Variant = null) -> void:
	if amount != null:
		set_experience_amount(int(amount))
	_prepare_active_state()


## 作用：标记已收集并注销管理器、禁用碰撞与隐藏节点。
## 使用：回收对象池前调用；不发放经验奖励。
func prepare_for_pool_despawn() -> void:
	_is_collected = true
	_unregister_pickup_manager()
	target = null
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	remove_from_group(&"experience_crystal")
	visible = false


## 作用：回收或释放。
## 使用：本文件由 _collect 调用。
func despawn_or_free() -> void:
	if has_meta(&"runtime_pool_owner") and has_meta(&"runtime_pool_key"):
		var pool_variant: Variant = get_meta(&"runtime_pool_owner")
		var key: StringName = StringName(String(get_meta(&"runtime_pool_key")))
		if pool_variant is Node and is_instance_valid(pool_variant) and (pool_variant as Node).has_method("despawn"):
			prepare_for_pool_despawn()
			(pool_variant as Node).call("despawn", key, self)
			return
	queue_free()


## 作用：收集转换玩家。
## 使用：供本模块调用者使用；输入 player（玩家）。
func collect_to_player(player: Node2D = null) -> void:
	var collector: Node2D = player
	if collector == null:
		collector = target if is_instance_valid(target) else _find_target()
	if collector != null:
		_collect(collector)


## 作用：获取拾取物状态，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 StringName 文本/标识。
func get_pickup_state() -> StringName:
	return _pickup_state


## 作用：待机扫描中检查收集距离和吸附半径，必要时进入吸附状态。
## 使用：由 PickupManager 的待机分桶调用；player_position/radius 为本帧共享缓存。
func manager_idle_check(player: Node2D, player_position: Vector2, target_pickup_radius: float) -> void:
	if _is_collected:
		return
	target = player
	if target == null:
		return
	var distance_to_target: float = global_position.distance_to(player_position)
	if distance_to_target <= pickup_radius:
		_collect(target)
		return
	if distance_to_target <= maxf(target_pickup_radius, magnet_radius):
		_set_pickup_state(PICKUP_STATE_MAGNETIZED)


## 作用：驱动已吸附晶体朝玩家移动，入收集半径时收集，离吸附范围时回待机。
## 使用：由 PickupManager 每物理帧调用，delta 为秒；已收集或目标缺失时不移动。
func manager_active_update(delta: float, player: Node2D, player_position: Vector2, target_pickup_radius: float) -> void:
	if _is_collected:
		return
	target = player
	if target == null:
		_set_pickup_state(PICKUP_STATE_IDLE)
		return
	var distance_to_target: float = global_position.distance_to(player_position)
	if distance_to_target <= pickup_radius:
		_collect(target)
		return
	var effective_pickup_radius: float = maxf(target_pickup_radius, magnet_radius)
	if distance_to_target > effective_pickup_radius and _pickup_state == PICKUP_STATE_MAGNETIZED:
		_set_pickup_state(PICKUP_STATE_IDLE)
		return
	global_position = global_position.move_toward(
		player_position,
		fly_speed * delta
	)


## 作用：查找目标，供当前模块后续逻辑使用。
## 使用：本文件由 collect_to_player、_prepare_active_state 调用；返回 Node2D 对象/值。
func _find_target() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(target_group) as Node2D


## 作用：先标记已收集，排队经验奖励后回收或释放晶体。
## 使用：重复收集直接返回；无管理器时回退直接 add_experience，保证同一晶体只发一次奖励。
func _collect(player: Node2D) -> void:
	if _is_collected or not player.has_method("add_experience"):
		return

	_is_collected = true
	_set_pickup_state(PICKUP_STATE_COLLECTING)
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("queue_experience_reward"):
		manager.call("queue_experience_reward", player, experience_amount)
	else:
		player.call(&"add_experience", experience_amount)
	despawn_or_free()


## 作用：准备活跃状态。
## 使用：本文件由 _ready、prepare_for_pool_spawn 调用。
func _prepare_active_state() -> void:
	_is_collected = false
	_pickup_state = PICKUP_STATE_IDLE
	visible = true
	set_process(true)
	set_physics_process(false)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if not is_in_group(&"experience_crystal"):
		add_to_group(&"experience_crystal")
	target = _find_target()
	_register_pickup_manager()


## 作用：获取目标拾取半径，供当前模块后续逻辑使用。
## 使用：本文件由 _physics_process_profiled 调用；返回计算或读取的数值。
func _get_target_pickup_radius() -> float:
	if target == null:
		return magnet_radius

	var configured_radius: Variant = target.get("pickup_radius")
	if target.has_method("get_effective_pickup_radius"):
		configured_radius = target.call("get_effective_pickup_radius")
	if configured_radius == null:
		return magnet_radius

	return maxf(float(configured_radius), magnet_radius)


## 作用：设置拾取物状态。
## 使用：本文件由 manager_idle_check、manager_active_update、_collect 调用；输入 new_state（新值状态）。
func _set_pickup_state(new_state: StringName) -> void:
	if _pickup_state == new_state:
		return
	var old_state: StringName = _pickup_state
	_pickup_state = new_state
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("notify_state_changed"):
		manager.call("notify_state_changed", self, old_state, new_state)


## 作用：登记拾取物管理服务；具体处理委托给 manager.register_pickup。
## 使用：本文件由 _prepare_active_state 调用。
func _register_pickup_manager() -> void:
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("register_pickup"):
		manager.call("register_pickup", self)


## 作用：注销拾取物管理服务；具体处理委托给 manager.unregister_pickup。
## 使用：本文件由 _exit_tree、prepare_for_pool_despawn 调用。
func _unregister_pickup_manager() -> void:
	var manager: Node = PickupManagerScript.get_or_create(self)
	if manager != null and manager.has_method("unregister_pickup"):
		manager.call("unregister_pickup", self)
