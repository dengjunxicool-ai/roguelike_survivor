extends "res://tools/verify/qa_app_fixture.gd"

const Resolver = preload("res://scripts/skills/modifier_resolver.gd")
const Support = preload("res://scripts/skills/skill_action_support.gd")

func run() -> void:
	await setup_run()
	var primary: RefCounted = manager.get_primary_attack_method()
	primary.current_level = 3
	primary.current_rarity = "rare"
	primary.add_runtime_modifier("range_add",37.0)
	primary.add_runtime_modifier("damage_add",5.0)
	player.set_run_modifier_source("qa_pause_movement",[{"stat":"move_speed","op":"multiplier_add","value":0.5,"scope":{"domain":"movement"},"source":"level_up_upgrade"}])
	ui._run_stats_tracker.damage_done_by_origin["primary_attack"] = 67
	var before_pause: Dictionary = _state()
	seed(24163)
	var refresh_random: int = randi()
	seed(24163)
	ui.transition_to("PAUSE_MENU")
	check(randi() == refresh_random, "pause refresh does not consume global random state")
	check(_state() == before_pause, "pause snapshot and preview construction are read only")
	await settle(8)
	var screen: Control = ui._screen_registry.get_screen("PAUSE_MENU")
	var stats_toggle: Button = screen.find_child("PauseStatsToggle", true, false)
	var skills_toggle: Button = screen.find_child("PauseSkillsToggle", true, false)
	check(stats_toggle != null, "pause exposes current attribute inspection")
	check(skills_toggle != null, "pause exposes learned skill inspection")
	if stats_toggle == null or skills_toggle == null:
		await finish()
		return
	var controller: RefCounted = ui.get("_pause_inspection_controller")
	var snapshot: Dictionary = controller.get_snapshot()
	check(snapshot.player_id == player.get_instance_id(), "snapshot belongs to current player")
	check(snapshot.attributes.attack_power == player.attack_power, "attributes use effective current player power")
	check(snapshot.attributes.pickup_radius == player.get_effective_pickup_radius(), "pickup inspection uses effective runtime radius")
	check(snapshot.attributes.move_speed == player._get_effective_move_speed(), "movement inspection includes dynamic movement modifiers")
	check("\n".join(snapshot.contribution_lines).contains("67"), "inspection reads existing recorded damage contribution")
	check(_skill(snapshot, primary.skill_id).level == primary.current_level, "independent neutral starting attack is inspectable")
	check(_skill(snapshot, primary.skill_id).rarity == primary.current_rarity, "primary inspection preserves actual rarity")
	var context: Dictionary = {"caster":player,"skill_instance":primary,"skill_manager":manager,"relic_manager":player.get_node("RelicManager")}
	var expected_range: float = float(Resolver.resolve_value(context,"range",primary.definition.components[1].params.range))
	check(_skill(snapshot, primary.skill_id).range == expected_range, "primary inspection includes current runtime range modifier")
	var output_action: Dictionary = primary.definition.events[1].actions[0]
	var expected_damage: int = roundi(Support.new()._resolve_scaled_amount(output_action.params.amount,context,"damage"))
	check(_skill(snapshot, primary.skill_id).preview.damage == expected_damage, "primary numeric preview matches runtime damage resolver with current modifier")
	check(not _skill(snapshot, &"basic_dash").is_empty(), "basic dash is inspectable before a school dash is learned")
	check(_skill(snapshot, primary.skill_id).range > 0, "starting attack includes actual targeting range")
	check(_skill(snapshot, primary.skill_id).preview.damage > 0, "starting attack includes numeric hit output")
	check(_skill(snapshot, primary.skill_id).trigger.contains("自动"), "starting attack explains automatic targeting")
	snapshot.skills.clear()
	check(not controller.get_snapshot().skills.is_empty(), "inspection snapshots are isolated from caller mutation")
	var state_before: Dictionary = _state()
	seed(41723)
	var expected_random: int = randi()
	seed(41723)
	await click(stats_toggle)
	await click(skills_toggle)
	screen.find_child("PauseInspectionScroll", true, false).scroll_vertical = 0
	await settle(6)
	await capture("pause-current-attributes")
	check(randi() == expected_random, "opening pause details does not consume global random state")
	check(_state() == state_before, "opening pause details leaves player, skills, upgrade options and rerolls unchanged")
	check(paused, "inspection preserves tree pause")
	check(screen.find_child("CombatControlsGuide", true, false).text.contains("空格"), "pause preserves combat input guide")
	var resume: Button = _button(screen, "继续游戏")
	var quit_button: Button = _button(screen, "返回主菜单")
	check(not _inside_scroll(resume, screen) and not _inside_scroll(quit_button, screen), "pause actions remain outside scrollable inspection")
	for resolution: Vector2i in [Vector2i(800,600), Vector2i(1152,648), Vector2i(1280,720)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		await settle(12)
		var scroll: ScrollContainer = screen.find_child("PauseInspectionScroll", true, false)
		scroll.scroll_vertical = 10000
		await settle(8)
		check(scroll.scroll_vertical > 0, "expanded inspection scrolls at %s" % resolution)
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(resume.get_global_rect()), "resume remains reachable at %s" % resolution)
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(quit_button.get_global_rect()), "quit remains reachable at %s" % resolution)
		await capture("pause-inspection-%dx%d" % [resolution.x,resolution.y])
	ui.transition_to("RUNNING")
	check(manager.add_skill(&"fire_dash_blazing_run"), "fixture learns a real school dash")
	check(manager.add_skill(&"fire_power_combustion_chain"), "fixture learns a real passive skill")
	manager.upgrade_skill(&"fire_dash_blazing_run")
	player.attack_power = 77.0
	ui.transition_to("PAUSE_MENU")
	await settle(8)
	snapshot = controller.get_snapshot()
	check(snapshot.attributes.attack_power == 77.0, "reopening pause refreshes changed attributes")
	check(_skill(snapshot, &"fire_dash_blazing_run").level == 2, "reopening pause refreshes learned skill level")
	check(_skill(snapshot, &"basic_dash").is_empty(), "school dash replaces basic dash inspection")
	check(_skill(snapshot, &"fire_dash_blazing_run").trigger.contains("冲刺"), "school dash explains its trigger")
	check(not _skill(snapshot, &"fire_power_combustion_chain").lines.is_empty(), "passive skill exposes actual current effects")
	check(not skills_toggle.button_pressed and not stats_toggle.button_pressed, "reopening starts with folded fresh details")
	await click(skills_toggle)
	await capture("pause-learned-skills")
	ui.transition_to("TITLE")
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"mage")
	await ui._start_run(&"abandoned_dungeon")
	ui._run_scene_coordinator.get_run_scene_parent(self).process_mode = Node.PROCESS_MODE_DISABLED
	await settle(8)
	player = get_first_node_in_group(&"player")
	manager = player.get_node("SkillManager")
	ui.transition_to("PAUSE_MENU")
	await settle(8)
	snapshot = controller.get_snapshot()
	check(snapshot.player_id == player.get_instance_id(), "new run refreshes inspection player identity")
	check(_skill(snapshot, &"fire_dash_blazing_run").is_empty(), "new run never shows previous learned skills")
	check(snapshot.attributes.attack_power != 77.0, "new run never shows previous attribute values")
	check(not "\n".join(snapshot.contribution_lines).contains("67"), "new run never shows previous contribution totals")
	await finish()

func _skill(snapshot: Dictionary, id: StringName) -> Dictionary:
	for skill: Dictionary in snapshot.skills:
		if StringName(skill.skill_id) == id: return skill
	return {}

func _state() -> Dictionary:
	var skills: Array = []
	for skill: RefCounted in manager.get_active_skills()+manager.get_passive_skills():
		skills.append([skill.skill_id,skill.current_level,skill.current_rarity,skill.cooldown_remaining,skill.runtime_modifiers.duplicate(true),skill.runtime_special_rules.duplicate(true),skill.runtime_events.duplicate(true),skill.definition.events.duplicate(true)])
	return {"health":player.current_health,"level":player.level,"experience":player.current_experience,"power":player.attack_power,"skills":skills,"learned":manager.learned_skill_ids.duplicate(true),"rerolls":ui._run_choice_modal_controller.get_rerolls_remaining(),"options":ui._run_choice_modal_controller.get("_current_level_options").duplicate(true),"statistics":ui._run_stats_tracker.get_summary()}

func _button(screen: Node, text: String) -> Button:
	for button: Button in buttons(screen):
		if button.text == text: return button
	return null

func _inside_scroll(control: Control, screen: Node) -> bool:
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != screen:
		if ancestor is ScrollContainer: return true
		ancestor = ancestor.get_parent()
	return false
