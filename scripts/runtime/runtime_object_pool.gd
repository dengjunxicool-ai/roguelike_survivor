extends Node
class_name RuntimeObjectPool


const POOL_KEY_META: StringName = &"runtime_pool_key"
const POOL_OWNER_META: StringName = &"runtime_pool_owner"
const DEFAULT_MAX_RETAINED_PER_KEY: int = 512

var max_retained_per_key: int = DEFAULT_MAX_RETAINED_PER_KEY
var _available: Dictionary = {}
var _active_keys: Dictionary = {}
var _stats: Dictionary = {
	"created": {},
	"reused": {},
	"spawned": {},
	"despawned": {},
	"discarded": {}
}


func prewarm(key: StringName, factory: Callable, count: int, parent: Node) -> void:
	for _index: int in range(maxi(count, 0)):
		var node: Node = _create_node(key, factory)
		if node == null:
			continue
		_store_available(key, node, parent)


func spawn(key: StringName, factory: Callable, parent: Node) -> Node:
	var node: Node = _find_available_for_parent(key, parent)
	if node != null:
		_increment_stat(&"reused", key)
	if node == null:
		node = _create_node(key, factory)
	if node == null:
		return null

	var current_parent: Node = node.get_parent()
	if parent != null and node.get_parent() == null:
		if Engine.is_in_physics_frame():
			parent.call_deferred("add_child", node)
		else:
			parent.add_child(node)
	elif current_parent != null and current_parent != parent:
		return spawn(key, factory, parent)
	_set_node_visible(node, true)
	node.set_process(true)
	node.set_physics_process(true)
	node.set_meta(POOL_KEY_META, key)
	node.set_meta(POOL_OWNER_META, self)
	_active_keys[int(node.get_instance_id())] = key
	_increment_stat(&"spawned", key)
	return node


func despawn(key: StringName, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var instance_id: int = int(node.get_instance_id())
	_active_keys.erase(instance_id)
	_set_node_visible(node, false)
	node.set_process(false)
	node.set_physics_process(false)
	_increment_stat(&"despawned", key)
	var bucket: Array = _get_bucket(key)
	if bucket.size() >= max_retained_per_key:
		_increment_stat(&"discarded", key)
		node.queue_free()
		return
	bucket.append(node)


func get_stats() -> Dictionary:
	return {
		"available": _available_counts(),
		"active": _active_counts(),
		"created": _duplicate_stat(&"created"),
		"reused": _duplicate_stat(&"reused"),
		"spawned": _duplicate_stat(&"spawned"),
		"despawned": _duplicate_stat(&"despawned"),
		"discarded": _duplicate_stat(&"discarded")
	}


func _create_node(key: StringName, factory: Callable) -> Node:
	if not factory.is_valid():
		return null
	var created: Variant = factory.call()
	if not (created is Node):
		return null
	var node: Node = created
	node.set_meta(POOL_KEY_META, key)
	node.set_meta(POOL_OWNER_META, self)
	_increment_stat(&"created", key)
	return node


func _store_available(key: StringName, node: Node, parent: Node) -> void:
	if parent != null and node.get_parent() == null:
		parent.add_child(node)
	_set_node_visible(node, false)
	node.set_process(false)
	node.set_physics_process(false)
	_get_bucket(key).append(node)


func _get_bucket(key: StringName) -> Array:
	if not _available.has(key):
		_available[key] = []
	return _available[key]


func _find_available_for_parent(key: StringName, parent: Node) -> Node:
	var bucket: Array = _get_bucket(key)
	for index: int in range(bucket.size() - 1, -1, -1):
		var candidate: Variant = bucket[index]
		if not is_instance_valid(candidate):
			bucket.remove_at(index)
			continue
		if not (candidate is Node):
			bucket.remove_at(index)
			continue
		var node: Node = candidate
		if node.get_parent() == parent or node.get_parent() == null:
			bucket.remove_at(index)
			return node
	return null


func _set_node_visible(node: Node, visible: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = visible


func _increment_stat(stat_key: StringName, pool_key: StringName) -> void:
	var stat: Dictionary = _stats.get(String(stat_key), {})
	var key_text: String = String(pool_key)
	stat[key_text] = int(stat.get(key_text, 0)) + 1
	_stats[String(stat_key)] = stat


func _duplicate_stat(stat_key: StringName) -> Dictionary:
	var stat: Dictionary = _stats.get(String(stat_key), {})
	return stat.duplicate(true)


func _available_counts() -> Dictionary:
	var counts: Dictionary = {}
	for key_variant: Variant in _available.keys():
		var key: StringName = StringName(String(key_variant))
		counts[String(key)] = (_available[key] as Array).size()
	return counts


func _active_counts() -> Dictionary:
	var counts: Dictionary = {}
	for key_variant: Variant in _active_keys.values():
		var key: StringName = StringName(String(key_variant))
		counts[String(key)] = int(counts.get(String(key), 0)) + 1
	return counts
