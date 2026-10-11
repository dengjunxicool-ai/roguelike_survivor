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
	var neighbor: EnemyBase = EnemyScene.instantiate()
	neighbor.enemy_id = &"skeleton"
	parent.add_child(neighbor)
	neighbor.process_mode = Node.PROCESS_MODE_DISABLED
	neighbor.max_health = 10000
	neighbor.current_health = 10000
	neighbor.armor = 0
	var bus: Node = player.get_node("SkillEventBus")
	for id: StringName in [&"storm_lynx", &"storm_crow"]:
		var skill_id: StringName = StringName("thunder_summon_" + String(id))
		check(Fixture.install_runtime_skill(manager, skill_id), "learn actual " + String(id) + " skill")
		bus.emit_skill_event(&"on_cast", {"caster":player,"owner":player,"skill_manager":manager,"skill_instance":manager.get_skill(skill_id),"target":enemy,"skill_id":skill_id,"origin_skill_id":skill_id,"scheduled_cast":true,"parent":parent,"power":float(player.attack_power)})
		var summons: Node = player.get_node("SummonManager")
		var active: Array = summons._active_by_id.get(id,[])
		check(not active.is_empty(), "production cast creates managed " + String(id))
		if active.is_empty(): continue
		var summon: SummonController = active[0]
		summon.set_physics_process(false)
		summon.global_position = player.global_position + Vector2(60,0)
		enemy.global_position = summon.global_position + Vector2(24,0)
		neighbor.global_position = enemy.global_position + Vector2(70,0)
		if id == &"storm_crow":
			# Regression: owner and target coincide, while the actual launcher is offset.
			enemy.global_position = player.global_position
			neighbor.global_position = player.global_position + Vector2(1000,0)
			bus.get_node("ThunderCombatPresentation").reset_presentation()
		var neighbor_hp: int = neighbor.current_health
		var hp: int = enemy.current_health
		var stacks: int = enemy.get_status_stack(&"conductive")
		summon._physics_process(0.05)
		check(summon.state == SummonController.STATE_ATTACK,"actual " + String(id) + " attack state")
		if id == &"storm_crow":
			# Deliver the actual managed projectile through its normal collision handler.
			var bolt: Projectile = active_crow_bolt()
			check(bolt != null,"crow produces actual projectile")
			if bolt != null:
				var launch_direction: Vector2 = summon.global_position.direction_to(enemy.global_position)
				check(enemy.global_position == player.global_position,"crow regression target is exactly on player")
				check(bolt.global_position.is_equal_approx(summon.global_position+launch_direction*16.0),"crow projectile originates sixteen pixels from actual summon")
				check(bolt.direction.is_equal_approx(bolt.global_position.direction_to(enemy.global_position)),"crow projectile aims from actual start toward coincident-owner target")
				var view: Node2D = bus.get_node("ThunderCombatPresentation")
				var marker: Node2D = marker_for(view,bolt)
				check(marker != null and marker.visible,"actual live crow projectile produces target marker")
				if marker != null:
					var tracking: Dictionary = view._marker_targets[marker.get_instance_id()]
					check(tracking.generation == bolt.spawn_generation and tracking.projectile.get_ref() == bolt,"crow marker tracks actual projectile spawn generation")
					check(marker.global_position.is_equal_approx(enemy.global_position),"crow marker tracks actual target position")
				bolt.set_physics_process(false)
				bolt._on_body_entered(enemy)
				await settle(2)
				var strike: Node2D
				for hit: Node2D in view._hits:
					if hit.visible and hit._strike != null and hit._strike.visible: strike = hit._strike
				check(strike != null,"actual crow Enemy hit produces visible sky-strike feedback")
				if strike != null:
					check(strike.effect_style == "lightning_strike" and not strike is AreaEffect,"crow sky strike uses pure lightning-strike presentation")
					var health_after_hit: int = enemy.current_health
					strike.update_state(strike.effect_radius,0.08,strike.effect_duration)
					check(enemy.current_health == health_after_hit,"updating crow sky-strike presentation cannot apply duplicate damage")
				check(not bolt.visible,"actual crow projectile returns hidden after collision")
				view._process(0.01)
				if marker != null: check(not marker.visible,"pool despawn hides crow marker on presentation refresh")
		check(enemy.current_health < hp, String(id) + " reduces actual Enemy health via strict damage pipeline")
		check(enemy.get_status_stack(&"conductive") == stacks+1, String(id) + " applies exactly one conductive stack")
		if id == &"storm_lynx":
			check(neighbor.current_health < neighbor_hp,"lynx actual chained attack reduces second real Enemy health")
			check(neighbor.get_status_stack(&"conductive") == 1,"lynx chain supplies one conductive stack to second target")
		check(summon._summon_effect != null,"managed " + String(id) + " attaches procedural presentation")
		if summon._summon_effect != null: check(summon._summon_effect._attack_remaining > 0,"confirmed attack drives " + String(id) + " pose")
		var after: int = enemy.current_health
		summon._physics_process(0.1)
		check(enemy.current_health == after, String(id) + " cooldown prevents duplicate damage")
		# True SceneTree pause must freeze both host cooldown and presentation clock.
		summon.process_mode = Node.PROCESS_MODE_PAUSABLE
		summon.set_physics_process(true)
		var cooldown: float = summon._attack._cooldown_remaining
		var age: float = summon._summon_effect._age if summon._summon_effect != null else 0.0
		paused = true
		for frame: int in 3: await physics_frame
		check(enemy.current_health == after and is_equal_approx(summon._attack._cooldown_remaining,cooldown),String(id)+" engine pause freezes damage and cooldown")
		if summon._summon_effect != null: check(is_equal_approx(summon._summon_effect._age,age),String(id)+" engine pause freezes actual managed visual clock")
		summon.set_physics_process(false)
		paused = false
		print("[thunder_summon_damage] %s hp=%d -> %d element=%s conductive=%d" % [String(id),hp,enemy.current_health,String(summon._attack.damage_type),enemy.get_status_stack(&"conductive")])
		if id == &"storm_lynx": print("[thunder_summon_damage] chain hp=%d -> %d conductive=%d" % [neighbor_hp,neighbor.current_health,neighbor.get_status_stack(&"conductive")])
		else: verify_crow_marker_reuse(summon,bus.get_node("ThunderCombatPresentation"))
		summon.queue_free()
		await settle(2)
	await finish()

func descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in node.get_children():
		found.append(child)
		found.append_array(descendants(child))
	return found

func active_crow_bolt() -> Projectile:
	for candidate: Node in descendants(root):
		if candidate is Projectile and candidate.source_id == &"thunder_arc_bolt" and candidate.visible and String(candidate.damage_packet.get("source_skill_id","")) == "thunder_summon_storm_crow": return candidate
	return null

func marker_for(view: Node2D, bolt: Projectile) -> Node2D:
	for marker: Node2D in view._markers:
		var tracking: Dictionary = view._marker_targets.get(marker.get_instance_id(),{})
		if marker.visible and not tracking.is_empty() and tracking.projectile.get_ref() == bolt and tracking.generation == bolt.spawn_generation: return marker
	return null

func verify_crow_marker_reuse(summon: SummonController, view: Node2D) -> void:
	# Use two actual managed attacks and the real pool; no fabricated generation changes.
	summon._physics_process(2.05)
	var prior: Projectile = active_crow_bolt()
	check(prior != null,"crow cooldown expiry creates next actual projectile")
	if prior == null: return
	var old_marker: Node2D = marker_for(view,prior)
	var old_generation: int = prior.spawn_generation
	check(old_marker != null and old_marker.visible,"next crow attack receives actual live marker")
	prior.despawn_or_free()
	check(not prior.visible,"real projectile pool despawn hides crow bolt")
	summon._physics_process(2.05)
	var reused: Projectile = active_crow_bolt()
	check(reused != null,"crow launches again after pool return")
	if reused == null: return
	check(reused == prior and reused.spawn_generation > old_generation,"real projectile pool reuse advances spawn generation")
	var live_marker: Node2D = marker_for(view,reused)
	view._process(0.01)
	if old_marker != null: check(not old_marker.visible,"visible reused projectile invalidates marker from prior generation")
	check(live_marker != null and live_marker.visible,"matching-generation crow marker remains visible")
	reused.despawn_or_free()
	view._process(0.01)
	if live_marker != null: check(not live_marker.visible,"final real pool despawn hides current crow marker")
