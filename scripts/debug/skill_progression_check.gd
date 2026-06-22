extends SceneTree


const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")

var _player: Node
var _upgrade_pool: RefCounted
var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	await _run_checks_impl()
	quit(1 if _failed else 0)


func _run_checks_impl() -> void:
	var main_scene: PackedScene = load("res://scenes/app_bootstrap.tscn") as PackedScene
	if main_scene == null:
		_fail("Cannot load app_bootstrap.tscn")
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var ui: Node = main.get_node_or_null("UIManager")
	if ui == null:
		_fail("Missing UIManager")
		return

	ui.call("transition_to", "TITLE")
	await process_frame
	ui.call("transition_to", "CHARACTER_SELECT")
	await process_frame
	ui.call("_on_loadout_confirmed", &"mage", &"fire_staff")
	await process_frame
	ui.call("_start_run", &"abandoned_dungeon")
	await process_frame
	await physics_frame

	_player = main.find_child("Player", true, false)
	if _player == null:
		_fail("Missing Player after starting run")
		return

	_upgrade_pool = UpgradePoolScript.new()
	_check_initial_weapon_skill()
	_check_lv2_branch_options()
	_apply_first_option_and_check_level(2, "branch_choice")
	_check_branch_locked_after_lv2()
	_check_level_up_option(3)
	_apply_first_option_and_check_level(3, "skill_level_up")
	_check_level_up_option(4)
	_apply_first_option_and_check_level(4, "skill_level_up")
	_check_level_up_option(5)
	_apply_first_option_and_check_level(5, "skill_level_up")
	_check_no_progression_options_after_lv5()
	print("[SkillProgressionCheck] done failed=%s" % str(_failed))


func _check_initial_weapon_skill() -> void:
	var skill: RefCounted = _get_weapon_skill()
	_expect(skill != null, "initial weapon skill exists")
	_expect(skill != null and int(skill.get("current_level")) == 1, "initial weapon skill is Lv1")


func _check_lv2_branch_options() -> void:
	var options: Array = _generate_options()
	var branch_count: int = 0
	var regular_count: int = 0
	for option: RefCounted in options:
		if String(option.get("type")) == "branch_choice":
			branch_count += 1
		else:
			regular_count += 1
	_expect(options.size() == 4, "Lv2 option pool has 4 choices in debug check")
	_expect(branch_count == 3, "Lv2 option pool keeps three branch choices")
	_expect(regular_count == 1, "Lv2 option pool keeps one regular upgrade")


func _check_branch_locked_after_lv2() -> void:
	var runtime: Node = _player.get_node_or_null("CharacterRuntime")
	var selected_branch_id: StringName = _get_selected_branch_id(runtime)
	_expect(selected_branch_id != &"", "Lv2 branch is locked after choosing one branch")
	_check_no_branch_choice_options(_generate_options())


func _check_level_up_option(target_level: int) -> void:
	var options: Array = _generate_options()
	_expect(options.size() == 4, "Lv%d option pool has 4 choices" % target_level)
	_expect(not options.is_empty() and String(options[0].get("type")) == "skill_level_up", "Lv%d first option is current branch level-up" % target_level)
	_check_no_branch_choice_options(options)
	if options.is_empty():
		return
	var payload: Dictionary = options[0].get("payload")
	_expect(int(payload.get("level", 0)) == target_level, "level-up option target is Lv%d" % target_level)


func _check_no_branch_choice_options(options: Array) -> void:
	for option: RefCounted in options:
		_expect(String(option.get("type")) != "branch_choice", "no extra Lv2 branch choices after branch lock")


func _check_no_progression_options_after_lv5() -> void:
	var options: Array = _generate_options()
	_expect(not options.is_empty(), "options still generate after Lv5")
	for option: RefCounted in options:
		var option_type: String = String(option.get("type"))
		_expect(option_type != "branch_choice", "no branch choices after Lv5")
		_expect(option_type != "skill_level_up", "no skill level-up choices after Lv5")
		_expect(option_type != "evolution", "no evolution choices after Lv5")


func _apply_first_option_and_check_level(expected_level: int, expected_type: String) -> void:
	var options: Array = _generate_options()
	if options.is_empty():
		_fail("No upgrade options available")
		return

	var option: RefCounted = options[0]
	_expect(String(option.get("type")) == expected_type, "option type is %s" % expected_type)
	_player.call("apply_upgrade", StringName(String(option.get("id"))))

	var skill: RefCounted = _get_weapon_skill()
	_expect(skill != null and int(skill.get("current_level")) == expected_level, "weapon skill reaches Lv%d" % expected_level)


func _generate_options() -> Array:
	return _upgrade_pool.call("generate_options", _player, 4)


func _get_weapon_skill() -> RefCounted:
	var runtime: Node = _player.get_node_or_null("CharacterRuntime")
	var skill_manager: Node = _player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null:
		return null
	return skill_manager.call("get_skill", StringName(String(runtime.call("get_equipped_weapon_skill_id")))) as RefCounted


func _get_selected_branch_id(runtime: Node) -> StringName:
	if runtime == null:
		return &""
	return StringName(String(runtime.call("get_selected_weapon_branch_id")))


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[SkillProgressionCheck] PASS %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	push_error("[SkillProgressionCheck] FAIL %s" % message)
