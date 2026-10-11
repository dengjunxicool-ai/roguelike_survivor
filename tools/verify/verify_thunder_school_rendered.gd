## 实际工厂、真实敌人和 GPU 截图；所有输出保存在 E:/codex。
extends "res://tools/verify/qa_app_fixture.gd"
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
var owned: Array[Node2D] = []
func enemy_at(offset: Vector2) -> Node2D:
	var enemy: Node2D=Enemy.instantiate()
	enemy.enemy_id=&"skeleton"
	player.get_parent().add_child(enemy)
	enemy.process_mode=Node.PROCESS_MODE_DISABLED
	enemy.global_position=player.global_position+offset
	enemy.max_health=10000
	enemy.current_health=10000
	enemy.armor=0
	return enemy
func verify_pixels(node: CanvasItem, label: String) -> void:
	paused=true
	await settle(4)
	await RenderingServer.frame_post_draw
	var shown:=root.get_texture().get_image()
	node.visible=false
	await settle(3)
	await RenderingServer.frame_post_draw
	var hidden:=root.get_texture().get_image()
	var changed:=0
	for y: int in range(0,shown.get_height(),3):
		for x: int in range(0,shown.get_width(),3):
			var a:=shown.get_pixel(x,y)
			var b:=hidden.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.025: changed+=1
	check(changed>12,label+" produces real visible pixels (%d)"%changed)
	node.visible=true
	paused=false
func run() -> void:
	await setup_run()
	check(DisplayServer.get_name()!="headless","rendered verification uses GPU")
	var count:=0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school",""))=="thunder" and String(definition.id).begins_with("thunder_") and definition.get("fusion_school")==null:
			check(Fixture.install_runtime_skill(manager,StringName(definition.id)),"learn "+String(definition.id))
			count+=1
	check(count==14,"all fourteen base thunder skills installed")
	var parent: Node=player.get_parent()
	var bus: Node=player.get_node("SkillEventBus")
	var view: Node=bus.get_node("ThunderCombatPresentation")
	view.process_mode=Node.PROCESS_MODE_PAUSABLE
	var ids: Array[String]=["thunderstorm_cloud","ball_lightning_orb","lightning_strike_area","emp_ring","overload_burst","magnetic_pull_field","ball_lightning_path"]
	var radii: Array[float]=[218.4,96.6,67.2,235.2,151.2,100.8,67.2]
	for start: int in [0,3]:
		var end:=3 if start==0 else ids.size()
		for i: int in range(start,end):
			var offset:=Vector2(-250+(i-start)%2*470,-110+(i-start)/2*220)
			var id:=ids[i]
			var area:=Factory.create_area_effect({"parent":parent,"area_id":id,"source_id":id,"position":player.global_position+offset,"radius":radii[i],"duration":4.0 if i<2 else 0.3,"damage":20,"caster":player,"event_bus":bus,"skill_manager":manager,"damage_packet":{"raw_amount":20,"amount":20,"damage_origin":"field","damage_type":"area_direct","element":"lightning","attacker":player,"source_skill_id":"thunder_cast_storm_circle","source_id":id,"source_instance_id":"thunder_render_%d"%i}}) as AreaEffect
			check(area!=null and area._visual_effect_node!=null,"canonical procedural area "+id)
			if area==null or area._visual_effect_node==null: continue
			area.process_mode=Node.PROCESS_MODE_PAUSABLE
			area.set_physics_process(false)
			area._age=0.8 if i<2 else 0.055
			area._visual_effect_node.update_state(area.radius,area._age,area.duration)
			owned.append(area)
		await capture("thunder_fields_%d"%start)
		for item: Node2D in owned: await verify_pixels(item._visual_effect_node,String(item.source_id))
		for item: Node2D in owned: item.prepare_for_pool_despawn()
		owned.clear()
	var target:=enemy_at(Vector2(180,-30))
	var next:=enemy_at(Vector2(300,45))
	var executor:=preload("res://scripts/skills/skill_action_executor.gd").new()
	var context: Dictionary={"caster":player,"owner":player,"source":player,"parent":parent,"target":target,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(&"thunder_cast_chain_lightning"),"skill_id":&"thunder_cast_chain_lightning","source_origin_id":&"thunder_cast_chain_lightning","power":float(player.attack_power)}
	executor.execute_action({"type":"chain_to_targets","params":{"radius":250.0,"count":1,"actions":[{"type":"deal_damage","params":{"amount":20,"damage_type":"thunder"}},{"type":"apply_status","params":{"status":"conductive","stacks":2,"duration":5.0}}]}},context)
	check(next.current_health<10000,"canonical chain damages a real next enemy")
	check(not view._arcs.is_empty(),"successful canonical chain creates actual endpoint arc")
	for arc: Node2D in view._arcs: arc.set_process(false)
	target.apply_status(&"conductive",{"stacks":4,"duration":5.0,"source":player})
	await settle()
	var status: Node=target.get_node("StatusEffectManager")
	var mantle: Node2D=status._status_visual_overlay.get_node("ProceduralStatus")
	mantle.process_mode=Node.PROCESS_MODE_PAUSABLE
	mantle._process(0.3)
	for id: StringName in [&"thunder_summon_storm_lynx",&"thunder_summon_storm_crow"]:
		bus.emit_skill_event(&"on_cast",{"caster":player,"owner":player,"parent":parent,"target":target,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(id),"skill_id":id,"origin_skill_id":id,"scheduled_cast":true,"power":float(player.attack_power)})
	var sm: Node=player.get_node("SummonManager")
	for i: int in 2:
		var summon: Node2D=sm._active_by_id[&"storm_lynx" if i==0 else &"storm_crow"][0]
		summon.global_position=player.global_position+Vector2(-180+i*100,-30)
		summon.set_physics_process(false)
		summon._summon_effect.update_summon(0.22,Vector2(80,0),10.0)
		owned.append(summon)
	# Eighteen genuine first generation hits trigger the real temporary modifier.
	var packet_script:=preload("res://scripts/combat/damage_packet.gd")
	for i: int in 18:
		target.take_damage(packet_script.from_dictionary({"raw_amount":1,"amount":1,"damage_origin":"primary_attack","damage_type":"direct_magical","element":"lightning","attacker":player,"source_skill_id":"thunder_attack_thundering","source_origin_id":"thunder_attack_thundering","source_instance_id":"thunder_charge_%d"%i}))
	view._process(0.11)
	check(view._charge!=null and view._charge.visible,"actual eighteen-hit static charge buff shows aura")
	check(view._core!=null and view._core.visible,"actual storm energy counter shows partial charge")
	for hit: Node2D in view._hits: hit.set_process(false)
	for arc: Node2D in view._arcs: arc.set_process(false)
	await capture("thunder_summons_conductive_and_charge")
	await verify_pixels(mantle,"four actual conductive stacks")
	for summon: Node2D in owned: await verify_pixels(summon._summon_effect,"managed "+String(summon.definition.id))
	if view._charge!=null: await verify_pixels(view._charge,"real static charge aura")
	if view._core!=null: await verify_pixels(view._core,"real storm energy aura")
	var crow: Node2D=sm._active_by_id[&"storm_crow"][0]
	crow._attack.tick(3.0)
	check(crow._attack.attack(crow,target,float(player.attack_power),crow._context),"actual crow attack launches target mark")
	var bolt: Projectile
	for projectile: Node in get_nodes_in_group(&"player_projectiles"):
		if projectile is Projectile and projectile.source_id==&"thunder_arc_bolt" and projectile.visible: bolt=projectile
	# Projectile registration may use a shared group; look through actual world descendants.
	if bolt==null:
		for projectile: Node in parent.get_children():
			if projectile is Projectile and projectile.source_id==&"thunder_arc_bolt" and projectile.visible: bolt=projectile
	check(bolt!=null,"crow creates actual managed projectile")
	if bolt!=null:
		bolt.set_physics_process(false)
		view._process(0.01)
		await capture("thunder_crow_target_mark")
		for marker: Node2D in view._markers:
			if marker.visible: await verify_pixels(marker,"actual crow flight target mark")
		bolt._on_body_entered(target)
		view._process(0.01)
		var sky_hit: Node2D
		for hit: Node2D in view._hits:
			if hit.visible and hit._strike!=null and hit._strike.visible: sky_hit=hit
		check(sky_hit!=null,"real crow hit confirms sky strike")
		if sky_hit!=null:
			sky_hit._process(0.045)
			sky_hit.set_process(false)
			await capture("thunder_crow_confirmed_strike")
			await verify_pixels(sky_hit._strike,"actual crow confirmed lightning column")
	for arc: Node2D in view._arcs: arc.deactivate()
	for summon: Node2D in owned: summon.visible=false
	owned.clear()
	for i: int in 3:
		var id: String=["lightning_orb_projectile","chain_lightning_bolt","thunder_arc_bolt"][i]
		var projectile:=Factory.create_projectile({"parent":parent,"projectile_id":id,"source_id":id,"position":player.global_position+Vector2(-220+i*200,110),"direction":Vector2(0.8,-0.6),"speed":900.0,"lifetime":3.0}) as Projectile
		check(projectile._visual_effect_node!=null,"canonical projectile "+id)
		projectile.set_physics_process(false)
		projectile._visual_effect_node.update_projectile(0.25)
		owned.append(projectile)
	await capture("thunder_projectiles")
	for item: Node2D in owned: await verify_pixels(item._visual_effect_node,String(item.source_id))
	paused=true
	await settle(4)
	await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	await create_timer(0.2,true).timeout
	await RenderingServer.frame_post_draw
	check(before.get_data()==root.get_texture().get_image().get_data(),"thunder pixels freeze exactly during engine pause")
	await finish()
