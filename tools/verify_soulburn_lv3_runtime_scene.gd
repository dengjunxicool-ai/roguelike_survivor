extends SceneTree


const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")


class TestSkillInstance:
	extends RefCounted
	var definition: RefCounted = null
	var runtime_modifiers: Dictionary = {}
	var runtime_special_rules: Dictionary = {}


var _failed: bool = false
var _lines: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var target: Node2D = _spawn_enemy()
	await process_frame

	var skill_instance: TestSkillInstance = TestSkillInstance.new()
	skill_instance.runtime_modifiers = {
		"burn_damage_multiplier_add": 0.3
	}
	skill_instance.runtime_special_rules = {
		"soul_ember_to_burn_on_full_stack_hit": {
			"status_id": "soul_ember",
			"required_stacks": 2,
			"consume_stacks": 2,
			"apply_burn_stacks": 1,
			"burn_max_stacks": 5
		}
	}
	var executor: RefCounted = SkillSpecialRuleExecutorScript.new()

	target.call("apply_status", &"soul_ember", {"stacks": 4, "max_stacks": 4, "duration": 4.0})
	executor.call("execute_event", &"on_projectile_hit", {
		"skill_instance": skill_instance,
		"target": target
	})

	_expect(int(target.call("get_status_stack", &"soul_ember")) == 0, "4 soul_ember consumes both pairs")
	_expect(int(target.call("get_status_stack", &"burn")) == 2, "4 soul_ember converts into 2 burn")
	_expect(_burn_tick_damage(target) > 2.07 and _burn_tick_damage(target) < 2.09, "Soulburn Lv3 converted burn gets +30% damage")

	for _index: int in range(10):
		target.call("apply_status", &"soul_ember", {"stacks": 2, "max_stacks": 4, "duration": 4.0})
		executor.call("execute_event", &"on_projectile_hit", {
			"skill_instance": skill_instance,
			"target": target
		})

	_expect(int(target.call("get_status_stack", &"burn")) == 5, "Soulburn Lv3 burn is capped at 5 stacks")

	_write_result()
	quit(1 if _failed else 0)


func _spawn_enemy() -> Node2D:
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
	enemy.set("enemy_id", &"small_slime")
	root.add_child(enemy)
	enemy.set("max_health", 999)
	enemy.set("current_health", 999)
	return enemy


func _burn_tick_damage(target: Node) -> float:
	var snapshot: Array = target.call("get_status_snapshot")
	for status_variant: Variant in snapshot:
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		if StringName(String(status.get("id", ""))) == &"burn":
			return float(status.get("tick_damage", 0.0))
	return 0.0


func _expect(condition: bool, message: String) -> void:
	var line: String = "[PASS] %s" % message if condition else "[FAIL] %s" % message
	_lines.append(line)
	if condition:
		return
	_failed = true


func _write_result() -> void:
	var file: FileAccess = FileAccess.open("res://tools/verify_soulburn_lv3_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
