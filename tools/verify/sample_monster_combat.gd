## 1 倍时间、真实生命、真实伤害的自动战斗观察；不能代表真人胜率。
extends "res://tools/verify/sample_monster_screening.gd"
const Observation=preload("res://tools/verify/fixtures/monster_combat_observation.gd")
var _observations: RefCounted
var _initial_player: Dictionary
var _selected_options: Array=[]
var _combat_loadouts: Dictionary={}
var _seed_offset:=0
func _run() -> void:
	var has_report_dir:=false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): has_report_dir=true
		if argument.begins_with("--seed-offset="): _seed_offset=int(argument.trim_prefix("--seed-offset="))
		if argument in ["--flow-assist","--disable-player-attack"] or argument.begins_with("--survival-health=") or argument.begins_with("--time-scale="):
			push_error("normal combat forbids survival/attack/time assistance")
			quit(1)
			return
	if not has_report_dir:
		push_error("normal combat requires an explicit isolated --report-dir under E:/codex")
		quit(1)
		return
	_sampling_time_scale=1.0
	if not node_added.is_connected(_observe_added): node_added.connect(_observe_added)
	await super._run()
func _screening_mode() -> String:
	return "normal-health automated combat; fixed 60 Hz, time scale 1; not human win rate"
func _start_run() -> void:
	_case.seed=int(_case.seed)+_seed_offset
	_observations=Observation.new()
	_selected_options=[]
	_combat_loadouts={}
	await super._start_run()
	_initial_player=_player_snapshot()
	for enemy: Node in get_nodes_in_group(&"enemy"): _enroll_enemy(enemy)
func _apply_autoplay_survival_assist() -> void: pass
func _maintain_autoplay_survival_assist() -> void: pass
func _observe_added(node: Node) -> void:
	if node.get_script()!=null and node.get_script().resource_path=="res://scripts/enemies/enemy_base.gd":
		node.ready.connect(_enroll_enemy.bind(node),CONNECT_ONE_SHOT)
func _enroll_enemy(enemy: Node) -> void:
	if _observations==null: return
	var key:=enemy.get_instance_id()
	if _observations.rows.has(key): return
	var definition: Dictionary=GameData.get_enemy(enemy.get("enemy_id"))
	_observations.enroll(key,{"enemy_id":String(enemy.get("enemy_id")),"rank":String(enemy.get_meta("enemy_rank","normal")),"definition":definition,"spawn_seconds":_runtime_elapsed_seconds(),"initial_health":enemy.get("current_health")},int(enemy.get("current_health")))
	enemy.health_changed.connect(_enemy_health.bind(key))
	enemy.died.connect(_enemy_died.bind(key))
	enemy.tree_exiting.connect(_enemy_exiting.bind(key))
func _enemy_health(health: int,_max_health: int,key: int) -> void:
	# Full loadout only needs copying on the first health loss.
	var row: Dictionary=_observations.rows[key]
	var context: Dictionary={}
	if float(row.first_hit_seconds)<0 and health<int(row.last_health):
		var loadout_key: String="%d:%d"%[int(_player.get("level")),_selected_options.size()]
		if not _combat_loadouts.has(loadout_key): _combat_loadouts[loadout_key]=_loadout()
		context={"player":_player_snapshot(),"loadout_ref":loadout_key,"run_seconds":_runtime_elapsed_seconds()}
	_observations.health_changed(key,health,_runtime_elapsed_seconds(),context)
func _enemy_died(key: int) -> void:
	_observations.finish(key,_runtime_elapsed_seconds(),"killed" if int(_observations.rows[key].last_health)<=0 else "self_death")
func _enemy_exiting(key: int) -> void: _observations.finish(key,_runtime_elapsed_seconds(),"cleanup_or_escape")
func _score_option(option: Dictionary) -> float:
	return _rarity_score(String(option.get("rarity","common")))+(100.0 if String(option.get("id","")).begins_with("skill_level_up:") else 0.0)
func _best_option(options: Array) -> Dictionary:
	var option: Dictionary=super._best_option(options)
	_selected_options.append({"seconds":_runtime_elapsed_seconds(),"option":option.duplicate(true)})
	return option
func _tick() -> void:
	if Time.get_ticks_msec()-_case_wall_started>300000:
		_fail("normal combat case exceeded 300 wall seconds")
		return
	if not is_instance_valid(_ui): return
	var state:=String(_ui.get("current_state"))
	var current_seconds:=_runtime_elapsed_seconds()
	var game_delta:=maxf(0,current_seconds-_elapsed)
	_elapsed=current_seconds
	match state:
		"RUNNING":
			paused=false
			_drive_player(game_delta)
			if _elapsed>=_next_sample:
				_record_sample("interval")
				_next_sample+=SAMPLE_INTERVAL_SECONDS
			if _elapsed>=_run_seconds:
				_write_outputs("CENSORED_TIME_LIMIT")
				_finish(0)
		"LEVEL_UP_MODAL", "RUN_REWARD_MODAL", "CURSE_CHOICE_MODAL":
			paused=true
			_release_movement()
			if _handled_modal_state!=state:
				_handled_modal_state=state
				if state=="LEVEL_UP_MODAL": _choose_level_option()
				elif state=="RUN_REWARD_MODAL": _choose_reward_option()
				else: _choose_curse_option()
		"RESULT_DEFEAT", "RESULT_VICTORY":
			_record_sample("terminal")
			_write_outputs("AUTOMATED_"+state)
			_finish(0)
		_: _release_movement()
func _write_outputs(status: String) -> void:
	if _observations!=null:
		for key: int in _observations.rows: _observations.finish(key,_elapsed,"censored_at_run_end")
	super._write_outputs(status)
	var path:=_report_dir.path_join("latest_samples.json")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.sampling_scope=_screening_mode()
	payload.survival_assist=false
	payload.initial_player=_initial_player
	payload.selected_options=_selected_options
	payload.combat_loadouts=_combat_loadouts
	payload.enemy_observations=_observations.snapshot() if _observations!=null else []
	payload.failure_source=payload.summary.get("last_damage_source","")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload,"\t"))
	file.close()
	_batch_results[-1].merge({"initial_player":_initial_player,"failure_source":payload.failure_source,"sampling_scope":payload.sampling_scope})
	var report:=FileAccess.open(_report_dir.path_join("report.md"),FileAccess.WRITE)
	report.store_string("# 自动战斗观测\n\n角色：%s；地图：%s；构筑：%d；种子：%d\n\n结果：%s；游戏时间：%.3f 秒；死亡来源：%s\n\n1 倍游戏时间、60 Hz、真实生命、伤害与冷却。机器人自动移动与选卡；不用于真人胜率或渲染性能结论。完整构筑、成长、伤害归因、首次掉血至死亡耗时及删失样本见 latest_samples.json。\n"%[_case.character,_case.map,_case.build,_case.seed,status,_elapsed,payload.failure_source])
	report.close()
