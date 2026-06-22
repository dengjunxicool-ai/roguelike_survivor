extends SceneTree


const UIManagerScript: Script = preload("res://scripts/ui/ui_manager.gd")
const UIStateRegistryScript: Script = preload("res://scripts/ui/ui_state_registry.gd")
const UIStateMachineScript: Script = preload("res://scripts/ui/ui_state_machine.gd")
const ModalFlowControllerScript: Script = preload("res://scripts/ui/modals/modal_flow_controller.gd")
const UICommandDispatcherScript: Script = preload("res://scripts/ui/ui_command_dispatcher.gd")
const UICommandScript: Script = preload("res://scripts/ui/ui_command.gd")
const CharacterLoadoutViewModelBuilderScript: Script = preload("res://scripts/ui/screens/character_loadout_view_model_builder.gd")
const MapSelectViewModelBuilderScript: Script = preload("res://scripts/ui/screens/map_select_view_model_builder.gd")
const MetaUpgradeViewModelBuilderScript: Script = preload("res://scripts/ui/screens/meta_upgrade_view_model_builder.gd")
const CodexViewModelBuilderScript: Script = preload("res://scripts/ui/screens/codex_view_model_builder.gd")
const ResultScreenViewModelBuilderScript: Script = preload("res://scripts/ui/screens/result_screen_view_model_builder.gd")
const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")
const UIThemeServiceScript: Script = preload("res://scripts/ui/ui_theme_service.gd")
const RunHudControllerScript: Script = preload("res://scripts/ui/hud/run_hud_controller.gd")


class FakePlayer:
	extends Node
	var applied_upgrade_id: StringName = &""

	func apply_upgrade(upgrade_id: StringName) -> void:
		applied_upgrade_id = upgrade_id


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	_verify_state_contracts()
	_verify_modal_flow_contracts()
	_verify_command_contracts()
	_verify_view_models()
	_verify_localization_and_theme()
	_verify_run_hud_contracts()
	await _verify_ui_manager_smoke()
	print("[UIArchitectureCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _verify_state_contracts() -> void:
	var registry: RefCounted = UIStateRegistryScript.new()
	_assert(bool(registry.call("can_transition", "BOOT", "TITLE")), "BOOT can transition to TITLE")
	_assert(bool(registry.call("is_running_child_state", "BRANCH_CHOICE_MODAL")), "branch choice is a running child state")
	_assert(not bool(registry.call("should_pause_for_state", "RUNNING")), "RUNNING does not pause the tree")
	_assert(bool(registry.call("should_pause_for_state", "BRANCH_CHOICE_MODAL")), "branch choice pauses through descriptor policy")
	_assert(StringName(registry.call("get_build_method", "BRANCH_CHOICE_MODAL")) == &"_build_branch_choice_modal", "branch choice has a build method")

	var build_order: Array = registry.call("get_build_order")
	for state: String in [
		"BOOT",
		"TITLE",
		"CHARACTER_SELECT",
		"MAP_SELECT",
		"LEVEL_UP_MODAL",
		"RUN_REWARD_MODAL",
		"CURSE_CHOICE_MODAL",
		"EVOLUTION_MODAL",
		"BRANCH_CHOICE_MODAL",
		"PAUSE_MENU",
		"RESULT_DEFEAT",
		"RESULT_VICTORY",
		"META_UPGRADE",
		"CODEX",
		"SETTINGS"
	]:
		_assert(build_order.has(state), "build order contains %s" % state)

	var machine: RefCounted = UIStateMachineScript.new()
	machine.call("setup", "BOOT", registry)
	_assert(bool(machine.call("transition_to", "TITLE")), "state machine accepts registered transition")
	_assert(not bool(machine.call("transition_to", "RESULT_DEFEAT")), "state machine blocks invalid title to result transition")


func _verify_modal_flow_contracts() -> void:
	var modal_flow: RefCounted = ModalFlowControllerScript.new()
	modal_flow.call("request_modal", "reward", "RUN_REWARD_MODAL", {}, 10, false)
	modal_flow.call("request_modal", "level", "LEVEL_UP_MODAL", {}, 20, true)
	_assert(String(modal_flow.call("get_pending_state", null)) == "LEVEL_UP_MODAL", "modal requests are prioritized")
	modal_flow.call("complete_current_modal")
	_assert(String(modal_flow.call("get_pending_state", null)) == "RUN_REWARD_MODAL", "modal queue advances after completion")
	_assert(bool(modal_flow.call("is_modal_state", "BRANCH_CHOICE_MODAL")), "branch choice is treated as a modal state")


func _verify_command_contracts() -> void:
	var dispatcher: RefCounted = UICommandDispatcherScript.new()
	var player := FakePlayer.new()
	var option: Dictionary = {"id": &"damage_boost", "payload": {}}
	var result: Dictionary = _get_dictionary(dispatcher.call("dispatch", UICommandScript.apply_choice_option(option), {"player": player, "tree": self}))
	_assert(bool(result.get("handled", false)), "UICommand apply_choice_option is handled")
	_assert(player.applied_upgrade_id == &"damage_boost", "UICommand applies upgrade through dispatcher")
	player.queue_free()


func _verify_view_models() -> void:
	var character_vm: Dictionary = _get_dictionary(CharacterLoadoutViewModelBuilderScript.new().call("build", &"mage", &"fire_staff", 0, true))
	_assert(not _get_dictionary(character_vm.get("character", {})).is_empty(), "character loadout view model has selected character")
	_assert(not _get_array(character_vm.get("weapons", [])).is_empty(), "character loadout view model has allowed weapons")
	_assert(_get_dictionary(character_vm.get("action", {})).has("text"), "character loadout view model has action state")

	var map_vm: Dictionary = _get_dictionary(MapSelectViewModelBuilderScript.new().call("build", &"mage", &"fire_staff", &"abandoned_dungeon"))
	_assert(not _get_array(map_vm.get("maps", [])).is_empty(), "map select view model has maps")
	_assert(_get_dictionary(map_vm.get("start_button", {})).has("text"), "map select view model has start button state")

	var meta_vm: Dictionary = _get_dictionary(MetaUpgradeViewModelBuilderScript.new().call("build"))
	_assert(meta_vm.has("souls") and meta_vm.has("upgrades"), "meta upgrade view model has economy state")

	var codex_vm: Dictionary = _get_dictionary(CodexViewModelBuilderScript.new().call("build"))
	_assert(_get_array(codex_vm.get("tabs", [])).size() >= 6, "codex view model has main tabs")

	var unlocks: Array[String] = []
	var result_vm: Dictionary = _get_dictionary(ResultScreenViewModelBuilderScript.new().call("build", "RESULT_DEFEAT", {
		"selected_character_id": &"mage",
		"selected_weapon_id": &"fire_staff",
		"selected_map_id": &"abandoned_dungeon",
		"selected_map_name": "废弃地牢",
		"run_seconds": 12.0,
		"kill_count": 3,
		"run_souls_earned": 0
	}, unlocks))
	_assert(_get_dictionary(result_vm.get("labels", {})).has("title"), "result view model has labels")


func _verify_localization_and_theme() -> void:
	LocalizationServiceScript.apply_language("en")
	_assert(LocalizationServiceScript.translate("title.start", {}, "") == "Start Run", "localization switches to English")
	LocalizationServiceScript.apply_language("zh")
	_assert(LocalizationServiceScript.translate("title.start", {}, "") == "开始冒险", "localization switches to Chinese")
	var accent: Color = UIThemeServiceScript.get_color_token(["tokens", "colors", "accent"], Color.BLACK)
	_assert(accent != Color.BLACK, "theme color token resolves")
	_assert(UIThemeServiceScript.get_number_token(["tokens", "radius", "medium"], 0.0) > 0.0, "theme numeric token resolves")


func _verify_run_hud_contracts() -> void:
	var hud: RefCounted = RunHudControllerScript.new()
	var screen: CanvasLayer = hud.call("build", self) as CanvasLayer
	root.add_child(screen)
	screen.visible = true
	await process_frame
	hud.call("update_layout")
	hud.call("update", {
		"run_seconds": 12.0,
		"run_duration": 600.0,
		"wave_remaining_seconds": 30.0,
		"health": 50.0,
		"max_health": 100.0,
		"level": 2,
		"exp": 8,
		"exp_required": 20,
		"character_id": "mage",
		"current_weapon": "fire_staff",
		"main_attack": "fireball",
		"boss": {"visible": false}
	})
	_assert(screen.find_child("PauseButton", true, false) != null, "run HUD keeps pause button")
	for removed_name: String in [
		"Timer",
		"HPBar",
		"EXPBar",
		"EXPNumber",
		"AvatarFrame",
		"SkillSlotWeapon",
		"SkillSlotPrimary",
		"SkillSlotUltimate",
		"BossStatusPanel"
	]:
		_assert(screen.find_child(removed_name, true, false) == null, "run HUD omits %s" % removed_name)
	screen.queue_free()


func _verify_ui_manager_smoke() -> void:
	var ui_manager: CanvasLayer = UIManagerScript.new() as CanvasLayer
	root.add_child(ui_manager)
	await process_frame
	await process_frame
	_assert(String(ui_manager.get("current_state")) == "TITLE", "UIManager boots to TITLE")
	_assert(ui_manager.find_child("TITLE", false, false) != null, "UIManager builds title screen")
	_assert(ui_manager.find_child("BRANCH_CHOICE_MODAL", false, false) != null, "UIManager builds branch choice modal screen")
	ui_manager.queue_free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[UIArchitectureCheck] PASS %s" % message)
	else:
		_failed = true
		push_error("[UIArchitectureCheck] FAIL %s" % message)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
