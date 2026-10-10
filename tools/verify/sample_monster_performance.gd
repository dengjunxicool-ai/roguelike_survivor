## 同一驱动供阶段 C 前后串行性能采样；Boss 压力不混入普通阶段。
extends "res://tools/verify/verify_performance_run.gd"
var _observed: Dictionary = {}
var _peaks := {"nodes":0,"enemy_projectiles":0,"areas":0,"static_memory_bytes":0}
var _boss_start_offset := 0.0
var _initial_loadout: Array=[]
func _capture_loadout() -> Array:
	var result: Array=[]
	var manager: Node=_player.get_node("SkillManager")
	var skills: Array=manager.call("get_all_skills")
	var primary: RefCounted=manager.call("get_primary_attack_method")
	if primary!=null: skills.push_front(primary)
	for skill: RefCounted in skills:
		result.append({"id":String(skill.get("skill_id")),"level":skill.get("current_level"),"rarity":skill.get("current_rarity"),"definition":GameData.get_skill(skill.get("skill_id"))})
	return result
func _skip_build_choice() -> void:
	_ui.get("_run_choice_modal_controller").call("reset_run")
	_ui.call("transition_to","RUNNING")
	_handled_modal_state=""
func _choose_level_option() -> void: _skip_build_choice()
func _choose_reward_option() -> void: _skip_build_choice()
func _observe_node(node: Node) -> void:
	var script: Script=node.get_script() as Script
	if script!=null and (script.resource_path.ends_with("/damage_area.gd") or script.resource_path.ends_with("/area_effect.gd")):
		_observed[node.get_instance_id()]=weakref(node)
func _tick() -> void:
	var areas := 0
	for id: Variant in _observed.keys():
		var node: Node=_observed[id].get_ref() as Node
		if not is_instance_valid(node):
			_observed.erase(id)
			continue
		if not node.is_queued_for_deletion() and node.get("_is_despawned")!=true and node.get("_attack_finished")!=true and node.get("_damage_window_finished")!=true: areas+=1
	_peaks.nodes=maxi(_peaks.nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_peaks.enemy_projectiles=maxi(_peaks.enemy_projectiles,get_nodes_in_group(&"enemy_projectile").size())
	_peaks.areas=maxi(_peaks.areas,areas)
	_peaks.static_memory_bytes=maxi(_peaks.static_memory_bytes,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	super._tick()
func _runtime_elapsed_seconds() -> float:
	return maxf(super._runtime_elapsed_seconds()-_boss_start_offset,0)
func _start_run() -> void:
	if not node_added.is_connected(_observe_node): node_added.connect(_observe_node)
	await super._start_run()
	_player=get_first_node_in_group(&"player") as Node2D
	_initial_loadout=_capture_loadout()
	if OS.get_cmdline_user_args().has("--boss-pressure"):
		var spawner: Node = get_first_node_in_group(&"enemy_spawner")
		spawner.call("_finish_normal_phase")
		spawner.call("_process_boss_event")
		while not get_nodes_in_group(&"enemy").any(func(enemy): return enemy.get_meta("enemy_rank","")=="boss" and not enemy.get_meta("spawn_reveal_pending",true)):
			# 两版本均保持初始构筑；不在固定压力基准里选择新增祝福。
			var choices: RefCounted=_ui.get("_run_choice_modal_controller")
			var rewards: Array=choices.get("pending_reward_kinds")
			rewards.clear()
			if String(_ui.get("current_state"))=="RUN_REWARD_MODAL": _ui.call("transition_to","RUNNING")
			await process_frame
		_boss_start_offset=float(spawner.get("_elapsed_time"))
func _write_outputs(status: String) -> void:
	var final_loadout := _capture_loadout()
	if final_loadout!=_initial_loadout:
		status="FAILED"
		_failure_reason="performance fixture changed its skill build"
	super._write_outputs(status)
	var path := _report_dir.path_join("latest_samples.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["p50_frame_ms"]=_percentile(_frame_ms_values,0.5)
	data["scenario"]="boss_pressure" if OS.get_cmdline_user_args().has("--boss-pressure") else "normal_180"
	data["player_attacks_disabled"]=OS.get_cmdline_user_args().has("--disable-player-attack")
	data["per_frame_peaks"]=_peaks
	data["observed_area_instances"]=_observed.size()
	data["initial_loadout"]=_initial_loadout
	data["final_loadout"]=final_loadout
	if is_instance_valid(_ui): data["monster_summary"]=_ui.get("_run_stats_tracker").get_summary()
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
func _finish(exit_code: int) -> void:
	super._finish(1 if not _failure_reason.is_empty() else exit_code)
