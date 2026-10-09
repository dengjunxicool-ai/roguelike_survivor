## 文件用途：管理调试状态打印和玩家、敌人的范围覆盖层，维护敌人实例与覆盖层索引。
## 使用方式：以 DevDebugPanel 宿主构造本页控制器；持有 WeakRef，宿主负责控件与回调装配，不能独立挂载到场景。
extends RefCounted

const EnemyAttackRangeOverlayScript: Script = preload("res://scripts/debug/enemy_attack_range_overlay.gd")

var _host_ref: WeakRef

## 作用：保存宿主弱引用，范围圈索引由 DevDebugPanel 持有。
## 使用：创建页面控制器时传入 DevDebugPanel 宿主，保存弱引用。
func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


## 作用：构建状态打印和范围圈开关按钮，并绑定到宿主操作。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：page_root: VBoxContainer。
func _build_utility_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var utility_page: VBoxContainer = host._add_category_page(page_root, "utility", "Utility")
	var util_row: HBoxContainer = host._add_row(utility_page)
	host._add_button(util_row, "Print", Callable(host, "_print_state"), 72)
	host._add_button(util_row, "Ranges", Callable(host, "_toggle_range_overlay"), 84)


## 作用：反转范围显示状态，统一更新玩家和敌人覆盖层并记录日志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _toggle_range_overlay() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var next_visible: bool = not host._are_range_overlays_visible()
	host._set_all_range_overlays_visible(next_visible)
	host._log("Range overlay visible=%s." % str(next_visible))


## 作用：设置玩家 PlayerDebugOverlay 与所有敌人范围圈可见性，保存根节点显示标志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：should_show: bool。
func _set_all_range_overlays_visible(should_show: bool) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	var overlay: CanvasItem = null
	if player != null:
		overlay = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
	if overlay != null:
		overlay.visible = should_show
	host._sync_enemy_attack_range_overlays(should_show)
	host._set_range_overlays_visible(should_show)


## 作用：剔除失效覆盖层后遍历有效 enemies 组实体，保证范围层存在并设置可见性、请求重绘。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：should_show: bool。
func _sync_enemy_attack_range_overlays(should_show: bool) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._prune_enemy_attack_range_overlays()
	for node: Node in host.get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var overlay: CanvasItem = host._ensure_enemy_attack_range_overlay(enemy)
		if overlay != null:
			overlay.visible = should_show
			overlay.queue_redraw()


## 作用：复用敌人已有覆盖层或新建 EnemyAttackRangeOverlay 子节点，setup 后缓存到实例 ID 索引。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：enemy: Node2D。 返回 CanvasItem；具体值及空输入行为见作用说明。
func _ensure_enemy_attack_range_overlay(enemy: Node2D) -> CanvasItem:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var key: int = enemy.get_instance_id()
	var existing: CanvasItem = host._get_valid_enemy_range_overlay(key)
	if existing != null:
		return existing

	var overlay: Node2D = enemy.get_node_or_null("EnemyAttackRangeOverlay") as Node2D
	if overlay == null:
		overlay = EnemyAttackRangeOverlayScript.new() as Node2D
		overlay.name = "EnemyAttackRangeOverlay"
		enemy.add_child(overlay)
	if overlay.has_method("setup"):
		overlay.call("setup", enemy)
	host._enemy_range_overlays[key] = overlay
	return overlay as CanvasItem


## 作用：遍历范围圈缓存，移除已释放或待删除的条目。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _prune_enemy_attack_range_overlays() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for key: Variant in host._enemy_range_overlays.keys():
		if host._get_valid_enemy_range_overlay(int(key)) == null:
			host._enemy_range_overlays.erase(key)


## 作用：按实例 ID 查找有效 CanvasItem 覆盖层，失效或待删除时返回 null。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：key: int。 返回 CanvasItem；具体值及空输入行为见作用说明。
func _get_valid_enemy_range_overlay(key: int) -> CanvasItem:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var value: Variant = host._enemy_range_overlays.get(key, null)
	if value == null or not is_instance_valid(value):
		return null
	var overlay: CanvasItem = value as CanvasItem
	if overlay == null or overlay.is_queued_for_deletion():
		return null
	return overlay


## 作用：优先读取根节点 debug_range_overlays_visible；不存在时查询玩家覆盖层可见性。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 bool；具体值及空输入行为见作用说明。
func _are_range_overlays_visible() -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var tree: SceneTree = host.get_tree()
	if tree != null and tree.root != null and tree.root.has_meta("debug_range_overlays_visible"):
		return bool(tree.root.get_meta("debug_range_overlays_visible", false))
	var player: Node = host._get_player()
	var overlay: CanvasItem = null
	if player != null:
		overlay = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
	return overlay != null and overlay.visible


## 作用：把范围显示开关保存到根节点 debug_range_overlays_visible 元数据。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：visible: bool。
func _set_range_overlays_visible(visible: bool) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_range_overlays_visible", visible)


## 作用：构建状态摘要并输出到控制台，更新宿主最近日志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _print_state() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var text: String = host._build_state_text()
	print_rich("[color=cyan][DevDebug][/color]\n%s" % text)
	host._log("Printed state.")
