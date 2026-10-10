extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Pool = preload("res://scripts/upgrades/upgrade_pool.gd")
var failed := false
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[offers_v2] " + label)
func run() -> void:
	var c := F.build(self)
	var m: Node = c.skill_manager
	c.caster.set_meta("character_level", 8)
	m.max_active_skills = 64
	for id in [&"fire_cast_meteor_rain", &"fire_cast_lava_rift", &"fire_cast_scorching_vortex"]: m.add_skill(id)
	var pool := Pool.new()
	pool.get("_rng").seed = 618
	c.caster.set_meta("core_offer_misses", 3)
	var options: Array = pool.generate_options(c.caster, 3)
	var core := false
	var upgrade := false
	for option: RefCounted in options:
		var id: String = str(option.payload.get("learn_skill_id", ""))
		core = core or id == "fire_core_inferno_cycle"
		upgrade = upgrade or str(option.id).begins_with("skill_level_up:")
	check(core, "fourth eligible offer guarantees core")
	check(upgrade, "upgrade guaranteed even with core")
	for index in range(40):
		for option: RefCounted in pool.generate_options(c.caster, 3):
			var id: String = str(option.payload.get("learn_skill_id", ""))
			var data: Dictionary = GameData.get_skill(StringName(id))
			check(data.get("skill_type", "") != "fusion", "unmigrated fusion never offered")
	check(pool.has_method("stage_weight"), "stage weight interface")
	if pool.has_method("stage_weight"):
		c.caster.set_meta("character_level", 2)
		check(is_equal_approx(pool.stage_weight(c.caster, "upgrade", {}), 1.5), "Lv2 upgrade weight")
		check(is_equal_approx(pool.stage_weight(c.caster, "learn", GameData.get_skill(&"frost_cast_frost_field")), 2.0), "Lv2 new school output weight")
		c.caster.set_meta("character_level", 5)
		check(is_equal_approx(pool.stage_weight(c.caster, "upgrade", {}), 2.0), "Lv5 upgrade weight")
	var Option = preload("res://scripts/upgrades/upgrade_option.gd")
	var Selection = preload("res://scripts/upgrades/upgrade_selection_helper.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 618
	var a: RefCounted = Option.new({"id": "normal", "rarity": "common", "payload": {"weight": 2.0}})
	var b: RefCounted = Option.new({"id": "legendary", "rarity": "legendary", "payload": {"weight": 2.0}})
	var count_b := 0
	for sample in range(4000):
		if Selection.pick_weighted_option_index([a, b], rng, {"common": 60.0, "legendary": 2.0}) == 1: count_b += 1
	check(count_b >= 1850 and count_b <= 2150, "category weights do not multiply rarity again")
	print("[offers_v2] PASS" if not failed else "[offers_v2] FAIL")
	quit(1 if failed else 0)
