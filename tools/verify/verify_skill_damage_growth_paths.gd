extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Growth = preload("res://scripts/skills/skill_growth_scaling.gd")
const Adapter = preload("res://scripts/skills/skill_effect_adapter.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
var failed: bool = false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	var s: RefCounted = F.skill()
	s.current_level = 2
	s.current_rarity = "legendary"
	c.skill_instance = s
	for pair: Array in [["damage", 1.68], ["tick_damage", 1.68], ["cooldown", 0.96], ["radius", 1.05], ["duration", 1.06]]:
		_close(Growth.stat_multiplier(s, pair[0]), pair[1], pair[0])
	for mode: String in ["apply", "tick"]:
		var action: Dictionary = Adapter.to_action({"type": "damage", "power_scale": 1.0}, s, mode)
		Executor.new().execute_action(action, c)
		_close(float(c.target.packets.back().raw_amount), 168.0, mode + " damage exactly once")
	var burst: Dictionary = Adapter.to_action({"type": "spawn_projectile_burst", "damage": {"power_scale": 1.0}, "effects_on_hit": [{"type": "damage", "power_scale": 1.0}]}, s)
	var p: Dictionary = burst.params
	_expect(p.has("actions_on_hit"), "burst nested effects normalized")
	_close(float(p.damage.get("scale", p.damage.get("power_scale", 0.0))), 1.68, "burst growth once")
	var chain: Dictionary = Adapter.to_action({"type": "chain_to_targets", "actions": [{"type": "damage", "power_scale": 1.0}]}, s)
	_close(float(chain.params.actions[0].params.amount.scale), 1.68, "chain growth once")
	var core: RefCounted = F.skill("core")
	core.current_rarity = "legendary"
	_close(Growth.stat_multiplier(core, "damage"), 1.0, "core fixed")
	c.caster.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_damage_growth_paths] PASS")
	quit(1 if failed else 0)
func _close(a: float, b: float, label: String) -> void:
	_expect(absf(a-b)<0.0001, "%s actual=%s expected=%s" % [label,a,b])
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_damage_growth_paths] FAIL " + label)
