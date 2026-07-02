extends Node
class_name RuntimePoolRegistry


const RuntimeObjectPoolScript: Script = preload("res://scripts/runtime/runtime_object_pool.gd")
const RuntimePoolRegistryScriptPath: String = "res://scripts/runtime/runtime_pool_registry.gd"
const REGISTRY_NODE_NAME: String = "RuntimePoolRegistry"
const ROOT_META_KEY: StringName = &"runtime_pool_registry"

var _pool: Node


static func get_or_create(context: Variant) -> Node:
	var tree: SceneTree = _resolve_tree(context)
	if tree == null or tree.root == null:
		return null
	var root: Window = tree.root
	if root.has_meta(ROOT_META_KEY):
		var existing: Variant = root.get_meta(ROOT_META_KEY)
		if existing is Node and is_instance_valid(existing) and (existing as Node).has_method("get_pool"):
			return (existing as Node).call("get_pool")

	var registry: Node = root.get_node_or_null(REGISTRY_NODE_NAME)
	if registry == null:
		var registry_script: Script = load(RuntimePoolRegistryScriptPath)
		registry = registry_script.new()
		registry.name = REGISTRY_NODE_NAME
		root.add_child(registry)
	root.set_meta(ROOT_META_KEY, registry)
	return registry.call("get_pool")


func get_pool() -> Node:
	if _pool != null and is_instance_valid(_pool):
		return _pool
	_pool = get_node_or_null("RuntimeObjectPool")
	if _pool == null:
		_pool = RuntimeObjectPoolScript.new()
		_pool.name = "RuntimeObjectPool"
		add_child(_pool)
	return _pool


static func _resolve_tree(context: Variant) -> SceneTree:
	if context is SceneTree:
		return context
	if context is Node:
		return (context as Node).get_tree()
	return null
