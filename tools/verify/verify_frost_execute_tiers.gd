extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	var executor: RefCounted = Executor.new()
	var skill: RefCounted = install(&"frost_power_shatter_execute")
	var action: Dictionary = {"type":"deal_damage", "params":{"amount":{"stat":"power", "scale":1.1}, "low_hp_execute_threshold":0.1, "damage_type":"frost"}}
	enemy.current_health = 900
	executor.execute_action(action, ctx(enemy,skill))
	expect(enemy.is_dead(), "normal ten percent execution")
	var elite: Enemy = make_enemy(Vector2(60,0),"elite")
	elite.current_health = 500
	executor.execute_action(action,ctx(elite,skill))
	expect(elite.current_health == 500, "elite above four percent survives without execute output")
	elite.current_health = 399
	executor.execute_action(action,ctx(elite,skill))
	expect(elite.is_dead(), "elite four percent execution")
	var boss: Enemy = make_enemy(Vector2(80,0),"boss")
	boss.current_health = 999
	executor.execute_action(action,ctx(boss,skill))
	expect(boss.current_health == 919, "Boss takes min 0.8P one percent maxHP bonus")
	executor.execute_action(action,ctx(boss,skill))
	expect(boss.current_health == 919, "Boss execute bonus ICD five seconds")
	advance(5.0)
	executor.execute_action(action,ctx(boss,skill))
	expect(boss.current_health == 839, "Boss bonus ready after five seconds")
	boss.set_meta("immovable",true)
	var pos: Vector2 = boss.position
	executor.execute_action({"type":"pull","params":{"distance":40}},ctx(boss,skill))
	expect(boss.position == pos, "immovable Boss cannot be pulled")
	finish()
