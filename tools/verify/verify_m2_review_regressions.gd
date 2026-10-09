extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Executor=preload("res://scripts/skills/skill_action_executor.gd")
const Pool=preload("res://scripts/upgrades/upgrade_pool.gd")
const Policy=preload("res://scripts/skills/skill_requirement_policy.gd")
const Offer=preload("res://scripts/skills/skill_offer_service.gd")
const Query=preload("res://scripts/modifiers/modifier_query.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	setup()
	enemy.get_node("StatusEffectManager").set_physics_process(false)
	# New output must preserve M1 growth in both settlement modes.
	var pact: RefCounted=install(&"curse_power_death_pact")
	pact.current_level=2
	pact.current_rarity="legendary"
	bus.emit_skill_event(&"on_cast",ctx(enemy,pact))
	advance(6)
	bus.update_skill_cycles()
	await process_frame
	expect(not enemy.packets.is_empty() and int(enemy.packets[-1].raw_amount)==151,"contract expiry preserves level and rarity")
	advance(8)
	bus.emit_skill_event(&"on_cast",ctx(enemy,pact))
	var corpse: Enemy=enemy
	var neighbor: Enemy=make_enemy(Vector2(35,0))
	corpse.current_health=0
	bus.emit_skill_event(&"on_enemy_killed",ctx(corpse))
	await process_frame
	expect(not neighbor.packets.is_empty() and int(neighbor.packets[-1].raw_amount)==302,"contract death preserves level and rarity")
	Registry.get_or_create(root).unregister_enemy(corpse)
	enemy=neighbor
	enemy.get_node("StatusEffectManager").set_physics_process(false)
	manager.clear_skills()
	# All positive cast hit forms, including real area damage, can ignite.
	install(&"fire_power_ignite_core")
	var cast: RefCounted=install(&"fire_cast_lava_rift")
	enemy.apply_status(&"burning",{"duration":4,"power":100.0})
	var hit: Dictionary=ctx(enemy,cast)
	hit.damage_amount=1
	bus.emit_skill_event(&"post_damage_hit",hit)
	expect(is_equal_approx(float(enemy.get_node("StatusEffectManager").get_status_snapshot()[0].duration_remaining),3),"area cast damage ignites one second")
	advance(1.0)
	enemy.packets.clear()
	bus.emit_skill_event(&"on_cast",ctx(enemy,cast))
	await process_frame
	for area: Node in root.get_children():
		if area is AreaEffect:
			if String(area.source_id)=="lava_rift": area.call("_physics_process",1.0)
	var actual_area_ignite: bool=false
	for packet: Dictionary in enemy.packets:
		actual_area_ignite=actual_area_ignite or (String(packet.get("listener_skill_id",""))=="fire_power_ignite_core" and int(packet.raw_amount)==90)
	expect(actual_area_ignite,"spawned lava area damage really triggers ignite")
	install(&"fire_passive_scorched_ground_affinity")
	expect(preload("res://scripts/skills/fire_ground_policy.gd").burning_bonus(enemy,player)>0,"deferred real lava area contributes ground bonus")
	manager.clear_skills()
	enemy.get_node("StatusEffectManager").clear_statuses()
	# A real attack rule produces a secondary status; that status earns resources.
	var cycle: RefCounted=install(&"fire_power_combustion_chain")
	var attack: RefCounted=install(&"fire_attack_searing")
	enemy.set_meta("enemy_rank","boss")
	bus.emit_skill_event(&"attack_hit",ctx(enemy,attack))
	var statuses: Node=enemy.get_node("StatusEffectManager")
	expect(statuses.has_status(&"burning"),"attack actually applies Burning")
	for i: int in 5:
		bus.emit_skill_event(&"attack_hit",ctx(enemy,attack))
		advance(1.0)
		statuses.update_status_effects(1.0)
	expect(is_equal_approx(float(cycle.get_meta("combustion_burning_deaths",0)),1),"five real attack Burning ticks charge Boss resource")
	manager.clear_skills()
	statuses.clear_statuses()
	enemy.set_meta("enemy_rank","normal")
	# Dependency is enforced by shared qualification and real learning/offer paths.
	var fear: Dictionary=GameData.get_skill(&"curse_power_fear_whisper")
	expect(not Policy.new().evaluate(player,fear).available,"fear requires Cursed source")
	expect(not Offer.new().is_skill_available(player,fear),"fear is not offered without Cursed source")
	expect(not manager.add_skill(&"curse_power_fear_whisper"),"fear cannot be learned as dead first entry")
	manager.clear_skills()
	# Earlier guarantees cannot overwrite a survival reservation.
	var pool: RefCounted=Pool.new()
	player.current_health=100
	var options: Array=pool.call("_build_skill_level_up_options",player)
	install(&"fire_cast_meteor_rain")
	options=pool.call("_build_skill_level_up_options",player)
	var attributes: Array=pool.call("_build_level_up_upgrade_options",player)
	var Opt=preload("res://scripts/upgrades/upgrade_option.gd")
	var selected: Array=[options[0],Opt.new({"id":"attribute_a","tags":["damage"]}),Opt.new({"id":"attribute_b","tags":["damage"]})]
	pool.call("_enforce_guaranteed_options",player,selected,3)
	pool.call("_enforce_god_skill_learn_option",player,selected,3)
	pool.call("_enforce_ordinary_active_learn_option",player,selected,3)
	pool.call("_enforce_progression",player,selected,pool.call("_build_god_skill_learn_options",player),3)
	var survival: bool=false
	var upgrade: bool=false
	for option: RefCounted in selected:
		survival=survival or option.tags.has("survival")
		upgrade=upgrade or String(option.id).begins_with("skill_level_up:")
	expect(survival and upgrade,"competing guarantees preserve upgrade then survival")
	manager.clear_skills()
	# Conditional shield bonus expires even without another incoming hit/grant.
	install(&"holy_passive_sanctuary")
	var ray: RefCounted=install(&"holy_cast_holy_ray")
	Executor.new().execute_action({"type":"grant_shield","params":{"amount":100,"duration":6.0}},ctx(null,ray))
	player.get_node("ModifierStore").set_source("sanctuary_real_effects",manager.passive_modifiers,[&"damage"])
	var query: RefCounted=Query.for_damage(DamagePacket.from_dictionary({"raw_amount":1,"element":"holy","source_skill_id":ray.skill_id}),player)
	var store: Node=player.get_node("ModifierStore")
	expect(float(store.collect(query).get("holy_damage_multiplier_add",0))>0,"sanctuary applies while shield alive")
	advance(6.1)
	expect(is_zero_approx(float(store.collect(query).get("holy_damage_multiplier_add",0))),"sanctuary stops after shield naturally expires")
	manager.clear_skills()
	store.clear_source("sanctuary_real_effects")
	statuses.clear_statuses()
	# Tick alignment must not matter while actually inside a fire ground.
	enemy.apply_status(&"burning",{"duration":4,"power":100.0})
	statuses.call("_execute_status_effects",statuses.get("_statuses")[&"burning"],"on_tick_effects")
	var baseline: float=enemy.packets[-1].raw_amount
	install(&"fire_passive_scorched_ground_affinity")
	for ground_id: String in ["meteor_burning_ground","searing_fire_path","blazing_run_path"]:
		var area: AreaEffect=AreaEffect.new()
		area.source_id=StringName(ground_id)
		area.radius=84
		area.position=enemy.position
		root.add_child(area)
		preload("res://scripts/combat/area_effect_manager.gd").get_or_create(root).register_area(area,1.0)
		area.set_physics_process(false)
		advance(0.8)
		statuses.call("_execute_status_effects",statuses.get("_statuses")[&"burning"],"on_tick_effects")
		expect(is_equal_approx(float(enemy.packets[-1].raw_amount),roundf(baseline*1.35)),"true ground bonus independent of tick offset: "+ground_id)
		area.position=Vector2(4000,4000)
		statuses.call("_execute_status_effects",statuses.get("_statuses")[&"burning"],"on_tick_effects")
		expect(is_equal_approx(float(enemy.packets[-1].raw_amount),baseline),"ground exit immediately stops bonus")
		area.free()
	manager.clear_skills()
	# Existing async meteor work must stop on replacement, and pause with the game.
	var meteor: RefCounted=install(&"fire_cast_meteor_rain")
	enemy.current_health=10000
	bus.emit_skill_event(&"on_cast",ctx(enemy,meteor))
	await process_frame
	for node: Node in root.get_children():
		if node is Projectile: node.set_physics_process(false)
	paused=true
	var before: int=projectile_count()
	await create_timer(0.65,true).timeout
	expect(projectile_count()==before,"pending meteor output pauses with gameplay")
	paused=false
	manager.clear_skills()
	meteor=install(&"fire_cast_meteor_rain")
	bus.emit_skill_event(&"on_cast",ctx(enemy,meteor))
	await process_frame
	expect(manager.replace_ordinary_skill(&"fire_cast_meteor_rain",&"fire_cast_lava_rift","normal"),"replace delayed source succeeds")
	await process_frame
	await create_timer(0.65).timeout
	expect(projectile_count()==0,"removed meteor cannot create delayed projectile")
	finish()
func projectile_count() -> int:
	var result: int=0
	for node: Node in root.get_children():
		if node is Projectile and not node.is_queued_for_deletion(): result+=1
	return result
