extends SceneTree

const Executor: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
var failed: bool = false

class Skill:
	extends RefCounted
	var definition: RefCounted
	var runtime_modifiers: Dictionary = {}
	var runtime_special_rules: Dictionary = {}

func _init() -> void:
	var executor: RefCounted = Executor.new()
	var skill := Skill.new()
	skill.runtime_special_rules = {"hot_rapid_fire": {"cast_interval": 2, "next_projectile_crit_chance_add": 0.4}, "holy_mark_tuning": {"duration_add": 2}, "shock_upgrade": {"duration_add": 0.3}, "hunter_mark_tuning": {"duration_add": 1, "max_stacks_add": 2}}
	var context: Dictionary = {"skill_instance": skill}
	executor.execute_event(&"on_cast", context)
	_expect(not skill.has_meta("hot_rapid_fire_next_cast"), "first cast does not trigger interval")
	executor.execute_event(&"on_cast", context)
	_expect(bool(skill.get_meta("hot_rapid_fire_next_cast", false)), "fire family triggers second cast")
	_expect(is_equal_approx(float(skill.get_meta("hot_rapid_fire_crit_chance_add", 0)), 0.4), "fire crit metadata retained")
	var original: Dictionary = {"duration": 4.0, "max_stacks": 1}
	var holy: Dictionary = executor.get_status_params(&"holy_mark", original, context)
	_expect(holy.duration == 6.0 and original.duration == 4.0, "holy tuning preserves input isolation")
	var shock: Dictionary = executor.get_status_params(&"shock", {"duration": 0.8}, context)
	_expect(is_equal_approx(shock.duration, 1.1), "lightning tuning retained")
	var hunter: Dictionary = executor.get_status_params(&"hunter_mark", original, context)
	_expect(hunter.duration == 5.0 and hunter.max_stacks == 3, "hunter tuning retained")
	for id: StringName in [&"chill", &"charge", &"arcane_mark"]:
		var params: Dictionary = executor.get_status_params(id, original, context)
		params.duration = 99
		_expect(original.duration == 4.0, "identity status deep copy retained: " + String(id))
	if not failed:
		print("[verify_rule_family_behavior] PASS")
	quit(1 if failed else 0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("[verify_rule_family_behavior] FAIL " + label)
