extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
var failed := false
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[replacement] " + label)
func run() -> void:
	var c := F.build(self)
	var m: Node = c.skill_manager
	for id in [&"fire_cast_meteor_rain", &"fire_cast_lava_rift", &"fire_cast_scorching_vortex", &"fire_summon_crimson_dragon", &"fire_summon_ember_fox_pack"]:
		check(m.add_skill(id), "setup " + str(id))
	var path := "res://scripts/skills/skill_replacement_service.gd"
	check(ResourceLoader.exists(path), "replacement service exists")
	if not ResourceLoader.exists(path):
		quit(1)
		return
	var service: RefCounted = load(path).new()
	var tx: Dictionary = service.begin(c.caster, &"frost_cast_glacial_lance", "rare")
	check(not tx.is_empty(), "begin full slot replacement")
	check(m.get_learned_god_schools() == [&"fire"], "begin does not lock frost")
	service.cancel(str(tx.id))
	check(m.active_skills.size() == 5 and m.get_learned_god_schools() == [&"fire"], "cancel preserves skills/schools")
	c.statuses.apply_status(&"burning", {"power": 100.0, "source_skill_id": &"fire_cast_lava_rift"})
	c.store.set_timed_source("skill:fire_cast_lava_rift:test", [{"stat": "damage_multiplier", "value": 0.2, "op": "add", "scope": {}}], [&"damage"], 5.0)
	c.event_bus.emit_skill_event(&"on_cast", {"caster": c.caster, "owner": c.caster, "skill_manager": m, "skill_instance": m.get_skill(&"fire_cast_lava_rift"), "parent": root, "power": 100.0})
	tx = service.begin(c.caster, &"frost_cast_glacial_lance", "rare")
	check(not service.confirm(c.caster, str(tx.id), &"fire_dash_blazing_run"), "protected slot rejected")
	check(service.confirm(c.caster, str(tx.id), &"fire_cast_lava_rift"), "confirm succeeds once")
	check(not m.has_skill(&"fire_cast_lava_rift") and m.has_skill(&"frost_cast_glacial_lance"), "atomic swap")
	check(c.statuses.get_status_stack(&"burning") == 0, "removed skill clears its statuses")
	check(not c.store.get_debug_sources().has("skill:fire_cast_lava_rift:test"), "removed skill clears timed buff")
	for object: Node in root.get_children():
		if object is AreaEffect: check(String(object.damage_packet.get("source_skill_id", "")) != "fire_cast_lava_rift", "removed skill clears live area")
	check(m.get_skill(&"frost_cast_glacial_lance").current_rarity == "rare", "new quality preserved")
	check(service.begin(c.caster, &"frost_cast_frost_field", "normal").is_empty(), "one confirmed replacement per run")
	check(not service.confirm(c.caster, str(tx.id), &"fire_cast_meteor_rain"), "stale transaction rejected")
	m.clear_skills()
	check(not bool(c.caster.get_meta("ordinary_replacement_used", false)), "restart resets opportunity")
	print("[replacement] PASS" if not failed else "[replacement] FAIL")
	quit(1 if failed else 0)
