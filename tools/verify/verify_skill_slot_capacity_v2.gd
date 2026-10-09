extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const HUD = preload("res://scripts/ui/hud/run_hud_controller.gd")
class EnabledFusionManager:
	extends "res://scripts/skills/skill_manager.gd"
	func _get_skill_definition_data(id: StringName) -> Dictionary:
		var data: Dictionary = GameData.get_skill(id).duplicate(true)
		if data.get("skill_type", "") == "fusion": data["offer_enabled"] = true
		return data
var failed := false
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[slots_v2] " + label)
func run() -> void:
	var c := F.build(self)
	c.skill_manager.free()
	var m: Node = EnabledFusionManager.new()
	m.name = "SkillManager"
	c.caster.add_child(m)
	c.caster.set_meta("character_level", 8)
	m.set_primary_attack_method(&"fireball")
	for id in [&"fire_dash_blazing_run", &"fire_cast_meteor_rain", &"fire_cast_lava_rift", &"fire_cast_scorching_vortex", &"fire_summon_crimson_dragon", &"frost_cast_frost_field"]:
		check(m.add_skill(id), "learn " + str(id))
	check(m.is_active_skill_full(), "five ordinary full")
	check(m.add_skill(&"fire_core_inferno_cycle"), "core independent of full ordinary")
	check(m.add_skill(&"fusion_fire_frost_steam_mist"), "fusion independent of full ordinary")
	check(not m.add_skill(&"fusion_fire_frost_shattered_ember"), "second fusion rejected")
	check(not m.add_skill(&"frost_core_absolute_zero"), "second core rejected")
	for id in [&"fire_passive_burning_focus", &"fire_passive_overheated_casting", &"frost_passive_frozen_vulnerability"]:
		check(m.add_skill(id), "passive " + str(id))
	check(m.get_active_skills().size() + m.get_passive_skills().size() == 12, "12 executable/HUD entries")
	var hud := HUD.new()
	hud.build(self)
	check(hud.get("_skill_slot_nodes").size() == 12, "HUD 12 slots")
	hud.get_screen().free()
	print("[slots_v2] PASS" if not failed else "[slots_v2] FAIL")
	quit(1 if failed else 0)
