extends SceneTree
var failed := false
class BlockedService extends EnemySpawnService:
	func try_find_spawn_position(_request: Dictionary,_actor: Node2D = null) -> Dictionary:
		return {"ok":false,"position":Vector2.ZERO,"reason":&"test_blocked"}
func _init() -> void:
	call_deferred("run")
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		push_error("[WavePressure] "+message)
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
	var director: RefCounted = spawner.get("_wave_director")
	expect(director.has_method("allocate_stage_budgets"),"largest remainder stage allocator exists")
	if director.has_method("allocate_stage_budgets"):
		for count: int in [35,50,65,80,95,110,125,140,39,56,73,90,106,123,140,157]:
			var budgets: Array = director.call("allocate_stage_budgets",count,[0.25,0.5,0.25])
			expect(budgets.size()==3 and budgets[0]+budgets[1]+budgets[2]==count,"stage sum equals density adjusted budget "+str(count))
	spawner.call("_start_wave",0)
	var wave: Dictionary = spawner.call("_get_wave_at_index",0)
	expect(wave.has("spawn_stages") and wave.duration_seconds==23,"real wave has authored stages and nominal duration")
	for frame in range(20):
		spawner.call("_process_wave_spawn",0.1,wave)
	expect(spawner.get("_wave_spawned_count")<=9,"empty field cannot consume future stages")
	expect(spawner.has_method("_get_wave_progress_snapshot"),"HUD and stats share wave snapshot")
	if spawner.has_method("_get_wave_progress_snapshot"):
		var snap: Dictionary = spawner.call("_get_wave_progress_snapshot")
		expect(snap.has("mandatory_events_remaining") and snap.has("pending_spawn_count") and snap.normal_budget==35,"snapshot reports real budget and events")
	var messages: Array = []
	spawner.timeline_event_started.connect(func(id: String,text: String): messages.append([id,text]))
	spawner.set("_elapsed_time",301.0)
	spawner.get("_timeline_controller").call("process",0.2)
	expect(spawner.get("_elapsed_time")>301.0,"actual run time does not freeze at standard target length")
	spawner.call("_finish_wave",false)
	expect(messages.any(func(item): return String(item[1]).contains("残余敌人")),"timeout transition announces remaining enemies")
	var blocked := BlockedService.new()
	spawner.set("_spawn_service",blocked)
	spawner.call("_sync_spawn_service")
	spawner.call("_start_wave",0)
	spawner.set("_wave_total_count",1)
	spawner.set("_wave_elapsed_time",23.0)
	spawner.call("_process_discrete_wave",0.1)
	expect(spawner.call("_get_wave_progress_snapshot").transition_kind=="delivery_grace","blocked delivery enters grace without pretending completion")
	for index in range(15): spawner.call("_process_discrete_wave",0.2)
	var incomplete: Dictionary = spawner.call("_get_wave_progress_snapshot")
	expect(incomplete.normal_spawned==0 and incomplete.delivery_failures.size()==1 and incomplete.delivery_failures[0].undelivered==1 and blocked.get_pending_count()==0,"grace timeout reports undelivered budget and cancels old requests")
	var hud := RunHudController.new()
	var screen := hud.build(self)
	root.add_child(screen)
	screen.visible=true
	hud.update(self,{"run_seconds":301.0,"run_duration":300.0})
	expect(screen.find_child("Timer",true,false).text=="05:01","production dictionary update displays actual time beyond target duration")
	screen.queue_free()
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
