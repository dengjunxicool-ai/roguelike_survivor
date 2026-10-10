## 四图实际配置/背景/投放与奖励事件渲染；合成无敌受击体，不计真人试玩。
extends "res://tools/verify/capture_monster_stage_b.gd"
func prepare_world() -> void:
	world=Node2D.new()
	root.add_child(world)
	player=Receiver.new()
	player.add_to_group("player")
	player.collision_layer=2
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=24
	collider.shape=circle
	player.add_child(collider)
	world.add_child(player)
	player.position=center+Vector2(180,0)
	camera=Camera2D.new()
	world.add_child(camera)
	camera.position=center
	camera.force_update_scroll()
	var layer := CanvasLayer.new()
	world.add_child(layer)
	label=Label.new()
	label.position=Vector2(24,20)
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
func run() -> void:
	environment=RunEnvironment.initialize("E:/codex/monster-system/stage-c-render")
	if environment.is_empty() or DisplayServer.get_name()=="headless":
		quit(1)
		return
	if not await RunEnvironment.configure_rendered_viewport():
		quit(1)
		return
	root.set_meta("debug_manual_spawn_only",true)
	dimensions=Vector2i(1280,720)
	center=Vector2(640,360)
	for map_id: String in ["abandoned_dungeon","toxic_fog_graveyard","lava_temple","abyss_corridor"]:
		prepare_world()
		var map: Dictionary=GameData.get_map(map_id)
		var background := ResponsiveBackground.new()
		background.name="DungeonBackground"
		background.z_index=-10
		world.add_child(background)
		preload("res://scripts/maps/map_runtime.gd").apply_background(self,map)
		var spawner := EnemySpawner.new()
		world.add_child(spawner)
		spawner.get("_rng").seed=618
		var map_runtime := MapVariableRuntime.new()
		world.add_child(map_runtime)
		map_runtime.setup(map)
		map_runtime.set("_hazard_timer",0.0)
		map_runtime.get("_rng").seed=619
		var frames: Array=[]
		var actual_elites: Array=[]
		for index in [3,5]:
			spawner.call("_start_wave",index)
			spawner.set("_wave_elapsed_time",5.0)
			spawner.call("_process_wave_events",spawner.call("_get_wave_at_index",index))
			actual_elites.append(spawner.call("_get_wave_at_index",index).events[0].enemy_id)
			for id: String in ["archer_skeleton","skeleton_priest","war_drum_goblin"]:
				spawner.call("spawn_enemy",EnemySpawnRequest.create(id,{"source_type":"wave"}))
			label.text="Stage C | %s | wave %d\nActual encounter / real rendering / automated invulnerable receiver"%[map_id,index+1]
			for delay in [0.3,0.65,1.0,1.5]:
				await create_timer(delay).timeout
				var path: String=environment.report_dir.path_join("%s_wave%d_%d.png"%[map_id,index+1,frames.size()])
				await capture(path)
				frames.append(path)
		spawner.call("_start_wave",2)
		spawner.set("_wave_elapsed_time",5.0)
		var director: RefCounted=spawner.get("_reward_event_director")
		var rng: RandomNumberGenerator=director.get("_treasure_roll_rng")
		for candidate in range(100):
			rng.seed=candidate
			if rng.randf()<0.35:
				rng.seed=candidate
				break
		director.set("_treasure_seeded",true)
		spawner.call("_process_reward_events")
		await create_timer(1.7).timeout
		label.text="Stage C | %s | treasure event\nForced successful draw for visual sample / twelve-second escape"%map_id
		await capture(environment.report_dir.path_join(map_id+"_treasure.png"))
		samples.append({"map":map_id,"elite_ids":actual_elites,"preview":preload("res://scripts/maps/map_encounter_resolver.gd").get_elite_preview_ids(map),"frames":frames,"treasure":director.call("get_treasure_snapshot")})
		world.queue_free()
		await process_frame
	var report := FileAccess.open(environment.report_dir.path_join("samples.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"viewport":dimensions,"mode":"real OpenGL; actual four-map configs and backgrounds, synthetic automated receiver; treasure draw forced for visual sample","samples":samples},"\t"))
	report.close()
	RunEnvironment.cleanup_save(environment)
	quit(1 if failed else 0)
