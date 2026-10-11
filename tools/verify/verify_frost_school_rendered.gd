## 在真实游戏场景内验收寒霜材质、实际施放、状态、反馈、暂停与同屏预算。
extends "res://tools/verify/qa_app_fixture.gd"
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var report_dir := "E:/codex/frost-vfx/rendered"
var bus: Node
var parent: Node
var enemies: Array[Node2D] = []
var owned: Array[Node2D] = []

func cast(id: StringName, target: Node2D) -> void:
	var skill: RefCounted = manager.get_skill(id)
	bus.emit_skill_event(&"on_cast", {"caster":player,"owner":player,"skill_manager":manager,"skill_instance":skill,"target":target,"skill_id":id,"origin_skill_id":id,"scheduled_cast":true,"parent":parent,"power":float(player.attack_power)})

func find_area(id: String) -> AreaEffect:
	for node: Node in get_nodes_in_group(&"area_effects"):
		if node is AreaEffect and String(node.source_id) == id and node.visible:
			return node
	return null

func hold_area(area: AreaEffect, age: float) -> void:
	area.process_mode = Node.PROCESS_MODE_PAUSABLE
	area.set_physics_process(false)
	area._age = age
	area.get_node("AreaVisualEffect").update_state(area.radius,age,area.duration)

func sample(seconds: float) -> Dictionary:
	var frames: Array[float] = []
	var end := Time.get_ticks_usec()+int(seconds*1000000)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-last)/1000.0)
		last = now
	frames.sort()
	return {"frames":frames.size(),"p50_ms":frames[int(frames.size()*0.5)],"p95_ms":frames[mini(int(frames.size()*0.95),frames.size()-1)]}

func verify_pixels(node: CanvasItem, name: String) -> void:
	paused = true
	await settle(5)
	await RenderingServer.frame_post_draw
	var shown := root.get_texture().get_image()
	node.visible = false
	await settle(3)
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	var changed := 0
	for y: int in range(0,shown.get_height(),2):
		for x: int in range(0,shown.get_width(),2):
			var a := shown.get_pixel(x,y)
			var b := hidden.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.025:
				changed += 1
	check(changed>15,name+" visibly changes actual pixels (%d)" % changed)
	node.visible = true
	paused = false

func run() -> void:
	check(DisplayServer.get_name()!="headless","requires GPU rendering")
	if failures: quit(1); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): report_dir=arg.trim_prefix("--capture-dir=").replace("\\","/").simplify_path()
	check(report_dir.begins_with("E:/codex/"),"all output remains on E drive")
	if failures: quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	parent = player.get_parent()
	bus = player.get_node("SkillEventBus")
	bus.get_node("FrostCombatPresentation").process_mode = Node.PROCESS_MODE_PAUSABLE
	var skills: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/skills.json"))
	var learned := 0
	for definition: Dictionary in skills.skills:
		if definition.school == "frost" and definition.get("fusion_school")==null:
			check(Fixture.install_runtime_skill(manager,StringName(definition.id)),"install "+definition.id)
			learned += 1
	check(learned==14,"all 14 frost skills installed")
	for i: int in 6:
		var enemy: Node2D = EnemyScene.instantiate()
		enemy.enemy_id = &"skeleton"
		parent.add_child(enemy)
		enemy.global_position = player.global_position+Vector2(150+(i%3)*110,-100+(i/3)*170)
		enemy.max_health = 10000
		enemy.current_health = 10000
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(enemy)
	await settle(3)
	var baseline := await sample(0.6)
	cast(&"frost_cast_frost_field",enemies[0])
	await settle(5)
	var field := find_area("frost_field")
	check(field!=null,"actual frost field cast mounts presentation")
	if field==null: await finish(); return
	hold_area(field,0.6)
	check(field.duration>3.0,"chill extension prolongs real field")
	cast(&"frost_summon_frost_wolf",enemies[0])
	cast(&"frost_summon_ice_crystal_guard",enemies[1])
	await settle(5)
	var summons := 0
	for node: Node in parent.get_children():
		if node is SummonController and node.get_node_or_null("SummonEffect")!=null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
			node.set_physics_process(false)
			node.global_position = player.global_position+Vector2(-120 if summons==0 else -230,-30)
			node.get_node("SummonEffect").update_summon(0.3,Vector2(80,0) if summons==0 else Vector2.ZERO,8.0)
			summons += 1
	check(summons==2,"actual summon casts show both procedural forms")
	for enemy: Node2D in enemies:
		enemy.apply_status(&"chilled",{"stacks":3,"duration":8.0,"caster":player,"event_bus":bus,"skill_manager":manager})
	enemies[1].apply_status(&"frozen",{"duration":1.2,"caster":player,"event_bus":bus,"skill_manager":manager})
	await settle(5)
	await capture("frost_field_and_summons")
	await verify_pixels(field.get_node("AreaVisualEffect"),"frost field material")
	var prison: Node2D = enemies[1].get_node("StatusVisualOverlay")
	await verify_pixels(prison,"frozen prison")
	# Create derived areas through their production factory; their combat remains disabled for stable comparison.
	var path: AreaEffect = Factory.create_area_effect({"parent":parent,"area_id":"frost_path","position":player.global_position+Vector2(-150,170),"radius":92.4,"duration":4.0}) as AreaEffect
	hold_area(path,0.5)
	var ring: AreaEffect = Factory.create_area_effect({"parent":parent,"area_id":"frost_ring","position":player.global_position+Vector2(165,180),"radius":151.2,"duration":0.28}) as AreaEffect
	hold_area(ring,0.085)
	var shatter: AreaEffect = Factory.create_area_effect({"parent":parent,"area_id":"shatter_splash","position":player.global_position+Vector2(370,175),"radius":100.8,"duration":0.18}) as AreaEffect
	hold_area(shatter,0.05)
	for id: String in ["ice_shard_projectile","glacial_lance_projectile","ice_crack_shard"]:
		var projectile: Projectile = Factory.create_projectile({"parent":parent,"projectile_id":id,"position":player.global_position+Vector2(-190,90+owned.size()*38),"direction":Vector2.RIGHT,"speed":680,"lifetime":3.0}) as Projectile
		projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
		projectile.set_physics_process(false)
		projectile._visual_effect_node.update_projectile(0.3)
		owned.append(projectile)
	await settle(4)
	await capture("frost_projectiles_and_bursts")
	await verify_pixels(ring.get_node("AreaVisualEffect"),"short frost counter ring")
	await verify_pixels(shatter.get_node("AreaVisualEffect"),"short shatter")
	for item: Node2D in owned:
		await verify_pixels(item._visual_effect_node,"projectile "+String(item._visual_style))
	# Real grant action: the event and actual shared pool drive the shield.
	var executor := preload("res://scripts/skills/skill_action_executor.gd").new()
	var shield_context := {"caster":player,"owner":player,"event_bus":bus,"skill_manager":manager,"skill_id":&"frost_power_ice_mist_guard","origin_skill_id":&"frost_power_ice_mist_guard","power":float(player.attack_power)}
	for i: int in 3:
		executor.execute_action({"type":"grant_shield","params":{"shield_type":"ice_mist","amount":20.0,"duration":8.0}},shield_context)
	var presentation: Node2D = bus.get_node("FrostCombatPresentation")
	check(presentation.get_node_or_null("IceMistShield")!=null,"real grant action attaches ice mist")
	presentation._refresh_shield()
	check(presentation._shield.shield_layers==3,"three confirmed shield grants show three layers")
	var hit: Node2D = presentation.play_hit(enemies[2].global_position+Vector2(0,-20),2)
	hit._process(0.1)
	hit.set_process(false)
	await capture("frost_shield_and_shatter")
	await verify_pixels(presentation._shield,"layered ice mist")
	var zero: AreaEffect = Factory.create_area_effect({"parent":parent,"area_id":"absolute_zero_field","position":player.global_position,"radius":1200.0,"duration":0.2}) as AreaEffect
	hold_area(zero,0.025)
	await capture("frost_absolute_zero")
	await verify_pixels(zero.get_node("AreaVisualEffect"),"absolute zero cold front")
	zero.prepare_for_pool_despawn()
	paused = true
	await settle(5)
	var ages := [field.get_node("AreaVisualEffect").effect_age,presentation._shield.visual_age]
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	await create_timer(0.2,true).timeout
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var changed := 0
	for y: int in range(0,before.get_height(),2):
		for x: int in range(0,before.get_width(),2):
			if before.get_pixel(x,y)!=after.get_pixel(x,y): changed+=1
	check(changed==0,"pause preserves all rendered pixels (%d changed)" % changed)
	check(ages==[field.get_node("AreaVisualEffect").effect_age,presentation._shield.visual_age],"pause preserves all visual clocks")
	paused = false
	var pressure := await sample(2.0)
	DirAccess.make_dir_recursive_absolute(report_dir)
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"baseline":baseline,"mixed_frost":pressure,"hit_pool_limit":32,"field_gpu_particles":48,"path_gpu_particles":24,"wolf_gpu_particles":18,"guard_gpu_particles":24,"failures":failures}
	var file := FileAccess.open(report_dir.path_join("rendered_metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	await finish()
