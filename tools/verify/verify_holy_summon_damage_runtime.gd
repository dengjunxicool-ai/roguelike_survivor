extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")

func run() -> void:
	await setup_run()
	var parent: Node = player.get_parent()
	var enemy: EnemyBase = EnemyScene.instantiate()
	enemy.enemy_id = &"skeleton"
	parent.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.max_health = 10000
	enemy.current_health = 10000
	enemy.armor = 0
	var bus: Node = player.get_node("SkillEventBus")
	for id: StringName in [&"seraph",&"holy_shield_guardian"]:
		var skill_id: StringName = &"holy_summon_seraph" if id == &"seraph" else &"holy_summon_shield_guardian"
		check(Fixture.install_runtime_skill(manager,skill_id),"install real " + String(skill_id))
		bus.emit_skill_event(&"on_cast",{"caster":player,"owner":player,"skill_manager":manager,"skill_instance":manager.get_skill(skill_id),"target":enemy,"skill_id":skill_id,"origin_skill_id":skill_id,"scheduled_cast":true,"parent":parent,"power":float(player.attack_power)})
		var summons: Node = player.get_node("SummonManager")
		var active: Array = summons._active_by_id.get(id,[])
		check(not active.is_empty(),"actual cast creates managed " + String(id))
		if active.is_empty(): continue
		var summon: SummonController = active[0]
		summon.set_physics_process(false)
		summon.global_position = player.global_position + Vector2(70,0)
		enemy.global_position = summon.global_position + Vector2(25,-10)
		var hp: int = enemy.current_health
		var stacks: int = enemy.get_status_stack(&"judgment")
		summon._physics_process(0.05)
		check(summon.state == SummonController.STATE_ATTACK,String(id) + " enters actual attack state")
		check(summon._summon_effect != null,String(id) + " configured managed procedural scene")
		if summon._summon_effect != null:
			check(summon._summon_effect._attack_remaining > 0,String(id) + " confirmed attack drives actual managed launch pose")
			check(summon._summon_effect._target_offset.is_equal_approx(enemy.global_position-summon.global_position),String(id) + " visual receives actual target offset")
			var before_vfx: int = enemy.current_health
			summon._summon_effect.update_summon(0.01,Vector2.ZERO,10.0)
			check(enemy.current_health == before_vfx,String(id) + " visual update cannot fabricate damage")
		if id == &"seraph":
			check(enemy.current_health == hp,"seraph projectile launch cannot preapply damage")
			check(enemy.get_status_stack(&"judgment") == stacks,"seraph projectile launch cannot preapply judgment")
			var bolt: Projectile = active_seraph_bolt()
			check(bolt != null,"seraph creates actual holy bolt")
			if bolt != null:
				var launch_direction: Vector2 = summon.global_position.direction_to(enemy.global_position)
				check(bolt.global_position.is_equal_approx(summon.global_position+launch_direction*16.0),"seraph bolt begins at actual summon muzzle")
				bolt.set_physics_process(false)
				bolt._on_body_entered(enemy)
				await settle(2)
				check(not bolt.visible,"actual holy bolt returns hidden after collision")
		check(enemy.current_health < hp,String(id) + " reduces real Enemy HP through strict pipeline")
		check(enemy.get_status_stack(&"judgment") == stacks+1,String(id) + " applies exactly one judgment stack")
		var after: int = enemy.current_health
		summon._physics_process(0.1)
		check(enemy.current_health == after,String(id) + " cooldown prevents duplicate damage")
		check(summon._attack._cooldown_remaining > 0,String(id) + " actual attack sets cooldown")
		summon.process_mode = Node.PROCESS_MODE_PAUSABLE
		summon.set_physics_process(true)
		var cooldown: float = summon._attack._cooldown_remaining
		var age: float = summon._summon_effect._age if summon._summon_effect != null else 0.0
		paused = true
		for frame: int in 3: await physics_frame
		check(enemy.current_health == after and is_equal_approx(summon._attack._cooldown_remaining,cooldown),String(id) + " true SceneTree pause freezes combat and cooldown")
		if summon._summon_effect != null: check(is_equal_approx(summon._summon_effect._age,age),String(id) + " true pause freezes managed visual clock")
		summon.set_physics_process(false)
		paused = false
		print("[holy_summon_damage] %s hp=%d -> %d element=%s judgment=%d" % [String(id),hp,enemy.current_health,String(summon._attack.damage_type),enemy.get_status_stack(&"judgment")])
		if id == &"holy_shield_guardian" and summon._summon_effect != null: verify_confirmed_guard(summon)
		# Advance the real host lifetime rather than calling visual.deactivate as a substitute.
		summon._physics_process(summon._remaining_duration+0.01)
		check(summon.state == SummonController.STATE_EXPIRED and summon.is_queued_for_deletion(),String(id) + " lifetime queues actual managed summon release")
		if summon._summon_effect != null: check(summon._summon_effect.modulate.a == 0,String(id) + " actual expiry hides procedural effect")
		await settle(2)
		check(not is_instance_valid(summon),String(id) + " engine frees actual expired summon")
		summons._prune(id)
		check(summons._active_by_id.get(id,[]).is_empty(),String(id) + " manager releases expired occupancy")
	await finish()
func verify_confirmed_guard(summon: SummonController) -> void:
	var effect: Node2D = summon._summon_effect
	check(effect._guard_remaining == 0,"guardian ordinary attack never fabricates guard pose")
	var hp: int = player.current_health
	var packet: DamagePacket = DamagePacket.from_dictionary({"raw_amount":5,"amount":5,"damage_origin":"special","damage_type":"direct_physical","element":"physical","source_type":"enemy","source_origin_id":"skeleton","source_skill_id":"holy_guard_qa","source_instance_id":"holy_guard_qa_first"})
	check(packet.validate().is_empty(),"guard probe uses registered strict damage packet")
	player.take_damage(packet)
	check(player.current_health == hp,"actual guardian absorbs first small hit without HP loss")
	check(effect._guard_remaining > 0,"actual positive absorption triggers guard presentation")
	effect.update_summon(0.1,Vector2.ZERO,10.0)
	var remaining: float = effect._guard_remaining
	packet = packet.clone()
	packet.set_value("source_instance_id","holy_guard_qa_second")
	player.take_damage(packet)
	check(is_equal_approx(effect._guard_remaining,remaining),"real guard cooldown prevents a second presentation refresh")
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result
func active_seraph_bolt() -> Projectile:
	for node: Node in descendants(root):
		if node is Projectile and node.visible and String(node.damage_packet.get("source_skill_id","")) == "holy_summon_seraph": return node
	return null
