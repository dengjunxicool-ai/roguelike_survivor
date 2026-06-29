extends SceneTree

const RunHudControllerScript: Script = preload("res://scripts/ui/hud/run_hud_controller.gd")
const RunHudStateProviderScript: Script = preload("res://scripts/ui/hud/run_hud_state_provider.gd")


class SkillDefinitionStub:
	extends RefCounted

	var id: StringName = &"meteor_test"
	var skill_type: String = "cast"
	var display_name: String = "流星火雨"
	var trigger_rules: Array[Dictionary] = [
		{"trigger": "cast_skill", "cooldown": 6.5}
	]
	var components: Array[Dictionary] = []
	var base: Dictionary = {}

	func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
		return base.get(stat_name, default_value)


class SkillInstanceStub:
	extends RefCounted

	var skill_id: StringName = &"meteor_test"
	var current_level: int = 2
	var cooldown_remaining: float = 3.25
	var definition: RefCounted = SkillDefinitionStub.new()


class SkillManagerStub:
	extends Node

	var skills: Array = [SkillInstanceStub.new()]

	func get_all_skills() -> Array:
		return skills


class DashSkillDefinitionStub:
	extends RefCounted

	var id: StringName = &"fire_dash_blazing_run"
	var display_name: String = "烈焰疾行"
	var skill_type: String = "dash"
	var trigger_rules: Array[Dictionary] = []
	var components: Array[Dictionary] = []
	var base: Dictionary = {}

	func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
		return base.get(stat_name, default_value)


class DashSkillInstanceStub:
	extends RefCounted

	var skill_id: StringName = &"fire_dash_blazing_run"
	var current_level: int = 1
	var cooldown_remaining: float = 0.0
	var skill_type: String = "dash"
	var definition: RefCounted = DashSkillDefinitionStub.new()


class DashSkillManagerStub:
	extends Node

	var skills: Array = [DashSkillInstanceStub.new()]

	func get_all_skills() -> Array:
		return skills


class DashPlayerStub:
	extends Node

	var _dash_cooldown_remaining: float = 2.1
	var dash_cooldown: float = 2.6

	func _init() -> void:
		add_to_group(&"player")


class RuntimeStub:
	extends Node

	func get_character_id() -> String:
		return "mage"

	func get_starting_skill_id() -> String:
		return "fireball"


class CategorizedSkillDefinitionStub:
	extends RefCounted

	var id: StringName
	var skill_type: String
	var display_name: String
	var trigger_rules: Array[Dictionary]
	var components: Array[Dictionary] = []
	var base: Dictionary = {}

	func _init(skill_id: StringName, type_value: String, name_value: String, cooldown: float = 0.0) -> void:
		id = skill_id
		skill_type = type_value
		display_name = name_value
		if cooldown > 0.0:
			trigger_rules = [{"trigger": "cast_skill", "cooldown": cooldown}]
		else:
			trigger_rules = []

	func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
		return base.get(stat_name, default_value)


class CategorizedSkillInstanceStub:
	extends RefCounted

	var skill_id: StringName
	var current_level: int = 1
	var cooldown_remaining: float = 0.0
	var skill_type: String
	var definition: RefCounted

	func _init(id_value: StringName, type_value: String, name_value: String, cooldown: float = 0.0, remaining: float = 0.0) -> void:
		skill_id = id_value
		skill_type = type_value
		cooldown_remaining = remaining
		definition = CategorizedSkillDefinitionStub.new(id_value, type_value, name_value, cooldown)


class CategorizedSkillManagerStub:
	extends Node

	var skills: Array = [
		CategorizedSkillInstanceStub.new(&"fireball", "cast", "Fireball", 1.1),
		CategorizedSkillInstanceStub.new(&"fire_dash_blazing_run", "dash", "Dash", 2.6, 1.2),
		CategorizedSkillInstanceStub.new(&"fire_cast_meteor_rain", "cast", "Meteor", 6.5, 3.0),
		CategorizedSkillInstanceStub.new(&"fire_cast_lava_rift", "cast", "Lava", 5.5),
		CategorizedSkillInstanceStub.new(&"fire_cast_scorching_vortex", "cast", "Vortex", 7.0),
		CategorizedSkillInstanceStub.new(&"fire_summon_crimson_dragon", "summon", "Dragon", 8.0),
		CategorizedSkillInstanceStub.new(&"fire_summon_ember_fox_pack", "summon", "Fox", 8.0),
		CategorizedSkillInstanceStub.new(&"fire_passive_burning_focus", "passive", "Focus"),
		CategorizedSkillInstanceStub.new(&"fire_passive_overheated_casting", "passive", "Overheat"),
		CategorizedSkillInstanceStub.new(&"fire_passive_scorched_ground_affinity", "passive", "Ground")
	]

	func get_all_skills() -> Array:
		return skills

	func get_skill(skill_id: Variant) -> RefCounted:
		for skill: RefCounted in skills:
			if StringName(String(skill.get("skill_id"))) == StringName(String(skill_id)):
				return skill
		return null


class CategorizedPlayerStub:
	extends Node

	var selected_character_id: StringName = &"mage"
	var max_health: int = 100
	var current_health: int = 100
	var level: int = 1
	var current_experience: int = 0
	var experience_to_next_level: int = 10

	func _init() -> void:
		add_to_group(&"player")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = true
	ok = _verify_state_provider_exports_skill_slots() and ok
	ok = _verify_state_provider_exports_dash_cooldown() and ok
	ok = _verify_state_provider_exports_categorized_skill_slots() and ok
	ok = await _verify_hud_controller_draws_skill_slots() and ok
	ok = await _verify_hud_controller_draws_fixed_categorized_slots() and ok
	ok = await _verify_player_hud_avatar_bar_composition() and ok
	if ok:
		print("[verify_run_hud_skill_slots] PASS")
	quit(0 if ok else 1)


func _verify_state_provider_exports_skill_slots() -> bool:
	var player := Node.new()
	player.name = "Player"
	player.add_to_group(&"player")
	var skill_manager := SkillManagerStub.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)

	var provider: RefCounted = RunHudStateProviderScript.new()
	var state: Dictionary = provider.call("build", {"tree": self})
	var skills: Array = state.get("skills", [])

	var ok: bool = true
	ok = _expect(skills.size() == 1, "provider exports one learned skill", skills.size()) and ok
	if skills.size() > 0:
		var skill: Dictionary = skills[0]
		ok = _expect(String(skill.get("id", "")) == "meteor_test", "provider exports skill id", skill) and ok
		ok = _expect(String(skill.get("display_name", "")) == "流星火雨", "provider exports skill display name", skill) and ok
		ok = _expect(int(skill.get("level", 0)) == 2, "provider exports skill level", skill) and ok
		ok = _expect(is_equal_approx(float(skill.get("cooldown_remaining", 0.0)), 3.25), "provider exports cooldown remaining", skill) and ok
		ok = _expect(is_equal_approx(float(skill.get("cooldown_total", 0.0)), 6.5), "provider resolves total cooldown", skill) and ok

	player.remove_from_group(&"player")
	player.queue_free()
	return ok


func _verify_state_provider_exports_categorized_skill_slots() -> bool:
	var player := CategorizedPlayerStub.new()
	player.name = "CategorizedPlayer"
	var runtime := RuntimeStub.new()
	runtime.name = "CharacterRuntime"
	player.add_child(runtime)
	var skill_manager := CategorizedSkillManagerStub.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)

	var provider: RefCounted = RunHudStateProviderScript.new()
	var state: Dictionary = provider.call("build", {"tree": self})
	var active_skills: Array = state.get("active_skills", [])
	var passive_skills: Array = state.get("passive_skills", [])
	var primary_skill: Dictionary = state.get("primary_skill", {})
	var dash_skill: Dictionary = state.get("dash_skill", {})

	var ok: bool = true
	ok = _expect(String(primary_skill.get("id", "")) == "fireball", "provider exports primary skill separately", primary_skill) and ok
	ok = _expect(String(dash_skill.get("id", "")) == "fire_dash_blazing_run", "provider exports dash skill separately", dash_skill) and ok
	ok = _expect(active_skills.size() == 5, "provider exports five ordinary active skills", active_skills.size()) and ok
	ok = _expect(passive_skills.size() == 3, "provider exports three passive skills", passive_skills.size()) and ok
	if active_skills.size() > 0:
		ok = _expect(String(active_skills[0].get("id", "")) == "fire_cast_meteor_rain", "first ordinary active excludes primary and dash", active_skills[0]) and ok
	player.remove_from_group(&"player")
	player.queue_free()
	return ok


func _verify_state_provider_exports_dash_cooldown() -> bool:
	var player := DashPlayerStub.new()
	player.name = "DashPlayer"
	var skill_manager := DashSkillManagerStub.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)

	var provider: RefCounted = RunHudStateProviderScript.new()
	var state: Dictionary = provider.call("build", {"tree": self})
	var dash_skill: Dictionary = state.get("dash_skill", {})

	var ok: bool = true
	ok = _expect(String(dash_skill.get("id", "")) == "fire_dash_blazing_run", "provider exports dash skill id", dash_skill) and ok
	ok = _expect(is_equal_approx(float(dash_skill.get("cooldown_remaining", 0.0)), 2.1), "provider exports player dash cooldown remaining", dash_skill) and ok
	ok = _expect(is_equal_approx(float(dash_skill.get("cooldown_total", 0.0)), 2.6), "provider exports player dash cooldown total", dash_skill) and ok

	player.remove_from_group(&"player")
	player.queue_free()
	return ok


func _verify_hud_controller_draws_skill_slots() -> bool:
	var controller: RefCounted = RunHudControllerScript.new()
	var screen: CanvasLayer = controller.call("build", self) as CanvasLayer
	root.add_child(screen)
	screen.visible = true
	await process_frame
	controller.call("update_layout")
	controller.call("update", self, {
		"max_health": 100.0,
		"health": 100.0,
		"level": 1,
		"exp": 0,
		"exp_required": 10,
		"run_duration": 60.0,
		"status_summary": "-",
		"skills": [
			{
				"id": "meteor_test",
				"display_name": "流星火雨",
				"level": 2,
				"cooldown_remaining": 3.25,
				"cooldown_total": 6.5
			}
		]
	})
	await process_frame

	var slot := screen.find_child("SkillSlotActive0", true, false) as Control
	var name_label := screen.find_child("SkillSlotActive0Name", true, false) as Label
	var cooldown_label := screen.find_child("SkillSlotActive0Cooldown", true, false) as Label
	var cooldown_mask := screen.find_child("SkillSlotActive0CooldownMask", true, false) as ColorRect

	var ok: bool = true
	ok = _expect(slot != null and slot.visible, "HUD creates first skill slot", slot) and ok
	ok = _expect(name_label != null and name_label.text == "流星火雨", "HUD shows learned skill name", name_label.text if name_label != null else "<missing>") and ok
	ok = _expect(cooldown_label != null and cooldown_label.visible and cooldown_label.text.begins_with("3."), "HUD shows cooldown countdown", cooldown_label.text if cooldown_label != null else "<missing>") and ok
	ok = _expect(cooldown_mask != null and cooldown_mask.visible and cooldown_mask.size.y > 0.0, "HUD shows cooldown overlay mask", cooldown_mask.size if cooldown_mask != null else "<missing>") and ok

	screen.queue_free()
	return ok


func _verify_hud_controller_draws_fixed_categorized_slots() -> bool:
	var controller: RefCounted = RunHudControllerScript.new()
	var screen: CanvasLayer = controller.call("build", self) as CanvasLayer
	root.add_child(screen)
	screen.visible = true
	await process_frame
	controller.call("update_layout")
	controller.call("update", self, {
		"max_health": 100.0,
		"health": 100.0,
		"level": 1,
		"exp": 0,
		"exp_required": 10,
		"run_duration": 60.0,
		"status_summary": "-",
		"primary_skill": {"id": "fireball", "display_name": "Fireball", "level": 1},
		"dash_skill": {"id": "fire_dash_blazing_run", "display_name": "Dash", "level": 1, "cooldown_remaining": 1.2, "cooldown_total": 2.6},
		"active_skills": [
			{"id": "fire_cast_meteor_rain", "display_name": "Meteor", "level": 1, "cooldown_remaining": 3.0, "cooldown_total": 6.5}
		],
		"passive_skills": [
			{"id": "fire_passive_burning_focus", "display_name": "Focus", "level": 1}
		]
	})
	await process_frame

	var primary_slot := screen.find_child("SkillSlotPrimary", true, false) as Control
	var dash_slot := screen.find_child("SkillSlotDash", true, false) as Control
	var active_slot_4 := screen.find_child("SkillSlotActive4", true, false) as Control
	var passive_slot_2 := screen.find_child("SkillSlotPassive2", true, false) as Control
	var overflow_slot := screen.find_child("SkillSlot10", true, false) as Control

	var ok: bool = true
	ok = _expect(primary_slot != null and primary_slot.visible, "HUD creates fixed primary slot", primary_slot) and ok
	ok = _expect(dash_slot != null and dash_slot.visible, "HUD creates fixed dash slot", dash_slot) and ok
	ok = _expect(active_slot_4 != null and active_slot_4.visible, "HUD keeps fifth ordinary active slot visible as capacity", active_slot_4) and ok
	ok = _expect(passive_slot_2 != null and passive_slot_2.visible, "HUD keeps third passive slot visible as capacity", passive_slot_2) and ok
	ok = _expect(overflow_slot == null, "HUD does not create mixed overflow slot beyond fixed layout", overflow_slot) and ok

	screen.queue_free()
	return ok


func _verify_player_hud_avatar_bar_composition() -> bool:
	var controller: RefCounted = RunHudControllerScript.new()
	var screen: CanvasLayer = controller.call("build", self) as CanvasLayer
	root.add_child(screen)
	screen.visible = true
	await process_frame
	controller.call("update_layout")
	controller.call("update", self, {
		"max_health": 75.0,
		"health": 75.0,
		"level": 12,
		"exp": 4,
		"exp_required": 10,
		"run_duration": 60.0,
		"status_summary": "-"
	})
	await process_frame

	var avatar_frame := screen.find_child("AvatarFrame", true, false) as Control
	var hp_bar := screen.find_child("HPBar", true, false) as TextureProgressBar
	var exp_bar := screen.find_child("EXPBar", true, false) as TextureProgressBar
	var level_badge := screen.find_child("LevelBadge", true, false) as Label

	var ok: bool = true
	ok = _expect(avatar_frame != null, "HUD has avatar frame", avatar_frame) and ok
	ok = _expect(hp_bar != null, "HUD has HP bar", hp_bar) and ok
	ok = _expect(exp_bar != null, "HUD has EXP bar", exp_bar) and ok
	ok = _expect(level_badge != null, "HUD has level badge", level_badge) and ok
	if avatar_frame != null and hp_bar != null and exp_bar != null and level_badge != null:
		var avatar_rect := _rect_for(avatar_frame)
		var hp_rect := _rect_for(hp_bar)
		var exp_rect := _rect_for(exp_bar)
		var level_rect := _rect_for(level_badge)
		ok = _expect(hp_rect.position.x <= avatar_rect.position.x + avatar_rect.size.x - 12.0, "HP bar starts inside avatar frame edge for integrated composition", {"avatar": avatar_rect, "hp": hp_rect}) and ok
		ok = _expect(exp_rect.size.y >= 22.0, "EXP bar is enlarged for reference layout", exp_rect) and ok
		ok = _expect(level_rect.position.x <= avatar_rect.position.x + avatar_rect.size.x * 0.24 and level_rect.position.y >= avatar_rect.position.y + avatar_rect.size.y * 0.62, "level badge sits on avatar lower-left", {"avatar": avatar_rect, "level": level_rect}) and ok
		ok = _expect(level_badge.text == "12", "level badge shows only numeric level", level_badge.text) and ok
	if hp_bar != null and hp_bar.texture_over != null:
		var over_image := hp_bar.texture_over.get_image()
		ok = _expect(over_image.get_pixel(0, 0).a < 0.2, "HP bar overlay has transparent corner for curved silhouette", over_image.get_pixel(0, 0)) and ok
		ok = _expect(over_image.get_pixel(3, over_image.get_height() / 2).a > 0.7, "HP gold edge wraps left curve", over_image.get_pixel(3, over_image.get_height() / 2)) and ok
		ok = _expect(over_image.get_pixel(over_image.get_width() - 4, over_image.get_height() / 2).a > 0.7, "HP gold edge wraps right curve", over_image.get_pixel(over_image.get_width() - 4, over_image.get_height() / 2)) and ok
		ok = _expect(over_image.get_pixel(over_image.get_width() / 2, 2).a > 0.5, "HP gold edge wraps top edge", over_image.get_pixel(over_image.get_width() / 2, 2)) and ok

	screen.queue_free()
	return ok


func _rect_for(control: Control) -> Rect2:
	return Rect2(
		Vector2(control.offset_left, control.offset_top),
		Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	)


func _expect(condition: bool, label: String, details: Variant = "") -> bool:
	if not condition:
		push_error("%s failed: %s" % [label, str(details)])
	return condition
