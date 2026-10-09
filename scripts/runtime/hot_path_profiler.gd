## 文件用途：提供运行时热点区间计时门面，通过根节点 Callable 将耗时传给已开启的整局采样器。
## 使用方式：区间开始时保存 begin(node) 的微秒戳，结束时调用 end(node, section, start_usec)；采样器未启用时 begin 返回零，end 忽略此值。
extends RefCounted
class_name HotPathProfiler


const ENABLED_META: StringName = &"real_full_run_profiler_enabled"
const HOT_PATH_EVENT_META: StringName = &"real_full_run_profiler_hot_path_event"


## 作用：确认节点所属树启用了采样且有热点回调，返回当前微秒时戳，否则返回零。
## 使用：以参与场景树的 node 调用 HotPathProfiler.begin(node)，保存返回的微秒戳；零表示未启用计时。
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


## 作用：计算从 start_usec 到当前的微秒耗时，将 section 与耗时送给根节点有效 Callable。
## 使用：把 begin 返回值连同原 node 和热点 section 传入；start_usec<=0 时无事件，有效采样将调用根节点热点回调。
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


## 作用：从执行上下文解析节点后复用 begin，返回区间开始微秒戳或零。
## 使用：传入技能执行上下文 context；从 event_bus/caster/owner/parent 寻树，返回微秒戳或零。
static func begin_context(context: Dictionary) -> int:
	return begin(_node_from_context(context))


## 作用：从执行上下文解析节点后复用 end，向采样器发送命名区间耗时。
## 使用：传入与开始计时一致的 context、区间名和微秒戳，结束计时并上报耗时。
static func end_context(context: Dictionary, section: StringName, start_usec: int) -> void:
	end(_node_from_context(context), section, start_usec)


## 作用：按 event_bus、caster、owner、parent 顺序返回上下文中的首个非空 Node，无匹配返回 null。
## 使用：通过预加载脚本的 _node_from_context(...) 静态入口调用。 入参：context: Dictionary。 返回 Node；具体值及空输入行为见作用说明。
static func _node_from_context(context: Dictionary) -> Node:
	for key: String in ["event_bus", "caster", "owner", "parent"]:
		var node: Node = context.get(key) as Node
		if node != null:
			return node
	return null
