extends SceneTree

const Provider = preload("res://scripts/ui/hud/run_hud_state_provider.gd")
const Controller = preload("res://scripts/ui/hud/run_hud_controller.gd")
const Runtime = preload("res://scripts/characters/character_runtime.gd")

class PlayerFixture:
	extends Node
	var max_health := 100.0
	var current_health := 100.0
	var level := 1
	var current_experience := 0
	var experience_to_next_level := 10
	var selected_character_id := "paladin"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PlayerFixture.new()
	player.add_to_group("player")
	var runtime := Runtime.new()
	runtime.name = "CharacterRuntime"
	player.add_child(runtime)
	root.add_child(player)
	runtime.initialize("paladin")
	runtime.trait_runtime_state = {"trait_type":"passive_with_periodic_shield", "shield_points":3, "shield_remaining_seconds":4.5, "shield_timer":0.0}
	var provider := Provider.new()
	var state: Dictionary = provider.build({"tree":self,"wave_index":3,"wave_remaining_seconds":19.2})
	_check(int(state.get("trait_state",{}).get("shield_points",-1)) == 3, "HUD reads real shield points")
	_check(String(state.get("trait_summary", "")).contains("4.5"), "HUD reads remaining shield lifetime")
	state.get("trait_state",{})["shield_points"] = 99
	_check(runtime.trait_runtime_state.shield_points == 3, "HUD snapshot cannot mutate runtime shield")
	runtime.trait_runtime_state = {"trait_type":"passive_with_periodic_shield", "shield_points":0, "shield_remaining_seconds":0.0, "shield_timer":5.0}
	state = provider.build({"tree":self})
	_check(String(state.get("trait_summary", "")).contains("13.0"), "broken shield shows next recharge from configured interval")
	runtime.initialize("mage")
	runtime.trait_runtime_state = {"trait_type":"skill_cast_stack", "stack_count":6,"cast_count":1}
	state = provider.build({"tree":self})
	_check(String(state.get("trait_summary", "")).contains("6/6"), "mage shows overload stack capacity")
	_check(String(state.get("trait_summary", "")).contains("9%"), "mage shows configured movement penalty at current stacks")
	player.remove_from_group("player")
	player.queue_free()
	await process_frame
	for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1152,648),Vector2i(1280,720)]:
		await _check_layout(dimensions)
	print("[verify_run_hud_awareness] %s failures=%d" % ["PASS" if failures == 0 else "FAIL",failures])
	quit(0 if failures == 0 else 1)

func _check_layout(dimensions: Vector2i) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions
	var controller := Controller.new()
	var screen: CanvasLayer = controller.build(self)
	root.add_child(screen)
	screen.visible = true
	_check((screen.find_child("SkillSlotActive0Key",true,false) as Label).text == "自动", "initial active capacity label is player facing")
	_check((screen.find_child("SkillSlotPassive0Key",true,false) as Label).text == "被动", "initial passive capacity label is player facing")
	await process_frame
	var state := {"health":20.0,"max_health":100.0,"wave_index":3,"wave_remaining_seconds":19.2,"trait_summary":"过载 6/6 · 移速 -9%", "primary_skill":{"id":"fireball","display_name":"火球"},"boss":{"visible":false}}
	controller.update(self,state)
	await process_frame
	var wave := screen.find_child("WaveProgress",true,false) as Label
	_check(wave != null and wave.visible and wave.text.contains("3/8") and wave.text.contains("00:20"), "current wave and rounded remaining time stay visible %s" % dimensions)
	var trait_label := screen.find_child("CharacterTraitStatus",true,false) as Label
	_check(trait_label != null and trait_label.visible and trait_label.text.contains("6/6"), "character trait is visible %s" % dimensions)
	var vignette := screen.find_child("LowHealthVignette",true,false) as Control
	var warning := screen.find_child("LowHealthWarning",true,false) as Label
	_check(vignette != null and vignette.visible and vignette.mouse_filter == Control.MOUSE_FILTER_IGNORE, "low health has noninteractive visual warning %s" % dimensions)
	_check(warning != null and warning.visible, "low health also has readable text %s" % dimensions)
	var bar := screen.find_child("SkillBar",true,false) as Control
	_check(bar != null and bar.size.y <= 76.0, "sparse skill bar uses compact height %s" % dimensions)
	var occupied := screen.find_child("SkillSlotPrimary",true,false) as Control
	var empty := screen.find_child("SkillSlotActive4",true,false) as Control
	_check((screen.find_child("SkillSlotActive4Key",true,false) as Label).text == "自动", "empty active capacity uses readable category")
	_check((screen.find_child("SkillSlotPassive2Key",true,false) as Label).text == "被动", "empty passive capacity uses readable category")
	_check(empty != null and empty.visible and occupied != null and empty.size.x < occupied.size.x, "empty capacity remains visible in smaller slots %s" % dimensions)
	if bar != null:
		_check(bar.get_children().size() == 12, "all skill capacity stays represented")
		for child: Node in bar.get_children():
			var slot := child as Control
			var rect := slot.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,slot.size)
			_check(rect.position.x >= 0 and rect.end.x <= dimensions.x and rect.end.y <= dimensions.y, "skill capacity stays inside viewport")
	state.health = 80.0
	state.boss = {"visible":true,"health":10.0,"max_health":20.0,"name":"Boss"}
	controller.update(self,state)
	var notice := screen.find_child("BossNotice",true,false) as Label
	_check(notice != null and notice.text.contains("已登场"), "boss notice changes once boss is present")
	_check(vignette != null and not vignette.visible and warning != null and not warning.visible, "warning clears after healing")
	var boss_panel := screen.find_child("BossStatusPanel",true,false) as Control
	var player_panel := screen.find_child("PlayerStatusPanel",true,false) as Control
	var boss_rect := boss_panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,boss_panel.size)
	var player_rect := player_panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,player_panel.size)
	_check(not boss_rect.intersects(player_rect), "boss and player health panels do not obscure each other")
	var boss_name := screen.find_child("BossName",true,false) as Label
	_check(boss_name.visible and boss_name.text == "Boss", "boss name remains visible with progress status")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].begins_with("E:/codex/"):
		state.health = 20.0
		controller.update(self,state)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0] + "/hud_sparse_%dx%d.png" % [dimensions.x,dimensions.y])
	# An occupied full bar must retain every category and cooldown semantics.
	state.active_skills = [{"id":"fireball","display_name":"火球","cooldown_remaining":2.0,"cooldown_total":4.0},{"id":"fireball","display_name":"流星火雨"},{"id":"fireball","display_name":"熔岩裂隙"},{"id":"fireball","display_name":"灼热漩涡"},{"id":"fireball","display_name":"赤焰巨龙"}]
	state.passive_skills = [{"id":"fireball","display_name":"灼热专注"},{"id":"fireball","display_name":"过热施法"},{"id":"fireball","display_name":"焦土亲和"}]
	state.core_skill = {"id":"fireball","display_name":"炽焰核心"}
	state.fusion_skill = {"id":"fireball","display_name":"烈火风暴"}
	state.dash_skill = {"id":"fireball","display_name":"烈焰疾行"}
	controller.update(self,state)
	var active_slot := screen.find_child("SkillSlotActive0",true,false) as Control
	var mask := screen.find_child("SkillSlotActive0CooldownMask",true,false) as Control
	var skill_name := screen.find_child("SkillSlotActive0Name",true,false) as Label
	var cooldown := screen.find_child("SkillSlotActive0Cooldown",true,false) as Label
	_check(skill_name.get_theme_font_size("font_size") >= 12 and cooldown.get_theme_font_size("font_size") >= 18, "full bar keeps readable name and cooldown sizes")
	_check(mask.visible and is_equal_approx(mask.size.y,active_slot.size.y * 0.5), "cooldown mask remains proportional after compact slot resize")
	_check(bar.size.x <= 780.0 and bar.size.y <= 76.0, "full skill capacity also remains compact")
	var actor := Node2D.new()
	actor.add_to_group("player")
	root.add_child(actor)
	actor.position = (bar.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,bar.size)).get_center()
	controller.update(self,state)
	var frame := screen.find_child("SkillSlotPrimaryFrame",true,false) as TextureRect
	_check(frame.self_modulate.a <= 0.3 and mask.visible, "player near footer fades decoration while cooldown stays visible")
	actor.position = Vector2(0,0)
	controller.update(self,state)
	_check(frame.self_modulate.a > 0.5, "footer decoration recovers after player leaves")
	actor.remove_from_group("player")
	actor.queue_free()
	# Optional real-render evidence uses only a caller supplied E:/codex directory.
	if not args.is_empty() and args[0].begins_with("E:/codex/"):
		state.health = 20.0
		controller.update(self,state)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0] + "/hud_%dx%d.png" % [dimensions.x,dimensions.y])
	screen.queue_free()
	await process_frame

func _check(passed: bool, message: String) -> void:
	if not passed:
		failures += 1
		push_error(message)
