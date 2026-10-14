extends "res://tools/verify/qa_app_fixture.gd"
const Summary = preload("res://scripts/skills/skill_effect_summary_builder.gd")
const UpgradePreview = preload("res://scripts/ui/upgrade_preview_service.gd")
const Icons = preload("res://scripts/ui/skill_icon_service.gd")
const Locale = preload("res://scripts/ui/localization_service.gd")

func effect(stat: String, op: String, value: float) -> Dictionary:
	return {"stat":stat,"op":op,"value":value,"scope":{"domain":"player"},"source":"upgrade"}

func option_for(id: String) -> Dictionary:
	var upgrade: Dictionary = GameData.get_upgrade(StringName(id))
	return {"id":"level_up_upgrade:"+id,"type":"level_up_upgrade","display_name":upgrade.get("display_name",id),"rarity":upgrade.get("rarity","common"),"payload":{"upgrade_id":id},"description":upgrade.get("description","")}

func run() -> void:
	await setup_run()
	var choice: RefCounted = ui._run_choice_modal_controller
	var store: Node = player.get_node("ModifierStore")
	var sources: Dictionary = store.get_debug_sources()
	var hp: int = player.max_health
	var current: int = player.current_health
	var armor: int = player.armor
	var health_text: String = Summary.build_for_option(option_for("survival_health"),player)
	var armor_text: String = Summary.build_for_option(option_for("survival_defense"),player)
	check(health_text.contains("%d→%d" % [hp,hp+18]) and health_text.contains("+18"),"health card previews real max HP and +18")
	check(armor_text.contains("%d→%d" % [armor,armor+2]) and armor_text.contains("+2"),"armor card previews real armor and +2")
	player.current_health = maxi(hp-10,0)
	var heal_text: String = Summary.build_for_option(option_for("survival_heal"),player)
	check(heal_text.contains("30") and heal_text.contains("%d→%d" % [player.current_health,hp]),"heal card shows configured amount and capped resulting health")
	check(str(choice._split_value_line(heal_text).value).contains("恢复30"),"compact heal value retains the configured healing amount")
	player.current_health = current
	check(store.get_debug_sources() == sources and player.max_health == hp and player.armor == armor,"reading previews never changes player or modifier sources")
	player.set_run_modifier_source("qa:existing-health",[effect("max_hp","multiplier_add",0.1)])
	var boosted_hp: int = player.max_health
	var combination: Array = [effect("max_hp","add",18),effect("max_hp","multiplier_add",0.2)]
	var expected_hp: int = roundi((hp+18)*1.3)
	var combined_text: String = UpgradePreview.build_for_upgrade({"modifiers":combination},player)
	check(combined_text.contains("%d→%d" % [boosted_hp,expected_hp]),"health preview aggregates existing and new percentage modifiers from base")
	player.set_run_modifier_source("qa:next-health",combination)
	check(player.max_health == expected_hp,"health preview matches actual combined modifier application")
	player.clear_run_modifier_source("qa:next-health")
	player.clear_run_modifier_source("qa:existing-health")
	player.current_health = current
	var levels: Dictionary = {"level_modifiers":[[effect("armor","add",1)],[effect("armor","add",7)]],"modifiers":[effect("armor","add",2)]}
	check(UpgradePreview.build_for_upgrade(levels,player,2).contains("%d→%d" % [armor,armor+7]),"ordinary upgrade preview honors target payload level")
	var pickup_before: float = player.get_effective_pickup_radius()
	var pickup_effects: Array = [effect("pickup_radius","multiplier_add",0.25),effect("pickup_radius","add",18)]
	var pickup_text: String = UpgradePreview.build_for_upgrade({"modifiers":pickup_effects},player)
	player.set_run_modifier_source("qa:pickup",pickup_effects)
	check(pickup_text.contains(str(int(player.get_effective_pickup_radius()))),"pickup preview agrees with dynamic percentage and flat runtime query")
	check(player.get_effective_pickup_radius() > pickup_before,"pickup fixture applies real modifiers")
	player.clear_run_modifier_source("qa:pickup")
	var fire_icon: String = choice._get_option_icon_texture({"payload":{"skill_id":"fire_attack_searing"}})
	var frost_icon: String = choice._get_option_icon_texture({"payload":{"skill_id":"frost_attack_frostbite"}})
	check(fire_icon != "res://icon.svg" and fire_icon != frost_icon,"schools have recognizable distinct icons")
	check(choice._get_option_icon_texture(option_for("survival_health")) != choice._get_option_icon_texture(option_for("survival_defense")),"health and armor cards have distinct icons")
	check(Icons.icon_path_for_option({"icon":"res://assets/ui/skill_icons/bow.svg"}) == "res://assets/ui/skill_icons/bow.svg","specific configured icon is preserved")
	check(Icons.icon_path_for_skill("basic_dash").ends_with("dash.svg"),"basic dash has a recognizable movement icon")
	check(ResourceLoader.exists(Icons.icon_path_for_option({"payload":null,"visual":7})),"malformed optional icon metadata uses safe fallback")
	for skill: Dictionary in GameData.get_skill_pool():
		check(ResourceLoader.exists(Icons.icon_path_for_skill(str(skill.id))),"skill icon resolves "+str(skill.id))
	choice.add_pending_level(2)
	choice.add_pending_level(3)
	ui.transition_to("LEVEL_UP_MODAL")
	await settle(12)
	var cards: Array[Button] = choice._choice_card_buttons.duplicate()
	check(choice._get_option_rarity_text({"rarity":"common"}) == "普通","common rarity is translated")
	var injected_details: Label = Label.new()
	var actual_details: Label = choice._level_details_label
	choice.set_details_label(injected_details)
	cards[1].grab_focus()
	check(injected_details.text == cards[1].get_meta("choice_details"),"keyboard focus exposes complete details without choosing the card")
	check(choice.pending_level_up_count == 2,"focusing details never consumes a pending upgrade")
	injected_details.free()
	choice.set_details_label(actual_details,choice._reward_details_label)
	choice._show_card_details(cards[1])
	var current_details: String = actual_details.text
	Locale.apply_language("en")
	Locale.refresh_tree(ui)
	check(actual_details.text == current_details, "language refresh preserves the focused card's actual effects")
	Locale.apply_language("zh")
	Locale.refresh_tree(ui)
	player.remove_from_group("player")
	choice.reroll_level_up_options()
	check(choice.get_rerolls_remaining() == 3 and choice.pending_level_up_count == 2,"unsuccessful reroll preserves budget and pending queue")
	player.add_to_group("player")
	var replacement: CanvasLayer = CanvasLayer.new()
	choice._replacement_view = replacement
	var locked_state: int = choice._upgrade_pool._rng.state
	choice.reroll_level_up_options()
	check(choice.get_rerolls_remaining() == 3 and choice._upgrade_pool._rng.state == locked_state,"replacement confirmation locks rerolls")
	choice._replacement_view = null
	replacement.free()
	check(cards[0].tooltip_text.is_empty(),"card details never create an overlapping floating tooltip")
	check(choice.has_method("get_rerolls_remaining"),"reroll budget is exposed to UI")
	for index: int in 3: choice.reroll_level_up_options()
	var rng_state: int = choice._upgrade_pool._rng.state
	var details: Variant = cards[0].get_meta("choice_option",cards[0].tooltip_text)
	choice.reroll_level_up_options()
	check(choice._upgrade_pool._rng.state == rng_state,"fourth reroll leaves RNG unchanged")
	check(cards[0].get_meta("choice_option",cards[0].tooltip_text) == details,"fourth reroll preserves candidates")
	if choice.has_method("get_rerolls_remaining"):
		check(choice.get_rerolls_remaining() == 0,"three successful rerolls exhaust budget")
		choice.refresh_level_up_modal()
		check(choice.get_rerolls_remaining() == 0 and choice._upgrade_pool._rng.state == rng_state,"reopening same pending upgrade preserves budget and candidates")
		choice._finish_upgrade_choice({"handled":true},"RUNNING",true)
		check(choice.get_rerolls_remaining() == 3 and choice.pending_level_up_count == 1,"next pending upgrade gets its own three rerolls")
		choice.reset_run()
		choice.add_pending_level(2)
		check(choice.get_rerolls_remaining() == 3,"new run resets reroll budget")
	var stat_options: Array[Dictionary] = [option_for("survival_health"),option_for("survival_defense"),option_for("survival_heal")]
	choice._refresh_choice_card_modal(ui._level_up_options,stat_options,"RUNNING",true)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(800,600)]:
		root.size = resolution
		await settle(12)
		await capture("stat-cards-%dx%d" % [resolution.x,resolution.y])
	await finish()
