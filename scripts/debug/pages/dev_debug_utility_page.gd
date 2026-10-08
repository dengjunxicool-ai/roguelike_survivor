extends RefCounted

const EnemyAttackRangeOverlayScript: Script = preload("res://scripts/debug/enemy_attack_range_overlay.gd")

var _host_ref: WeakRef

func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


func _build_utility_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var utility_page: VBoxContainer = host._add_category_page(page_root, "utility", "Utility")
	var util_row: HBoxContainer = host._add_row(utility_page)
	host._add_button(util_row, "Print", Callable(host, "_print_state"), 72)
	host._add_button(util_row, "Ranges", Callable(host, "_toggle_range_overlay"), 84)


func _toggle_range_overlay() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var next_visible: bool = not host._are_range_overlays_visible()
	host._set_all_range_overlays_visible(next_visible)
	host._log("Range overlay visible=%s." % str(next_visible))


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


func _prune_enemy_attack_range_overlays() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for key: Variant in host._enemy_range_overlays.keys():
		if host._get_valid_enemy_range_overlay(int(key)) == null:
			host._enemy_range_overlays.erase(key)


func _get_valid_enemy_range_overlay(key: int) -> CanvasItem:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var value: Variant = host._enemy_range_overlays.get(key, null)
	if value == null or not is_instance_valid(value):
		return null
	var overlay: CanvasItem = value as CanvasItem
	if overlay == null or overlay.is_queued_for_deletion():
		return null
	return overlay


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


func _set_range_overlays_visible(visible: bool) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_range_overlays_visible", visible)


func _print_state() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var text: String = host._build_state_text()
	print_rich("[color=cyan][DevDebug][/color]\n%s" % text)
	host._log("Printed state.")
