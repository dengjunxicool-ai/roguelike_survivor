extends SceneTree

const DevDebugEffectsPageScript: Script = preload("res://scripts/debug/pages/dev_debug_effects_page.gd")

var _failed: bool = false
var _world: Node2D
var _player: Node2D
var _enemy: Node2D
var _orphan_player: Node2D
var _logs: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node2D.new()
	_world.name = "EffectsPageWorld"
	root.add_child(_world)
	_player = Node2D.new()
	_player.name = "EffectsPagePlayer"
	_player.global_position = Vector2(40.0, 60.0)
	_world.add_child(_player)
	_enemy = Node2D.new()
	_enemy.name = "EffectsPageEnemy"
	_enemy.global_position = Vector2(240.0, 60.0)
	_world.add_child(_enemy)

	var page: VBoxContainer = DevDebugEffectsPageScript.new() as VBoxContainer
	root.add_child(page)
	page.call("setup", Callable(self, "_get_player"), Callable(self, "_get_nearest_enemy"))
	page.connect("log_requested", Callable(self, "_on_log_requested"))
	page.call("build")
	page.call("build")
	page.call("populate_options")
	page.call("populate_options")

	var option: OptionButton = page.call("get_effect_option") as OptionButton
	_expect(option != null, "effect option exists")
	_expect(_count_option_buttons(page) == 1, "effect option stays unique", _count_option_buttons(page))
	_expect(option.item_count == 2, "effect options stay idempotent", option.item_count)
	_expect(option.get_item_text(0) == "Fire Tornado", "fire option label", option.get_item_text(0))
	_expect(String(option.get_item_metadata(0)) == "fire_tornado", "fire option id", option.get_item_metadata(0))
	_expect(option.get_item_text(1) == "火星飞弹", "mars option label", option.get_item_text(1))
	_expect(String(option.get_item_metadata(1)) == "mars_spark_missile", "mars option id", option.get_item_metadata(1))
	_expect(_count_button_text(page, "持续发射") == 1, "continuous button stays unique")
	_expect(_count_button_text(page, "单次发射") == 1, "single button stays unique")
	var continuous_button: Button = _find_button_text(page, "持续发射")
	var single_button: Button = _find_button_text(page, "单次发射")
	_expect(continuous_button != null, "continuous button is bound")
	_expect(single_button != null, "single button is bound")

	option.select(0)
	if single_button != null:
		single_button.pressed.emit()
	await process_frame
	var tornado: Node2D = _find_child_by_script_suffix(_world, "fire_tornado_effect.gd") as Node2D
	_expect(tornado != null, "fire tornado spawns")
	if tornado != null:
		_expect(tornado.global_position.is_equal_approx(Vector2(136.0, 60.0)), "fire tornado keeps spawn position", tornado.global_position)
		tornado.queue_free()
	await process_frame

	option.select(1)
	if continuous_button != null:
		continuous_button.pressed.emit()
	await process_frame
	var continuous_mars: Node = _find_child_by_script_suffix(_world, "mars_spark_missile_effect.gd")
	_expect(continuous_mars != null and bool(continuous_mars.get("_continuous")), "continuous button enables continuous mode")
	if continuous_mars != null:
		continuous_mars.queue_free()
	await process_frame

	if single_button != null:
		single_button.pressed.emit()
	await process_frame
	var single_mars: Node = _find_child_by_script_suffix(_world, "mars_spark_missile_effect.gd")
	_expect(single_mars != null and not bool(single_mars.get("_continuous")), "single button disables continuous mode")
	if single_mars != null:
		single_mars.queue_free()
	await process_frame

	option.set_item_metadata(option.selected, &"unknown_effect")
	_logs.clear()
	page.call("fire_single_effect")
	_expect(_has_log_level(&"warning"), "unknown effect emits warning")

	var isolated_page: VBoxContainer = DevDebugEffectsPageScript.new() as VBoxContainer
	root.add_child(isolated_page)
	isolated_page.connect("log_requested", Callable(self, "_on_log_requested"))
	isolated_page.call("setup", Callable(), Callable())
	isolated_page.call("build")
	isolated_page.call("populate_options")
	_logs.clear()
	isolated_page.call("fire_single_effect")
	_expect(_has_log_level(&"warning"), "invalid player lookup emits warning")

	_orphan_player = Node2D.new()
	var orphan_page: VBoxContainer = DevDebugEffectsPageScript.new() as VBoxContainer
	root.add_child(orphan_page)
	orphan_page.connect("log_requested", Callable(self, "_on_log_requested"))
	orphan_page.call("setup", Callable(self, "_get_orphan_player"), Callable())
	orphan_page.call("build")
	orphan_page.call("populate_options")
	_logs.clear()
	orphan_page.call("fire_single_effect")
	await process_frame
	_expect(_has_log_level(&"error"), "missing spawn parent emits error")
	_expect(_find_child_by_script_suffix(root, "fire_tornado_effect.gd") == null, "missing-parent effect is not retained")
	_orphan_player.free()

	if not _failed:
		print("[verify_dev_debug_effects_page] PASS")
	quit(1 if _failed else 0)


func _get_player() -> Node2D:
	return _player


func _get_nearest_enemy() -> Node2D:
	return _enemy


func _get_orphan_player() -> Node2D:
	return _orphan_player


func _on_log_requested(level: StringName, message: String) -> void:
	_logs.append({"level": level, "message": message})


func _has_log_level(level: StringName) -> bool:
	for entry: Dictionary in _logs:
		if StringName(String(entry.get("level", ""))) == level:
			return true
	return false


func _count_option_buttons(node: Node) -> int:
	return node.find_children("*", "OptionButton", true, false).size()


func _count_button_text(node: Node, text: String) -> int:
	var count: int = 0
	for child: Node in node.find_children("*", "Button", true, false):
		if child is OptionButton:
			continue
		if child is Button and (child as Button).text == text:
			count += 1
	return count


func _find_button_text(node: Node, text: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		if child is Button and not child is OptionButton and (child as Button).text == text:
			return child as Button
	return null


func _find_child_by_script_suffix(parent: Node, suffix: String) -> Node:
	for child: Node in parent.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with(suffix):
			return child
	return null


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_dev_debug_effects_page] FAIL %s actual=%s" % [label, str(actual)])
