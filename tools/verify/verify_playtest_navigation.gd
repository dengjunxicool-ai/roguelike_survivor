extends "res://tools/verify/qa_app_fixture.gd"

const ViewModel = preload("res://scripts/ui/screens/result_screen_view_model_builder.gd")

func run() -> void:
	await setup_run()
	ui.transition_to("RESULT_DEFEAT")
	await settle(12)
	var result: Control = ui._screen_registry.get_screen("RESULT_DEFEAT")
	var boss: Label = ui._result_controller._labels_by_state["RESULT_DEFEAT"]["boss"]
	check(not boss.visible, "a run without a boss hides boss combat metrics")
	var retry: Button = _button_with_text(result, "再来一局")
	check(retry != null, "result keeps a retry action")
	if retry != null:
		check(not _inside_scroll(retry, result), "retry is fixed outside long combat details")
	for resolution: Vector2i in [Vector2i(1152,648), Vector2i(800,600), Vector2i(720,480), Vector2i(1920,1080)]:
		root.size = resolution
		await settle(12)
		if retry != null:
			check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(retry.get_global_rect()), "retry is visible without scrolling at %s" % resolution)
	await capture("result-fixed-actions")
	root.size = Vector2i(800,600)
	await settle(12)
	var toggle: Button = result.find_child("CombatDetailsToggle", true, false)
	await click(toggle)
	var result_scroll: ScrollContainer = ui._result_controller._labels_by_state["RESULT_DEFEAT"]["title"].get_parent().get_parent()
	result_scroll.scroll_vertical = 1000
	await settle(12)
	check(toggle.button_pressed and result_scroll.scroll_vertical > 0, "result details can be expanded and scrolled before retry")
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	await settle(12)
	ui.transition_to("RESULT_DEFEAT")
	await settle(12)
	check(not toggle.button_pressed, "new run resets the result detail toggle")
	check(not result.find_child("CombatResultDetails", true, false).visible, "new run folds previous combat details")
	check(result_scroll.scroll_vertical == 0, "new result begins at the top instead of the previous scroll position")
	ui.transition_to("TITLE")
	ui.transition_to("CHARACTER_SELECT")
	await settle(12)
	var screen: Control = ui._screen_registry.get_screen("CHARACTER_SELECT")
	var confirm: Button = screen.find_child("CharacterConfirmButton", true, false)
	check(confirm != null and not _inside_scroll(confirm, screen), "character confirmation is fixed outside scrollable information")
	for resolution: Vector2i in [Vector2i(1152,648), Vector2i(800,600), Vector2i(720,480), Vector2i(1920,1080)]:
		root.size = resolution
		await settle(12)
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(confirm.get_global_rect()), "character confirm is visible without scrolling at %s" % resolution)
		var scroll: ScrollContainer = ui._character_loadout_controller._layout_controls["body_scroll"]
		scroll.scroll_vertical = 1000
		await settle(8)
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(confirm.get_global_rect()), "scrolling character details does not move confirmation at %s" % resolution)
	root.size = Vector2i(720,480)
	await settle(12)
	ui._character_loadout_controller._layout_controls["body_scroll"].scroll_vertical = 1000
	await settle(8)
	check(ui._character_loadout_controller._layout_controls["body_scroll"].scroll_vertical > 0, "compact character details contain scrollable information")
	ui._character_loadout_controller.refresh(&"mage")
	await settle(8)
	check(ui._character_loadout_controller._layout_controls["body_scroll"].scroll_vertical == 0, "reopening character selection begins at the top")
	await capture("character-fixed-confirm")
	ui._on_loadout_confirmed(&"mage")
	await settle(8)
	var preparation: Node = ui._screen_registry.get_screen("MAP_SELECT")
	var hint: Label = preparation.find_child("CombatControlsHint", true, false)
	check(hint != null and hint.is_visible_in_tree() and hint.text.contains("空格"), "battle preparation explains dash before starting combat")
	check(hint != null and hint.text.contains("自动"), "battle preparation explains automatic attacks")
	ui.transition_to("CHARACTER_SELECT")
	ui.transition_to("TITLE")
	ui.transition_to("SETTINGS")
	await settle()
	var settings: Node = ui._screen_registry.get_screen("SETTINGS")
	check(_text(settings).contains("空格") and _text(settings).contains("自动"), "settings exposes complete combat controls")
	var recorded: Dictionary = {"selected_character_id":"mage", "player_dead":false, "run_stats":{"damage_done_total":40,"damage_taken_total":50}}
	var victory: Dictionary = ViewModel.new().build("RESULT_VICTORY", recorded, [] as Array[String])
	check(not str(victory.diagnostic.diagnosis_text).contains("先补稳定性"), "victory context prevents a defeat-specific survival diagnosis")
	check(not recorded.has("result_state"), "building a result never mutates the recorded run state")
	await finish()

func _button_with_text(node: Node, value: String) -> Button:
	for button: Button in buttons(node):
		if button.text == value:
			return button
	return null

func _inside_scroll(control: Control, screen: Node) -> bool:
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != screen:
		if ancestor is ScrollContainer:
			return true
		ancestor = ancestor.get_parent()
	return false

func _text(node: Node) -> String:
	var result: String = str(node.text) if node is Label or node is Button else ""
	for child: Node in node.get_children():
		result += "\n" + _text(child)
	return result
