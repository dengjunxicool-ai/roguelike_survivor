## 文件用途：实现可池化的圆形/扇形持续区域，处理候选缓存、分帧伤害、状态、action和资源/程序化视觉。
## 使用方式：挂在Area2D战斗区域场景，由CombatObjectFactory.create_area_effect配置；生命周期结束取消碰撞并回池或释放。
extends Area2D
class_name AreaEffect


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const AreaEffectManagerScript: Script = preload("res://scripts/combat/area_effect_manager.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")
const PROGRAMMATIC_VISUAL_REDRAW_INTERVAL: float = 0.08
const MAX_TICK_HITS_PER_AREA_FRAME: int = 2

@export_range(0, 10000, 1, "or_greater") var damage: int = 4
@export_range(0.05, 30.0, 0.05, "or_greater") var duration: float = 3.0
@export_range(0.05, 10.0, 0.05, "or_greater") var tick_interval: float = 1.0
@export_range(1.0, 1000.0, 1.0, "or_greater") var radius: float = 52.0
@export_range(0, 1000, 1, "or_greater") var max_targets: int = 0
@export_range(0.0, 360.0, 1.0) var cone_width_degrees: float = 0.0
@export var cone_direction: Vector2 = Vector2.RIGHT
@export var status_on_hit: StringName = &""
@export var statuses_on_hit: Array[StringName] = []
@export var status_params: Dictionary = {}
@export var status_normal_only: bool = false
@export var damage_type: StringName = &""
@export var damage_packet: Dictionary = {}
@export var target_group: StringName = &"enemies"
@export var area_id: StringName = &""
@export var source_id: StringName = &""
@export var move_direction: Vector2 = Vector2.ZERO
@export_range(0.0, 2000.0, 1.0, "or_greater") var move_speed: float = 0.0
@export var event_on_hit: StringName = &""
@export var event_on_expire: StringName = &""
@export var finish_after_damage: bool = false
@export var damage_once_per_body: bool = false
@export var impact_target_id: String = ""
@export var impact_target_damage_multiplier: float = 1.0

var _age: float = 0.0
var _tick_timer: float = 0.0
var _visual_config: Dictionary = {}
var _visual_mode: String = ""
var _visual_style: String = ""
var _visual_color: Color = Color(0.35, 0.95, 0.2, 0.32)
var _visual_ring_color: Color = Color(0.75, 1.0, 0.25, 0.66)
var _visual_seed: float = 0.0
var _redraw_timer: float = 0.0
var _damage_window_finished: bool = false
var _finished_by_damage: bool = false
var _base_radius: float = 52.0
var _expand_from_radius: float = -1.0
var _expand_to_radius: float = -1.0
var _damaged_body_ids: Dictionary = {}
var _current_tick_targets_hit: int = 0
var _candidate_body_ids: Dictionary = {}
var _candidate_body_order: Array[int] = []
var _candidate_cache_seeded: bool = false
var _area_effect_manager: Node = null
var _current_tick_stats: Dictionary = {}
var _pending_tick_target_ids: Array[int] = []
var _pending_tick_index: int = 0
var _pending_tick_stats: Dictionary = {}
var _dash_path_filter: bool = false
var _dash_path_start: Vector2 = Vector2.ZERO
var _dash_path_end: Vector2 = Vector2.ZERO
var event_bus: Node
var skill_instance: RefCounted
var caster: Node
var skill_manager: Node
var relic_manager: Node
var impact_target: Node
var actions_on_apply: Array = []
var actions_on_tick: Array = []
var actions_on_hit: Array = []
var actions_on_expire: Array = []
var actions_on_death: Array = []

static var _status_apply_coalesce_frame: int = -1
static var _status_apply_coalesce_keys: Dictionary = {}


## 作用：生成视觉相位种子、连接碰撞候选信号并设置初始半径。
## 使用：节点入树自动调用，生成参数由setup随后应用。
func _ready() -> void:
	_visual_seed = float(get_instance_id() % 997) / 997.0 * TAU
	_connect_candidate_signals()
	_apply_radius(radius)


## 作用：按核心、payload、action、上下文、视觉顺序配置，再重置状态启用碰撞与tick登记。
## 使用：params为spawn参数；执行on_apply后才裁剪同来源活跃数量。
func setup(params: Dictionary) -> void:
	_apply_area_core_params(params)
	_apply_area_payload_params(params)
	_apply_area_action_params(params)
	_apply_area_context_params(params)
	_apply_area_visual_params(params)
	_reset_area_runtime_state(params)
	_enable_area_collision()
	_apply_radius(radius)
	_apply_visual(params)
	_register_area_effect()
	_execute_apply_actions()
	_enforce_max_active(int(params.get("max_active", 0)))


## 作用：恢复显示与处理并调用setup重建本次spawn状态。
## 使用：params为对象完整生成参数，池复用时调用。
func prepare_for_pool_spawn(params: Dictionary) -> void:
	visible = true
	set_process(true)
	set_physics_process(true)
	setup(params)


## 作用：关闭伤害窗口与碰撞，清空引用、action、命中/候选/待处理tick并注销调度。
## 使用：回池前调用，隐藏节点避免残留上下文污染下一次spawn。
func prepare_for_pool_despawn() -> void:
	_damage_window_finished = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.stop()
	event_bus = null
	skill_instance = null
	caster = null
	skill_manager = null
	relic_manager = null
	impact_target = null
	_dash_path_filter = false
	_dash_path_start = Vector2.ZERO
	_dash_path_end = Vector2.ZERO
	actions_on_apply.clear()
	actions_on_tick.clear()
	actions_on_hit.clear()
	actions_on_expire.clear()
	actions_on_death.clear()
	_damaged_body_ids.clear()
	_clear_pending_tick_damage()
	_clear_candidate_cache()
	_unregister_area_effect()
	visible = false


## 作用：有有效runtime池元数据时清理并回池，否则queue_free释放。
## 使用：生命周期结束入口；池路径会调用prepare_for_pool_despawn。
func despawn_or_free() -> void:
	if has_meta(&"runtime_pool_owner") and has_meta(&"runtime_pool_key"):
		var pool_variant: Variant = get_meta(&"runtime_pool_owner")
		var key: StringName = StringName(String(get_meta(&"runtime_pool_key")))
		if pool_variant is Node and is_instance_valid(pool_variant) and (pool_variant as Node).has_method("despawn"):
			prepare_for_pool_despawn()
			(pool_variant as Node).call("despawn", key, self)
			return
	queue_free()


## 作用：读取伤害量、时长、tick间隔、半径、目标上限和扇形方向。
## 使用：规范数值边界，零方向回退向右，否则归一化。
func _apply_area_core_params(params: Dictionary) -> void:
	damage = maxi(int(params.get("damage", damage)), 0)
	duration = maxf(float(params.get("duration", duration)), 0.05)
	tick_interval = maxf(float(params.get("tick_interval", tick_interval)), 0.05)
	radius = maxf(float(params.get("radius", params.get("area_radius", radius))), 1.0)
	max_targets = maxi(int(params.get("max_targets", max_targets)), 0)
	cone_width_degrees = clampf(float(params.get("cone_width_degrees", cone_width_degrees)), 0.0, 360.0)
	cone_direction = _get_vector2(params.get("cone_direction", cone_direction), Vector2.RIGHT)
	if cone_direction.length_squared() <= 0.0001:
		cone_direction = Vector2.RIGHT
	else:
		cone_direction = cone_direction.normalized()


## 作用：读取状态、伤害模板、目标组、来源、移动和命中/结束事件。
## 使用：移动方向规范为单位向量或零向量。
func _apply_area_payload_params(params: Dictionary) -> void:
	status_on_hit = StringName(String(params.get("status_on_hit", status_on_hit)))
	statuses_on_hit = _get_status_array(params.get("statuses_on_hit", []), status_on_hit)
	status_params = _get_dictionary(params.get("status_params", status_params))
	status_normal_only = bool(params.get("status_normal_only", status_normal_only))
	damage_type = StringName(String(params.get("damage_type", damage_type)))
	damage_packet = _get_dictionary(params.get("damage_packet", damage_packet))
	target_group = StringName(String(params.get("target_group", target_group)))
	area_id = StringName(String(params.get("area_id", area_id)))
	source_id = StringName(String(params.get("source_id", source_id)))
	move_direction = _get_vector2(params.get("move_direction", move_direction), Vector2.ZERO)
	move_direction = move_direction.normalized() if move_direction.length_squared() > 0.0001 else Vector2.ZERO
	move_speed = maxf(float(params.get("move_speed", move_speed)), 0.0)
	event_on_hit = StringName(String(params.get("event_on_hit", event_on_hit)))
	event_on_expire = StringName(String(params.get("event_on_expire", event_on_expire)))


## 作用：复制各生命周期action并配置一次命中、触发结束、主目标加成与冲刺路径过滤。
## 使用：params用于spawn，路径坐标是世界坐标。
func _apply_area_action_params(params: Dictionary) -> void:
	actions_on_apply = _get_array(params.get("actions_on_apply", []))
	actions_on_tick = _get_array(params.get("actions_on_tick", []))
	actions_on_hit = _get_array(params.get("actions_on_hit", []))
	actions_on_expire = _get_array(params.get("actions_on_expire", []))
	actions_on_death = _get_array(params.get("actions_on_death", []))
	finish_after_damage = bool(params.get("finish_after_damage", finish_after_damage))
	damage_once_per_body = bool(params.get("damage_once_per_body", damage_once_per_body))
	impact_target_id = String(params.get("impact_target_id", impact_target_id))
	impact_target_damage_multiplier = maxf(float(params.get("impact_target_damage_multiplier", impact_target_damage_multiplier)), 0.0)
	_dash_path_filter = bool(params.get("dash_path_filter", false))
	_dash_path_start = _get_vector2(params.get("dash_path_start", Vector2.ZERO), Vector2.ZERO)
	_dash_path_end = _get_vector2(params.get("dash_path_end", Vector2.ZERO), Vector2.ZERO)


## 作用：补稳定来源与追踪，绑定caster、技能、事件总线、遗物和主目标。
## 使用：供后续事件/action保留来源，不执行伤害。
func _apply_area_context_params(params: Dictionary) -> void:
	_stabilize_damage_packet_source("area", params)
	DamageTraceContextScript.apply_to_node_meta(self, params)
	damage_packet = DamageTraceContextScript.apply_to_packet(damage_packet, params)
	event_bus = params.get("event_bus") as Node
	skill_instance = params.get("skill_instance") as RefCounted
	caster = params.get("caster") as Node
	skill_manager = params.get("skill_manager") as Node
	relic_manager = params.get("relic_manager") as Node
	impact_target = params.get("impact_target") as Node


## 作用：读取视觉模式、风格及填充/轮廓颜色。
## 使用：颜色使用解析函数回退当前值。
func _apply_area_visual_params(params: Dictionary) -> void:
	_visual_mode = String(params.get("visual_mode", _visual_mode))
	_visual_style = String(params.get("visual_style", ""))
	_visual_color = _get_color(params.get("visual_color", _visual_color), _visual_color)
	_visual_ring_color = _get_color(params.get("visual_ring_color", _visual_ring_color), _visual_ring_color)


## 作用：重置年龄、tick、结束标记、命中记录、候选及待处理队列。
## 使用：支持扩圈参数，启用时初始radius取expand_from_radius。
func _reset_area_runtime_state(params: Dictionary) -> void:
	_age = 0.0
	_tick_timer = 0.0
	_damage_window_finished = false
	_finished_by_damage = false
	_redraw_timer = 0.0
	_base_radius = radius
	_expand_from_radius = float(params.get("expand_from_radius", -1.0))
	_expand_to_radius = float(params.get("expand_to_radius", -1.0))
	_damaged_body_ids.clear()
	_current_tick_targets_hit = 0
	_current_tick_stats = {}
	_clear_pending_tick_damage()
	_clear_candidate_cache()
	if _uses_expanding_radius():
		radius = maxf(_expand_from_radius, 1.0)


## 作用：确保信号连接并deferred启用监测和碰撞形状。
## 使用：monitorable保持false；物理帧安全写入。
func _enable_area_collision() -> void:
	_connect_candidate_signals()
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)


## 作用：幂等连接body_entered与body_exited维护候选缓存。
## 使用：ready和重新spawn均可调用，不重复连接。
func _connect_candidate_signals() -> void:
	if not body_entered.is_connected(Callable(self, "_on_body_entered")):
		body_entered.connect(Callable(self, "_on_body_entered"))
	if not body_exited.is_connected(Callable(self, "_on_body_exited")):
		body_exited.connect(Callable(self, "_on_body_exited"))


## 作用：取得全局区域管理器并登记当前区域tick。
## 使用：管理器失败时后续使用无预算回退。
func _register_area_effect() -> void:
	_area_effect_manager = AreaEffectManagerScript.get_or_create(self)
	if _area_effect_manager != null and _area_effect_manager.has_method("register_area"):
		_area_effect_manager.call("register_area", self, tick_interval)


## 作用：从有效管理器注销并清本地引用。
## 使用：伤害窗口结束或回池时调用。
func _unregister_area_effect() -> void:
	if _area_effect_manager != null and is_instance_valid(_area_effect_manager) and _area_effect_manager.has_method("unregister_area"):
		_area_effect_manager.call("unregister_area", self)
	_area_effect_manager = null


## 作用：必要时重新登记，再查询当前区域是否轮到tick桶。
## 使用：无管理器/接口时允许tick。
func _area_effect_manager_allows_tick() -> bool:
	if _area_effect_manager == null or not is_instance_valid(_area_effect_manager):
		_register_area_effect()
	if _area_effect_manager == null or not _area_effect_manager.has_method("request_tick"):
		return true
	return bool(_area_effect_manager.call("request_tick", self))


## 作用：创建候选、命中、状态施加计数均为0的统计字典。
## 使用：每次新tick使用独立字典。
func _new_tick_stats() -> Dictionary:
	return {
		"candidate_count": 0,
		"hit_count": 0,
		"status_apply_count": 0
	}


## 作用：向区域管理器提交本次tick统计。
## 使用：必要时重取管理器，通常待处理队列耗尽后调用。
func _record_current_tick_stats() -> void:
	if _area_effect_manager == null or not is_instance_valid(_area_effect_manager):
		_register_area_effect()
	if _area_effect_manager != null and _area_effect_manager.has_method("record_tick"):
		_area_effect_manager.call("record_tick", self, _current_tick_stats)


## 作用：向管理器申请当帧命中额度，管理器缺失时全额返回。
## 使用：desired_count非正返回0；额度消费由管理器记录。
func _request_tick_hit_budget(desired_count: int) -> int:
	if desired_count <= 0:
		return 0
	if _area_effect_manager == null or not is_instance_valid(_area_effect_manager):
		_register_area_effect()
	if _area_effect_manager != null and _area_effect_manager.has_method("request_hit_budget"):
		return int(_area_effect_manager.call("request_hit_budget", self, desired_count))
	return desired_count


## 作用：清候选ID表、遍历顺序并允许下次重新播种。
## 使用：新spawn或回池调用，不释放目标。
func _clear_candidate_cache() -> void:
	_candidate_body_ids.clear()
	_candidate_body_order.clear()
	_candidate_cache_seeded = false


## 作用：清待命中ID、游标和tick统计。
## 使用：队列完成、重置或回池时调用。
func _clear_pending_tick_damage() -> void:
	_pending_tick_target_ids.clear()
	_pending_tick_index = 0
	_pending_tick_stats = {}


## 作用：将进入碰撞体登记为目标候选。
## 使用：Area2D信号回调，仅有效且匹配target_group的节点加入。
func _on_body_entered(body: Node) -> void:
	_add_candidate(body)


## 作用：从候选表和顺序数组移除离开碰撞体。
## 使用：Area2D信号回调，不清一次性命中历史。
func _on_body_exited(body: Node) -> void:
	_remove_candidate(body)


## 作用：按实例ID去重添加符合目标组的候选。
## 使用：只保存ID，不强持有节点引用。
func _add_candidate(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group(target_group):
		return
	var body_id: int = int(body.get_instance_id())
	if _candidate_body_ids.has(body_id):
		return
	_candidate_body_ids[body_id] = true
	_candidate_body_order.append(body_id)


## 作用：按实例ID从缓存和遍历顺序删除节点。
## 使用：节点为空或未登记时无操作。
func _remove_candidate(body: Node) -> void:
	if body == null:
		return
	var body_id: int = int(body.get_instance_id())
	if not _candidate_body_ids.has(body_id):
		return
	_candidate_body_ids.erase(body_id)
	_candidate_body_order.erase(body_id)


## 作用：首次tick用空间查询补充已处于区域内的候选。
## 使用：每spawn只播种一次，之后依赖出入信号。
func _seed_candidate_cache_if_needed() -> void:
	if _candidate_cache_seeded:
		return
	_candidate_cache_seeded = true
	for body: Node2D in query_target_candidates(global_position, radius):
		_add_candidate(body)


## 作用：敌人组使用注册表半径查询，其余组用物理圆形查询。
## 使用：origin/query_radius为世界坐标与半径，返回有效二维候选。
func query_target_candidates(origin: Vector2, query_radius: float) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if target_group == &"enemies" or target_group == &"enemy":
		var registry: Node = CombatTargetRegistryScript.get_or_create(self)
		var targets: Array = registry.call("get_targets_in_radius", origin, query_radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
		for node: Node in targets:
			var target: Node2D = node as Node2D
			if target == null or _candidate_should_prune(target):
				continue
			candidates.append(target)
		return candidates

	var world: World2D = get_world_2d()
	if world == null:
		return candidates
	var shape := CircleShape2D.new()
	shape.radius = maxf(query_radius, 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	var hits: Array[Dictionary] = world.direct_space_state.intersect_shape(query, 512)
	for hit: Dictionary in hits:
		var body: Node2D = hit.get("collider") as Node2D
		if body == null or not body.is_in_group(target_group):
			continue
		if _candidate_should_prune(body):
			continue
		candidates.append(body)
	return candidates


## 作用：检查候选是否释放中、组不匹配或已死。
## 使用：true时调用方应从缓存移除。
func _candidate_should_prune(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return true
	if not body.is_in_group(target_group):
		return true
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		return true
	return false


## 作用：直接按失效实例ID删缓存与顺序项。
## 使用：body_id=0忽略，用于无法恢复节点的队列项。
func _prune_candidate_id(body_id: int) -> void:
	if body_id == 0:
		return
	_candidate_body_ids.erase(body_id)
	_candidate_body_order.erase(body_id)


## 作用：把剩余时间延长到请求值但不超过允许上限。
## 使用：target_duration指希望保留的剩余秒数，duration按当前年龄重新写入。
func extend_duration(target_duration: float, max_duration: float = 5.0) -> void:
	var remaining: float = maxf(duration - _age, 0.0)
	var new_remaining: float = minf(maxf(remaining, target_duration), max_duration)
	duration = _age + new_remaining


## 作用：更新正半径、碰撞形状并请求重绘。
## 使用：new_radius为世界范围，最少1。
func set_effect_radius(new_radius: float) -> void:
	radius = maxf(new_radius, 1.0)
	_apply_radius(radius)
	queue_redraw()


## 作用：伤害窗口开启时立即发起一次tick并推迟下一tick到生命周期之外。
## 使用：供调试攻击trace使用；分帧队列仍会继续消费。
func apply_immediate_tick_once() -> void:
	if _damage_window_finished:
		return
	_apply_tick_damage()
	_tick_timer = duration + tick_interval


## 作用：以性能采样包装区域移动、扩圈、预算tick和结束处理。
## 使用：引擎每物理帧传delta。
func _physics_process(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_physics_process_profiled(delta)
	HotPathProfilerScript.end(self, &"area_effect_update", hot_path_start)


## 作用：推进年龄与移动，优先消费积压目标，再按分桶tick和到期结束。
## 使用：未耗尽队列时提前返回，保留本次tick目标处理。
func _physics_process_profiled(delta: float) -> void:
	if _damage_window_finished:
		return

	_age += delta
	if move_speed > 0.0 and move_direction.length_squared() > 0.0001:
		global_position += move_direction * move_speed * delta
	_update_expanding_radius()
	if _uses_programmatic_visual():
		_queue_programmatic_visual_redraw(delta)

	if not _pending_tick_target_ids.is_empty():
		_apply_tick_damage()
		if not _pending_tick_target_ids.is_empty():
			return

	_tick_timer -= delta
	if _tick_timer <= 0.0 and _area_effect_manager_allows_tick():
		_tick_timer = tick_interval
		_apply_tick_damage()

	if _age >= duration:
		_finish_damage_window()


## 作用：以0.08秒间隔合并程序化重绘。
## 使用：delta推进倒计时，不每帧重绘。
func _queue_programmatic_visual_redraw(delta: float) -> void:
	_redraw_timer = maxf(_redraw_timer - delta, 0.0)
	if _redraw_timer > 0.0:
		return
	_redraw_timer = PROGRAMMATIC_VISUAL_REDRAW_INTERVAL
	queue_redraw()


## 作用：按area_id或source_id裁剪同父节点的可见同来源区域，先移除最旧。
## 使用：max_active<=0不限量；裁剪通过生命周期入口回池。
func _enforce_max_active(max_active: int) -> void:
	if max_active <= 0 or get_parent() == null:
		return

	var grouping_key: StringName = area_id if area_id != &"" else source_id
	if grouping_key == &"":
		return

	var matches: Array[Node] = []
	for child: Node in get_parent().get_children():
		var area: AreaEffect = child as AreaEffect
		if area == null or not is_instance_valid(area) or area.is_queued_for_deletion() or not area.visible:
			continue
		var area_grouping_key: StringName = area.get("area_id") if area.get("area_id") != &"" else area.get("source_id")
		if String(area_grouping_key) != String(grouping_key):
			continue
		matches.append(area)

	while matches.size() > max_active:
		var oldest: Node = _oldest_area_effect(matches)
		if oldest == null:
			return
		matches.erase(oldest)
		if oldest.has_method("despawn_or_free"):
			oldest.call("despawn_or_free")
		else:
			oldest.queue_free()


## 作用：选择年龄最大区域，年龄相同时取较小实例ID。
## 使用：areas为有效区域节点列表，空列表返回null。
func _oldest_area_effect(areas: Array[Node]) -> Node:
	var oldest: Node = null
	var oldest_age: float = -INF
	var oldest_instance_id: int = 0
	for area: Node in areas:
		var age: float = float(area.get("_age"))
		var instance_id: int = int(area.get_instance_id())
		if oldest == null or age > oldest_age or (is_equal_approx(age, oldest_age) and instance_id < oldest_instance_id):
			oldest = area
			oldest_age = age
			oldest_instance_id = instance_id
	return oldest


## 作用：以性能采样包装新tick发起或待命中队列消费。
## 使用：不保证单次调用处理完所有目标。
func _apply_tick_damage() -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_apply_tick_damage_profiled()
	HotPathProfilerScript.end(self, &"area_effect_tick", hot_path_start)


## 作用：有积压则继续消费，否则收集目标ID并建立本次统计/队列。
## 使用：没有伤害、状态或action工作时直接返回。
func _apply_tick_damage_profiled() -> void:
	if not _pending_tick_target_ids.is_empty():
		_drain_pending_tick_damage()
		return

	if damage <= 0 and status_on_hit == &"" and statuses_on_hit.is_empty() and event_on_hit == &"" and actions_on_tick.is_empty() and actions_on_hit.is_empty() and actions_on_death.is_empty():
		return

	_pending_tick_stats = _new_tick_stats()
	_current_tick_stats = _pending_tick_stats
	var targets: Array[Node] = _collect_tick_damage_targets()
	_pending_tick_target_ids = _get_target_instance_ids(targets)
	_pending_tick_index = 0
	_current_tick_targets_hit = targets.size()
	_pending_tick_stats["hit_count"] = targets.size()
	_drain_pending_tick_damage()


## 作用：按单区域每帧最多2目标和全局额度逐步处理队列。
## 使用：失效目标清缓存；队列结束提交统计并清状态。
func _drain_pending_tick_damage() -> void:
	if _pending_tick_target_ids.is_empty():
		return
	var grant: int = _request_tick_hit_budget(mini(MAX_TICK_HITS_PER_AREA_FRAME, _pending_tick_target_ids.size() - _pending_tick_index))
	if grant <= 0:
		return
	_current_tick_stats = _pending_tick_stats
	var processed: int = 0
	while processed < grant and _pending_tick_index < _pending_tick_target_ids.size():
		if _damage_window_finished:
			break
		var body_id: int = int(_pending_tick_target_ids[_pending_tick_index])
		_pending_tick_index += 1
		processed += 1
		var body: Node = instance_from_id(body_id) as Node
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			_prune_candidate_id(body_id)
			continue
		_damage_body(body)
	if _damage_window_finished or _pending_tick_index >= _pending_tick_target_ids.size():
		_record_current_tick_stats()
		_clear_pending_tick_damage()
		_current_tick_targets_hit = 0
	_current_tick_stats = {}


## 作用：从有效目标保存整数实例ID列表。
## 使用：过滤释放中节点，避免长时间持有目标引用。
func _get_target_instance_ids(targets: Array[Node]) -> Array[int]:
	var target_ids: Array[int] = []
	for target: Node in targets:
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		target_ids.append(int(target.get_instance_id()))
	return target_ids


## 作用：用缓存快照过滤有效目标、一次性命中、路径和几何形状并遵守max_targets。
## 使用：返回本次目标列表并保存候选计数。
func _collect_tick_damage_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var damaged_bodies: Dictionary = {}
	var damaged_count: int = 0

	_seed_candidate_cache_if_needed()
	var candidate_count: int = 0
	var radius_squared: float = radius * radius
	var snapshot: Array[int] = _candidate_body_order.duplicate()
	for body_id: int in snapshot:
		if _damage_window_finished:
			break
		if max_targets > 0 and damaged_count >= max_targets:
			break
		var body: Node2D = instance_from_id(body_id) as Node2D
		if body == null or damaged_bodies.has(body):
			_prune_candidate_id(body_id)
			continue
		if _candidate_should_prune(body):
			_prune_candidate_id(body_id)
			continue
		candidate_count += 1
		if not _can_damage_body(body):
			continue
		if global_position.distance_squared_to(body.global_position) <= radius_squared and _body_in_effect_shape(body):
			targets.append(body)
			damaged_bodies[body] = true
			damaged_count += 1
	if not _current_tick_stats.is_empty():
		_current_tick_stats["candidate_count"] = candidate_count
	return targets


## 作用：检查目标组、一次命中历史及冲刺路径过滤。
## 使用：只判资格，不检查圆/扇几何或施加伤害。
func _can_damage_body(body: Node) -> bool:
	if body == null or not body.is_in_group(target_group):
		return false
	if damage_once_per_body and _damaged_body_ids.has(body.get_instance_id()):
		return false
	if _dash_path_filter and not _is_body_on_dash_path(body):
		return false
	return true


## 作用：计算目标到冲刺线段的最近点并用双方碰撞半径加8像素判断接触。
## 使用：零长度路径返回false，使用world坐标。
func _is_body_on_dash_path(body: Node) -> bool:
	var body_node: Node2D = body as Node2D
	if body_node == null:
		return false
	var path: Vector2 = _dash_path_end - _dash_path_start
	var path_length_squared: float = path.length_squared()
	if path_length_squared <= 0.001:
		return false
	var body_offset: Vector2 = body_node.global_position - _dash_path_start
	var along_path: float = clampf(body_offset.dot(path) / path_length_squared, 0.0, 1.0)
	var closest_point: Vector2 = _dash_path_start + path * along_path
	var clearance: float = _get_collision_radius(caster as Node2D, 24.0) + _get_collision_radius(body_node, 24.0) + 8.0
	return closest_point.distance_squared_to(body_node.global_position) <= clearance * clearance


## 作用：读取圆形CollisionShape2D半径，否则返回默认半径。
## 使用：用于几何路径与目标间距判断，不改变形状。
func _get_collision_radius(node: Node2D, fallback: float) -> float:
	if node == null:
		return fallback
	var collision_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return maxf((collision_shape.shape as CircleShape2D).radius, 0.0)
	return fallback


## 作用：检查目标中心位于半径内且符合扇形角度。
## 使用：宽度<=0或>=360视作圆形，圆心目标总符合角度。
func _body_in_effect_shape(body: Node) -> bool:
	var body_node: Node2D = body as Node2D
	if body_node == null:
		return false
	var to_body: Vector2 = body_node.global_position - global_position
	if to_body.length_squared() > radius * radius:
		return false
	if cone_width_degrees <= 0.0 or cone_width_degrees >= 360.0:
		return true
	if to_body.length_squared() <= 0.0001:
		return true
	var half_angle: float = deg_to_rad(cone_width_degrees) * 0.5
	return absf(cone_direction.angle_to(to_body.normalized())) <= half_angle


## 作用：按伤害、状态、tick/命中事件、tick/命中/死亡action顺序处理目标。
## 使用：返回是否处理；记录一次命中，finish_after_damage可立即结束窗口。
func _damage_body(body: Node) -> bool:
	if not _can_damage_body(body):
		return false
	var body_id: int = body.get_instance_id()

	if damage > 0 and body.has_method("take_damage"):
		body.call(&"take_damage", _get_damage_payload(body))
	_increment_current_tick_status_apply(_apply_status(body))
	_emit_area_event(&"area_tick", body)
	_emit_area_event(event_on_hit, body)
	_execute_adapted_actions(actions_on_tick, body)
	_execute_adapted_actions(actions_on_hit, body)
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		_execute_adapted_actions(actions_on_death, body)
	if damage_once_per_body:
		_damaged_body_ids[body_id] = true
	if finish_after_damage:
		_finished_by_damage = true
		_finish_damage_window()
	return true


## 作用：复制模板并按指定主目标倍率调整伤害量，构造typed区域包。
## 使用：target为当前命中对象，来源模板与追踪保持。
func _get_damage_payload(target: Node = null) -> DamagePacket:
	var adjusted_damage: int = _get_adjusted_damage_for_target(target)
	var packet_template: Dictionary = damage_packet.duplicate(true)
	if adjusted_damage != damage:
		packet_template["raw_amount"] = adjusted_damage
		packet_template["amount"] = adjusted_damage
	return DamagePacketBuilderScript.from_combat_object_hit_object({
		"template": packet_template,
		"target": target,
		"amount": adjusted_damage,
		"source_type": "area",
		"source_id": source_id,
		"source_origin_id": StringName(String(damage_packet.get("source_origin_id", ""))),
		"source_skill_id": StringName(String(damage_packet.get("source_skill_id", source_id))),
		"source_instance_id": str(get_instance_id()),
		"instance_id": get_instance_id(),
		"default_damage_origin": "field",
		"default_damage_type": damage_type if damage_type != &"" else &"area_direct",
		"default_element": &"physical"
	})


## 作用：仅对impact_target_id对应节点放大伤害量并四舍五入。
## 使用：其余目标返回damage，不改区域默认伤害量。
func _get_adjusted_damage_for_target(target: Node = null) -> int:
	if target == null or impact_target_id == "" or impact_target_damage_multiplier == 1.0:
		return damage
	if str(target.get_instance_id()) == impact_target_id:
		return maxi(roundi(float(damage) * impact_target_damage_multiplier), 0)
	return damage


## 作用：为非空模板补缺失的实例、来源类型与技能身份。
## 使用：保留显式来源，持续命中复用节点实例ID。
func _stabilize_damage_packet_source(default_source_type: String, params: Dictionary = {}) -> void:
	if damage_packet.is_empty():
		return
	if not damage_packet.has("source_instance_id") or String(damage_packet.get("source_instance_id", "")) == "":
		damage_packet["source_instance_id"] = str(get_instance_id())
	if not damage_packet.has("source_type") or String(damage_packet.get("source_type", "")) == "":
		damage_packet["source_type"] = default_source_type
	if (not damage_packet.has("source_id") or String(damage_packet.get("source_id", "")) == "") and source_id != &"":
		damage_packet["source_id"] = source_id
	if not damage_packet.has("source_skill_id") or String(damage_packet.get("source_skill_id", "")) == "":
		damage_packet["source_skill_id"] = StringName(String(params.get("source_skill_id", params.get("skill_id", source_id))))
	if not damage_packet.has("source_origin_id") or String(damage_packet.get("source_origin_id", "")) == "":
		damage_packet["source_origin_id"] = StringName(String(params.get("source_origin_id", "")))


## 作用：对有效状态列表施加状态，可排除精英/Boss并按同帧目标/状态合并。
## 使用：返回调用施加接口次数供性能统计；不等同于成功状态数量。
func _apply_status(body: Node) -> int:
	if statuses_on_hit.is_empty() and status_on_hit != &"":
		statuses_on_hit = [status_on_hit]
	if statuses_on_hit.is_empty():
		return 0
	if status_normal_only and _is_strong_target(body):
		return 0

	var applied_count: int = 0
	for status_id: StringName in statuses_on_hit:
		if status_id == &"":
			continue
		if _should_coalesce_status_apply(body, status_id):
			continue

		if body.has_method("apply_status"):
			body.call(&"apply_status", status_id, status_params)
			applied_count += 1
		elif body.has_method("add_status_effect"):
			body.call(&"add_status_effect", status_id)
			applied_count += 1
	return applied_count


## 作用：把正状态施加次数累加进当前tick统计。
## 使用：没有统计字典时无操作。
func _increment_current_tick_status_apply(amount: int) -> void:
	if amount <= 0 or _current_tick_stats.is_empty():
		return
	_current_tick_stats["status_apply_count"] = int(_current_tick_stats.get("status_apply_count", 0)) + amount


## 作用：按物理帧、目标ID和状态ID去重区域重复施加。
## 使用：首次登记返回false，重复/非法输入返回true。
func _should_coalesce_status_apply(body: Node, status_id: StringName) -> bool:
	if body == null or status_id == &"":
		return true
	var frame: int = int(Engine.get_physics_frames())
	if _status_apply_coalesce_frame != frame:
		_status_apply_coalesce_frame = frame
		_status_apply_coalesce_keys.clear()
	var key: String = "%d|%s" % [int(body.get_instance_id()), String(status_id)]
	if _status_apply_coalesce_keys.has(key):
		return true
	_status_apply_coalesce_keys[key] = true
	return false


## 作用：按enemy_rank识别精英与Boss。
## 使用：用于status_normal_only的目标排除。
func _is_strong_target(body: Node) -> bool:
	return body != null and String(body.get_meta("enemy_rank", "normal")) in ["elite", "boss"]


## 作用：只更新现有圆形碰撞形状半径。
## 使用：new_radius至少1，不新建缺失形状。
func _apply_radius(new_radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is CircleShape2D):
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = maxf(new_radius, 1.0)


## 作用：判断启用了合法起始与目标半径。
## 使用：起始>=0且目标>0才启用。
func _uses_expanding_radius() -> bool:
	return _expand_from_radius >= 0.0 and _expand_to_radius > 0.0


## 作用：按年龄/时长线性插值半径并更新碰撞。
## 使用：未启用时无操作。
func _update_expanding_radius() -> void:
	if not _uses_expanding_radius():
		return
	var progress: float = clampf(_age / maxf(duration, 0.05), 0.0, 1.0)
	radius = lerpf(_expand_from_radius, _expand_to_radius, progress)
	_apply_radius(radius)


## 作用：程序化风格隐藏sprite并重绘，否则合并资源视觉默认色/缩放并播放loop。
## 使用：params显式z_index用于程序化模式。
func _apply_visual(params: Dictionary) -> void:
	if _uses_programmatic_visual():
		var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			sprite.visible = false
		var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if animated_sprite != null:
			animated_sprite.visible = false
			animated_sprite.stop()
		z_index = int(params.get("z_index", z_index))
		queue_redraw()
		return

	_visual_config = _get_dictionary(params.get("visual", {}))
	if _visual_config.is_empty():
		_visual_config["modulate"] = _visual_color
	if not _visual_config.has("scale"):
		_visual_config["scale"] = [radius / 64.0, radius / 64.0]
	VisualConfigApplierScript.play_state(self, _visual_config, "loop", "idle")


## 作用：按已命名风格绘制，未命名时再处理毒区/毒云。
## 使用：引擎重绘回调，只负责视觉。
func _draw() -> void:
	if _draw_named_visual_style():
		return
	if _visual_style == "poison_zone" or _visual_style == "poison_cloud":
		_draw_poison_zone()


## 作用：把已登记风格分派到对应程序化绘制函数。
## 使用：返回是否成功分派，未知风格返回false。
func _draw_named_visual_style() -> bool:
	match _visual_style:
		"fire_burst":
			_draw_fire_burst()
			return true
		"frost_patch":
			_draw_frost_patch()
			return true
		"trap_circle":
			_draw_trap_circle()
			return true
		"holy_field":
			_draw_holy_field()
			return true
		"holy_shield_pulse":
			_draw_holy_shield_pulse()
			return true
		"holy_shield_break", "holy_shield_shockwave", "holy_shield_break_shockwave":
			_draw_holy_shield_pulse()
			return true
		"hammer_shockwave":
			_draw_hammer_shockwave()
			return true
		"warhammer_crack_field", "warhammer_execution_shockwave":
			_draw_hammer_shockwave()
			return true
		"lava_zone":
			_draw_lava_zone()
			return true
		"meteor_crater":
			_draw_meteor_crater()
			return true
		"lightning_field":
			_draw_lightning_field()
			return true
		"lightning_strike":
			_draw_lightning_strike()
			return true
		"thunderstorm_cloud":
			_draw_thunderstorm_cloud()
			return true
		"emp_ring":
			_draw_emp_ring()
			return true
		"protective_lava_zone":
			_draw_protective_lava_zone()
			return true
		"smoke_zone":
			_draw_smoke_zone()
			return true
		"acid_cone":
			_draw_acid_cone()
			return true
		_:
			return false
	return false


## 作用：按当前半径、年龄和颜色绘制毒雾多层圆、脉动边环和旋转气泡。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_poison_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.5 + _visual_seed)
	var center: Vector2 = Vector2.ZERO
	var mist_color: Color = Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.62 + pulse * 0.18) * fade)
	draw_circle(center, radius, mist_color)

	for layer: int in range(3):
		var layer_radius: float = radius * (0.55 + float(layer) * 0.18 + pulse * 0.025)
		var layer_alpha: float = _visual_color.a * (0.18 - float(layer) * 0.035) * fade
		draw_circle(center, layer_radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, layer_alpha))

	var ring_alpha: float = _visual_ring_color.a * (0.65 + pulse * 0.25) * fade
	draw_arc(center, radius * (0.96 + pulse * 0.015), 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, ring_alpha), 2.0, true)
	draw_arc(center, radius * 0.72, _visual_seed + _age * 0.45, _visual_seed + _age * 0.45 + TAU * 0.55, 48, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, ring_alpha * 0.45), 1.5, true)

	for index: int in range(8):
		var offset_angle: float = _visual_seed + float(index) * TAU / 8.0 + _age * (0.32 + float(index % 3) * 0.05)
		var offset_distance: float = radius * (0.16 + float(index % 4) * 0.12)
		var bubble_radius: float = radius * (0.045 + float(index % 3) * 0.012) * (0.82 + pulse * 0.32)
		var bubble_position: Vector2 = Vector2(cos(offset_angle), sin(offset_angle)) * offset_distance
		var bubble_alpha: float = (0.18 + float(index % 2) * 0.06) * fade
		draw_circle(bubble_position, bubble_radius, Color(0.83, 1.0, 0.32, bubble_alpha))
		draw_arc(bubble_position, bubble_radius, 0.0, TAU, 20, Color(0.95, 1.0, 0.58, bubble_alpha * 0.9), 1.0, true)


## 作用：按当前半径、年龄和颜色绘制火焰爆发底色、中心光和放射火线。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_fire_burst() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 12.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.68 + pulse * 0.12) * fade))
	draw_circle(Vector2.ZERO, radius * (0.48 + pulse * 0.06), Color(1.0, 0.72, 0.18, 0.24 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.4, true)
	for index: int in range(8):
		var angle: float = _visual_seed + float(index) * TAU / 8.0 + pulse * 0.2
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius * (0.72 + pulse * 0.12), Color(1.0, 0.48, 0.08, 0.16 * fade), 1.4, true)


## 作用：按当前半径、年龄和颜色绘制冰霜圆片、六向冰纹和亮点。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_frost_patch() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.5 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.0, true)
	for index: int in range(6):
		var angle: float = _visual_seed + float(index) * TAU / 6.0
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius * (0.78 + pulse * 0.04), Color(0.88, 0.96, 1.0, 0.28 * fade), 1.6, true)
		draw_circle(Vector2(cos(angle), sin(angle)) * radius * 0.42, radius * 0.035, Color(1.0, 1.0, 1.0, 0.35 * fade))


## 作用：按当前半径、年龄和颜色绘制陷阱圆环与十二条刻线。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_trap_circle() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * 0.55, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.42 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 80, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.4, true)
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0
		var inner: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.70
		var outer: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.92
		draw_line(inner, outer, Color(0.34, 0.24, 0.12, 0.42 * fade), 1.8, true)


## 作用：按当前半径、年龄和颜色绘制圣域双环和中心十字。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_holy_field() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.98, 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.5, true)
	draw_arc(Vector2.ZERO, radius * (0.62 + pulse * 0.025), 0.0, TAU, 96, Color(1.0, 1.0, 0.82, 0.36 * fade), 1.8, true)
	draw_line(Vector2(-radius * 0.28, 0.0), Vector2(radius * 0.28, 0.0), Color(1.0, 1.0, 0.84, 0.46 * fade), 2.0, true)
	draw_line(Vector2(0.0, -radius * 0.32), Vector2(0.0, radius * 0.34), Color(1.0, 1.0, 0.84, 0.46 * fade), 2.0, true)


## 作用：按当前半径、年龄和颜色绘制随寿命扩大的圣盾脉冲环。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_holy_shield_pulse() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.36 * fade))
	draw_arc(Vector2.ZERO, radius * (0.55 + 0.42 * life_ratio), 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.74, 0.0, TAU, 96, Color(1.0, 1.0, 0.86, 0.36 * fade), 1.8, true)


## 作用：按当前半径、年龄和颜色绘制扩展冲击环与五向地裂线。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_hammer_shockwave() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.42 * fade))
	draw_arc(Vector2.ZERO, radius * (0.35 + life_ratio * 0.62), 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 3.0, true)
	for index: int in range(5):
		var angle: float = _visual_seed + float(index) * TAU / 5.0
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.22
		var end: Vector2 = Vector2(cos(angle + 0.08 * sin(_visual_seed)), sin(angle + 0.08 * sin(_visual_seed))) * radius * 0.82
		draw_line(start, end, Color(0.42, 0.28, 0.10, 0.34 * fade), 2.2, true)


## 作用：按当前半径、年龄和颜色绘制熔岩底色、热环和旋转气泡。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_lava_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 6.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.12, 0.02, 0.26 * fade))
	draw_circle(Vector2.ZERO, radius * (0.72 + pulse * 0.04), Color(1.0, 0.34, 0.04, 0.18 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(1.0, 0.72, 0.12, 0.72 * fade), 2.0, true)
	for index: int in range(6):
		var angle: float = _visual_seed + float(index) * TAU / 6.0 - _age * 0.28
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.2 + float(index % 3) * 0.16)
		draw_circle(pos, radius * (0.05 + pulse * 0.018), Color(1.0, 0.84, 0.18, 0.28 * fade))


## 作用：按当前半径、年龄和颜色绘制暗陨坑、炽热裂缝和余烬。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_meteor_crater() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 7.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(0.12, 0.07, 0.05, 0.46 * fade))
	draw_circle(Vector2.ZERO, radius * 0.70, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_circle(Vector2.ZERO, radius * (0.38 + pulse * 0.025), Color(1.0, 0.28, 0.04, 0.28 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.8, true)
	draw_arc(Vector2.ZERO, radius * 0.58, _visual_seed - _age * 0.32, _visual_seed - _age * 0.32 + TAU * 0.72, 64, Color(1.0, 0.62, 0.10, 0.48 * fade), 2.0, true)
	for index: int in range(7):
		var angle: float = _visual_seed + float(index) * TAU / 7.0
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.18 + float(index % 2) * 0.05)
		var end: Vector2 = Vector2(cos(angle + 0.08 * sin(_visual_seed + float(index))), sin(angle + 0.08 * sin(_visual_seed + float(index)))) * radius * (0.72 + float(index % 3) * 0.06)
		draw_line(start, end, Color(1.0, 0.34, 0.06, 0.30 * fade), 2.0, true)
	for ember_index: int in range(5):
		var ember_angle: float = _visual_seed + float(ember_index) * TAU / 5.0 + _age * 0.25
		var ember_pos: Vector2 = Vector2(cos(ember_angle), sin(ember_angle)) * radius * (0.22 + float(ember_index % 3) * 0.12)
		draw_circle(ember_pos, radius * (0.035 + pulse * 0.012), Color(1.0, 0.78, 0.16, 0.34 * fade))


## 作用：按当前半径、年龄和颜色绘制闪电场的脉动圆环及旋转电线。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_lightning_field() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio * 0.6, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 18.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.52 + pulse * 0.16) * fade))
	draw_arc(Vector2.ZERO, radius * (0.88 + pulse * 0.04), 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.2, true)
	for index: int in range(7):
		var angle: float = _visual_seed + _age * 4.2 + float(index) * TAU / 7.0
		var bend: float = angle + sin(_age * 7.0 + float(index)) * 0.24
		var inner: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.18 + 0.08 * float(index % 3))
		var outer: Vector2 = Vector2(cos(bend), sin(bend)) * radius * (0.62 + pulse * 0.18)
		draw_line(inner, outer, Color(0.82, 0.96, 1.0, 0.38 * fade), 1.6, true)


## 作用：按当前半径、年龄和颜色绘制闪电落点圆与三道折线雷击。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_lightning_strike() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 64, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.5, true)
	var top: Vector2 = Vector2(0.0, -radius)
	var bottom: Vector2 = Vector2(0.0, radius * 0.72)
	for branch: int in range(3):
		var offset: float = (float(branch) - 1.0) * radius * 0.16
		draw_polyline([
			top + Vector2(offset, 0.0),
			Vector2(radius * 0.12 - offset, -radius * 0.36),
			Vector2(-radius * 0.08 + offset, radius * 0.06),
			bottom + Vector2(-offset, 0.0)
		], Color(0.92, 1.0, 1.0, 0.72 * fade), 2.4, true)


## 作用：按当前半径、年龄和颜色绘制多层雷云底色与电弧。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_thunderstorm_cloud() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio * 0.25, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	for layer: int in range(5):
		var angle: float = _visual_seed + float(layer) * TAU / 5.0 + sin(_age * 1.8 + float(layer)) * 0.12
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.12 + float(layer % 2) * 0.08)
		draw_circle(offset, radius * (0.42 + float(layer) * 0.04), Color(0.28, 0.38, 0.52, 0.18 * fade))
	draw_arc(Vector2.ZERO, radius * (0.88 + pulse * 0.03), 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * 0.7 * fade), 1.8, true)
	for index: int in range(4):
		var angle: float = _visual_seed + _age * 3.0 + float(index) * TAU / 4.0
		draw_line(Vector2(cos(angle), sin(angle)) * radius * 0.38, Vector2(cos(angle + 0.28), sin(angle + 0.28)) * radius * 0.68, Color(0.9, 1.0, 0.7, 0.28 * fade), 1.4, true)


## 作用：按当前半径、年龄和颜色绘制三层扩展电磁脉冲环与径向线。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_emp_ring() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * 0.65, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.32 * fade))
	for ring: int in range(3):
		var ring_radius: float = radius * clampf(life_ratio + float(ring) * 0.18, 0.12, 1.0)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.0, true)
	for index: int in range(10):
		var angle: float = _visual_seed + float(index) * TAU / 10.0
		draw_line(Vector2(cos(angle), sin(angle)) * radius * 0.28, Vector2(cos(angle), sin(angle)) * radius * 0.88, Color(0.82, 0.96, 1.0, 0.14 * fade), 1.0, true)


## 作用：按当前半径、年龄和颜色绘制防护熔岩双环与旋转光点。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_protective_lava_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.98, 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 3.0, true)
	draw_arc(Vector2.ZERO, radius * (0.76 + pulse * 0.02), 0.0, TAU, 96, Color(1.0, 0.75, 0.16, 0.58 * fade), 2.0, true)
	for index: int in range(10):
		var angle: float = _visual_seed + float(index) * TAU / 10.0 + _age * 0.35
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.86
		draw_circle(pos, radius * 0.025, Color(0.55, 1.0, 0.62, 0.45 * fade))


## 作用：按当前半径、年龄和颜色绘制多层旋转烟雾与边界环。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_smoke_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 3.7 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	for layer: int in range(4):
		var angle: float = _visual_seed + float(layer) * TAU / 4.0 + _age * (0.08 + float(layer) * 0.03)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.10 + float(layer) * 0.09)
		var layer_radius: float = radius * (0.42 + float(layer) * 0.10 + pulse * 0.03)
		var alpha: float = _visual_color.a * (0.34 - float(layer) * 0.045) * fade
		draw_circle(offset, layer_radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, alpha))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 80, Color(0.78, 0.80, 0.82, 0.30 * fade), 1.5, true)


## 作用：按当前半径、年龄和颜色绘制按扇形方向和角度绘制酸液多边形及放射线。
## 使用：仅由_draw分派调用，生命周期比例控制淡出；不施加伤害或状态。
func _draw_acid_cone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 9.0 + _visual_seed)
	var direction_angle: float = cone_direction.angle()
	var width: float = deg_to_rad(clampf(cone_width_degrees, 1.0, 360.0))
	var start_angle: float = direction_angle - width * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	var segments: int = maxi(int(width / TAU * 96.0), 8)
	for index: int in range(segments + 1):
		var angle: float = start_angle + width * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.68 + pulse * 0.12) * fade))
	draw_arc(Vector2.ZERO, radius * (0.96 + pulse * 0.012), start_angle, start_angle + width, segments, Color(0.86, 1.0, 0.28, 0.72 * fade), 2.5, true)
	for index: int in range(5):
		var angle: float = start_angle + width * (float(index) + 0.5) / 5.0
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius * (0.88 + pulse * 0.03), Color(0.86, 1.0, 0.28, 0.18 * fade), 1.0, true)


## 作用：幂等关闭伤害、注销调度，非命中结束时发过期事件/action，再停碰撞。
## 使用：程序化视觉立即回池；资源非循环动画可等待播完。
func _finish_damage_window() -> void:
	if _damage_window_finished:
		return
	_damage_window_finished = true
	_unregister_area_effect()
	if not _finished_by_damage:
		_emit_area_event(event_on_expire, null)
		_execute_adapted_actions(actions_on_expire, null)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if _uses_programmatic_visual():
		despawn_or_free()
		return
	if not _wait_for_non_loop_visual_finish():
		despawn_or_free()


## 作用：可用动画正在播且非循环时连接一次结束回调。
## 使用：返回是否成功等待，false时调用方应结束节点。
func _wait_for_non_loop_visual_finish() -> bool:
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	var animation_name: StringName = animated_sprite.animation
	if animation_name == &"" or not animated_sprite.sprite_frames.has_animation(animation_name):
		return false
	if animated_sprite.sprite_frames.get_animation_loop(animation_name):
		return false
	if not animated_sprite.is_playing():
		return false
	if not animated_sprite.animation_finished.is_connected(Callable(self, "_on_visual_animation_finished")):
		animated_sprite.animation_finished.connect(Callable(self, "_on_visual_animation_finished"), CONNECT_ONE_SHOT)
	return true


## 作用：资源视觉播完后回池或释放。
## 使用：一次性animation_finished信号回调。
func _on_visual_animation_finished() -> void:
	despawn_or_free()


## 作用：发送包含区域、来源、当前命中数和技能服务的规范事件上下文。
## 使用：空event_name或无有效总线时无操作。
func _emit_area_event(event_name: StringName, target: Node) -> void:
	if event_bus == null or event_name == &"" or not event_bus.has_method("emit_skill_event"):
		return
	event_bus.call("emit_skill_event", event_name, DamageTraceContextScript.normalize_event_context({
		"caster": caster,
		"owner": caster,
		"target": target,
		"enemy": target,
		"area": self,
		"source": self,
		"source_id": source_id,
		"source_key": String(damage_packet.get("source_id", source_id)),
		"source_instance_id": String(damage_packet.get("source_instance_id", str(get_instance_id()))),
		"explosion_targets_hit": _current_tick_targets_hit,
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else &"",
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_type": damage_type,
		"damage_packet": damage_packet,
		"position": global_position
	}))


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回深复制，嵌套修改不会污染输入。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回深复制。
func _get_array(value: Variant) -> Array:
	if value is Array:
		var items: Array = value
		return items.duplicate(true)
	return []


## 作用：把action列表和当前目标/区域来源上下文交给技能总线。
## 使用：actions为空或缺总线时无操作，area_tick_stats供事件统计。
func _execute_adapted_actions(actions: Array, target: Node) -> void:
	if actions.is_empty() or event_bus == null or not event_bus.has_method("execute_adapted_actions"):
		return
	event_bus.call("execute_adapted_actions", actions, DamageTraceContextScript.normalize_event_context({
		"caster": caster,
		"owner": caster,
		"target": target,
		"enemy": target,
		"area": self,
		"source": self,
		"source_id": source_id,
		"source_key": String(damage_packet.get("source_id", source_id)),
		"source_instance_id": String(damage_packet.get("source_instance_id", str(get_instance_id()))),
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else &"",
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_type": damage_type,
		"damage_packet": damage_packet,
		"area_tick_stats": _current_tick_stats,
		"position": global_position
	}))


## 作用：on_apply对显式impact_target执行，否则对当前区域内目标逐一执行。
## 使用：不通过tick预算，必须在setup上下文绑定后调用。
func _execute_apply_actions() -> void:
	if actions_on_apply.is_empty():
		return
	if impact_target != null:
		if _can_damage_body(impact_target):
			_execute_adapted_actions(actions_on_apply, impact_target)
		return
	for target: Node in _collect_tick_damage_targets():
		_execute_adapted_actions(actions_on_apply, target)


## 作用：解析Color、RGB/RGBA数组或HTML颜色字符串。
## 使用：无法解析时返回fallback；三成员RGB数组沿用fallback透明度。
func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			var alpha: float = float(items[3]) if items.size() > 3 else fallback.a
			return Color(float(items[0]), float(items[1]), float(items[2]), alpha)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return fallback


## 作用：将Vector2或至少两个成员的[x,y]数组，也支持x/y字典解析为二维值。
## 使用：无法解析时返回fallback；不修改输入。
func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	if value is Dictionary:
		var dictionary: Dictionary = value
		return Vector2(float(dictionary.get("x", fallback.x)), float(dictionary.get("y", fallback.y)))
	return fallback


## 作用：将状态数组转为去空去重的StringName列表，空列表可用单状态回退。
## 使用：fallback_status在没有有效数组成员时追加。
func _get_status_array(value: Variant, fallback_status: StringName = &"") -> Array[StringName]:
	var statuses: Array[StringName] = []
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			var status_id: StringName = StringName(String(item))
			if status_id != &"" and not statuses.has(status_id):
				statuses.append(status_id)

	if statuses.is_empty() and fallback_status != &"":
		statuses.append(fallback_status)

	return statuses


## 作用：asset模式强制使用资源，否则按风格白名单选择程序化绘图。
## 使用：返回布尔值供初始化、重绘和结束生命周期共用。
func _uses_programmatic_visual() -> bool:
	if _visual_mode == "asset":
		return false
	return [
		"fire_burst",
		"frost_patch",
		"trap_circle",
		"holy_field",
		"holy_shield_pulse",
		"holy_shield_break",
		"holy_shield_shockwave",
		"holy_shield_break_shockwave",
		"hammer_shockwave",
		"warhammer_crack_field",
		"warhammer_execution_shockwave",
		"poison_zone",
		"poison_cloud",
		"lava_zone",
		"meteor_crater",
		"protective_lava_zone",
		"smoke_zone",
		"acid_cone"
	].has(_visual_style)
