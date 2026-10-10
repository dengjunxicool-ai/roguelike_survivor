extends "res://tools/verify/verify_run_restart_contract.gd"
func _capture(label: String,ui: Node) -> void:
	await super._capture(label,ui)
	if label!="second-defeat": return
	for iteration in range(5):
		await ui.call("_start_run",MAP_ID)
		var main: Node=ui.get("_run_scene_coordinator").call("get_run_scene_parent",self)
		main.process_mode=Node.PROCESS_MODE_DISABLED
		var spawner: Node=main.get_node("EnemySpawner")
		var tracker: Node=ui.get("_run_stats_tracker")
		spawner.call("_start_wave",2)
		spawner.set("_wave_elapsed_time",5.0)
		var rewards: RefCounted=spawner.get("_reward_event_director")
		var roll_rng: RandomNumberGenerator=rewards.get("_treasure_roll_rng")
		for candidate in range(100):
			roll_rng.seed=candidate
			if roll_rng.randf()<0.35:
				roll_rng.seed=candidate
				break
		rewards.set("_treasure_seeded",true)
		spawner.call("_process_reward_events")
		_expect(rewards.call("get_treasure_snapshot").reserved==1,"restart fixture reserves actual treasure event")
		var actor: Node2D=spawner.call("spawn_enemy",Request.create(&"skeleton",{"source_type":"wave"}))
		_expect(actor!=null,"restart fixture holds normal reveal")
		var support: Node2D=spawner.call("spawn_enemy",Request.create(&"war_drum_goblin",{}))
		var effects: Array[Dictionary]=[{"stat":"move_speed","op":"multiply","value":1.25,"scope":{"tag":"movement"},"source":"war_drum"}]
		actor.get("_support_buff_controller").call("refresh",support,effects,10.0)
		var scheduler: RefCounted=actor.get("_boss_mechanic_scheduler")
		_expect(scheduler.call("try_reserve",&"test_reset",&"area_denial",2)>0,"restart fixture holds scheduler token")
		var actor_id:=actor.get_instance_id()
		while bool(ui.get("_run_loading_active")): await process_frame
		await ui.call("_start_run",MAP_ID)
		main.process_mode=Node.PROCESS_MODE_DISABLED
		await process_frame
		_expect(not is_instance_id_valid(actor_id),"restart "+str(iteration+1)+" clears owners and buff receivers")
		_expect(scheduler.get("_tokens").is_empty(),"restart clears scheduler token")
		_expect(rewards.call("get_treasure_snapshot").reserved==0 and rewards.call("get_treasure_snapshot").pending==0,"restart clears treasure count and queue")
		var service: RefCounted=spawner.get("_spawn_service")
		_expect(service.call("get_pending_count")==0 and service.call("get_reveal_count")==0,"restart clears ordinary queue and warnings")
		_expect(service.get("statistics").created==0,"restart clears delivery statistics")
		_expect(tracker.get_summary().monster_metrics.is_empty(),"old owner cleanup cannot pollute next run metrics")
		while bool(ui.get("_run_loading_active")): await process_frame
