extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
var failed := false
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[requirements] " + label)
func run() -> void:
	var c := F.build(self)
	var m: Node = c.skill_manager
	m.max_active_skills = 64
	for id in [&"fire_cast_meteor_rain", &"fire_cast_lava_rift", &"fire_cast_scorching_vortex"]: m.add_skill(id)
	var offer := preload("res://scripts/skills/skill_offer_service.gd").new()
	c.caster.set_meta("character_level", 7)
	check(not offer.is_skill_available(c.caster, GameData.get_skill(&"fire_core_inferno_cycle")), "core Lv7 rejected")
	check(not offer.is_skill_available(c.caster, GameData.get_skill(&"frost_passive_frozen_vulnerability")), "pure passive cannot open school")
	var path := "res://scripts/skills/skill_requirement_policy.gd"
	check(ResourceLoader.exists(path), "shared requirement policy exists")
	if not ResourceLoader.exists(path):
		quit(1)
		return
	var policy: RefCounted = load(path).new()
	c.caster.set_meta("character_level", 8)
	check(policy.evaluate(c.caster, GameData.get_skill(&"fire_core_inferno_cycle")).available, "core Lv8 three skills and status")
	c.caster.set_meta("character_level", 6)
	m.add_skill(&"frost_cast_frost_field")
	var fusion: Dictionary = GameData.get_skill(&"fusion_fire_frost_steam_mist").duplicate(true)
	fusion["offer_enabled"] = true
	check(policy.evaluate(c.caster, fusion).available, "fire2 frost1 Lv6 region fusion")
	var lance: Dictionary = GameData.get_skill(&"fusion_frost_holy_judgment_ice_lance").duplicate(true)
	lance["offer_enabled"] = true
	check(not policy.evaluate(c.caster, lance).available, "missing dedicated skill rejected")
	for school in ["thunder", "holy", "chaos"]:
		var data := {"id": school + "_test", "skill_type": "core", "school": school, "offer_rule": {}}
		var result: Dictionary = policy.evaluate(c.caster, data)
		check(not result.available and not result.missing_requirements.is_empty(), "core requires reaction " + school)
	check(offer.is_skill_available(c.caster, GameData.get_skill(&"fusion_fire_frost_steam_mist")), "behavior-accepted steam is available after M3 migration")
	print("[requirements] PASS" if not failed else "[requirements] FAIL")
	quit(1 if failed else 0)
