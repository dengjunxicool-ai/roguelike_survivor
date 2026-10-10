extends SceneTree
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const Service = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const Spawner = preload("res://scripts/enemies/enemy_spawner.gd")
var failed := false
var created := 0
class ControlledService extends EnemySpawnService:
	var blocked := true
	func try_find_spawn_position(request: Dictionary, spawned_enemy: Node2D = null) -> Dictionary:
		if blocked:
			return {"ok":false,"position":Vector2.ZERO,"reason":&"test_blocked"}
		return super.try_find_spawn_position(request,spawned_enemy)
	func _is_position_clear(_position: Vector2, _clearance: float, _enemy: Node2D) -> bool:
		return not blocked
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world := Node2D.new()
	root.add_child(world)
	var player := Node2D.new()
	world.add_child(player)
	player.add_to_group("player")
	var service := ControlledService.new()
	service.call("setup",world,EnemyScene)
	if service.has_method("set_context"):
		service.call("set_context",0,"w1")
	var request := {"enemy_id":&"skeleton","position":Vector2(300,200),"parent":world,"source_type":"wave","wave_id":"w1","spawn_request_id":41}
	var enemy: Node2D = service.call("spawn",request)
	expect(enemy==null, "blocked positions never create an enemy or consume budget")
	if enemy != null:
		enemy.queue_free()
	if not service.has_method("retry_pending"):
		expect(false,"spawn service retains failed requests for retry")
		world.queue_free()
		await process_frame
		quit(1)
		return
	service.connect("spawn_created",Callable(self,"on_created"))
	expect(service.call("get_pending_count")==1,"failed request is retained exactly once")
	service.blocked=false
	service.call("retry_pending",0.3)
	service.call("retry_pending",0.3)
	expect(created==1 and service.call("get_pending_count")==0,"retry emits successful creation exactly once")
	for node: Node in get_nodes_in_group("enemies"):
		if not node.is_queued_for_deletion():
			enemy=node as Node2D
	expect(enemy!=null and enemy.get_meta("spawn_reveal_pending",false),"all sources begin disabled during birth warning")
	if enemy!=null:
		player.global_position=enemy.global_position
		var old_position := enemy.global_position
		var warning: Node2D = enemy.get_meta("spawn_warning_node").get_ref()
		service.call("_finish_spawn_reveal",weakref(enemy),weakref(warning))
		expect(enemy.get_meta("spawn_reveal_pending",false) and enemy.global_position.distance_to(old_position)>50,"player enters birth point: relocate while still disabled")
		var replacement: Node2D = enemy.get_meta("spawn_warning_node").get_ref()
		expect(replacement!=warning and replacement.global_position==enemy.global_position and enemy.get_meta("spawn_warning_duration")==1.5,"relocation replaces warning at new center for full duration")
		service.call("_finish_spawn_reveal",weakref(enemy),weakref(replacement))
		expect(not enemy.get_meta("spawn_reveal_pending",true),"safe final check activates enemy")
	service.blocked=true
	request.spawn_request_id=42
	service.call("spawn",request)
	service.call("set_context",2,"w2")
	service.blocked=false
	service.call("retry_pending",0.3)
	expect(created==1 and service.call("get_pending_count")==0,"old generation request cannot deliver into a new run")
	for source: String in ["summon","death_split","map_event","elite_event","boss"]:
		var actual: Node2D = service.call("spawn",{"enemy_id":&"skeleton","parent":world,"position":Vector2(500,300),"source_type":source,"spawn_clearance":0})
		expect(actual!=null and actual.get_meta("spawn_reveal_pending",false),source+" birth disables behavior and collisions")
		if actual!=null:
			var duration := 0.6 if source in ["summon","death_split"] else (0.8 if source=="elite_event" else 1.5)
			expect(actual.get_meta("spawn_warning_duration")==duration,source+" uses required warning duration")
	world.queue_free()
	await process_frame
	service=null
	await test_budget_callbacks()
	await test_core_source_expiry()
	quit(1 if failed else 0)
func test_core_source_expiry() -> void:
	var world := Node2D.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var boss: Node2D = EnemyScene.instantiate()
	var tracker := RunStatsTracker.new()
	world.add_child(tracker)
	boss.set("enemy_id",&"dungeon_heart")
	world.add_child(boss)
	boss.position=Vector2(640,360)
	var service := ControlledService.new()
	boss.get("_action_executor").set("_spawn_service",service)
	boss.call("_spawn_corrupted_cores",2,120)
	expect(service.call("get_pending_count","boss_core")==2,"blocked cores reserve two pending requests")
	boss.set("_is_dead",true)
	service.blocked=false
	service.call("retry_pending",0.3)
	expect(get_nodes_in_group("boss_cores").is_empty() and service.call("get_pending_count")==0,"Boss death cancels queued core requests")
	expect(tracker.boss_core_spawned_count==0,"cancelled core requests do not create spawn statistics")
	boss.set("_is_dead",false)
	service.blocked=true
	boss.call("_spawn_corrupted_cores",2,120)
	service.blocked=false
	service.call("retry_pending",0.3)
	service.call("retry_pending",0.3)
	expect(tracker.boss_core_spawned_count==2 and get_nodes_in_group("boss_cores").size()==2,"asynchronous core delivery records two real spawns exactly once")
	world.queue_free()
	await process_frame
func test_budget_callbacks() -> void:
	root.set_meta("debug_manual_spawn_only",true)
	var world := Node2D.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var player := Node2D.new()
	world.add_child(player)
	player.add_to_group("player")
	var controlled := ControlledService.new()
	var spawner: Node = Spawner.new()
	spawner.set("_spawn_service",controlled)
	world.add_child(spawner)
	spawner.set("_current_wave_id","budget_test")
	spawner.call("_sync_spawn_context")
	spawner.set("_wave_total_count",3)
	spawner.set("_max_spawn_batch_size",3)
	var wave := {"groups":[{"enemy_ids":["skeleton"],"weight":100,"count_min":1,"count_max":1}]}
	spawner.call("_process_wave_spawn",0.01,wave)
	spawner.call("_process_wave_spawn",0.01,wave)
	expect(spawner.get("_wave_spawned_count")==0 and controlled.call("get_pending_count","wave")==3,"real director reserves three queued requests without counting or duplicating them")
	controlled.blocked=false
	controlled.call("retry_pending",0.3)
	expect(spawner.get("_wave_spawned_count")==3,"asynchronous success counts the real wave exactly once")
	var first: Node
	for enemy: Node in get_nodes_in_group("enemies"):
		if not enemy.is_queued_for_deletion():
			first=enemy
			break
	if first != null:
		var request: Dictionary = first.get_meta("spawn_request")
		spawner.call("_on_spawn_created",request,first)
		expect(spawner.get("_wave_spawned_count")==3,"duplicate success callback cannot spend budget twice")
		var warning: Node = first.get_meta("spawn_warning_node").get_ref()
		warning.queue_free()
		controlled.blocked=true
		controlled.call("retry_pending",0.3)
		expect(spawner.get("_wave_spawned_count")==2 and controlled.call("get_pending_count","wave")==1,"removed wave warning refunds once and retains its request")
		spawner.call("_start_wave",1)
		controlled.blocked=false
		controlled.call("retry_pending",0.3)
		spawner.call("_on_spawn_created",request,first)
		expect(spawner.get("_wave_spawned_count")==0 and controlled.call("get_pending_count","wave")==0,"old wave queue and callback cannot affect next wave")
		spawner.call("reset_for_run")
		spawner.call("_on_spawn_created",request,first)
		expect(spawner.get("_wave_spawned_count")==0,"old run callback cannot affect restarted run")
	controlled.blocked=true
	spawner.set("_normal_phase_complete",true)
	spawner.call("_process_boss_event")
	spawner.call("_process_boss_event")
	expect(not bool(spawner.get("_boss_active")) and controlled.call("get_pending_count","boss")==1,"failed Boss placement queues exactly one encounter request")
	controlled.blocked=false
	controlled.call("retry_pending",0.3)
	var boss: Node
	for candidate: Node in get_nodes_in_group("bosses"):
		if not candidate.is_queued_for_deletion():
			boss=candidate
	expect(boss!=null and bool(spawner.get("_boss_active")),"asynchronous Boss delivery activates the encounter")
	var wins: Array = []
	spawner.connect("boss_defeated",func(time: float): wins.append(time))
	if boss!=null:
		boss.set_meta("reward_policy",{"award_soul":false,"drop_experience":false,"notify_kill_events":false})
		boss.call("_finish_death")
		boss.call("_finish_death")
	expect(wins.size()==1 and not bool(spawner.get("_boss_active")),"asynchronously delivered Boss death reports victory once")
	world.queue_free()
	await process_frame
	root.remove_meta("debug_manual_spawn_only")
func on_created(_request: Dictionary,_enemy: Node2D) -> void:
	created+=1
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		push_error("[SpawnSafety] FAIL "+message)
	else:
		print("[SpawnSafety] PASS "+message)
