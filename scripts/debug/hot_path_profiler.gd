extends RefCounted
class_name HotPathProfiler


const ENABLED_META: StringName = &"real_full_run_profiler_enabled"
const HOT_PATH_EVENT_META: StringName = &"real_full_run_profiler_hot_path_event"


static func begin(node: Node) -> int:
	if node == null:
		return 0
	var tree: SceneTree = node.get_tree()
	if tree == null or tree.root == null:
		return 0
	if not bool(tree.root.get_meta(ENABLED_META, false)):
		return 0
	if not tree.root.has_meta(HOT_PATH_EVENT_META):
		return 0
	return Time.get_ticks_usec()


static func end(node: Node, section: StringName, start_usec: int) -> void:
	if start_usec <= 0 or node == null:
		return
	var tree: SceneTree = node.get_tree()
	if tree == null or tree.root == null:
		return
	var callback_variant: Variant = tree.root.get_meta(HOT_PATH_EVENT_META, Callable())
	if not (callback_variant is Callable):
		return
	var callback: Callable = callback_variant
	if callback.is_valid():
		callback.call(section, Time.get_ticks_usec() - start_usec)


static func begin_context(context: Dictionary) -> int:
	return begin(_node_from_context(context))


static func end_context(context: Dictionary, section: StringName, start_usec: int) -> void:
	end(_node_from_context(context), section, start_usec)


static func _node_from_context(context: Dictionary) -> Node:
	for key: String in ["event_bus", "caster", "owner", "parent"]:
		var node: Node = context.get(key) as Node
		if node != null:
			return node
	return null
