extends "res://tools/verify/qa_app_fixture.gd"
const Builder = preload("res://scripts/upgrades/skill_learn_option_builder.gd")
const Repo = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func run() -> void:
	await setup_run()
	root.size = Vector2i(800, 600)
	player.level = 12
	for id: StringName in [&"fire_cast_meteor_rain", &"fire_cast_lava_rift", &"fire_cast_scorching_vortex", &"fire_summon_crimson_dragon", &"fire_summon_ember_fox_pack"]:
		check(manager.add_skill(id), "fill actual ordinary skill " + String(id))
	var option: Dictionary = Builder.build_option_data(GameData.get_skill(&"holy_summon_shield_guardian"), Repo.resolve_upgrade(&"learn_skill_holy_summon_shield_guardian"), "epic")
	var choice: RefCounted = ui._run_choice_modal_controller
	choice.add_pending_level(2)
	ui.transition_to("LEVEL_UP_MODAL")
	var options: Array[Dictionary] = [option]
	choice._refresh_choice_card_modal(ui._level_up_options, options, "RUNNING", true)
	await settle(12)
	var card: Button = choice._choice_card_buttons[0]
	# Selecting a focused card exercises the same input route as a player.
	card.grab_focus()
	await key(KEY_ENTER)
	var view: CanvasLayer = choice._replacement_view
	check(is_instance_valid(view) and paused, "keyboard selection opens paused replacement transaction")
	if not is_instance_valid(view):
		await finish()
		return
	var focus: Control = root.gui_get_focus_owner()
	check(focus != null and view.is_ancestor_of(focus), "replacement takes focus away from background cards")
	var cancel_button: Button = buttons(view)[-1]
	for step: int in 9:
		await key(KEY_TAB)
		focus = root.gui_get_focus_owner()
		check(focus != null and view.is_ancestor_of(focus), "replacement keeps Tab focus inside modal %d" % step)
	for step: int in 30:
		focus = root.gui_get_focus_owner()
		if focus == cancel_button:
			break
		await key(KEY_TAB)
	check(root.gui_get_focus_owner() == cancel_button, "keyboard reaches cancellation")
	var scroll: ScrollContainer = view.find_child("ReplacementScroll", true, false)
	check(scroll.get_global_rect().intersects(cancel_button.get_global_rect()), "focused cancel is scrolled into view in compact window")
	await key(KEY_ENTER)
	await settle(8)
	check(not is_instance_valid(choice._replacement_view) and paused, "keyboard cancellation closes overlay while preserving pause")
	check(choice.pending_level_up_count == 1 and not player.get_meta("ordinary_replacement_used", false), "cancellation preserves pending upgrade and replacement opportunity")
	focus = root.gui_get_focus_owner()
	check(focus == card, "cancellation restores selected card focus")
	await key(KEY_ENTER)
	await settle(8)
	view = choice._replacement_view
	check(is_instance_valid(view) and paused, "keyboard reopens replacement after cancellation")
	if is_instance_valid(view):
		focus = root.gui_get_focus_owner()
		check(focus is Button and view.is_ancestor_of(focus) and focus != buttons(view)[-1], "replacement defaults to a valid target")
		await key(KEY_ENTER)
		await settle(8)
		check(manager.has_skill(&"holy_summon_shield_guardian"), "keyboard confirms real replacement skill")
		check(manager._count_capacity_active_skills() == 5, "replacement retains ordinary slot count")
		check(ui.current_state == "RUNNING" and not paused and choice.pending_level_up_count == 0, "keyboard commit consumes choice and restores gameplay")
	await finish()
