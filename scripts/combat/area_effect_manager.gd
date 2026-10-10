## 文件用途：将区域tick分配到四个物理帧桶，并限制全局每帧8次命中处理及记录采样。
## 使用方式：AreaEffect注册后请求tick与命中预算；未消费命中由区域保存到后续帧继续处理。
extends Node
class_name AreaEffectManager


const MANAGER_NAME: StringName = &"AreaEffectManager"
const PROFILER_AOE_TICK_EVENT_META: StringName = &"real_full_run_profiler_aoe_tick_event"
const TICK_BUCKET_COUNT: int = 4
const MAX_TICK_HITS_PER_FRAME: int = 8

var _active_area_ids: Dictionary = {}
var _tick_buckets: Dictionary = {}
var _next_tick_bucket: int = 0
var _hit_budget_frame: int = -1
var _hit_budget_used: int = 0


## 作用：从根节点复用或创建区域调度管理器。
## 使用：context提供树或使用主循环，无有效树返回null。
static func get_or_create(context: Node) -> Node:
	var tree: SceneTree = context.get_tree() if context != null and context.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var existing: Node = tree.root.get_node_or_null(NodePath(String(MANAGER_NAME)))
	if existing != null:
		return existing
	var script: Script = load("res://scripts/combat/area_effect_manager.gd")
	var manager: Node = script.new() as Node
	manager.name = MANAGER_NAME
	tree.root.add_child(manager)
	return manager


## 作用：登记区域弱引用并轮流分配四个tick桶。
## 使用：重复注册返回原桶；_tick_interval当前不参与分桶。
func register_area(area: Node, _tick_interval: float) -> int:
	if area == null or not is_instance_valid(area):
		return 0
	var area_instance_id: int = int(area.get_instance_id())
	if _active_area_ids.has(area_instance_id):
		return int(_tick_buckets.get(area_instance_id, 0))
	var tick_bucket: int = _next_tick_bucket % TICK_BUCKET_COUNT
	_next_tick_bucket += 1
	_spatial_frame = -1
	_active_area_ids[area_instance_id] = weakref(area)
	_tick_buckets[area_instance_id] = tick_bucket
	return tick_bucket


## 作用：移除区域登记与桶信息。
## 使用：结束伤害窗口或回池时调用。
func unregister_area(area: Node) -> void:
	if area == null:
		return
	var area_instance_id: int = int(area.get_instance_id())
	_spatial_frame = -1
	_active_area_ids.erase(area_instance_id)
	_tick_buckets.erase(area_instance_id)


## 作用：确保区域登记并按当前物理帧与桶判断是否可发起tick。
## 使用：返回布尔值，每区域四帧中分得一帧。
func request_tick(area: Node) -> bool:
	if area == null or not is_instance_valid(area):
		return false
	var area_instance_id: int = int(area.get_instance_id())
	if not _active_area_ids.has(area_instance_id):
		register_area(area, float(area.get("tick_interval")))
	var tick_bucket: int = int(_tick_buckets.get(area_instance_id, 0))
	return int(Engine.get_physics_frames() + tick_bucket) % TICK_BUCKET_COUNT == 0


## 作用：读取区域分桶编号，缺失返回0。
## 使用：用于诊断payload，不触发登记。
func tick_bucket(area: Node) -> int:
	if area == null:
		return 0
	return int(_tick_buckets.get(int(area.get_instance_id()), 0))


## 作用：在每物理帧重置全局预算后分配剩余命中额度。
## 使用：desired_count为请求数，返回0至剩余8点预算并消费额度。
func request_hit_budget(_area: Node, desired_count: int) -> int:
	if desired_count <= 0:
		return 0
	var frame: int = int(Engine.get_physics_frames())
	if _hit_budget_frame != frame:
		_hit_budget_frame = frame
		_hit_budget_used = 0
	var available: int = maxi(MAX_TICK_HITS_PER_FRAME - _hit_budget_used, 0)
	var granted: int = mini(desired_count, available)
	_hit_budget_used += granted
	return granted


## 作用：复制区域统计并补对象、技能来源和桶号，再调用可选采样回调。
## 使用：tick_stats含候选、命中和状态施加数。
func record_tick(area: Node, tick_stats: Dictionary) -> void:
	if area == null or not is_instance_valid(area):
		return
	var payload: Dictionary = tick_stats.duplicate(true)
	payload["area_instance_id"] = str(area.get_instance_id())
	payload["area_id"] = String(area.get("area_id"))
	payload["source_id"] = String(area.get("source_id"))
	payload["tick_bucket"] = tick_bucket(area)
	payload["candidate_count"] = int(payload.get("candidate_count", 0))
	payload["hit_count"] = int(payload.get("hit_count", 0))
	payload["status_apply_count"] = int(payload.get("status_apply_count", 0))
	var damage_packet_variant: Variant = area.get("damage_packet")
	if damage_packet_variant is Dictionary:
		var damage_packet: Dictionary = damage_packet_variant
		payload["source_skill_id"] = String(damage_packet.get("source_skill_id", ""))
	else:
		payload["source_skill_id"] = ""
	_emit_profiler_tick_event(payload)


## 作用：从根元数据取有效Callable并发送区域tick统计。
## 使用：无回调时无操作，不依赖debug页面。
func _emit_profiler_tick_event(payload: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null or not tree.root.has_meta(PROFILER_AOE_TICK_EVENT_META):
		return
	var callback_variant: Variant = tree.root.get_meta(PROFILER_AOE_TICK_EVENT_META)
	if callback_variant is Callable:
		var callback: Callable = callback_variant
		if callback.is_valid():
			callback.call(payload)

# Authoritative live-area inventory, also valid for deferred factory spawns.
func get_active_areas() -> Array[Node]:
	var result: Array[Node] = []
	for id: Variant in _active_area_ids.keys():
		var area: Node = _active_area_ids[id].get_ref()
		if area == null or area.is_queued_for_deletion():
			_active_area_ids.erase(id)
			_tick_buckets.erase(id)
		else: result.append(area)
	return result

# Uniform grid broadphase, rebuilt once per physics frame; narrowphase is mandatory.
var _spatial_frame: int = -1
var _spatial_cells: Dictionary = {}
const SPATIAL_CELL: float = 168.0
func query_areas(box: Rect2) -> Array[Node]:
	if _spatial_frame != Engine.get_physics_frames():
		_spatial_frame = Engine.get_physics_frames()
		_spatial_cells.clear()
		for area: Node in get_active_areas():
			if not area.has_method("geometry_shape"): continue
			var bounds: Rect2 = preload("res://scripts/skills/skill_object_geometry.gd").bounds(area.geometry_shape())
			for cell: Vector2i in _cells_for(bounds):
				if not _spatial_cells.has(cell): _spatial_cells[cell] = []
				_spatial_cells[cell].append(weakref(area))
	var found: Dictionary = {}
	var out: Array[Node] = []
	for cell: Vector2i in _cells_for(box):
		for ref: WeakRef in _spatial_cells.get(cell,[]):
			var area: Node = ref.get_ref()
			if area != null and not area.is_queued_for_deletion() and not found.has(area.get_instance_id()):
				found[area.get_instance_id()] = true
				out.append(area)
	return out
func _cells_for(box: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var low: Vector2i = Vector2i(floori(box.position.x/SPATIAL_CELL),floori(box.position.y/SPATIAL_CELL))
	var high: Vector2i = Vector2i(floori(box.end.x/SPATIAL_CELL),floori(box.end.y/SPATIAL_CELL))
	for x: int in range(low.x,high.x+1):
		for y: int in range(low.y,high.y+1): out.append(Vector2i(x,y))
	return out
