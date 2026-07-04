extends Node
class_name PickupManager


const HotPathProfilerScript: Script = preload("res://scripts/debug/hot_path_profiler.gd")
const MANAGER_NAME: StringName = &"PickupManager"
const IDLE_SCAN_INTERVAL: float = 0.1
const IDLE_BUCKET_COUNT: int = 10
const IDLE_BUCKET_INTERVAL: float = IDLE_SCAN_INTERVAL / float(IDLE_BUCKET_COUNT)
const MAX_REWARD_AMOUNTS_PER_FRAME: int = 8
const PLAYER_GROUP: StringName = &"player"
const PICKUP_STATE_IDLE: StringName = &"idle"
const PICKUP_STATE_MAGNETIZED: StringName = &"magnetized"
const PICKUP_STATE_COLLECTING: StringName = &"collecting"

var _pickup_refs: Dictionary = {}
var _pickup_states: Dictionary = {}
var _idle_buckets: Array[Dictionary] = []
var _active_pickup_ids: Dictionary = {}
var _idle_bucket_index: int = 0
var _idle_bucket_timer: float = 0.0
var _player: Node2D
var _player_position: Vector2 = Vector2.ZERO
var _player_pickup_radius: float = 0.0
var _player_valid: bool = false
var _experience_rewards_by_player: Dictionary = {}


static func get_or_create(context: Node = null) -> Node:
	var tree: SceneTree = null
	if context != null and context.is_inside_tree():
		tree = context.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var manager: Node = tree.root.get_node_or_null(NodePath(String(MANAGER_NAME)))
	if manager != null:
		return manager
	var manager_script: Script = load("res://scripts/drops/pickup_manager.gd") as Script
	if manager_script == null:
		return null
	manager = manager_script.new() as Node
	manager.name = String(MANAGER_NAME)
	tree.root.add_child(manager)
	return manager


func _ready() -> void:
	_ensure_idle_buckets()


func _physics_process(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_cache_player_state()
	var idle_start: int = HotPathProfilerScript.begin(self)
	_process_idle_bucket(delta)
	HotPathProfilerScript.end(self, &"pickup_idle_check", idle_start)
	var active_start: int = HotPathProfilerScript.begin(self)
	_process_active_pickups(delta)
	HotPathProfilerScript.end(self, &"pickup_active_update", active_start)
	HotPathProfilerScript.end(self, &"pickup_update", hot_path_start)
	var reward_start: int = HotPathProfilerScript.begin(self)
	flush_rewards()
	HotPathProfilerScript.end(self, &"pickup_reward_flush", reward_start)


func register_pickup(pickup: Node) -> void:
	if pickup == null:
		return
	_ensure_idle_buckets()
	var pickup_id: int = int(pickup.get_instance_id())
	_pickup_refs[pickup_id] = weakref(pickup)
	var state: StringName = _get_pickup_state(pickup)
	_pickup_states[pickup_id] = state
	_add_to_state_bucket(pickup_id, state)


func unregister_pickup(pickup: Node) -> void:
	if pickup == null:
		return
	var pickup_id: int = int(pickup.get_instance_id())
	_remove_from_state_bucket(pickup_id, StringName(_pickup_states.get(pickup_id, PICKUP_STATE_IDLE)))
	_pickup_refs.erase(pickup_id)
	_pickup_states.erase(pickup_id)


func notify_state_changed(pickup: Node, old_state: StringName, new_state: StringName) -> void:
	if pickup == null:
		return
	var pickup_id: int = int(pickup.get_instance_id())
	if not _pickup_refs.has(pickup_id):
		register_pickup(pickup)
		return
	_remove_from_state_bucket(pickup_id, old_state)
	_pickup_states[pickup_id] = new_state
	_add_to_state_bucket(pickup_id, new_state)


func queue_experience_reward(player: Node, amount: int) -> void:
	if player == null or amount <= 0:
		return
	var player_id: int = int(player.get_instance_id())
	var record: Dictionary = _experience_rewards_by_player.get(player_id, {
		"player_ref": weakref(player),
		"amounts": []
	})
	var amounts: Array = record.get("amounts", [])
	amounts.append(amount)
	record["amounts"] = amounts
	_experience_rewards_by_player[player_id] = record


func flush_rewards() -> void:
	if _experience_rewards_by_player.is_empty():
		return
	var rewards: Dictionary = _experience_rewards_by_player
	_experience_rewards_by_player = {}
	var reward_budget: int = MAX_REWARD_AMOUNTS_PER_FRAME
	for player_id: Variant in rewards.keys():
		if reward_budget <= 0:
			_experience_rewards_by_player[player_id] = rewards[player_id]
			continue
		var record: Dictionary = rewards[player_id]
		var player: Node = _target_from_ref(record.get("player_ref"))
		if player == null or not is_instance_valid(player):
			continue
		var amounts: Array = record.get("amounts", [])
		if amounts.is_empty():
			continue
		var current_amounts: Array = amounts
		if amounts.size() > reward_budget:
			current_amounts = amounts.slice(0, reward_budget)
			record["amounts"] = amounts.slice(reward_budget)
			_experience_rewards_by_player[player_id] = record
		reward_budget -= current_amounts.size()
		if player.has_method("add_experience_batch"):
			player.call("add_experience_batch", current_amounts)
		elif player.has_method("add_experience"):
			for amount_variant: Variant in current_amounts:
				player.call("add_experience", int(amount_variant))


func _cache_player_state() -> void:
	_player_valid = false
	if _player == null or not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_player = _find_player()
	if _player == null:
		return
	_player_position = _player.global_position
	_player_pickup_radius = _get_player_pickup_radius(_player)
	_player_valid = true


func _process_idle_bucket(delta: float) -> void:
	if not _player_valid:
		return
	_idle_bucket_timer += maxf(delta, 0.0)
	if _idle_bucket_timer < IDLE_BUCKET_INTERVAL:
		return
	_idle_bucket_timer = fmod(_idle_bucket_timer, IDLE_BUCKET_INTERVAL)
	_process_idle_bucket_index(_idle_bucket_index)
	_idle_bucket_index = (_idle_bucket_index + 1) % IDLE_BUCKET_COUNT


func _process_active_pickups(delta: float) -> void:
	if not _player_valid:
		return
	var ids: Array = _active_pickup_ids.keys()
	for pickup_id_variant: Variant in ids:
		var pickup_id: int = int(pickup_id_variant)
		var pickup: Node = _pickup_from_id(pickup_id)
		if pickup == null:
			_forget_pickup_id(pickup_id)
			continue
		if pickup.has_method("manager_active_update"):
			pickup.call("manager_active_update", delta, _player, _player_position, _player_pickup_radius)


func _process_idle_bucket_index(bucket_index: int) -> void:
	if bucket_index < 0 or bucket_index >= _idle_buckets.size():
		return
	var bucket: Dictionary = _idle_buckets[bucket_index]
	var ids: Array = bucket.keys()
	for pickup_id_variant: Variant in ids:
		var pickup_id: int = int(pickup_id_variant)
		var pickup: Node = _pickup_from_id(pickup_id)
		if pickup == null:
			_forget_pickup_id(pickup_id)
			continue
		if pickup.has_method("manager_idle_check"):
			pickup.call("manager_idle_check", _player, _player_position, _player_pickup_radius)


func _add_to_state_bucket(pickup_id: int, state: StringName) -> void:
	if state == PICKUP_STATE_IDLE:
		_idle_buckets[_bucket_index_for_id(pickup_id)][pickup_id] = true
	elif state == PICKUP_STATE_MAGNETIZED or state == PICKUP_STATE_COLLECTING:
		_active_pickup_ids[pickup_id] = true


func _remove_from_state_bucket(pickup_id: int, state: StringName) -> void:
	if state == PICKUP_STATE_IDLE and not _idle_buckets.is_empty():
		_idle_buckets[_bucket_index_for_id(pickup_id)].erase(pickup_id)
	_active_pickup_ids.erase(pickup_id)


func _forget_pickup_id(pickup_id: int) -> void:
	_remove_from_state_bucket(pickup_id, StringName(_pickup_states.get(pickup_id, PICKUP_STATE_IDLE)))
	_pickup_refs.erase(pickup_id)
	_pickup_states.erase(pickup_id)


func _pickup_from_id(pickup_id: int) -> Node:
	var pickup: Node = _target_from_ref(_pickup_refs.get(pickup_id))
	if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
		return null
	return pickup


func _target_from_ref(reference: Variant) -> Node:
	if reference is WeakRef:
		return (reference as WeakRef).get_ref() as Node
	return reference as Node


func _get_pickup_state(pickup: Node) -> StringName:
	if pickup != null and pickup.has_method("get_pickup_state"):
		return StringName(pickup.call("get_pickup_state"))
	return PICKUP_STATE_IDLE


func _find_player() -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(PLAYER_GROUP) as Node2D


func _get_player_pickup_radius(player: Node) -> float:
	if player == null:
		return 0.0
	var configured_radius: Variant = player.get("pickup_radius")
	if player.has_method("get_effective_pickup_radius"):
		configured_radius = player.call("get_effective_pickup_radius")
	if configured_radius == null:
		return 0.0
	return maxf(float(configured_radius), 0.0)


func _bucket_index_for_id(pickup_id: int) -> int:
	return absi(pickup_id) % IDLE_BUCKET_COUNT


func _ensure_idle_buckets() -> void:
	while _idle_buckets.size() < IDLE_BUCKET_COUNT:
		_idle_buckets.append({})
