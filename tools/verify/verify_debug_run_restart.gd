extends SceneTree

const Page := preload("res://scripts/debug/pages/dev_debug_run_setup_page.gd")

class RunUI:
	extends Node
	var options: Dictionary = {}
	func start_developer_debug_run(value: Dictionary) -> void:
		options = value

class Host:
	extends CanvasLayer
	var ui: RunUI = RunUI.new()
	var _character_option: OptionButton = OptionButton.new()
	var _map_option: OptionButton = OptionButton.new()
	var refresh_count := 0
	func _get_ui_manager() -> Node: return ui
	func _get_selected_id(option: OptionButton) -> String:
		return "knight" if option == _character_option else "crypt"
	func _refresh_state() -> void: refresh_count += 1
	func _log(_text: String) -> void: pass
	func _log_error(_text: String) -> void: pass
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			ui.free()
			_character_option.free()
			_map_option.free()

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var host := Host.new()
	root.add_child(host)
	var page := Page.new(host)
	page._restart_debug_run()
	var correct_payload := host.ui.options == {"character_id": "knight", "map_id": "crypt"}
	await process_frame
	var passed := correct_payload and host.refresh_count == 1
	if passed: print("[verify_debug_run_restart] PASS")
	else: push_error("[verify_debug_run_restart] FAIL restart must refresh its host once")
	host.free()
	quit(0 if passed else 1)
