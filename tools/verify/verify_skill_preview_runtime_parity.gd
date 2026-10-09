extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var path: String = "res://scripts/ui/skill_preview_service.gd"
	if not ResourceLoader.exists(path):
		push_error("M4 missing shared runtime preview service")
		quit(1)
		return
	var preview: Script = load(path)
	var c: Dictionary = F.build(self)
	var count: int = 0
	for data: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/skills.json")).skills:
		if data.get("skill_type", "") != "cast": continue
		var instance: RefCounted = F.Instance.new(F.Definition.new(data))
		instance.current_level = 5
		instance.current_rarity = "legendary"
		var actual: Dictionary = preview.build(c.caster, instance.skill_id, 5, "legendary")
		assert(actual.has_all(["damage","dps","cooldown","radius","duration","statuses","shield_amount","next_milestone","requirements"]))
		assert(actual.next_milestone.is_empty())
		c["skill_instance"] = instance
		c["skill_id"] = instance.skill_id
		for rule: Dictionary in data.get("trigger_rules", []):
			var actions: Array = Adapter.to_event(rule, instance).actions
			for action: Dictionary in actions:
				if action.type == "deal_damage":
					c.target.packets.clear()
					Executor.new().execute_action(action, c)
					assert(absf(float(actual.damage) - F.damage_total(c.target)) <= 1.0)
		count += 1
	assert(count == 18)
	assert(F.install_runtime_skill(c.skill_manager, &"holy_cast_divine_barrier", "legendary"))
	var retained: Dictionary = preview.build(c.caster, &"holy_cast_divine_barrier", 2, "normal")
	assert(retained.rarity == "legendary")
	assert(not retained.next_milestone.is_empty())
	assert(preview.build(c.caster, &"nonexistent",1,"normal").is_empty())
	print("[verify_skill_preview_runtime_parity] PASS cast=18 milestone=5 rarity retained")
	c.caster.queue_free()
	c.target.queue_free()
	await process_frame
	quit(0)
