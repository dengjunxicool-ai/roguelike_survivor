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
	var normal: Node2D = _spawn_enemy(false, false)
	var elite: Node2D = _spawn_enemy(true, false)
	var boss: Node2D = _spawn_enemy(false, true)
	await process_frame

	var skill_instance: TestSkillInstance = TestSkillInstance.new()
	skill_instance.runtime_special_rules = {
		"soulburn_burst_on_full_burn_direct_hit": {
			"required_burn_stacks": 5,
			"consume_burn_stacks": "all",
			"normal_max_hp_damage": 0.03,
			"elite_max_hp_damage": 0.01,
			"boss_max_hp_damage": 0.0025,
			"same_target_cooldown": 0.0,
			"can_crit": false,
			"uses_primary_attack_damage": false
		}
	}
	var executor: RefCounted = SkillSpecialRuleExecutorScript.new()

	_apply_burn(normal, 7)
	_apply_burn(elite, 5)
	_apply_burn(boss, 6)

	executor.call("execute_event", &"on_projectile_hit", {"skill_instance": skill_instance, "target": normal})
	executor.call("execute_event", &"on_projectile_hit", {"skill_instance": skill_instance, "target": elite})
	executor.call("execute_event", &"on_projectile_hit", {"skill_instance": skill_instance, "target": boss})

	_expect(int(normal.get("current_health")) == 970, "normal Soulburn burst deals 3% max HP")
	_expect(int(elite.get("current_health")) == 990, "elite Soulburn burst deals 1% max HP")
	_expect(int(boss.get("current_health")) == 997, "Boss Soulburn burst deals rounded 0.25% max HP")
	_expect(int(normal.call("get_status_stack", &"burning")) == 0, "normal Soulburn burst consumes all burning")
	_expect(int(elite.call("get_status_stack", &"burning")) == 0, "elite Soulburn burst consumes all burning")
	_expect(int(boss.call("get_status_stack", &"burning")) == 0, "Boss Soulburn burst consumes all burning")

	var under_stacked: Node2D = _spawn_enemy(false, false)
	await process_frame
	_apply_burn(under_stacked, 4)
	executor.call("execute_event", &"on_projectile_hit", {"skill_instance": skill_instance, "target": under_stacked})
	_expect(int(under_stacked.get("current_health")) == 1000, "Soulburn burst does not trigger below 5 burn")
	_expect(int(under_stacked.call("get_status_stack", &"burning")) == 4, "Soulburn burst does not consume burning below 5 stacks")

	_write_result()
	quit(1 if _failed else 0)


func _apply_burn(target: Node, stacks: int) -> void:
	target.call("apply_status", &"burning", {
		"stacks": stacks,
		"max_stacks": stacks,
		"duration": 4.0,
		"power": 100.0
	})


func _spawn_enemy(is_elite: bool, is_boss: bool) -> Node2D:
	var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate() as Node2D
	enemy.set("enemy_id", &"small_slime")
	root.add_child(enemy)
	enemy.set("max_health", 1000)
	enemy.set("current_health", 1000)
	if is_elite:
		enemy.set_meta("is_elite", true)
		enemy.set_meta("enemy_rank", "elite")
		enemy.add_to_group(&"elites")
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
	var file: FileAccess = FileAccess.open("user://verify_soulburn_lv5_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
