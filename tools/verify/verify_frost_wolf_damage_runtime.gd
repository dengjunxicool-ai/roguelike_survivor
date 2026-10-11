## 生产施放、召唤控制器及真实敌人受击管线的霜狼伤害回归。
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")

func run() -> void:
	await setup_run()
	check(Fixture.install_runtime_skill(manager, &"frost_summon_frost_wolf"), "learn actual frost wolf skill")
	var parent: Node = player.get_parent()
	var enemy: EnemyBase = EnemyScene.instantiate()
	enemy.enemy_id = &"skeleton"
	parent.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.max_health = 1000
	enemy.current_health = 1000
	enemy.armor = 0
	var bus: Node = player.get_node("SkillEventBus")
	bus.emit_skill_event(&"on_cast", {
		"caster": player, "owner": player, "skill_manager": manager,
		"skill_instance": manager.get_skill(&"frost_summon_frost_wolf"),
		"target": enemy, "skill_id": &"frost_summon_frost_wolf",
		"origin_skill_id": &"frost_summon_frost_wolf", "scheduled_cast": true,
		"parent": parent, "power": float(player.attack_power)
	})
	var wolf: SummonController
	for node: Node in parent.get_children():
		if node is SummonController and String(node.get_meta("summon_definition_id", "")) == "summon_frost_wolf":
			wolf = node
			break
	check(wolf != null, "production cast creates frost wolf")
	if wolf == null:
		await finish()
		return
	wolf.set_physics_process(false)
	wolf.global_position = player.global_position + Vector2(50, 0)
	enemy.global_position = wolf.global_position + Vector2(24, 0)
	var before: int = enemy.current_health
	wolf._physics_process(0.05)
	check(wolf.state == SummonController.STATE_ATTACK, "wolf reaches actual melee attack state")
	check(enemy.current_health < before, "first wolf bite reduces real enemy health")
	check(enemy.get_status_stack(&"chilled") == 1, "bite still applies one chilled stack")
	check(float(wolf.get_node("SummonEffect").get("_attack_remaining")) > 0.0, "bite retains synchronized attack presentation")
	var after_first: int = enemy.current_health
	wolf._physics_process(0.1)
	check(enemy.current_health == after_first, "cooldown prevents duplicate bite damage")
	wolf._physics_process(1.1)
	check(enemy.current_health < after_first, "next bite after cooldown also reduces real health")
	check(enemy.get_status_stack(&"chilled") == 2, "repeated bite preserves chilled stacking")
	var before_chase: int = enemy.current_health
	enemy.global_position = wolf.global_position + Vector2(200, 0)
	wolf._physics_process(0.05)
	check(wolf.state == SummonController.STATE_CHASE and enemy.current_health == before_chase, "out-of-range wolf chases without remote melee damage")
	# Exercise engine pause, rather than manually calling a paused controller.
	enemy.global_position = wolf.global_position + Vector2(24, 0)
	wolf.process_mode = Node.PROCESS_MODE_PAUSABLE
	wolf.set_physics_process(true)
	var remaining: float = wolf._attack._cooldown_remaining
	paused = true
	for frame: int in 3:
		await physics_frame
	check(enemy.current_health == before_chase and is_equal_approx(wolf._attack._cooldown_remaining, remaining), "pause freezes melee health and cooldown")
	wolf.set_physics_process(false)
	paused = false
	print("[frost_wolf_damage] health_before=%d health_after=%d element=%s" % [before, enemy.current_health, String(wolf._attack.damage_type)])
	await finish()
