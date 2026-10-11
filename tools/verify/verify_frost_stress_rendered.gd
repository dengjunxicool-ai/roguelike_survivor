## 运行中的多区域、循环弹体与真实敌人命中采样；报告只写 E 盘。
extends "res://tools/verify/qa_app_fixture.gd"
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var report_dir := "E:/codex/frost-vfx/stress"
var live_areas: Array[AreaEffect] = []
var peak_projectiles := 0
var bus: Node

func run() -> void:
	check(DisplayServer.get_name()!="headless","requires actual GPU")
	if failures: quit(1); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): report_dir=arg.trim_prefix("--capture-dir=").replace("\\","/").simplify_path()
	check(report_dir.begins_with("E:/codex/"),"E drive output only")
	if failures: quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	var parent: Node = player.get_parent()
	bus = player.get_node("SkillEventBus")
	bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	bus.get_node("FrostCombatPresentation").process_mode = Node.PROCESS_MODE_PAUSABLE
	var enemies: Array[Node2D] = []
	for i: int in 16:
		var enemy: Node2D = EnemyScene.instantiate()
		enemy.enemy_id = &"skeleton"
		parent.add_child(enemy)
		enemy.global_position = player.global_position + Vector2.from_angle(float(i)*TAU/16.0)*210.0
		enemy.max_health = 10000
		enemy.current_health = 10000
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(enemy)
	for i: int in 8:
		var id := "frost_field" if i%2==0 else "frost_path"
		var area: AreaEffect = Factory.create_area_effect({"parent":parent,"area_id":id,"source_id":id,"position":player.global_position+Vector2.from_angle(float(i)*TAU/8)*170,"radius":134.4,"duration":9.0,"tick_interval":0.5,"damage":4,"damage_type":"area_direct","damage_packet":{"element":"ice","attacker":player},"caster":player,"event_bus":bus,"skill_manager":manager,"status_on_hit":&"chilled","status_params":{"stacks":1,"duration":4.0}}) as AreaEffect
		area.process_mode = Node.PROCESS_MODE_PAUSABLE
		live_areas.append(area)
	var frames: Array[float] = []
	var end := Time.get_ticks_usec()+4000000
	var last := Time.get_ticks_usec()
	var burst_at := last
	var spawns := 0
	var spawn_times: Array[float] = []
	while Time.get_ticks_usec()<end:
		var now := Time.get_ticks_usec()
		if now>=burst_at:
			var burst_start := Time.get_ticks_usec()
			burst_at=now+250000
			for i: int in 8:
				var angle := float(i)*TAU/8+float(spawns)*0.015
				var id := "glacial_lance_projectile" if i%3==0 else ("ice_shard_projectile" if i%3==1 else "ice_crack_shard")
				var projectile: Projectile = Factory.create_projectile({"parent":parent,"projectile_id":id,"position":player.global_position,"direction":Vector2.from_angle(angle),"speed":300.0,"lifetime":1.6,"pierce":2,"damage":3,"damage_type":"projectile_small","damage_packet":{"element":"ice","attacker":player},"caster":player,"event_bus":bus,"skill_manager":manager,"status_on_hit":&"chilled","status_params":{"stacks":1,"duration":4.0}}) as Projectile
				projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
				spawns+=1
			var active := 0
			for child: Node in parent.get_children():
				if child is Projectile and child.visible: active+=1
			peak_projectiles=maxi(peak_projectiles,active)
			spawn_times.append(float(Time.get_ticks_usec()-burst_start)/1000.0)
		await process_frame
		now = Time.get_ticks_usec()
		frames.append(float(now-last)/1000.0)
		last = now
	frames.sort()
	spawn_times.sort()
	var slow_frames := 0
	for frame: float in frames:
		if frame > 16.67: slow_frames += 1
	var damaged := 0
	for enemy: Node2D in enemies:
		if enemy.current_health<10000: damaged+=1
	check(damaged>0,"running workload includes actual enemy damage")
	check(peak_projectiles>=24,"running workload includes concurrent moving projectiles")
	var presentation: Node2D = bus.get_node("FrostCombatPresentation")
	check(presentation._hits.size()>0 and presentation._hits.size()<=32,"confirmed ice damage uses bounded feedback pool")
	check(live_areas[0]._age>3.0 and live_areas[0]._age<live_areas[0].duration,"area clocks run during sample")
	await capture("frost_live_pressure")
	var report := {"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(root.size),"live_areas":8,"area_particles":288,"target_count":16,"projectiles_spawned":spawns,"peak_live_projectiles":peak_projectiles,"targets_damaged":damaged,"hit_pool_nodes":presentation._hits.size(),"sample_seconds":4,"frames":frames.size(),"frames_over_16_ms":slow_frames,"spawn_p95_ms":spawn_times[mini(int(spawn_times.size()*0.95),spawn_times.size()-1)],"p50_ms":frames[int(frames.size()*0.5)],"p95_ms":frames[mini(int(frames.size()*0.95),frames.size()-1)],"failures":failures}
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file := FileAccess.open(report_dir.path_join("stress_metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	await finish()
