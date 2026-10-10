## fixed matrix / real 300s episodes use real startup, enemy data, physics and skill executor.
extends SceneTree
const Metrics = preload("res://scripts/runtime/skill_balance_metrics.gd")
const Env = preload("res://tools/verify/verification_run_environment.gd")
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Controller = preload("res://scripts/debug/real_full_run_profiler.gd")
var config: Dictionary
var report_dir: String
var environment: Dictionary
var rows: Array = []
var mode: String = "matrix"
var cohort: String = "exploration"
var limit: int = 0
var preset_limit: int = 0
var preset_start: int = 0
func _init() -> void: call_deferred("run")
func run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/skill_balance_presets.json"))
	assert(config.presets.size()==18 and config.fusion_pairs.size()==15 and config.scenes.size()==6)
	for preset: Dictionary in config.presets:
		assert(preset.has_all(["character_id","map_id","meta_state","seed","skills","levels","rarities","controller_policy"]))
		assert(preset.levels.reduce(func(a: int,b: int) -> int: return a+b,0)==12)
		for id: String in preset.skills: assert(not GameData.get_skill(id).is_empty())
	for preset: Dictionary in config.fusion_pairs:
		var f: Dictionary = Fixture.build(self)
		f.caster.set_meta("character_level",6)
		for id: String in preset.skills: assert(Fixture.install_runtime_skill(f.skill_manager,StringName(id)))
		var admission: Dictionary = preload("res://scripts/skills/skill_requirement_policy.gd").new().evaluate(f.caster,GameData.get_skill(preset.fusion))
		assert(admission.available,str(preset.id)+str(admission.missing_requirements))
		f.caster.free()
		f.target.free()
	if not OS.get_cmdline_user_args().has("--execute"):
		print("[verify_skill_balance_matrix] PASS contract only; no balance acceptance asserted")
		quit(0)
		return
	environment = Env.initialize(OS.get_environment("APPDATA").get_base_dir()+"/data")
	if environment.is_empty(): quit(1); return
	report_dir = environment.report_dir
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--cohort="): cohort = arg.trim_prefix("--cohort=")
		if arg.begins_with("--seed-limit="): limit = int(arg.trim_prefix("--seed-limit="))
		if arg.begins_with("--preset-start="): preset_start = int(arg.trim_prefix("--preset-start="))
		if arg.begins_with("--preset-limit="): preset_limit = int(arg.trim_prefix("--preset-limit="))
	if mode not in ["matrix","real"] or cohort not in ["exploration","confirmation","fusion","outlier"]:
		push_error("Invalid mode or cohort")
		quit(1)
		return
	var seeds: Array = config[cohort+"_seeds"]
	if limit > 0: seeds = seeds.slice(0,limit)
	var presets: Array = config.fusion_pairs if cohort in ["fusion","outlier"] else config.presets
	presets = presets.slice(preset_start,preset_start+preset_limit if preset_limit > 0 else presets.size())
	var scenes: Array = config.scenes if mode == "matrix" else [{"id":"real_300s"}]
	for preset: Dictionary in presets:
		for value: int in seeds:
			for scenario: Dictionary in scenes:
				for variant: int in (2 if cohort in ["fusion","outlier"] else 1):
					var row: Dictionary = await episode(preset,scenario,value,variant==1)
					rows.append(row)
					_write()
					print("MATRIX rows=%d preset=%s seed=%d scene=%s terminal=%s seconds=%.2f damage=%.0f" % [rows.size(),preset.id,value,scenario.id,row.terminal,row.seconds,row.actual_damage])
	_write()
	print("[verify_skill_balance_matrix] captured=%d data=%s; acceptance is report review" % [rows.size(),report_dir])
	quit(0)
func episode(preset: Dictionary, scenario: Dictionary, seed_value: int, fusion_enabled: bool) -> Dictionary:
	paused = false
	Engine.time_scale = 1.0
	preload("res://tools/verify/skill_balance_protocol.gd").configure_viewport(self)
	SaveManager.reset_progress()
	environment.seed = seed_value
	environment.rng_seeds.global = seed_value
	environment.spawn_seed_applied = false
	if not node_added.is_connected(environment.spawn_seed_listener): node_added.connect(environment.spawn_seed_listener)
	seed(seed_value)
	var scene: Node = load("res://scenes/app/app_bootstrap.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var ui: Node = scene.get_node("UIManager")
	ui.transition_to("TITLE")
	await process_frame
	ui.transition_to("CHARACTER_SELECT")
	await process_frame
	ui.get("_character_loadout_controller").refresh(StringName(preset.character_id))
	await process_frame
	ui._on_loadout_confirmed(StringName(preset.character_id))
	await process_frame
	await ui._start_run(StringName(preset.map_id))
	assert(Env.seed_gameplay_rngs(ui,environment))
	var player: Node2D = get_first_node_in_group(&"player")
	assert(player != null)
	var manager: Node = player.get_node("SkillManager")
	manager.clear_skills()
	player.level = int(preset.player_level)
	# Controlled starting grant is identical in budget across presets; offers are tested separately.
	manager.set_primary_attack_method(&"fireball","normal")
	for index: int in preset.skills.size():
		var id: StringName = StringName(preset.skills[index])
		if GameData.get_skill(id).get("skill_type","") == "attack": assert(manager.add_skill(id,preset.rarities[index]))
		else: assert(Fixture.install_runtime_skill(manager,id,preset.rarities[index]))
		var skill: RefCounted = manager.get_skill(id)
		assert(skill != null)
		skill.current_level = int(preset.levels[index])
		manager._refresh_skill_modifier_payload(skill)
	if preset.has("fusion"):
		var qualification: Dictionary = preload("res://scripts/skills/skill_requirement_policy.gd").new().evaluate(player,GameData.get_skill(preset.fusion))
		assert(qualification.available, str(qualification.missing_requirements))
		if fusion_enabled: assert(Fixture.install_runtime_skill(manager,StringName(preset.fusion),"epic"))
		else:
			var skill: RefCounted = manager.get_skill(preset.skills[0])
			skill.current_level += 1
			manager._refresh_skill_modifier_payload(skill)
	var world: Node = ui.get("_run_scene_coordinator").get_run_scene_parent(self)
	var fixed: bool = scenario.id != "real_300s"
	if fixed:
		for spawner: Node in get_nodes_in_group(&"enemy_spawner"): spawner.set_physics_process(false)
		for enemy: Node in get_nodes_in_group(&"enemy"): enemy.queue_free()
		await process_frame
		for i: int in int(scenario.count):
			var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
			enemy.enemy_id = StringName(scenario.enemy_id)
			enemy.position = player.position+Vector2(100 if scenario.id == "boss_stationary_phase" else 230,0).rotated(float(i)*TAU/float(scenario.count))
			world.add_child(enemy)
	var driver: Node = Controller.new()
	world.add_child(driver)
	driver.set("_player",player)
	driver.set("_ui",ui)
	var metrics: RefCounted = Metrics.new()
	root.set_meta(Metrics.META,metrics)
	var bus: Node = player.get_node("SkillEventBus")
	var initial_time: float = bus.combat_seconds()
	var duration: float = float(config.fixed_scene_seconds if fixed else config.real_run_seconds)
	var elapsed: float = 0.0
	var last_frame: int = Time.get_ticks_usec()
	var initial_nodes: int = get_node_count()
	var peak_queue: int = 0
	var control_step: float = 0.0
	var terminal: String = "horizon"
	var iterations: int = 0
	var wall_start: int = Time.get_ticks_msec()
	var stationary: bool = fixed and scenario.id != "mobile_boss"
	var samples: Array = []
	var sample_at: float = 1.0
	while elapsed < duration:
		await physics_frame
		iterations += 1
		if iterations%600 == 0: print("EPISODE state=%s time=%.2f frames=%d hp=%d" % [ui.current_state,elapsed,iterations,player.current_health])
		if iterations > 24000 or Time.get_ticks_msec()-wall_start > 360000:
			terminal="watchdog"
			break
		if not is_instance_valid(player): terminal="player_removed"; break
		var now: int = Time.get_ticks_usec()
		var seconds: float = bus.combat_seconds()-initial_time
		if ui.current_state != "RUNNING":
			if str(ui.current_state).begins_with("RESULT_"): terminal=str(ui.current_state); break
			# Fixed build budget: discard pending rewards/upgrades, never grant extra stats or healing.
			var choice: RefCounted = ui.get("_run_choice_modal_controller")
			choice.pending_level_up_count = 0
			choice.pending_reward_kinds.clear()
			ui.transition_to("RUNNING")
			paused = false
			last_frame = Time.get_ticks_usec()
			continue
		elapsed = seconds
		if elapsed > 2.0: metrics.record({"kind":"frame","milliseconds":float(now-last_frame)/1000.0,"objects":maxi(get_node_count()-initial_nodes,0)})
		last_frame = now
		peak_queue = maxi(peak_queue,bus.get("_pending_events").size())
		if elapsed >= sample_at:
			samples.append({"seconds":elapsed,"damage":metrics.snapshot().actual_damage,"objects":get_node_count(),"pending":bus.get("_pending_events").size()})
			sample_at += 1.0
		control_step += 1.0/60.0
		if control_step >= .1:
			if not stationary: driver._drive_player(control_step)
			else: driver._release_movement()
			for source: Dictionary in player.get_node("ModifierStore").get_debug_sources().values():
				if source.has("remaining"): metrics.record({"kind":"buff","duration":control_step})
			for enemy: Node in get_nodes_in_group(&"enemy"):
				if enemy.has_status(&"frozen"): metrics.record({"kind":"control","seconds":control_step})
			control_step=0
		if int(player.current_health)<=0: terminal="death"; break
		if fixed and get_nodes_in_group(&"enemy").is_empty(): terminal="cleared"; break
	var result: Dictionary = metrics.snapshot()
	result.merge({"config_revision":FileAccess.get_sha256("res://tools/verify/skill_balance_presets.json"),"controller_policy":("hold_position" if stationary else preset.controller_policy),"preset":preset.id,"scenario":scenario.id,"seed":seed_value,"cohort":cohort,"seconds":elapsed,"terminal":terminal,"fusion_enabled":fusion_enabled,"player_health":player.current_health,"player_max_health":player.max_health,"power":player.attack_power,"survival_assist":false,"enemy_stats_changed":false,"budget":preset.upgrade_budget,"pending_peak":peak_queue,"completed_300s":not fixed and elapsed>=300,"rng_seeds":environment.rng_seeds.duplicate(true),"time_scale":Engine.time_scale,"viewport":str(root.size),"player_level_start":preset.player_level,"series":samples,"stationary_boss_proxy":scenario.id=="boss_stationary_phase"})
	root.remove_meta(Metrics.META)
	driver._release_movement()
	paused=false
	ui.get("_run_scene_coordinator").teardown(self)
	scene.queue_free()
	await process_frame
	await process_frame
	return result
func _write() -> void:
	var file: FileAccess = FileAccess.open(report_dir+"/matrix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"mode":mode,"cohort":cohort,"source_revision":environment.revision,"rows":rows,"targets":{"single_span":1.5,"clear_span":1.8,"fusion_min":.15,"fusion_max":.35},"automatic_controller":true,"human_playtest":false},"  "))
	file.close()
	var csv: FileAccess = FileAccess.open(report_dir+"/matrix.csv",FileAccess.WRITE)
	var keys: Array = ["preset","scenario","seed","fusion_enabled","seconds","terminal","actual_damage","overkill","status_damage","trigger_count","buff_uptime","shield_generated","shield_absorbed","control_seconds","resource_cycles","boss_trigger_count","object_peak","pending_peak","frame_p95","completed_300s"]
	csv.store_csv_line(PackedStringArray(keys))
	for row: Dictionary in rows:
		var values: PackedStringArray = []
		for key: String in keys: values.append(str(row[key]))
		csv.store_csv_line(values)
	csv.close()
