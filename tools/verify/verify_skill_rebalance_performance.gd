## Shared T0/M4 rendered stress protocol; survival assistance is explicit and never balance evidence.
extends SceneTree
const IDs: Array[String] = ["fire_attack_searing","fire_dash_blazing_run","fire_cast_meteor_rain","fire_cast_lava_rift","fire_cast_scorching_vortex","holy_cast_holy_ray","holy_cast_divine_barrier","fire_passive_burning_focus","fire_passive_scorched_ground_affinity","holy_passive_sanctuary","fire_core_inferno_cycle","fusion_fire_holy_burning_light_barrier"]
func _init() -> void: call_deferred("run")
func run() -> void:
	for id: String in IDs:
		if GameData.get_skill(id).is_empty(): push_error("Missing stress skill "+id); quit(1); return
	if not OS.get_cmdline_user_args().has("--execute"):
		print("[verify_skill_rebalance_performance] PASS protocol inventory only; no performance acceptance")
		quit(0)
		return
	var output: String = OS.get_environment("APPDATA").get_base_dir()+"/data"
	DirAccess.make_dir_recursive_absolute(output)
	if not ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with("e:/codex/"): quit(1); return
	root.size=Vector2i(1280,720)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(618)
	var scene: Node = load("res://scenes/app/app_bootstrap.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var ui: Node = scene.get_node("UIManager")
	ui.transition_to("TITLE")
	await process_frame
	ui.transition_to("CHARACTER_SELECT")
	await process_frame
	ui.get("_character_loadout_controller").refresh(&"mage")
	await process_frame
	ui._on_loadout_confirmed(&"mage")
	await process_frame
	await ui._start_run(&"abandoned_dungeon")
	var player: Node2D = get_first_node_in_group(&"player")
	var manager: Node = player.get_node("SkillManager")
	manager.clear_skills()
	var definition_script: Script = load("res://scripts/skills/skill_definition.gd")
	var instance_script: Script = load("res://scripts/skills/skill_instance.gd")
	for id: String in IDs:
		var data: Dictionary = GameData.get_skill(id).duplicate(true)
		if data.skill_type == "attack":
			for key: String in ["base","components","events","damage_scaling","runtime_family","particle"]:
				if not data.has(key) or data[key] == null or (data[key] is Dictionary or data[key] is Array) and data[key].is_empty(): data[key]=GameData.get_starting_skill_pool()[0].get(key)
		var instance: RefCounted = instance_script.new(definition_script.new(data))
		instance.current_level=3
		instance.current_rarity="normal"
		if data.skill_type == "passive": manager.passive_skills[StringName(id)]=instance
		else: manager.active_skills[StringName(id)]=instance
		manager._refresh_skill_modifier_payload(instance)
	assert(manager.get_all_skills().size()==12)
	var world: Node = ui.get("_run_scene_coordinator").get_run_scene_parent(self)
	var spawners: Array[Node] = get_nodes_in_group(&"enemy_spawner")
	for spawner: Node in spawners:
		spawner.set_physics_process(false)
		spawner.get("_rng").seed=619
	for enemy: Node in get_nodes_in_group(&"enemy"): enemy.queue_free()
	await process_frame
	var rows: Array = []
	for phase: String in ["fixed_24","actual_waves_60s"]:
		for enemy: Node in get_nodes_in_group(&"enemy"): enemy.queue_free()
		await process_frame
		if phase=="actual_waves_60s":
			for spawner: Node in spawners:
				spawner.reset_for_run()
				spawner.get("_rng").seed=619
				spawner.set_physics_process(true)
		var frames: Array[float] = []
		var node_series: Array = []
		var last_usec: int = Time.get_ticks_usec()
		var peak: int = 0
		var enemy_peak: int = 0
		var queue_peak: int = 0
		var phase_start: int = Time.get_ticks_msec()
		var duration_ms: int = 12000 if phase=="fixed_24" else 62000
		var i: int = 0
		var node_at: int = phase_start
		while Time.get_ticks_msec()-phase_start < duration_ms:
			await process_frame
			i += 1
			player.current_health=player.max_health
			if ui.current_state != "RUNNING":
				if str(ui.current_state).begins_with("RESULT_"): push_error("Stress terminated early");quit(1);return
				ui.get("_run_choice_modal_controller").pending_level_up_count=0
				ui.get("_run_choice_modal_controller").pending_reward_kinds.clear()
				ui.transition_to("RUNNING")
				paused=false
			if phase=="fixed_24":
				for j: int in maxi(24-get_nodes_in_group(&"enemy").size(),0):
					var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
					enemy.enemy_id=&"small_slime"
					enemy.position=player.position+Vector2(180,0).rotated(float(j+i)*.618*TAU)
					world.add_child(enemy)
			var now: int = Time.get_ticks_usec()
			if Time.get_ticks_msec()-phase_start>=2000: frames.append(float(now-last_usec)/1000.0)
			last_usec=now
			peak=maxi(peak,get_node_count())
			enemy_peak=maxi(enemy_peak,get_nodes_in_group(&"enemy").size())
			var pending: Variant = player.get_node("SkillEventBus").get("_pending_events")
			if pending is Array: queue_peak=maxi(queue_peak,pending.size())
			if Time.get_ticks_msec()>=node_at:
				node_series.append(get_node_count())
				node_at += 1000
		frames.sort()
		rows.append({"phase":phase,"frame_p95":frames[ceili(frames.size()*.95)-1],"samples":frames.size(),"node_peak":peak,"enemy_peak":enemy_peak,"pending_peak":queue_peak,"node_series":node_series})
		print("PERF "+JSON.stringify(rows[-1]))
	var file: FileAccess = FileAccess.open(output+"/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"protocol":"1280x720 rendered/mobile/no-vsync; 2s wall-clock warmup; process_frame wall intervals; fixed24 replenished + actual unmodified 60s wave timeline","skills":IDs,"rarity":"normal","levels":3,"seed":618,"meta_state":"fresh","survival_assist":true,"balance_evidence":false,"enemy_stats_changed":false,"rows":rows},"  "))
	file.close()
	paused=false
	ui.get("_run_scene_coordinator").teardown(self)
	scene.queue_free()
	await process_frame
	quit(0)
