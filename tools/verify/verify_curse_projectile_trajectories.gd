## 描述要求的真实追踪与回程，使用正式施法/工厂/敌人。
extends "res://tools/verify/qa_app_fixture.gd"
const Fixture=preload("res://tools/verify/skill_rebalance_fixture.gd")
const Enemy=preload("res://scenes/enemies/enemy.tscn")
func enemy_at(offset: Vector2) -> Node2D:
	var target: Node2D=Enemy.instantiate();target.enemy_id=&"skeleton"
	player.get_parent().add_child(target);target.global_position=player.global_position+offset
	target.process_mode=Node.PROCESS_MODE_DISABLED;target.max_health=10000;target.current_health=10000;target.armor=0
	return target
func run() -> void:
	await setup_run()
	var bus: Node=player.get_node("SkillEventBus")
	var close:=enemy_at(Vector2(100,0));close.apply_status(&"cursed",{"stacks":1,"duration":3.0})
	var fresh:=enemy_at(Vector2(190,-80))
	for id: StringName in [&"curse_cast_black_serpent_hunt",&"curse_cast_death_scythe"]:
		check(Fixture.install_runtime_skill(manager,id),"learn "+String(id))
		bus.emit_skill_event(&"on_cast",{"caster":player,"owner":player,"parent":player.get_parent(),"target":fresh,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(id),"skill_id":id,"origin_skill_id":id,"scheduled_cast":true,"power":float(player.attack_power)})
	var snake: Projectile
	var scythe: Projectile
	for child: Node in player.get_parent().get_children():
		if child is Projectile:
			child.set_physics_process(false)
			if child.source_id==&"black_serpent_projectile": snake=child
			if child.source_id==&"death_scythe_projectile": scythe=child
	check(snake!=null and scythe!=null,"canonical casts create both projectile profiles")
	if snake!=null:
		check(snake.homing_enabled,"black serpent enables actual steering")
		check(snake._find_nearest_homing_target()==fresh,"serpent retarget prefers uncursed over closer cursed enemy")
		fresh.global_position+=Vector2(0,120)
		var before:=snake.direction
		snake._update_homing_direction(0.1)
		check(not snake.direction.is_equal_approx(before),"serpent turns after actual enemy movement")
	if scythe!=null:
		check(scythe._return_once,"death scythe enables actual one-time return")
		scythe.global_position=player.global_position+Vector2(180,-50)
		scythe.direction=Vector2.RIGHT
		player.global_position+=Vector2(0,50)
		scythe._begin_return()
		check(scythe._returned and scythe.direction.dot(scythe.global_position.direction_to(player.global_position))>0.999,"return aims at actual moved caster")
		var before:int=fresh.current_health
		scythe._on_body_entered(fresh)
		check(fresh.current_health<before,"return leg still applies real damage")
		var direction:=scythe.direction
		scythe._begin_return()
		check(scythe.direction==direction,"second return call cannot flip again")
	await finish()
