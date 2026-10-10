extends SceneTree
const APP = preload("res://scenes/app/app_bootstrap.tscn")
var failures: int = 0
var app: Node
var ui: Node
var player: Node
var manager: Node
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func settle(count: int = 5) -> void:
	for i: int in count: await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-dir="): continue
		var output: String = argument.trim_prefix("--capture-dir=").replace("\\","/").simplify_path()
		if not output.begins_with("E:/codex/"):
			check(false,"capture output must stay on E:/codex")
			return
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"rendered screenshot " + label)
func setup_run() -> void:
	var resolution := Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-resolution="):
			var dimensions := argument.trim_prefix("--qa-resolution=").split("x")
			if dimensions.size() == 2: resolution = Vector2i(int(dimensions[0]),int(dimensions[1]))
	root.size = resolution
	create_timer(25.0, true).timeout.connect(func() -> void: push_error("QA test timed out"); quit(1))
	app = APP.instantiate()
	root.add_child(app)
	await settle()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		await settle()
	ui = app.get_node("UIManager")
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	await settle()
	player = get_first_node_in_group(&"player")
	manager = player.get_node("SkillManager")
	ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	# Startup returns while its 0.18 s loading fade is still in flight.
	await create_timer(0.3, true).timeout
	check(not ui._run_loading_overlay.visible,"startup overlay finishes before interaction")
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child: Node in node.get_children(): result.append_array(buttons(child))
	return result
func click(button: Button) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.ensure_control_visible(button)
		await settle()
	var visible_rect: Rect2 = button.get_global_rect().intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
	if ancestor is ScrollContainer: visible_rect = visible_rect.intersection(ancestor.get_global_rect())
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = visible_rect.get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func finish() -> void:
	paused = false
	app.queue_free()
	await settle(2)
	print("[qa] failures=", failures)
	quit(1 if failures else 0)
