extends RefCounted
class_name UIStateRegistry

const UIStateDescriptorScript: Script = preload("res://scripts/ui/ui_state_descriptor.gd")

const STATE_BOOT: String = "BOOT"
const STATE_TITLE: String = "TITLE"
const STATE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const STATE_MAP_SELECT: String = "MAP_SELECT"
const STATE_RUNNING: String = "RUNNING"
const STATE_LEVEL_UP_MODAL: String = "LEVEL_UP_MODAL"
const STATE_RUN_REWARD_MODAL: String = "RUN_REWARD_MODAL"
const STATE_CURSE_CHOICE_MODAL: String = "CURSE_CHOICE_MODAL"
const STATE_PAUSE_MENU: String = "PAUSE_MENU"
const STATE_RESULT_DEFEAT: String = "RESULT_DEFEAT"
const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const STATE_META_UPGRADE: String = "META_UPGRADE"
const STATE_CODEX: String = "CODEX"
const STATE_SETTINGS: String = "SETTINGS"


var _allowed_to_by_state: Dictionary = {}
var _running_child_states: Dictionary = {}
var _fullscreen_choice_states: Dictionary = {}
var _descriptors: Dictionary = {}
var _build_order: Array[String] = []


func _init() -> void:
	_register_defaults()


func can_transition(from_state: String, to_state: String) -> bool:
	if from_state == to_state:
		return true
	if not _allowed_to_by_state.has(from_state):
		return true
	var allowed_to: Array = _allowed_to_by_state.get(from_state, [])
	return allowed_to.has(to_state)


func get_descriptor(state: String) -> Dictionary:
	if _descriptors.has(state):
		return _descriptors[state]
	return {}


func get_build_order() -> Array[String]:
	return _build_order.duplicate()


func get_build_method(state: String) -> StringName:
	var descriptor: Dictionary = get_descriptor(state)
	if descriptor.is_empty():
		return &""
	return StringName(String(descriptor.get("build_method", "")))


func get_prepare_method(state: String) -> StringName:
	var descriptor: Dictionary = get_descriptor(state)
	if descriptor.is_empty():
		return &""
	return StringName(String(descriptor.get("prepare_method", "")))


func is_running_child_state(state: String) -> bool:
	return _running_child_states.has(state)


func is_fullscreen_choice_state(state: String) -> bool:
	return _fullscreen_choice_states.has(state)


func should_pause_for_state(state: String) -> bool:
	var descriptor: Dictionary = get_descriptor(state)
	if not descriptor.is_empty():
		return String(descriptor.get("pause_mode", "")) != UIStateDescriptorScript.PAUSE_MODE_RUNNING
	return state != STATE_RUNNING


func _register_defaults() -> void:
	_register_descriptor({
		"id": STATE_BOOT,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_boot",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_TITLE,
		"allowed_to": [STATE_CHARACTER_SELECT, STATE_META_UPGRADE, STATE_CODEX, STATE_SETTINGS],
		"build_method": "_build_title",
		"prepare_method": "_reset_title_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_CHARACTER_SELECT,
		"allowed_to": [STATE_MAP_SELECT, STATE_TITLE],
		"build_method": "_build_character_select",
		"prepare_method": "_refresh_character_select_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_MAP_SELECT,
		"allowed_to": [STATE_RUNNING, STATE_CHARACTER_SELECT],
		"build_method": "_build_map_select",
		"prepare_method": "_refresh_map_select_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_RUNNING,
		"allowed_to": [
			STATE_LEVEL_UP_MODAL,
			STATE_RUN_REWARD_MODAL,
			STATE_CURSE_CHOICE_MODAL,
			STATE_PAUSE_MENU,
			STATE_RESULT_DEFEAT,
			STATE_RESULT_VICTORY,
			STATE_TITLE
		],
		"build_method": "_build_run_hud",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_RUNNING
	})
	var running_child_targets: Array = [
		STATE_RUNNING,
		STATE_TITLE,
		STATE_CHARACTER_SELECT,
		STATE_META_UPGRADE,
		STATE_RESULT_DEFEAT,
		STATE_RESULT_VICTORY
	]
	for state: String in _get_running_child_state_list():
		_register_descriptor({
			"id": state,
			"allowed_to": running_child_targets,
			"is_running_child": true,
			"is_fullscreen_choice": [STATE_LEVEL_UP_MODAL, STATE_RUN_REWARD_MODAL].has(state),
			"build_method": _get_default_build_method(state),
			"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
		})
	_register_descriptor({
		"id": STATE_META_UPGRADE,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_meta_upgrade",
		"prepare_method": "_refresh_meta_upgrade_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_CODEX,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_codex",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_SETTINGS,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_settings",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})


func _register_descriptor(data: Dictionary) -> void:
	var descriptor: Dictionary = UIStateDescriptorScript.from_dictionary(data)
	var state: String = String(descriptor.get("id", ""))
	if state == "":
		return
	_descriptors[state] = descriptor
	if not _build_order.has(state):
		_build_order.append(state)
	_allowed_to_by_state[state] = descriptor.get("allowed_to", [])
	if bool(descriptor.get("is_running_child", false)):
		_running_child_states[state] = true
	if bool(descriptor.get("is_fullscreen_choice", false)):
		_fullscreen_choice_states[state] = true


func _get_default_build_method(state: String) -> String:
	match state:
		STATE_LEVEL_UP_MODAL:
			return "_build_level_up_modal"
		STATE_RUN_REWARD_MODAL:
			return "_build_run_reward_modal"
		STATE_CURSE_CHOICE_MODAL:
			return "_build_curse_choice_modal"
		STATE_PAUSE_MENU:
			return "_build_pause_menu"
		STATE_RESULT_DEFEAT, STATE_RESULT_VICTORY:
			return "_build_result_screen"
		_:
			return ""


func _get_running_child_state_list() -> Array[String]:
	return [
		STATE_LEVEL_UP_MODAL,
		STATE_RUN_REWARD_MODAL,
		STATE_CURSE_CHOICE_MODAL,
		STATE_PAUSE_MENU,
		STATE_RESULT_DEFEAT,
		STATE_RESULT_VICTORY
	]
