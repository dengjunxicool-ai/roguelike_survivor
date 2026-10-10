extends "res://tools/verify/qa_app_fixture.gd"
const Locale = preload("res://scripts/ui/localization_service.gd")
const Settings = preload("res://scripts/ui/ui_settings_service.gd")
func texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label or node is Button: result.append(str(node.text))
	if node is TabContainer:
		for index: int in node.get_tab_count(): result.append(node.get_tab_title(index))
	for child: Node in node.get_children(): result.append_array(texts(child))
	return result
func expect_text(screen: Node, expected: String, label: String) -> void:
	check(texts(screen).has(expected), label + ": " + expected)
func find_tabs(node: Node) -> TabContainer:
	if node is TabContainer: return node
	for child: Node in node.get_children():
		var result: TabContainer = find_tabs(child)
		if result != null: return result
	return null
func run() -> void:
	# Persist English before instantiating UI: this exercises the startup path.
	SaveManager.set_language_id("en")
	SaveManager.add_soul_stones(123)
	SaveManager.save_value("permanent_upgrades", "meta_health", 20)
	root.size = Vector2i(800,600)
	app = APP.instantiate()
	root.add_child(app)
	await settle(12)
	ui = app.get_node("UIManager")
	check(Locale.get_language_id() == "en", "saved English applied at cold boot")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(800,600))
		await settle(12)
		for repeat: int in 3:
			Settings.apply_window_mode(false)
			await settle(12)
			check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "window preference stays windowed repeat %d" % repeat)
			check(DisplayServer.window_get_size() == Vector2i(800,600), "window preference preserves useful size repeat %d" % repeat)
		Settings.apply_window_mode(true)
		await settle(12)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen preference applies explicit target")
		Settings.apply_window_mode(true)
		await settle(12)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen preference is idempotent")
		Settings.apply_window_mode(false)
		await settle(12)
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "fullscreen returns to windowed")
		check(DisplayServer.window_get_size() == Vector2i(800,600), "fullscreen roundtrip preserves window dimensions")
	ui.transition_to("SETTINGS")
	await settle()
	var settings: RefCounted = ui._settings_controller
	for state: String in ["CODEX", "META_UPGRADE", "CHARACTER_SELECT"]:
		ui.transition_to("TITLE")
		ui.transition_to(state)
		await settle(12)
		var screen: Node = ui._screen_registry.get_screen(state)
		verify_page(screen,state,"cold English")
		var button_count: int = buttons(screen).size()
		if state == "CODEX": find_tabs(screen).current_tab = 2
		settings._on_language_selected(0)
		await settle()
		check(ui.current_state == state,"language callback preserves open " + state)
		if state == "CODEX": expect_text(screen,"返回主菜单", "existing codex switches Chinese")
		if state == "META_UPGRADE": expect_text(screen,"灵魂石：123", "existing meta balance switches Chinese")
		if state == "CHARACTER_SELECT": expect_text(screen,"选择角色", "existing character title switches Chinese")
		settings._on_language_selected(1)
		await settle(12)
		verify_page(screen,state,"live English")
		check(ui._screen_registry.get_screen(state) == screen,"language callback retains " + state + " page instance")
		check(buttons(screen).size() == button_count,"language callback adds no duplicate " + state + " controls")
		if state == "CODEX":
			check(find_tabs(screen).current_tab == 2,"language callback preserves selected codex tab")
			find_tabs(screen).current_tab = 0
			await settle()
		await capture(state.to_lower()+"-english-800")
	var character: RefCounted = ui._character_loadout_controller
	character._select_character(&"ranger")
	settings._on_language_selected(0)
	settings._on_language_selected(1)
	await settle()
	check(character.selected_character_id == &"ranger","language callback preserves chosen character")
	var scroll: ScrollContainer = character._layout_controls.body_scroll
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await settle(12)
	await capture("character-controls-english-800")
	await finish()
func verify_page(screen: Node, state: String, label: String) -> void:
	if state == "CODEX":
		for expected: String in ["Codex","Back to Title","Characters","Skills","Enemies","Statuses","Relics"]: expect_text(screen,expected,label+" codex")
	elif state == "META_UPGRADE":
		for expected: String in ["Soul Stones: 123","Back to Title","Max Level"]: expect_text(screen,expected,label+" meta")
		var purchase_found := false
		for button: Button in buttons(screen):
			if button.text.begins_with("Upgrade "): purchase_found = true
			if button.text == "Max Level": check(button.disabled,label+" max level prevents purchase")
		check(purchase_found,label+" meta cost buttons localized")
	else:
		for expected: String in ["Select Character","Back","Soul Stones: 123","Confirm","Characters","Base Stats"]: expect_text(screen,expected,label+" character")
