extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Hud = preload("res://scripts/ui/hud/run_hud_controller.gd")
const State = preload("res://scripts/ui/hud/run_hud_state_provider.gd")
const Replace = preload("res://scripts/ui/skill_replacement_view.gd")
const Service = preload("res://scripts/skills/skill_replacement_service.gd")
const Preview = preload("res://scripts/ui/skill_preview_service.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	setup()
	var state: RefCounted = State.new()
	expect(state.has_method("_skill_feedback"),"HUD reads actual core resources and echo readiness")
	if failed > 0: finish(); return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/skills.json"))
	for skill: Dictionary in data.skills:
		var text: String = skill.description
		for internal: String in Preview.Names:
			expect(not text.contains(internal) and not text.contains(internal.capitalize()),str(skill.id)+" localized "+internal)
	for god: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/gods.json")).gods:
		expect(not god.description.contains("规划中"),str(god.id)+" implemented description")
	var core: RefCounted = install(&"fire_core_inferno_cycle")
	var rule: Dictionary = {}
	for candidate: Dictionary in core.definition.trigger_rules:
		if candidate.has("counter_key"): rule = candidate; break
	core.set_meta(str(rule.get("counter_key","")),3.0)
	var feedback: String = state._skill_feedback(player,core)
	expect(feedback.contains("3/") and not feedback.contains("fire_"),"core charge is readable")
	var selected: Dictionary = {"attack":0,"dash":0,"ordinary":0,"passive":0,"fusion":0}
	for skill: Dictionary in data.skills:
		if skill.school not in ["fire","frost"]: continue
		var category: String = str(preload("res://scripts/skills/skill_slot_policy.gd").capacity_group(skill))
		if not selected.has(category): continue
		var cap: int = 5 if category == "ordinary" else (3 if category == "passive" else 1)
		if selected[category] >= cap: continue
		install(StringName(skill.id))
		selected[category] += 1
	var hud: RefCounted = Hud.new()
	root.add_child(hud.build(self))
	hud.get("_screen").visible = true
	hud.update(state.build({"tree":self}))
	var slots: Array = hud.get("_skill_slot_nodes")
	expect(slots.size() == 12,"all twelve HUD slots retained")
	for size: Vector2 in [Vector2(1280,720),Vector2(960,540)]:
		if DisplayServer.get_name() != "headless":
			await preload("res://tools/verify/verification_run_environment.gd").configure_rendered_viewport()
			DisplayServer.window_set_size(Vector2i(size))
			await process_frame
			await process_frame
		root.size = Vector2i(size)
		hud.update_layout()
		var panel: Control = hud.get("_skill_slot_panel")
		for slot: Dictionary in slots:
			var control: Control = slot.slot
			expect(control.position.x >= -1 and control.position.x+control.size.x <= panel.size.x+1,"HUD fits window "+str(size))
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var dir: String = OS.get_environment("APPDATA").get_base_dir()
			root.get_texture().get_image().save_png(dir+"/hud-"+str(int(size.x))+".png")
	hud.get("_screen").queue_free()
	var cards_layer: CanvasLayer = CanvasLayer.new()
	cards_layer.layer = 250
	root.add_child(cards_layer)
	var background: ColorRect = ColorRect.new()
	background.color = Color(.04,.04,.05,1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cards_layer.add_child(background)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(cards)
	var modal: RefCounted = preload("res://scripts/ui/modals/run_choice_modal_controller.gd").new()
	var dummy: VBoxContainer = VBoxContainer.new()
	background.add_child(dummy)
	modal.setup(self,cards,dummy)
	var options: Array[Dictionary] = []
	for id: StringName in [&"fire_cast_meteor_rain",&"frost_cast_glacial_lance",&"fire_core_inferno_cycle"]:
		options.append({"display_name":GameData.get_skill(id).display_name,"description":GameData.get_skill(id).description,"rarity":"legendary","payload":{"skill_id":id,"level":5,"target_rarity":"legendary"}})
	modal._refresh_choice_card_modal(cards,options,"RUNNING",false)
	await process_frame
	await process_frame
	for button: Button in modal.get("_choice_card_buttons"):
		var label: Label = button.find_child("SkillCardDescription",true,false)
		expect(label != null and label.max_lines_visible == 3 and label.clip_contents,"long Chinese description is bounded to its card")
		expect(button.tooltip_text.contains("伤害") and not button.tooltip_text.contains("proc_"),"full numerical preview retained in tooltip")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("APPDATA").get_base_dir()+"/cards-960.png")
	cards_layer.queue_free()
	manager.clear_skills()
	for id: StringName in [&"fire_cast_meteor_rain",&"fire_cast_lava_rift",&"fire_cast_scorching_vortex",&"fire_summon_crimson_dragon",&"fire_summon_ember_fox_pack"]: manager.add_skill(id)
	var service: RefCounted = Service.new()
	var tx: Dictionary = service.begin(player,&"frost_cast_glacial_lance","rare")
	expect(not tx.is_empty(),"UI replacement transaction available")
	var view: CanvasLayer = Replace.new()
	root.add_child(view)
	view.open(player,service,tx,func() -> void: pass)
	await process_frame
	var scroll: Control = view.get_node_or_null("ReplacementBackdrop/ReplacementScroll")
	expect(scroll != null and scroll.size.x <= root.size.x,"replacement scroll fits narrow window")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("APPDATA").get_base_dir()+"/replacement.png")
	var buttons: Array[Node] = view.find_children("*","Button",true,false)
	buttons.back().emit_signal("pressed")
	await process_frame
	expect(not player.get_meta("ordinary_replacement_used",false),"UI cancel preserves chance")
	tx = service.begin(player,&"frost_cast_glacial_lance","rare")
	view = Replace.new()
	root.add_child(view)
	view.open(player,service,tx,func() -> void: pass)
	buttons = view.find_children("*","Button",true,false)
	buttons.front().emit_signal("pressed")
	await process_frame
	expect(manager.has_skill(&"frost_cast_glacial_lance") and player.get_meta("ordinary_replacement_used",false),"UI confirm performs actual replacement")
	finish()
