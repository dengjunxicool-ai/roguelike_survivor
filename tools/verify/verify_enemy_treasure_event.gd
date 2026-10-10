extends SceneTree
var failed := false
class TestSpawner extends EnemySpawner:
	func _get_config_dictionary(key: String) -> Dictionary:
		var data := super._get_config_dictionary(key).duplicate(true)
		if key=="rewards":
			for event: Dictionary in data.get("treasure_events",[]): event.chance=1.0
		return data
class BlockedService extends EnemySpawnService:
	func try_find_spawn_position(_request: Dictionary,_enemy: Node2D=null) -> Dictionary:
		return {"ok":false,"position":Vector2.ZERO,"reason":&"test_blocked"}
func _init() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		push_error("[Treasure] "+message)
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.set_meta("debug_manual_spawn_only",true)
	var world := Node2D.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var player := Node2D.new()
	player.position=Vector2(960,540)
	player.add_to_group("player")
	world.add_child(player)
	var spawner := TestSpawner.new()
	world.add_child(spawner)
	var data: Dictionary=GameData.get_enemy(&"gem_slime")
	expect(data.behavior.type=="flee_player","gem uses flee behavior")
	expect(data.base_stats.contact_damage==0,"gem never deals contact damage")
	var waves: Array=spawner.call("_get_config_array","waves")
	for wave: Dictionary in waves:
		for group: Dictionary in wave.groups:
			expect(not group.enemy_ids.has("gem_slime"),"gem absent from ordinary budget")
	var events: Array=spawner.call("_get_config_dictionary","rewards").get("treasure_events",[])
	expect(events.size()==2,"two independent treasure events configured")
	var rng: RandomNumberGenerator=spawner.get("_rng")
	rng.seed=618
	var previous_state: int=rng.state
	var director: RefCounted=spawner.get("_reward_event_director")
	spawner.call("_start_wave",2)
	spawner.set("_wave_elapsed_time",5.0)
	spawner.call("_process_reward_events")
	spawner.call("_process_reward_events")
	expect(rng.state==previous_state,"treasure draw and placement leave ordinary RNG unchanged")
	expect(spawner.get("_wave_spawned_count")==0,"treasure does not spend ordinary budget")
	var triggered: Dictionary=spawner.get("_triggered_reward_events")
	expect(triggered.has("treasure:wave_3"),"one draw registered for wave three")
	spawner.call("_start_wave",6)
	spawner.set("_wave_elapsed_time",5.0)
	spawner.call("_process_reward_events")
	expect(spawner.get("_triggered_reward_events").has("treasure:wave_7"),"wave seven draw registered once")
	expect(director.call("get_treasure_snapshot").reserved==2,"successful draws reserve at most two births")
	expect(get_nodes_in_group("enemy").filter(func(actor): return actor.get_meta("spawn_source_type","")=="treasure_event").size()==2,"independent service creates both actual treasure actors")
	expect(spawner.call("_get_wave_blocking_enemy_count")==0,"treasure reveals do not block wave completion")
	var gem := preload("res://scenes/enemies/enemy.tscn").instantiate() as EnemyBase
	gem.enemy_id=&"gem_slime"
	gem.position=player.position+Vector2(180,0)
	gem.set_meta("treasure_lifetime",12.0)
	world.add_child(gem)
	gem.process_mode=Node.PROCESS_MODE_ALWAYS
	gem.set_physics_process(false)
	await physics_frame
	await process_frame
	gem.call("_update_behavior",0.1)
	expect(gem.velocity.x>0,"gem flees away from player")
	var before_drops := get_nodes_in_group("experience_crystal").size()
	var died: Array=[]
	gem.died.connect(func(): died.append(true))
	gem.call("_physics_process_profiled",11.9)
	expect(not gem.is_queued_for_deletion(),"gem remains before lifetime deadline")
	gem.call("_physics_process_profiled",0.1)
	expect(gem.is_queued_for_deletion(),"gem escapes after twelve active seconds")
	expect(died.is_empty() and get_nodes_in_group("experience_crystal").size()==before_drops,"escape grants no kills or experience")
	var killed := preload("res://scenes/enemies/enemy.tscn").instantiate() as EnemyBase
	killed.enemy_id=&"gem_slime"
	world.add_child(killed)
	var kill_notifications: Array=[]
	killed.died.connect(func(): kill_notifications.append(true))
	killed.call("_finish_death","damage")
	killed.call("_finish_death","damage")
	expect(kill_notifications.size()==1 and killed.dropped_experience==24,"player kill retains original 24 XP and one death notification")
	expect(get_nodes_in_group("experience_crystal").size()==before_drops+1,"real gem kill drops exactly one experience crystal")
	if director.has_method("get_treasure_snapshot"):
		var snap: Dictionary=director.call("get_treasure_snapshot")
		expect(snap.reserved<=2 and snap.draws==2,"independent event cap and single draws")
	spawner.reset_for_run()
	if director.has_method("get_treasure_snapshot"):
		expect(director.call("get_treasure_snapshot").reserved==0,"restart clears treasure reservation")
	director.set("_treasure_service",BlockedService.new())
	director.call("setup",spawner)
	spawner.call("_start_wave",2)
	spawner.set("_wave_elapsed_time",5.0)
	for repeat in range(5):
		spawner.call("_process_reward_events")
		director.get("_treasure_service").call("retry_pending",0.2)
	var blocked: Dictionary=director.call("get_treasure_snapshot")
	expect(blocked.draws==1 and blocked.reserved==1 and blocked.pending==1,"retries reuse one successful draw and one reservation")
	spawner.get("_wave_director").call("finish_wave",false)
	expect(director.call("get_treasure_snapshot").pending==0,"timeout transition immediately cancels uncreated treasure requests")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
