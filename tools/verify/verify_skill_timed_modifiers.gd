extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Stats = preload("res://scripts/skills/skill_stat_service.gd")
var failed: bool = false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	var source: RefCounted = F.skill("passive", "fire_passive_overheated_casting")
	c.skill_instance = source
	var effect: Dictionary = {"type": "add_temporary_modifier", "params": {"effect_id": "cast_damage", "stat": "damage", "op": "multiplier_add", "value": 0.3, "scope": {"domain": "skill", "skill_type": "cast"}, "source": "skill", "duration": 5.0}}
	Executor.new().execute_action(effect, c)
	var cast: RefCounted = F.skill()
	var attack: RefCounted = F.skill("attack")
	_close(float(Stats.calculate_value(cast, "damage", 100.0, c.skill_manager, null, c.caster)), 130.0, "buff affects another cast")
	_close(float(Stats.calculate_value(attack, "damage", 100.0, c.skill_manager, null, c.caster)), 100.0, "buff excludes attack")
	_expect(source.runtime_modifiers.is_empty(), "temporary effects never become permanent")
	if c.store.has_method("tick_timed_sources"):
		c.store.tick_timed_sources(2.0)
		Executor.new().execute_action(effect, c)
		c.store.tick_timed_sources(0.0)
		_close(float(Stats.calculate_value(cast, "damage", 100.0, c.skill_manager, null, c.caster)), 130.0, "refresh does not stack")
		c.store.tick_timed_sources(4.99)
		_close(float(Stats.calculate_value(cast, "damage", 100.0, c.skill_manager, null, c.caster)), 130.0, "pause consumes no duration")
		c.store.tick_timed_sources(0.02)
		_close(float(Stats.calculate_value(cast, "damage", 100.0, c.skill_manager, null, c.caster)), 100.0, "expires at 5.01s")
		Executor.new().execute_action(effect, c)
		c.store.clear_skill_sources(&"fire_passive_overheated_casting")
		_close(float(Stats.calculate_value(cast, "damage", 100.0, c.skill_manager, null, c.caster)), 100.0, "removal clears skill sources")
		Executor.new().execute_action(effect, c)
		c.skill_manager.clear_skills()
		_close(float(Stats.calculate_value(cast, "damage", 100.0, c.skill_manager, null, c.caster)), 100.0, "clear skills clears timed sources")
	else:
		_expect(false, "store supports timed lifecycle")
	c.caster.queue_free()
	c.target.queue_free()
	await process_frame
	if not failed: print("[verify_skill_timed_modifiers] PASS")
	quit(1 if failed else 0)
func _close(a: float, b: float, label: String) -> void:
	_expect(absf(a-b)<0.0001, "%s actual=%s expected=%s" % [label,a,b])
func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[verify_skill_timed_modifiers] FAIL " + label)
