extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")

class TestPlayer:
	extends Node

	var modifier_sources: Dictionary = {}

	func set_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
		modifier_sources[String(source_id)] = modifiers

	func clear_run_modifier_source(source_id: Variant) -> void:
		modifier_sources.erase(String(source_id))


var _failed: bool = false
var _player: TestPlayer
var _skill_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_nodes()
	_expect(bool(_skill_manager.call("add_skill", &"fire_attack_searing")), "learns fire_attack_searing")
	_expect(_skill_manager.call("get_active_skills").size() == 1, "learned attack occupies one slot", _skill_manager.call("get_active_skills").size())
	_expect_close(_modifier_value("skill:fire_attack_searing:effects", "primary_attack_damage_multiplier_add"), 0.2, "Lv1 normal attack modifier")
	_expect(bool(_skill_manager.call("upgrade_skill", &"fire_attack_searing", "rare")), "upgrades fire_attack_searing with rare card")
	var skill: RefCounted = _skill_manager.call("get_skill", &"fire_attack_searing") as RefCounted
	_expect(skill != null and int(skill.get("current_level")) == 2, "same skill_id reaches Lv2", skill.get("current_level") if skill != null else null)
	_expect(skill != null and String(skill.get("current_rarity")) == "rare", "skill stores current rarity", skill.get("current_rarity") if skill != null else null)
	_expect(_skill_manager.call("get_active_skills").size() == 1, "upgrade does not create another slot", _skill_manager.call("get_active_skills").size())
	_expect_close(_modifier_value("skill:fire_attack_searing:effects", "primary_attack_damage_multiplier_add"), 0.2 * 1.08 * 1.25, "Lv2 rare attack modifier")
	if not _failed:
		print("[verify_skill_growth_skill_manager] PASS")
	quit(1 if _failed else 0)


func _build_nodes() -> void:
	_player = TestPlayer.new()
	_player.name = "SkillGrowthPlayer"
	root.add_child(_player)
	_skill_manager = SkillManagerScript.new()
	_skill_manager.name = "SkillManager"
	_player.add_child(_skill_manager)


func _modifier_value(source_id: String, key: String) -> float:
	var modifiers_variant: Variant = _player.modifier_sources.get(source_id, [])
	if modifiers_variant is Array:
		for modifier_variant: Variant in modifiers_variant:
			if not (modifier_variant is Dictionary):
				continue
			var modifier: Dictionary = modifier_variant
			var values: Dictionary = modifier.get("values", {})
			if values.has(key):
				return float(values[key])
	return 0.0


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.0001:
		return
	_fail(label, {"actual": actual, "expected": expected})


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_skill_growth_skill_manager] FAIL %s actual=%s" % [label, str(actual)])
