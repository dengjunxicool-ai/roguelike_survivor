## 实际游戏工厂、敌人伤害和 GPU 像素验证；截图仅写 E:/codex。
extends "res://tools/verify/qa_app_fixture.gd"
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
var owned: Array[Node2D] = []
func hold_area(area: AreaEffect, age: float) -> void:
	area.process_mode = Node.PROCESS_MODE_PAUSABLE
	area.set_physics_process(false)
	area._age = age
	area.get_node("AreaVisualEffect").update_state(area.radius,age,area.duration)
func enemy_at(offset: Vector2) -> Node2D:
	var enemy: Node2D = Enemy.instantiate()
	enemy.enemy_id = &"skeleton"
	player.get_parent().add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = player.global_position+offset
	enemy.max_health = 10000
	enemy.current_health = 10000
	enemy.armor = 0
	return enemy
func verify_pixels(node: CanvasItem, label: String) -> void:
	paused = true
	await settle(4)
	await RenderingServer.frame_post_draw
	var shown := root.get_texture().get_image()
	node.visible = false
	await settle(3)
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	var changed := 0
	for y: int in range(0,shown.get_height(),3):
		for x: int in range(0,shown.get_width(),3):
			var a := shown.get_pixel(x,y)
			var b := hidden.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.025: changed+=1
	check(changed>12,label+" changes real pixels (%d)" % changed)
	node.visible = true
	paused = false
func run() -> void:
	await setup_run()
	check(DisplayServer.get_name()!="headless","full fire school test uses GPU")
	var count := 0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school",""))=="fire" and String(definition.id).begins_with("fire_") and definition.get("fusion_school")==null:
			check(Fixture.install_runtime_skill(manager,StringName(definition.id)),"learn "+String(definition.id))
			count+=1
	check(count==14,"all fourteen base fire skills covered")
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	var view: Node2D = bus.get_node("FireCombatPresentation")
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	var enemy := enemy_at(Vector2(-250,-90))
	var area_ids := ["searing_fire_path","blazing_run_path","meteor_burning_ground","lava_rift"]
	var offsets := [Vector2(-250,-90),Vector2(-250,120),Vector2(220,-90),Vector2(30,130)]
	for i: int in area_ids.size():
		var params := {"parent":parent,"area_id":area_ids[i],"source_id":area_ids[i],"position":player.global_position+offsets[i],"radius":80.0,"duration":5.0,"damage":20,"caster":player,"source_skill_id":&"fire_cast_lava_rift","event_bus":bus,"skill_manager":manager,"damage_packet":{"raw_amount":20,"amount":20,"damage_origin":"field","damage_type":"area_direct","element":"fire","attacker":player,"source_skill_id":"fire_cast_lava_rift","source_id":area_ids[i],"source_instance_id":"fire_render_area_%d" % i}}
		if area_ids[i]=="lava_rift":
			params.merge({"shape":"line","length":260.0,"width":42.0,"cone_direction":Vector2.RIGHT.rotated(-0.25)})
		var area := Factory.create_area_effect(params) as AreaEffect
		check(area!=null and area.get_node_or_null("AreaVisualEffect")!=null,"canonical area attaches shader "+area_ids[i])
		owned.append(area)
		if i==0:
			area.apply_immediate_tick_once()
			check(enemy.current_health<10000,"visible fire area applies real typed health damage")
		hold_area(area,0.7)
	await capture("fire_ground_and_lava")
	for area: Node2D in owned: await verify_pixels(area.get_node("AreaVisualEffect"),"fire field "+String(area.source_id))
	for item: Node2D in owned: item.prepare_for_pool_despawn()
	owned.clear()
	# Actual cast rules create the moving vortex and managed dragon.
	var target := enemy_at(Vector2(180,0))
	for id: StringName in [&"fire_cast_scorching_vortex",&"fire_summon_crimson_dragon"]:
		bus.emit_skill_event(&"on_cast",{"caster":player,"owner":player,"parent":parent,"target":target,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(id),"skill_id":id,"origin_skill_id":id,"scheduled_cast":true,"power":float(player.attack_power)})
	var vortex: AreaEffect
	for area: Node in get_nodes_in_group(&"area_effects"):
		if area is AreaEffect and area.source_id==&"scorching_vortex" and area.visible: vortex=area
	check(vortex!=null,"actual vortex cast creates effect")
	if vortex != null:
		hold_area(vortex,0.9)
		vortex.global_position=player.global_position+Vector2(150,30)
	target.apply_status(&"burning",{"stacks":4,"duration":4.0,"source":player})
	await settle()
	var status: Node = target.get_node("StatusEffectManager")
	var flames: Node2D = status._status_visual_overlay.get_node("ProceduralStatus")
	flames.process_mode=Node.PROCESS_MODE_PAUSABLE
	flames._process(0.4)
	var summon_manager: Node = player.get_node("SummonManager")
	var dragon: Node2D = summon_manager._active_by_id[&"crimson_dragon"][0]
	dragon.global_position=player.global_position+Vector2(-180,-20)
	dragon._physics_process(0.05)
	dragon._summon_effect.update_summon(0.12,Vector2.ZERO,100.0)
	dragon.set_physics_process(false)
	var executor := preload("res://scripts/skills/skill_action_executor.gd").new()
	var context := {"caster":player,"owner":player,"target":player,"event_bus":bus,"skill_manager":manager,"skill_id":&"fire_passive_overheated_casting","skill_instance":manager.get_skill(&"fire_passive_overheated_casting")}
	bus.emit_skill_event(&"on_player_damaged",context)
	view._process(0.11)
	view._heat._process(0.2)
	await capture("fire_vortex_dragon_and_burning")
	await verify_pixels(vortex.get_node("AreaVisualEffect"),"moving vortex hot column")
	check(vortex._visual_effect_node.effect_style=="scorching_vortex" and vortex._visual_effect_node._column.visible,"actual moving cast selects elevated vortex profile")
	await verify_pixels(vortex._visual_effect_node._column,"elevated vortex is visibly distinct from its ground")
	await verify_pixels(flames,"four actual burning layers")
	await verify_pixels(dragon._summon_effect,"managed dragon")
	await verify_pixels(view._heat,"actual overheat aura")
	vortex.prepare_for_pool_despawn()
	view._heat.deactivate()
	flames.deactivate()
	dragon.visible=false
	for i: int in 4:
		var id: String = ["fireball_projectile","meteor_rain_meteor","inferno_cycle_meteor","ember_attachment_bolt"][i]
		var projectile := Factory.create_projectile({"parent":parent,"projectile_id":id,"source_id":id,"position":player.global_position+Vector2(-180+i*120,20),"direction":Vector2(0.8,0.6),"speed":680.0,"lifetime":3.0}) as Projectile
		check(projectile._visual_effect_node!=null,"canonical projectile attaches fire "+id)
		projectile.set_physics_process(false)
		projectile._visual_effect_node.update_projectile(0.3)
		owned.append(projectile)
	var burst: Node2D = view.play_burst(player.global_position+Vector2(180,120),117.6,"inferno")
	burst._process(0.16)
	burst.set_process(false)
	await capture("fire_projectiles_and_inferno")
	for item: Node2D in owned: await verify_pixels(item._visual_effect_node,"fire projectile "+String(item.source_id))
	await verify_pixels(burst,"inferno death explosion")
	# Clock and pixels must remain stable through a true engine pause.
	paused=true
	await settle(4)
	await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	await create_timer(0.2,true).timeout
	await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image()
	check(before.get_data()==after.get_data(),"fire pixels stop exactly through engine pause")
	await finish()
