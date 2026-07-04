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


func register_area(area: Node, _tick_interval: float) -> int:
	if area == null or not is_instance_valid(area):
		return 0
	var area_instance_id: int = int(area.get_instance_id())
	if _active_area_ids.has(area_instance_id):
		return int(_tick_buckets.get(area_instance_id, 0))
	var tick_bucket: int = _next_tick_bucket % TICK_BUCKET_COUNT
	_next_tick_bucket += 1
	_active_area_ids[area_instance_id] = weakref(area)
	_tick_buckets[area_instance_id] = tick_bucket
	return tick_bucket


func unregister_area(area: Node) -> void:
	if area == null:
		return
	var area_instance_id: int = int(area.get_instance_id())
	_active_area_ids.erase(area_instance_id)
	_tick_buckets.erase(area_instance_id)


func request_tick(area: Node) -> bool:
	if area == null or not is_instance_valid(area):
		return false
	var area_instance_id: int = int(area.get_instance_id())
	if not _active_area_ids.has(area_instance_id):
		register_area(area, float(area.get("tick_interval")))
	var tick_bucket: int = int(_tick_buckets.get(area_instance_id, 0))
	return int(Engine.get_physics_frames() + tick_bucket) % TICK_BUCKET_COUNT == 0


func tick_bucket(area: Node) -> int:
	if area == null:
		return 0
	return int(_tick_buckets.get(int(area.get_instance_id()), 0))


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


func _emit_profiler_tick_event(payload: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null or not tree.root.has_meta(PROFILER_AOE_TICK_EVENT_META):
		return
	var callback_variant: Variant = tree.root.get_meta(PROFILER_AOE_TICK_EVENT_META)
	if callback_variant is Callable:
		var callback: Callable = callback_variant
		if callback.is_valid():
			callback.call(payload)
