extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("run")
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		push_error("[WaveEvents] "+message)
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.set_meta("debug_manual_spawn_only",true)
	var world := Node2D.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var player := Node2D.new()
	player.add_to_group("player")
	player.position=Vector2(960,540)
	world.add_child(player)
	var spawner := EnemySpawner.new()
	world.add_child(spawner)
	spawner.call("_start_wave",3)
	spawner.set("_wave_spawned_count",spawner.get("_wave_total_count"))
	spawner.call("_process_discrete_wave",0.1)
	expect(float(spawner.get("_wave_transition_timer"))==0.0,"future mandatory elite prevents premature clear")
	spawner.set("_wave_elapsed_time",5.0)
	var wave: Dictionary = spawner.call("_get_wave_at_index",3)
	spawner.call("_process_wave_events",wave)
	spawner.call("_process_wave_events",wave)
	var elites := 0
	for enemy: Node in get_nodes_in_group("enemies"):
		if String(enemy.get_meta("spawn_source_type",""))=="elite_event": elites+=1
	expect(elites==1,"elite event executes once after normal budget is exhausted")
	expect(spawner.get("_wave_spawned_count")==spawner.get("_wave_total_count"),"elite event uses independent budget")
	var sixth: Dictionary = spawner.call("_get_wave_at_index",5)
	expect(sixth.get("events",[]).any(func(event): return event.type=="spawn_elite"),"wave six includes mandatory second elite")
	for enemy: Node in get_nodes_in_group("enemies"): enemy.queue_free()
	await process_frame
	spawner.call("_start_wave",7)
	var blessings: Array = []
	spawner.timeline_event_started.connect(func(id: String,_text: String):
		if id=="final_blessing:builtin": blessings.append(id))
	spawner.call("_finish_normal_phase")
	spawner.call("_process_reward_events")
	spawner.call("_process_reward_events")
	expect(blessings.size()==1,"Boss prepare triggers final blessing once even before 220 seconds")
	spawner.call("_start_wave",3)
	spawner.call("_spawn_batch_from_source",{"groups":[{"role":"ranged","enemy_ids":["archer_skeleton"],"weight":100},{"role":"filler","enemy_ids":["skeleton"],"weight":1}]},{},&"wave",30)
	var ranged := 0
	for enemy: Node in get_nodes_in_group("enemies"):
		if enemy.get("enemy_id")==&"archer_skeleton": ranged+=1
	expect(ranged<=6 and spawner.get("_wave_spawned_count")==30,"pending reveal role cap rerolls filler without losing budget")
	var map_runtime := MapVariableRuntime.new()
	world.add_child(map_runtime)
	map_runtime.setup(GameData.get_map(&"toxic_fog_graveyard"))
	spawner.call("_finish_normal_phase")
	map_runtime.set("_hazard_timer",0.0)
	map_runtime.set("_map_enemy_timer",0.0)
	map_runtime.call("_physics_process",0.1)
	expect(get_nodes_in_group("map_hazard").is_empty(),"Boss prepare suppresses new map hazards")
	spawner.call("_process_discrete_wave",2.0)
	spawner.call("_process_boss_event")
	map_runtime.call("_physics_process",0.1)
	expect(get_nodes_in_group("map_hazard").is_empty(),"Boss reveal retains safe preparation")
	var boss: Node2D
	for actor: Node in get_nodes_in_group("enemy"):
		if actor.get_meta("enemy_rank","")=="boss": boss=actor
	expect(boss!=null,"real Boss request creates a warning actor")
	if boss!=null:
		spawner.get("_spawn_service").call("_finish_spawn_reveal",weakref(boss),boss.get_meta("spawn_warning_node"))
		map_runtime.call("_physics_process",0.1)
		expect(spawner.call("_get_wave_progress_snapshot").transition_kind=="boss_active" and not get_nodes_in_group("map_hazard").is_empty(),"actual Boss activation exits preparation and restores map hazards")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
