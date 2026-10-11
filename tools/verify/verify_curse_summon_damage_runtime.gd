extends "res://tools/verify/qa_app_fixture.gd"
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")

func run() -> void:
	await setup_run()
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	var summons: Node
	check(Fixture.install_runtime_skill(manager,&"curse_summon_bone_servant"),"install actual cursed-death bone skill")
	# These are actual Enemy deaths, not synthetic death events or a damage stub.
	for index: int in 5:
		var victim: EnemyBase = make_enemy(parent,100)
		victim.global_position = player.global_position+Vector2(90+index*4,0)
		victim.apply_status(&"cursed",{"stacks":1,"duration":5.0})
		victim.take_damage(DamagePacket.from_dictionary({"raw_amount":1000,"damage_origin":"primary_attack","damage_type":"direct_physical","element":"physical","source_type":"player","source_origin_id":"mage","source_skill_id":"mage_basic_attack","source_instance_id":"curse_qa_death_%d" % index},player,victim))
		check(victim.is_dead(),"actual cursed Enemy death %d" % (index+1))
		summons=player.get_node_or_null("SummonManager")
		var active: Array = summons._active_by_id.get(&"bone_servant",[]) if summons!=null else []
		check(active.size()==(1 if index==4 else 0),"bone threshold five is authoritative at death %d" % (index+1))
	check(Fixture.install_runtime_skill(manager,&"curse_summon_soul_crow"),"install actual soul crow skill")
	bus.emit_skill_event(&"on_cast",{"caster":player,"owner":player,"skill_manager":manager,"skill_instance":manager.get_skill(&"curse_summon_soul_crow"),"skill_id":&"curse_summon_soul_crow","origin_skill_id":&"curse_summon_soul_crow","scheduled_cast":true,"parent":parent,"power":float(player.attack_power)})
	summons=player.get_node_or_null("SummonManager")
	check(summons!=null,"actual rules create summon manager")
	if summons==null:
		await finish()
		return
	var enemy: EnemyBase = make_enemy(parent,10000)
	for id: StringName in [&"bone_servant",&"soul_crow"]:
		var active: Array = summons._active_by_id.get(id,[])
		check(not active.is_empty(),"actual rule creates managed "+String(id))
		if active.is_empty(): continue
		var summon: SummonController = active[0]
		summon.set_physics_process(false)
		summon.global_position=player.global_position+Vector2(70,0)
		enemy.global_position=summon.global_position+Vector2(24,0)
		if id==&"soul_crow": enemy.global_position=player.global_position
		var hp: int=enemy.current_health
		var stacks: int=enemy.get_status_stack(&"cursed")
		summon._physics_process(0.05)
		check(summon.state==SummonController.STATE_ATTACK,String(id)+" managed host enters attack")
		if id==&"soul_crow":
			var bolt: Projectile=find_bolt(root)
			check(bolt!=null,"actual soul crow launches real projectile")
			if bolt!=null:
				check(bolt.global_position.is_equal_approx(summon.global_position+summon.global_position.direction_to(enemy.global_position)*16.0),"soul bolt starts at actual crow rather than owner")
				check(bolt.direction.is_equal_approx(bolt.global_position.direction_to(enemy.global_position)),"soul bolt aims toward target coincident with owner")
				bolt.set_physics_process(false)
				bolt._on_body_entered(enemy)
				await settle(2)
				check(not bolt.visible,"actual soul bolt normal collision despawns")
		check(enemy.current_health<hp,String(id)+" strict Enemy pipeline reduces real HP")
		check(enemy.get_status_stack(&"cursed")==stacks+1,String(id)+" actual hit adds exactly one cursed stack")
		check(summon._attack.damage_type==&"arcane",String(id)+" uses registered arcane element")
		check(summon._summon_effect!=null,String(id)+" managed host attaches procedural effect")
		if summon._summon_effect!=null: check(summon._summon_effect._attack_remaining>0.0,String(id)+" attack drives visual pose")
		var after: int=enemy.current_health
		summon._physics_process(0.1)
		check(enemy.current_health==after,String(id)+" cooldown prevents duplicate damage")
		summon.process_mode=Node.PROCESS_MODE_PAUSABLE
		summon.set_physics_process(true)
		var cooldown: float=summon._attack._cooldown_remaining
		var age: float=summon._summon_effect._age if summon._summon_effect!=null else 0.0
		paused=true
		for frame: int in 3: await physics_frame
		check(enemy.current_health==after and is_equal_approx(summon._attack._cooldown_remaining,cooldown),String(id)+" engine pause freezes damage and cooldown")
		if summon._summon_effect!=null: check(is_equal_approx(summon._summon_effect._age,age),String(id)+" engine pause freezes visual clock")
		summon.set_physics_process(false)
		paused=false
		print("[curse_summon_damage] %s hp=%d -> %d element=%s cursed=%d" % [id,hp,enemy.current_health,summon._attack.damage_type,enemy.get_status_stack(&"cursed")])
		summon._physics_process(summon._remaining_duration+0.01)
		check(summon.state==SummonController.STATE_EXPIRED and summon.is_queued_for_deletion(),String(id)+" actual managed lifetime expires host")
		if summon._summon_effect!=null: check(summon._summon_effect.modulate.a==0.0,String(id)+" host expiry immediately fades procedural effect")
		await settle(2)
		check(not is_instance_valid(summon),String(id)+" actual expiry releases managed summon")
	await finish()

func make_enemy(parent: Node,hp: int) -> EnemyBase:
	var enemy: EnemyBase=EnemyScene.instantiate()
	enemy.enemy_id=&"skeleton"
	parent.add_child(enemy)
	enemy.process_mode=Node.PROCESS_MODE_DISABLED
	enemy.max_health=hp
	enemy.current_health=hp
	enemy.armor=0
	return enemy

func find_bolt(node: Node) -> Projectile:
	if node is Projectile and node.visible and node.source_id==&"soul_bolt_projectile" and String(node.damage_packet.get("source_skill_id",""))=="curse_summon_soul_crow": return node
	for child: Node in node.get_children():
		var found: Projectile=find_bolt(child)
		if found!=null: return found
	return null
