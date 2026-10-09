extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Pool = preload("res://scripts/upgrades/upgrade_pool.gd")
var failed: bool = false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	_expect(c.skill_manager.add_skill(&"fire_cast_meteor_rain", "legendary"), "learn legendary")
	var s: RefCounted = c.skill_manager.get_skill(&"fire_cast_meteor_rain")
	_expect(c.skill_manager.upgrade_skill(s.skill_id, "normal"), "upgrade to level two")
	_expect(s.current_rarity == "legendary" and s.current_level == 2, "lower rarity cannot downgrade")
	_expect(c.skill_manager.upgrade_skill(s.skill_id, ""), "empty rarity upgrades")
	_expect(s.current_rarity == "legendary", "empty rarity preserves")
	while s.current_level < 5:
		c.skill_manager.upgrade_skill(s.skill_id, "normal")
	_expect(not c.skill_manager.upgrade_skill(s.skill_id, "rare"), "max level rejects")
	_expect(s.current_rarity == "legendary", "reject preserves rarity")
	c.skill_manager.clear_skills()
	c.skill_manager.add_skill(&"fire_cast_meteor_rain", "normal")
	s = c.skill_manager.get_skill(&"fire_cast_meteor_rain")
	var pool := Pool.new()
	for _index in range(10):
		for option: RefCounted in pool.call("_build_skill_level_up_options", c.caster):
			_expect(String(option.rarity) == "normal", "ordinary upgrade never rerolls rarity")
	c.skill_manager.upgrade_skill(s.skill_id, "rare")
	_expect(s.current_rarity == "rare", "explicit promotion permitted")
	c.caster.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_upgrade_monotonic] PASS")
	quit(1 if failed else 0)
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_upgrade_monotonic] FAIL " + label)
