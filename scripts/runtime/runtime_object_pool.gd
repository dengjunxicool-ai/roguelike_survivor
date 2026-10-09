## 文件用途：按稳定池键与父节点复用运行时 Node，控制活跃状态、保留容量和创建回收统计。
## 使用方式：由 RuntimePoolRegistry 取得池；spawn(key, factory, parent) 后调用方重置业务状态，用 despawn(key, node) 回收；factory 必须产生 Node。
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


## 作用：按 count 预创建节点并加入指定父节点的可用桶，关闭处理与显示；负数数量按零处理。
## 使用：调用 prewarm(key, factory, count, parent)；key 对应对象类型，factory 为无参 Node 工厂；预热实例仅进入闲置桶，业务状态由借出方重置。
func prewarm(key: StringName, factory: Callable, count: int, parent: Node) -> void:
	for _index: int in range(maxi(count, 0)):
		var node: Node = _create_node(key, factory)
		if node == null:
			continue
		_store_available(key, node, parent)


## 作用：优先取同父节点或无父节点的可用实例，否则调用工厂创建；激活处理与显示，写池元数据并返回节点。
## 使用：传入池键、无参工厂与目标父节点，返回可用 Node 或 null；物理帧中 add_child 延迟执行，调用方仍须重置复用实例的业务状态。
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


## 作用：将有效节点从活跃索引移除，隐藏并停用处理后放回桶；容量满时 queue_free 并计丢弃。
## 使用：回收时传入原池键与有效实例；节点保留父节点，业务 reset 由调用方负责；容量超限会排队释放。
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


## 作用：返回可用、活跃以及各创建复用回收计数字典快照，统计项深拷贝。
## 使用：调用 get_stats() 取得计数快照；available/active 按池键统计，统计结果可用于界面诊断。
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


## 作用：调用有效 factory 创建 Node，写入池键与 owner 元数据并计创建；结果非法返回 null。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：key: StringName, factory: Callable。 返回 Node；具体值及空输入行为见作用说明。
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


## 作用：必要时挂入 parent，关闭显示和处理后存入可用桶，用于预热。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：key: StringName, node: Node, parent: Node。
func _store_available(key: StringName, node: Node, parent: Node) -> void:
	if parent != null and node.get_parent() == null:
		parent.add_child(node)
	_set_node_visible(node, false)
	node.set_process(false)
	node.set_physics_process(false)
	_get_bucket(key).append(node)


## 作用：按 key 懒创建可用数组并返回其引用，供池内原位追加或取出。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：key: StringName。 返回 Array；具体值及空输入行为见作用说明。
func _get_bucket(key: StringName) -> Array:
	if not _available.has(key):
		_available[key] = []
	return _available[key]


## 作用：逆序查找可归当前 parent 的节点并移出桶，同时剔除失效或非 Node 条目。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：key: StringName, parent: Node。 返回 Node；具体值及空输入行为见作用说明。
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


## 作用：仅对 CanvasItem 更新 visible 属性，其他 Node 不做显示操作。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：node: Node, visible: bool。
func _set_node_visible(node: Node, visible: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = visible


## 作用：按 stat_key 与 pool_key 递增池统计计数。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：stat_key: StringName, pool_key: StringName。
func _increment_stat(stat_key: StringName, pool_key: StringName) -> void:
	var stat: Dictionary = _stats.get(String(stat_key), {})
	var key_text: String = String(pool_key)
	stat[key_text] = int(stat.get(key_text, 0)) + 1
	_stats[String(stat_key)] = stat


## 作用：返回指定统计桶的深拷贝，避免调用方修改池内部数据。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：stat_key: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _duplicate_stat(stat_key: StringName) -> Dictionary:
	var stat: Dictionary = _stats.get(String(stat_key), {})
	return stat.duplicate(true)


## 作用：按池键生成可用桶大小字典，不额外筛除尚未访问的失效条目。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _available_counts() -> Dictionary:
	var counts: Dictionary = {}
	for key_variant: Variant in _available.keys():
		var key: StringName = StringName(String(key_variant))
		counts[String(key)] = (_available[key] as Array).size()
	return counts


## 作用：按活跃实例索引中的池键累计活动节点数量。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _active_counts() -> Dictionary:
	var counts: Dictionary = {}
	for key_variant: Variant in _active_keys.values():
		var key: StringName = StringName(String(key_variant))
		counts[String(key)] = int(counts.get(String(key), 0)) + 1
	return counts
