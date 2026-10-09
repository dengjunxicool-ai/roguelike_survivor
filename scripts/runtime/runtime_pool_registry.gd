## 文件用途：在 SceneTree 根节点维护唯一运行时对象池注册点，按需创建池与登记元数据。
## 使用方式：调用 RuntimePoolRegistry.get_or_create(node_or_tree) 获得共享池；仅在有效场景树中调用，随后通过池 spawn/despawn 管理对象。
extends Node
class_name RuntimePoolRegistry


const RuntimeObjectPoolScript: Script = preload("res://scripts/runtime/runtime_object_pool.gd")
const RuntimePoolRegistryScriptPath: String = "res://scripts/runtime/runtime_pool_registry.gd"
const REGISTRY_NODE_NAME: String = "RuntimePoolRegistry"
const ROOT_META_KEY: StringName = &"runtime_pool_registry"

var _pool: Node


## 作用：从 Node 或 SceneTree 定位根节点，优先复用元数据或已有注册节点，缺失时新建并返回对象池。
## 使用：通过 RuntimePoolRegistry.get_or_create(Node 或 SceneTree) 取得共享池；缺树/根返回 null，首次调用会向根节点挂载注册节点。
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


## 作用：复用有效缓存或现有 RuntimeObjectPool 子节点，否则创建并挂载对象池，返回池引用。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 返回 Node；具体值及空输入行为见作用说明。
func get_pool() -> Node:
	if _pool != null and is_instance_valid(_pool):
		return _pool
	_pool = get_node_or_null("RuntimeObjectPool")
	if _pool == null:
		_pool = RuntimeObjectPoolScript.new()
		_pool.name = "RuntimeObjectPool"
		add_child(_pool)
	return _pool


## 作用：将 SceneTree 直接返回，Node 转为其场景树，其他输入返回 null。
## 使用：通过预加载脚本的 _resolve_tree(...) 静态入口调用。 入参：context: Variant。 返回 SceneTree；具体值及空输入行为见作用说明。
static func _resolve_tree(context: Variant) -> SceneTree:
	if context is SceneTree:
		return context
	if context is Node:
		return (context as Node).get_tree()
	return null
