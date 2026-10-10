extends SceneTree
const Tracker = preload("res://scripts/game/run_stats_tracker.gd")
const Progression = preload("res://scripts/game/run_progression_service.gd")
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var tracker: Node = Tracker.new()
	root.add_child(tracker)
	var target: Node2D = Node2D.new()
	root.add_child(target)
	var packet: DamagePacket = DamagePacket.from_dictionary({"raw_amount":1000,"damage_origin":"status_dot","damage_type":"status_dot"},null,target)
	tracker.record_damage_done(target,1000,{"damage_origin":"status_dot","damage_type":"status_dot"},packet)
	var stats: Dictionary = tracker.get_summary()
	var run_state: Dictionary = {"run_seconds":142.65,"selected_character_id":"mage","selected_map_id":"toxic_fog_graveyard","run_stats":stats}
	stats.boss_phase_started_at = 137.68
	var summary: Dictionary = Progression.record_run_result("RESULT_VICTORY",run_state)
	check(Progression._map_objective_met(&"clear_with_dot_damage",summary), "real tracker DOT victory completes challenge")
	check(SaveManager.is_map_challenge_completed(&"toxic_fog_graveyard",&"clear_with_dot_damage"), "DOT challenge persisted")
	check(summary.reached_boss and SaveManager.get_last_run_summary().reached_boss, "early boss arrival saved true")
	check(SaveManager.get_counter(&"victories") == 1 and SaveManager.get_counter(&"boss_kills") == 1, "terminal counters recorded once")
	for amount: int in [0,34,35,100]:
		var boundary: Dictionary = {"victory":true,"run_stats":{"damage_done_total":100,"damage_done_by_origin":{"status_dot":amount,"primary_attack":100-amount}}}
		check(Progression._map_objective_met(&"clear_with_dot_damage",boundary) == (amount>=35), "DOT threshold " + str(amount))
	check(not Progression._map_objective_met(&"clear_with_dot_damage",{"victory":false,"run_stats":stats}), "DOT defeat cannot complete clear challenge")
	check(not Progression._map_objective_met(&"clear_with_dot_damage",{"victory":true,"run_stats":{"damage_done_total":0}}), "zero damage safe")
	var legacy := {"victory":true,"run_stats":{"damage_done_total":100,"damage_done_by_origin":{"dot":35}}}
	check(Progression._map_objective_met(&"clear_with_dot_damage",legacy), "legacy DOT alias supported")
	legacy.run_stats.damage_done_by_origin.status_dot = 10
	check(not Progression._map_objective_met(&"clear_with_dot_damage",legacy), "current key takes precedence without double counting")
	check(Progression._build_summary("RESULT_DEFEAT",{"run_seconds":140,"run_stats":{"boss_phase_started_at":137}}).reached_boss, "early boss defeat still reached boss")
	check(not Progression._build_summary("RESULT_DEFEAT",{"run_seconds":280,"run_stats":{"boss_phase_started_at":-1}}).reached_boss, "long survival without boss remains false")
	check(Progression._build_summary("RESULT_VICTORY",{"run_seconds":120}).reached_boss, "victory implies boss reached even if optional stats missing")
	tracker.queue_free()
	target.queue_free()
	await process_frame
	print("[qa-progression] failures=",failures)
	quit(1 if failures else 0)
