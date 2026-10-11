## 真实工厂与战斗事件的GPU验收；截图只能输出E:/codex。
extends "res://tools/verify/qa_app_fixture.gd"
const Fixture=preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory=preload("res://scripts/combat/combat_object_factory.gd")
const Enemy=preload("res://scenes/enemies/enemy.tscn")
const Packet=preload("res://scripts/combat/damage_packet.gd")
var owned: Array[Node2D]=[]
func enemy_at(offset: Vector2,hp: int=10000) -> Node2D:
	var target: Node2D=Enemy.instantiate();target.enemy_id=&"skeleton"
	player.get_parent().add_child(target);target.global_position=player.global_position+offset
	target.process_mode=Node.PROCESS_MODE_DISABLED;target.max_health=10000;target.current_health=hp;target.armor=0
	return target
func verify_pixels(node: CanvasItem,label: String) -> void:
	paused=true;await settle(3);await RenderingServer.frame_post_draw
	var shown:=root.get_texture().get_image()
	node.visible=false;await settle(3);await RenderingServer.frame_post_draw
	var hidden:=root.get_texture().get_image();var changed:=0
	for y: int in range(0,shown.get_height(),3):
		for x: int in range(0,shown.get_width(),3):
			var a:=shown.get_pixel(x,y);var b:=hidden.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.025: changed+=1
	check(changed>12,label+" visible GPU pixels (%d)"%changed)
	node.visible=true;paused=false
func cast(bus: Node,id: StringName,target: Node2D) -> void:
	bus.emit_skill_event(&"on_cast",{"caster":player,"owner":player,"parent":player.get_parent(),"target":target,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(id),"skill_id":id,"origin_skill_id":id,"power":float(player.attack_power)})
func run() -> void:
	await setup_run()
	check(DisplayServer.get_name()!="headless","rendered verification uses GPU")
	var count:=0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school",""))=="curse" and String(definition.id).begins_with("curse_") and definition.get("fusion_school")==null:
			check(Fixture.install_runtime_skill(manager,StringName(definition.id)),"learn "+String(definition.id));count+=1
	check(count==14,"all fourteen base curse skills installed")
	var parent: Node=player.get_parent();var bus: Node=player.get_node("SkillEventBus")
	var view: Node=bus.get_node("CurseCombatPresentation");view.process_mode=Node.PROCESS_MODE_PAUSABLE
	var ids: Array[String]=["doom_circle_delay","doom_circle_burst","curse_whisper_burst","soul_explosion_area","soul_chain_link"]
	var radii: Array[float]=[184.8,184.8,184.8,168.0,37.8]
	for start: int in [0,2]:
		var end:=2 if start==0 else ids.size()
		for i: int in range(start,end):
			var area:=Factory.create_area_effect({"parent":parent,"area_id":ids[i],"source_id":ids[i],"position":player.global_position+Vector2(-230+(i-start)%2*460,-65+(i-start)/2*190),"radius":radii[i],"duration":1.2 if i==0 else 0.24,"damage":0,"caster":player}) as AreaEffect
			check(area!=null and area._visual_effect_node!=null,"canonical area "+ids[i])
			if area==null or area._visual_effect_node==null: continue
			area.set_physics_process(false);area._age=0.68 if i==0 else 0.07
			area._visual_effect_node.update_state(area.radius,area._age,area.duration);owned.append(area)
		await capture("curse_fields_%d"%start)
		for item: Node2D in owned: await verify_pixels(item._visual_effect_node,String(item.source_id))
		for item: Node2D in owned: item.prepare_for_pool_despawn()
		owned.clear()
	var target:=enemy_at(Vector2(150,-30))
	target.apply_status(&"cursed",{"stacks":3,"duration":3.0,"source":player,"power":float(player.attack_power)})
	await settle()
	var statuses: Node=target.get_node("StatusEffectManager")
	var mantle: Node2D=statuses._status_visual_overlay.get_node("ProceduralStatus")
	mantle.process_mode=Node.PROCESS_MODE_PAUSABLE
	# Twelve actual cursed deaths earn the canonical next-cast charge and summon bone servants.
	for i: int in 12:
		var victim:=enemy_at(Vector2(360,190),1)
		victim.apply_status(&"cursed",{"stacks":1,"duration":3.0,"source":player,"power":float(player.attack_power)})
		victim.take_damage(Packet.from_dictionary({"raw_amount":1,"amount":1,"damage_origin":"primary_attack","damage_type":"direct_magical","element":"arcane","attacker":player,"source_skill_id":"curse_attack_cursing","source_origin_id":"curse_attack_cursing","source_instance_id":"curse_render_kill_%d"%i}))
		await settle(1);bus.process_pending_events()
	view._process(0.11)
	check(view._harvest!=null and view._harvest.visible,"twelve real cursed deaths show actual harvest readiness")
	check(view._debt!=null and view._debt.visible,"real soul-debt counter shows partial coffin seal")
	await capture("curse_harvest_ready")
	if view._harvest!=null: await verify_pixels(view._harvest,"actual charged soul harvest")
	cast(bus,&"curse_summon_soul_crow",target)
	cast(bus,&"curse_power_death_pact",target)
	cast(bus,&"curse_cast_black_serpent_hunt",target)
	bus.process_pending_events()
	var sm: Node=player.get_node("SummonManager")
	for i: int in 2:
		var id: StringName=&"bone_servant" if i==0 else &"soul_crow"
		var active: Array=sm._active_by_id.get(id,[])
		check(not active.is_empty(),"actual managed "+String(id))
		if active.is_empty(): continue
		var summon: Node2D=active[0];summon.global_position=player.global_position+Vector2(-210+i*115,-15)
		summon.set_physics_process(false);summon._summon_effect.update_summon(0.22,Vector2(80,0),10.0);owned.append(summon)
	view._process(0.11)
	for item: Node2D in view._hits: item.deactivate()
	for item: Node2D in view._bursts: item.deactivate()
	for item: Node2D in view._links: item.deactivate()
	# Actual subsequent casts consumed the one-shot harvest charge.
	check(view._harvest!=null and not view._harvest.visible,"real cast consumes readiness aura")
	var corpse:=enemy_at(Vector2(20,110),1)
	corpse.apply_status(&"cursed",{"stacks":1,"duration":3.0,"source":player,"power":float(player.attack_power)})
	corpse.take_damage(Packet.from_dictionary({"raw_amount":1,"amount":1,"damage_origin":"primary_attack","damage_type":"direct_magical","element":"arcane","attacker":player,"source_skill_id":"curse_attack_cursing","source_origin_id":"curse_attack_cursing","source_instance_id":"curse_render_crow_absorption"}))
	await settle(1);bus.process_pending_events()
	var absorbed:=false
	for link: Node2D in view._links:
		if not link.visible: continue
		link._process(0.12);link.set_process(false)
		if int(link.get_node("BatchedSouls").material.get_shader_parameter("link_kind"))==0: absorbed=true
	check(absorbed,"real cursed death creates crow absorption thread")
	await capture("curse_crow_real_soul_absorption")
	for link: Node2D in view._links:
		if link.visible and int(link.get_node("BatchedSouls").material.get_shader_parameter("link_kind"))==0: await verify_pixels(link,"actual crow soul absorption")
	for link: Node2D in view._links: link.deactivate()
	await capture("curse_summons_status_and_contract")
	await verify_pixels(mantle,"three real curse stacks")
	for summon: Node2D in owned: await verify_pixels(summon._summon_effect,String(summon.definition.id))
	for marker: Node2D in view._contracts:
		if marker.visible: await verify_pixels(marker,"actual death pact countdown")
	if view._debt!=null: await verify_pixels(view._debt,"actual grand-coffin debt")
	var health_before:int=target.current_health
	statuses.resolve_cursed(&"natural")
	await settle(1);bus.process_pending_events()
	check(target.current_health<health_before,"actual curse resolution applies damage")
	check(view._bursts.any(func(item: Node2D)->bool: return item.visible),"confirmed curse resolution creates feedback")
	for burst: Node2D in view._bursts:
		if burst.visible: burst._process(0.09);burst.set_process(false)
	await capture("curse_confirmed_settlement")
	for burst: Node2D in view._bursts:
		if burst.visible: await verify_pixels(burst,"confirmed soul settlement");burst.deactivate()
	var fresh:=enemy_at(Vector2(270,50))
	var executor:=preload("res://scripts/skills/skill_action_executor.gd").new()
	executor.execute_action({"type":"chain_to_targets","params":{"radius":170.0,"count":1,"actions":[{"type":"apply_status","params":{"status_id":"cursed","stacks":1,"duration":3.0}}]}},{"caster":player,"owner":player,"parent":parent,"source":target,"target":target,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(&"curse_passive_plague_spread")})
	check(fresh.get_status_stack(&"cursed")>0 and not view._links.is_empty(),"actual plague recipient creates confirmed spread thread")
	for link: Node2D in view._links: link._process(0.12);link.set_process(false)
	await capture("curse_actual_soul_links")
	for link: Node2D in view._links:
		if link.visible: await verify_pixels(link,"real plague spread thread");link.deactivate()
	for item: Node2D in owned: item.visible=false
	owned.clear()
	for i: int in 4:
		var id: String=["black_serpent_projectile","death_scythe_projectile","soul_bolt_projectile","soul_storm_bolt"][i]
		var projectile:=Factory.create_projectile({"parent":parent,"projectile_id":id,"source_id":id,"position":player.global_position+Vector2(-270+i*180,120),"direction":Vector2(0.8,-0.6),"speed":520.0,"lifetime":3.0}) as Projectile
		check(projectile._visual_effect_node!=null,"canonical projectile "+id)
		projectile.set_physics_process(false);projectile._visual_effect_node.update_projectile(0.25);owned.append(projectile)
	await capture("curse_projectiles")
	for item: Node2D in owned: await verify_pixels(item._visual_effect_node,String(item.source_id))
	paused=true;await settle(3);await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	await create_timer(0.2,true).timeout;await RenderingServer.frame_post_draw
	check(before.get_data()==root.get_texture().get_image().get_data(),"curse pixels freeze exactly during engine pause")
	await finish()
