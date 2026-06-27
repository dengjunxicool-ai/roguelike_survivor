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
	var normal: Node2D = _spawn_enemy(false)
	var boss: Node2D = _spawn_enemy(true)
	await process_frame

	var skill_instance: TestSkillInstance = TestSkillInstance.new()
	skill_instance.runtime_special_rules = {
		"soul_ember_to_burn_on_full_stack_hit": {
			"status_id": "soul_ember",
			"required_stacks": 2,
			"consume_stacks": 2,
			"apply_burn_stacks": 1,
			"burn_max_stacks": 5
		}
	}
	skill_instance.runtime_modifiers = {
		"burn_max_stacks_add": 2,
		"boss_burn_max_stacks_add": 1,
		"burn_duration_add": 1
	}

	var executor: RefCounted = SkillSpecialRuleExecutorScript.new()
	for _index: int in range(10):
		_convert_pair(executor, skill_instance, normal)
		_convert_pair(executor, skill_instance, boss)

	_expect(int(normal.call("get_status_stack", &"burn")) == 7, "Soulburn Lv4 normal burn cap is 7")
	_expect(int(boss.call("get_status_stack", &"burn")) == 6, "Soulburn Lv4 Boss burn cap is 6")
	_expect(_burn_duration_remaining(normal) > 3.9, "Soulburn Lv4 normal burn duration is extended to 4s")
	_expect(_burn_duration_remaining(boss) > 3.9, "Soulburn Lv4 Boss burn duration is extended to 4s")

	_write_result()
	quit(1 if _failed else 0)


func _convert_pair(executor: RefCounted, skill_instance: RefCounted, target: Node) -> void:
	target.call("apply_status", &"soul_ember", {"stacks": 2, "max_stacks": 4, "duration": 4.0})
	executor.call("execute_event", &"on_projectile_hit", {
		"skill_instance": skill_instance,
		"target": target
	})


func _burn_duration_remaining(target: Node) -> float:
	var snapshot: Array = target.call("get_status_snapshot")
	for status_variant: Variant in snapshot:
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		if StringName(String(status.get("id", ""))) == &"burn":
			return float(status.get("duration_remaining", 0.0))
	return 0.0


func _spawn_enemy(is_boss: bool) -> Node2D:
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
	enemy.set("enemy_id", &"small_slime")
	root.add_child(enemy)
	enemy.set("max_health", 999)
	enemy.set("current_health", 999)
	if is_boss:
		enemy.set_meta("is_boss", true)
		enemy.set_meta("enemy_rank", "boss")
		enemy.add_to_group(&"bosses")
	return enemy


func _expect(condition: bool, message: String) -> void:
	var line: String = "[PASS] %s" % message if condition else "[FAIL] %s" % message
	_lines.append(line)
	if condition:
		return
	_failed = true


func _write_result() -> void:
	var file: FileAccess = FileAccess.open("res://tools/verify/verify_soulburn_lv4_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
