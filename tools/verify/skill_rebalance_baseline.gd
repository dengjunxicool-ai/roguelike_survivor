extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Growth = preload("res://scripts/skills/skill_growth_scaling.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c: Dictionary = F.build(self)
	c.skill_manager.add_skill(&"fire_cast_meteor_rain", "legendary")
	var instance: RefCounted = c.skill_manager.get_skill(&"fire_cast_meteor_rain")
	var before: float = Growth.stat_multiplier(instance, "damage")
	c.skill_manager.upgrade_skill(&"fire_cast_meteor_rain", "normal")
	print("BASELINE rarity=%s damage_ratio=%s" % [instance.current_rarity, Growth.stat_multiplier(instance, "damage") / before])
	c.skill_instance = instance
	Executor.new().execute_action({"type": "add_temporary_modifier", "params": {"stat": "damage", "op": "multiplier_add", "value": 0.3, "scope": {"domain": "skill", "skill_type": "cast"}, "source": "skill", "duration": 5.0}}, c)
	print("BASELINE timed_api=%s runtime_modifiers=%s" % [c.store.has_method("tick_timed_sources"), instance.runtime_modifiers])
	c.statuses.apply_status(&"cursed", {"power": 100.0})
	c.statuses.update_status_effects(2.0)
	c.statuses.apply_status(&"cursed", {"power": 100.0})
	c.statuses.update_status_effects(1.0)
	print("BASELINE cursed_t3_stacks=%s damage=%s" % [c.statuses.get_status_stack(&"cursed"), F.damage_total(c.target)])
	print("[skill_rebalance_baseline] OBSERVED; behavior findings above are not acceptance PASS")
	c.caster.queue_free()
	c.target.queue_free()
	await process_frame
	quit(0)
