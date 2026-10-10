## 真实应用的自动辅助流程初筛；高血量、自动移动/选卡、16 倍时间，不能推导真人胜率。
extends "res://tools/verify/verify_performance_run.gd"
var _case: Dictionary
var _cases: Array[Dictionary]=[]
var _case_cleanup_done := false
var _initial_loadout: Array=[]
var _case_wall_started := 0
var _batch_results: Array=[]
var _batch_dir := "E:/codex/monster-system/stage-c-screening"
var _assisted_kills := 0
var _sampling_time_scale := 16.0
func _run() -> void:
	root.size=Vector2i(1280,720)
	var limit := 240
	var start_index := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--limit="): limit=int(argument.trim_prefix("--limit="))
		if argument.begins_with("--start-index="): start_index=int(argument.trim_prefix("--start-index="))
		if argument.begins_with("--report-dir="): _batch_dir=argument.trim_prefix("--report-dir=")
		if argument.begins_with("--time-scale="): _sampling_time_scale=float(argument.trim_prefix("--time-scale="))
	for character: String in ["mage","ranger","paladin","alchemist"]:
		for map: String in ["abandoned_dungeon","toxic_fog_graveyard","lava_temple","abyss_corridor"]:
			for build in range(3):
				for run_seed in [618,619,620,621,622]: _cases.append({"character":character,"map":map,"build":build,"seed":run_seed})
	_cases=_cases.slice(start_index,start_index+limit)
	for index in range(_cases.size()):
		_case=_cases[index]
		_finished=false
		_case_cleanup_done=false
		_elapsed=0
		_next_sample=0
		_movement_phase=0
		_handled_modal_state=""
		_failure_reason=""
		_samples.clear()
		_frame_ms_values.clear()
		_spike_33ms_count=0
		_spike_50ms_count=0
		_max_frame_ms=0
		_initial_loadout=[]
		_assisted_kills=0
		_case_wall_started=Time.get_ticks_msec()
		await super._run()
		while not _case_cleanup_done: await process_frame
		print("[MonsterScreening] case ",index+1,"/",_cases.size()," ",_case)
	var report := FileAccess.open(_batch_dir.path_join("screening.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"mode":_screening_mode(),"cases":_batch_results},"\t"))
	report.close()
	quit(1 if _batch_results.any(func(item): return item.status=="FAILED") else 0)
func _screening_mode() -> String:
	return "automated assisted flow screening; not human win rate or balance acceptance"
func _start_run() -> void:
	_environment.seed=int(_case.seed)
	_environment.rng_seeds.global=int(_case.seed)
	seed(int(_case.seed))
	_report_dir=_batch_dir.path_join("%s_%s_b%d_s%d"%[_case.character,_case.map,_case.build,_case.seed])
	DirAccess.make_dir_recursive_absolute(_report_dir)
	_ui.call("transition_to","TITLE")
	await process_frame
	_ui.call("transition_to","CHARACTER_SELECT")
	await process_frame
	_ui.get("_character_loadout_controller").call("refresh",StringName(_case.character))
	_ui.call("_on_loadout_confirmed",StringName(_case.character))
	await _ui.call("_start_run",StringName(_case.map))
	if not RunEnvironment.seed_gameplay_rngs(_ui,_environment):
		_fail("screening RNG initialization failed")
		return
	_player=get_first_node_in_group(&"player") as Node2D
	_assist_max_health=100000
	var manager: Node=_player.get_node("SkillManager")
	print("[MonsterScreening] initial schools ",manager.call("get_learned_god_schools"))
	var schools := ["chaos","curse","fire","frost","holy","thunder"]
	var existing: Array=manager.call("get_learned_god_schools")
	var candidates: Array=schools.filter(func(school): return not existing.has(StringName(school)))
	var selected: Array=[String(existing[0]),String(candidates[int(_case.build)])] if not existing.is_empty() else schools.slice(int(_case.build)*2,int(_case.build)*2+2)
	for school: String in selected:
		for category: String in ["cast","passive"]:
			var learned := false
			for definition: Dictionary in GameData.get_skill_pool():
				if String(definition.get("school",""))==school and String(definition.get("skill_type",""))==category and manager.call("add_skill",definition.id,"common"):
					learned=true
					break
			if not learned:
				_fail("no legal "+school+" "+category+" build candidate; schools="+str(manager.call("get_learned_god_schools")))
				return
	_initial_loadout=_loadout()
	Engine.time_scale=_sampling_time_scale
	await physics_frame
func _loadout() -> Array:
	var result: Array=[]
	if not is_instance_valid(_player): return result
	var manager: Node=_player.get_node("SkillManager")
	var skills: Array=manager.call("get_all_skills")
	var primary: RefCounted=manager.call("get_primary_attack_method")
	if primary!=null: skills.push_front(primary)
	for skill: RefCounted in skills:
		result.append({"id":String(skill.get("skill_id")),"level":skill.get("current_level"),"rarity":skill.get("current_rarity"),"definition":GameData.get_skill(skill.get("skill_id"))})
	return result
func _tick() -> void:
	if Time.get_ticks_msec()-_case_wall_started>60000:
		_fail("screening case exceeded sixty wall seconds")
		return
	if OS.get_cmdline_user_args().has("--flow-assist"):
		for enemy: Node in get_nodes_in_group(&"enemy"):
			if enemy.get("_is_dead")==true or enemy.get_meta("spawn_reveal_pending",true): continue
			var is_boss: bool = enemy.get_meta("enemy_rank","")=="boss"
			if is_boss and float(_ui.get("_run_seconds"))<float(enemy.get_meta("monster_spawn_seconds",0))+5.0: continue
			var packet := DamagePacket.from_dictionary({"raw_amount":1000000.0,"source_type":"primary_attack","source_instance_id":str(_player.get_instance_id())+":flow_assist","source_origin_id":"flow_assist","source_skill_id":"flow_assist","source_id":"flow_assist","damage_type":"direct_physical","element":"physical","damage_origin":"primary_attack","can_crit":false,"can_trigger_reaction":false,"uses_character_damage_multiplier":false,"uses_skill_level_coefficient":false,"ignore_defense":true,"ignore_resistance":true,"ignore_vulnerability":true,"ignore_min_damage":true},_player,enemy)
			enemy.call("take_damage",packet)
			_assisted_kills+=1
	if is_instance_valid(_ui) and String(_ui.get("current_state")) in ["RESULT_DEFEAT","RESULT_VICTORY"]:
		_record_sample("terminal")
		_write_outputs("AUTOMATED_"+String(_ui.get("current_state")))
		_finish(0)
		return
	super._tick()
func _write_outputs(status: String) -> void:
	var spawner: Node=get_first_node_in_group(&"enemy_spawner")
	var wave_snapshot: Dictionary=spawner.call("_get_wave_progress_snapshot") if spawner!=null and spawner.has_method("_get_wave_progress_snapshot") else {}
	if not wave_snapshot.get("delivery_failures",[]).is_empty():
		status="FAILED"
		_failure_reason="wave_delivery_failed"
	super._write_outputs(status)
	var path := _report_dir.path_join("latest_samples.json")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.character=_case.character
	payload.map=_case.map
	payload.seed=_case.seed
	payload["build_index"]=_case.build
	payload["initial_loadout"]=_initial_loadout
	payload["final_loadout"]=_loadout()
	payload["summary"]=_ui.get("_run_stats_tracker").get_summary() if is_instance_valid(_ui) else {}
	payload["final_wave"]=wave_snapshot
	payload["wall_seconds"]=(Time.get_ticks_msec()-_case_wall_started)/1000.0
	payload["flow_assisted_kills"]=_assisted_kills
	payload["sampling_time_scale"]=_sampling_time_scale
	payload["player_attacks_disabled"]=OS.get_cmdline_user_args().has("--disable-player-attack")
	payload["sampling_scope"]="assisted delivery/death/reward/transition flow; exclude damage and kill-time balance" if OS.get_cmdline_user_args().has("--flow-assist") else "automated high-health combat; exclude human win rate and dodge experience"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload,"\t"))
	file.close()
	_batch_results.append({"case":_case.duplicate(),"status":status,"report":path,"duration":_elapsed,"summary":payload.summary,"final_wave":payload.get("final_wave",{})})
func _finish(exit_code: int) -> void:
	if _finished: return
	_finished=true
	Engine.time_scale=1.0
	_release_movement()
	if not RunEnvironment.cleanup_save(_environment): push_error("screening save cleanup failed")
	if is_instance_valid(_ui): _ui.call("_teardown_run_scene")
	if is_instance_valid(_main_scene): _main_scene.queue_free()
	await physics_frame
	await process_frame
	await process_frame
	_case_cleanup_done=true
