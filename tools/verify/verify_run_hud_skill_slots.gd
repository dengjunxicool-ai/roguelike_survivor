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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = true
	ok = _verify_state_provider_exports_skill_slots() and ok
	ok = _verify_state_provider_exports_dash_cooldown() and ok
	ok = await _verify_hud_controller_draws_skill_slots() and ok
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


func _verify_state_provider_exports_dash_cooldown() -> bool:
	var player := DashPlayerStub.new()
	player.name = "DashPlayer"
	var skill_manager := DashSkillManagerStub.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	root.add_child(player)

	var provider: RefCounted = RunHudStateProviderScript.new()
	var state: Dictionary = provider.call("build", {"tree": self})
	var skills: Array = state.get("skills", [])

	var ok: bool = true
	ok = _expect(skills.size() == 1, "provider exports dash skill slot", skills.size()) and ok
	if skills.size() > 0:
		var skill: Dictionary = skills[0]
		ok = _expect(String(skill.get("id", "")) == "fire_dash_blazing_run", "provider exports dash skill id", skill) and ok
		ok = _expect(is_equal_approx(float(skill.get("cooldown_remaining", 0.0)), 2.1), "provider exports player dash cooldown remaining", skill) and ok
		ok = _expect(is_equal_approx(float(skill.get("cooldown_total", 0.0)), 2.6), "provider exports player dash cooldown total", skill) and ok

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

	var slot := screen.find_child("SkillSlot0", true, false) as Control
	var name_label := screen.find_child("SkillSlot0Name", true, false) as Label
	var cooldown_label := screen.find_child("SkillSlot0Cooldown", true, false) as Label
	var cooldown_mask := screen.find_child("SkillSlot0CooldownMask", true, false) as ColorRect

	var ok: bool = true
	ok = _expect(slot != null and slot.visible, "HUD creates first skill slot", slot) and ok
	ok = _expect(name_label != null and name_label.text == "流星火雨", "HUD shows learned skill name", name_label.text if name_label != null else "<missing>") and ok
	ok = _expect(cooldown_label != null and cooldown_label.visible and cooldown_label.text.begins_with("3."), "HUD shows cooldown countdown", cooldown_label.text if cooldown_label != null else "<missing>") and ok
	ok = _expect(cooldown_mask != null and cooldown_mask.visible and cooldown_mask.size.y > 0.0, "HUD shows cooldown overlay mask", cooldown_mask.size if cooldown_mask != null else "<missing>") and ok

	screen.queue_free()
	return ok


func _expect(condition: bool, label: String, details: Variant = "") -> bool:
	if not condition:
		push_error("%s failed: %s" % [label, str(details)])
	return condition
