extends "res://tools/verify/qa_app_fixture.gd"
const Locale = preload("res://scripts/ui/localization_service.gd")
const Controller = preload("res://scripts/ui/screens/settings_screen_controller.gd")
func run() -> void:
	check(ProjectSettings.globalize_path("user://").replace("\\","/").begins_with("E:/codex/"),"settings failure test uses E drive userdata")
	SaveManager.set_language_id("en")
	SaveManager.set_master_volume_percent(37.0)
	SaveManager.set_fullscreen_enabled(false)
	Locale.apply_language("en")
	var body := VBoxContainer.new()
	root.add_child(body)
	var controller := Controller.new()
	controller.build(body)
	var changes: Array = []
	controller.language_changed.connect(func() -> void: changes.append(true))
	var before_bytes := FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	# Blocking only the atomic temporary destination makes real save calls fail,
	# without injecting ConfigFile parse errors into ordinary runtime logs.
	var blocked_path := ProjectSettings.globalize_path(SaveManager.SAVE_PATH + ".tmp")
	check(DirAccess.make_dir_absolute(blocked_path) == OK,"block save destination for controlled write failure")
	controller._language_button.select(0)
	controller._on_language_selected(0)
	check(Locale.get_language_id() == "en","failed language write leaves applied language intact")
	check(controller._language_button.selected == 1,"failed language write rolls selection back")
	check(changes.is_empty(),"failed language write emits no successful language change")
	controller._fullscreen_button.button_pressed = true
	check(not controller._fullscreen_button.button_pressed,"failed fullscreen write rolls toggle back")
	var previous_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	controller._master_slider.value = 55.0
	check(is_equal_approx(controller._master_slider.value,37.0),"failed volume write rolls slider back")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")),previous_db),"failed volume write leaves applied audio intact")
	check(FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before_bytes,"failed settings writes preserve whole saved progress")
	DirAccess.remove_absolute(blocked_path)
	body.queue_free()
	await settle()
	print("[qa] failures=",failures)
	quit(1 if failures else 0)
