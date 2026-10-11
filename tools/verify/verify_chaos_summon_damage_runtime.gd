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
	enemy.global_position = player.global_position + Vector2(90,0)
	var bus: Node = player.get_node("SkillEventBus")
	for id: StringName in [&"chaos_clone", &"void_maw"]:
		var skill_id: StringName = StringName("chaos_summon_" + String(id))
		check(Fixture.install_runtime_skill(manager,skill_id), "install actual " + String(skill_id))
		bus.emit_skill_event(&"on_cast", context(skill_id,enemy,parent))
		var summons: Node = player.get_node_or_null("SummonManager")
		check(summons != null, "actual cast lazily creates SummonManager")
		if summons == null: continue
		var active: Array = summons._active_by_id.get(id,[])
		check(not active.is_empty(), "actual cast creates " + String(id))
		if active.is_empty(): continue
		var summon: SummonController = active[0]
		summon.set_physics_process(false)
		summon.global_position = player.global_position + Vector2(60,0)
		enemy.global_position = summon.global_position + Vector2(30,0)
		check(summon._summon_effect != null, String(id) + " uses managed custom scene")
		var hp: int = enemy.current_health
		if id == &"chaos_clone":
			bus._snapshots.clear()
			summon._physics_process(2.0)
			check(enemy.current_health == hp, "empty clone record creates no fake damage")
			if summon._summon_effect != null: check(summon._summon_effect._attack_remaining == 0.0, "failed replay creates no false cast gesture")
			check(Fixture.install_runtime_skill(manager,&"frost_cast_glacial_lance"), "install real source lance")
			bus.emit_skill_event(&"on_cast",context(&"frost_cast_glacial_lance",enemy,parent))
			var original: Projectile = find_lance(root,false)
			check(original != null, "original cast creates real lance")
			var original_damage: int = original.damage if original != null else 0
			if original != null: original.despawn_or_free()
			summon._physics_process(1.99)
			check(find_lance(root,true) == null, "clone waits complete two-second interval")
			summon._physics_process(0.01)
			var copied: Projectile = find_lance(root,true)
			check(copied != null, "clone copies original lance instead of chaos bolt")
			if copied != null:
				check(copied.damage == roundi(original_damage * 0.35), "copied lance retains one 35-percent damage scaling")
				check(String(copied.damage_packet.get("source_skill_id","")) == "frost_cast_glacial_lance", "clone retains original skill damage attribution")
				copied.set_physics_process(false)
				copied._on_body_entered(enemy)
				check(enemy.current_health < hp, "copied original lance lowers real Enemy HP")
			if summon._summon_effect != null: check(summon._summon_effect._attack_remaining > 0.0, "successful replay drives confirmed clone gesture")
		else:
			var origin: Vector2 = summon.global_position
			summon._physics_process(0.05)
			var area: AreaEffect = find_maw_area(root)
			check(area != null, "maw produces actual void_rift_field area")
			if area != null:
				check(area.global_position.is_equal_approx(origin) and area.radius == 168.0, "maw real pulse stays at stationary summon with radius168")
				check(is_equal_approx(area.duration,0.35) and is_equal_approx(area.tick_interval,0.1), "maw actual area has short repeated damage window")
				check(area.damage == roundi(summon.player_power * 0.2), "maw real area uses 20-percent Power")
				area._on_body_entered(enemy)
				area.process_mode = Node.PROCESS_MODE_PAUSABLE
				for frame: int in 14: await physics_frame
				check(enemy.current_health < hp, "maw actual area ticks lower real Enemy HP")
			check(summon.global_position.is_equal_approx(origin), "maw real host remains stationary")
			if summon._summon_effect != null: check(summon._summon_effect._attack_remaining > 0.0, "actual area launch drives confirmed maw opening")
		var after: int = enemy.current_health
		var before_vfx: int = enemy.current_health
		if summon._summon_effect != null: summon._summon_effect.update_summon(0.01,Vector2.ZERO,4.0)
		check(enemy.current_health == before_vfx, String(id) + " visual update never applies damage")
		summon.process_mode = Node.PROCESS_MODE_PAUSABLE
		summon.set_physics_process(true)
		var age: float = summon._summon_effect._age if summon._summon_effect != null else 0.0
		var copy_timer: float = summon._copy_remaining
		var cooldown: float = summon._attack._cooldown_remaining
		paused = true
		for frame: int in 3: await physics_frame
		check(enemy.current_health == after and is_equal_approx(summon._copy_remaining,copy_timer) and is_equal_approx(summon._attack._cooldown_remaining,cooldown), String(id) + " engine pause freezes real attacks")
		if summon._summon_effect != null: check(is_equal_approx(summon._summon_effect._age,age), String(id) + " engine pause freezes presentation")
		summon.set_physics_process(false)
		paused = false
		summon._physics_process(summon._remaining_duration+0.01)
		check(summon.state == SummonController.STATE_EXPIRED, String(id) + " real lifetime expires host")
		if summon._summon_effect != null: check(summon._summon_effect.modulate.a == 0.0, String(id) + " expiry hides procedural effect")
		await settle(2)
		check(not is_instance_valid(summon), String(id) + " expired host released")
	await finish()
func context(skill_id: StringName, enemy: Node, parent: Node) -> Dictionary:
	return {"caster":player,"owner":player,"skill_manager":manager,"skill_instance":manager.get_skill(skill_id),"target":enemy,"skill_id":skill_id,"origin_skill_id":skill_id,"scheduled_cast":true,"parent":parent,"power":float(player.attack_power)}
func find_lance(node: Node, copied: bool) -> Projectile:
	if node is Projectile and node.visible and String(node.damage_packet.get("source_skill_id","")) == "frost_cast_glacial_lance" and bool(node.damage_packet.get("is_copy",false)) == copied: return node
	for child: Node in node.get_children():
		var found: Projectile = find_lance(child,copied)
		if found != null: return found
	return null
func find_maw_area(node: Node) -> AreaEffect:
	if node is AreaEffect and node.visible and node.source_id == &"void_rift_field" and String(node.damage_packet.get("source_skill_id","")) == "chaos_summon_void_maw": return node
	for child: Node in node.get_children():
		var found: AreaEffect = find_maw_area(child)
		if found != null: return found
	return null
