extends "res://tools/verify/qa_app_fixture.gd"
const Locale = preload("res://scripts/ui/localization_service.gd")

func signatures(cards: Array[Button]) -> Array[String]:
	var result: Array[String] = []
	for card: Button in cards:
		result.append(str(card.get_meta("choice_option",{})))
	return result

func skill_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill: RefCounted in manager.get_active_skills():
		result.append({"id": skill.skill_id, "level": skill.current_level, "rarity": skill.current_rarity})
	return result

func run() -> void:
	await setup_run()
	var choice: RefCounted = ui._run_choice_modal_controller
	choice._upgrade_pool._rng.seed = 512
	choice.add_pending_level(2)
	ui.transition_to("LEVEL_UP_MODAL")
	await settle(12)
	var screen: Node = ui._screen_registry.get_screen("LEVEL_UP_MODAL")
	var refresh: Button = screen.find_child("RerollSkills", true, false) as Button
	check(refresh != null, "skill choices expose a reroll button")
	if refresh == null:
		await finish()
		return
	var cards: Array[Button] = choice._choice_card_buttons.duplicate()
	var detail_scroll: ScrollContainer = screen.find_child("ChoiceDetailsScroll",true,false) as ScrollContainer
	var detail_label: Label = screen.find_child("ChoiceDetailsLabel",true,false) as Label
	check(detail_scroll != null and detail_label != null,"skill choices expose bounded details")
	var original := signatures(cards)
	var skills_before := skill_state()
	var pending_before: int = choice.pending_level_up_count
	var soul_before: int = SaveManager.get_soul_stones()
	for repeat: int in 8:
		await click(refresh)
		check(ui.current_state == "LEVEL_UP_MODAL" and paused, "reroll retains choice and pause %d" % repeat)
		check(choice.pending_level_up_count == pending_before, "reroll retains upgrade opportunity %d" % repeat)
		check(choice._choice_card_buttons.size() == 3, "reroll keeps three cards %d" % repeat)
		check(choice._choice_card_buttons == cards, "reroll reuses existing cards %d" % repeat)
		check(choice.get_rerolls_remaining() == maxi(2-repeat,0), "reroll respects three-use budget %d" % repeat)
	check(signatures(cards) != original, "repeated clicks generate new random candidates")
	check(skill_state() == skills_before, "reroll does not grant or upgrade skills")
	check(SaveManager.get_soul_stones() == soul_before, "reroll is free")
	for resolution: Vector2i in [Vector2i(1280,720), Vector2i(1152,648), Vector2i(800,600), Vector2i(1920,1080)]:
		root.size = resolution
		await settle(12)
		var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
		check(bounds.encloses(refresh.get_global_rect()), "reroll stays in viewport %s" % resolution)
		if detail_scroll != null and detail_label != null:
			cards[1].grab_focus()
			await settle()
			check(detail_label.text == cards[1].get_meta("choice_details",""),"focus exposes full details %s" % resolution)
			check(bounds.encloses(detail_scroll.get_global_rect()),"details stay in viewport %s" % resolution)
			check(detail_scroll.get_global_rect().end.y <= refresh.get_global_rect().position.y,"details end before reroll %s" % resolution)
		for card: Button in cards:
			check(bounds.encloses(card.get_global_rect()), "card stays in viewport %s" % resolution)
			check(card.get_global_rect().end.y <= refresh.get_global_rect().position.y, "reroll sits below cards %s" % resolution)
			if detail_scroll != null:
				check(card.get_global_rect().end.y <= detail_scroll.get_global_rect().position.y,"details never overlap candidate %s" % resolution)
	Locale.apply_language("en")
	Locale.refresh_tree(ui)
	check(refresh.text == "Free Reroll (0 left)" and refresh.disabled, "exhausted reroll follows selected language and stays disabled")
	Locale.apply_language("zh")
	Locale.refresh_tree(ui)
	check(refresh.text == "免费刷新（剩余 0 次）" and refresh.disabled, "Chinese reroll retains exhausted count")
	root.size = Vector2i(1280,720)
	await settle(12)
	await capture("skill-reroll")
	await click(cards[0])
	check(choice.pending_level_up_count == pending_before - 1, "choosing refreshed card consumes one opportunity")
	check(ui.current_state == "RUNNING" and not paused, "choosing refreshed card resumes game")
	await finish()
