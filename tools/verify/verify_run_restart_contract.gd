extends SceneTree

const APP_SCENE: PackedScene = preload("res://scenes/app/app_bootstrap.tscn")
const Save := preload("res://scripts/game/save_manager.gd")
const Packet := preload("res://scripts/combat/damage_packet.gd")
const Request := preload("res://scripts/enemies/spawning/enemy_spawn_request.gd")
const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const LEARNED_SKILL_ID: StringName = &"fire_cast_meteor_rain"
const MODIFIER_SOURCE: StringName = &"restart_contract"

var _failed: bool = false
var _save_path: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_save_path = ProjectSettings.globalize_path("user://save.cfg").replace("\\", "/")
	if not _expect(_save_path.to_lower().begins_with("e:/codex/"), "save directory is isolated under E:/codex", _save_path):
		quit(1)
		return
	create_timer(15.0, true).timeout.connect(_timeout)
	_clean_save()
	var owner: Node = root.get_node_or_null("DataManager")
	if not _expect(owner != null and bool(owner.get("is_loaded")), "real content owner is ready"):
		quit(1)
		return
	var app: Node = APP_SCENE.instantiate()
	root.add_child(app)
	for _frame: int in range(4):
		await process_frame
	var ui: Node = app.get_node("UIManager")
	_expect(String(ui.get("current_state")) == "TITLE", "real application reaches title")
	ui.call("transition_to", "CHARACTER_SELECT")
	ui.call("_on_loadout_confirmed", CHARACTER_ID)
	_expect(String(ui.get("current_state")) == "MAP_SELECT", "character confirmation reaches map selection")
	await ui.call("_start_run", MAP_ID)
	var coordinator: RefCounted = ui.get("_run_scene_coordinator")
	var main: Node = coordinator.call("get_run_scene_parent", self)
	if not _expect(main != null and main != app and main.get_node_or_null("Player") != null, "start_run creates a real combat scene"):
		await _finish(app, ui)
		return
	# Keep autonomous combat out of the deterministic lifecycle assertions.
	# Scene assembly, loadout, damage, death, rewards and restart use production entry points.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node2D = main.get_node("Player")
	var manager: Node = player.get_node_or_null("SkillManager")
	var tracker: Node = ui.get("_run_stats_tracker")
	var spawner: Node = main.get_node("EnemySpawner")
	var store: Node = player.get_node_or_null("ModifierStore")
	if not _expect(manager != null and tracker != null and store != null, "real player and run subsystems are assembled"):
		await _finish(app, ui)
		return
	var starting_id: StringName = StringName(GameData.get_character(CHARACTER_ID).starting_skill_id)
	var primary: RefCounted = manager.call("get_primary_attack_method")
	_expect(String(ui.get("current_state")) == "RUNNING" and not paused, "real run enters unpaused running state")
	_expect(StringName(player.get("selected_character_id")) == CHARACTER_ID and StringName(ui.get("_selected_map_id")) == MAP_ID, "selected owner loadout is applied")
	_expect(primary != null and StringName(primary.get("skill_id")) == starting_id, "primary attack comes from owner character reference")
	if primary != null:
		var definition: RefCounted = primary.get("definition")
		var starting: Dictionary = GameData.get_skill(starting_id)
		_expect(definition.get("display_name") == starting.display_name and definition.get("skill_type") == starting.skill_type and definition.get("base") == starting.base, "primary runtime retains canonical owner definition")
	var baseline_skills: Array[StringName] = _skill_ids(manager)
	var baseline_speed: float = float(player.get("move_speed"))
	_expect(manager.call("add_skill", LEARNED_SKILL_ID), "real manager learns canonical skill")
	_expect(manager.call("get_skill", LEARNED_SKILL_ID).get("school") == &"fire", "learned runtime uses canonical school")
	player.call("set_run_modifier_source", MODIFIER_SOURCE, [{"stat": "move_speed", "op": "add", "value": 42.0, "scope": {}, "source": "restart_contract"}])
	_expect(store.call("get_debug_sources").has(String(MODIFIER_SOURCE)), "first run stores a structured modifier source")
	_expect(player.call("apply_status", &"burning", {"duration": 10.0, "damage": 1.0}), "first run holds a transient status")
	player.set("_dash_cooldown_remaining", 7.0)
	var expected_souls: int = Save.get_soul_stones()
	var expected_crystals: int = get_nodes_in_group(&"experience_crystal").size()
	for rank: String in ["normal", "elite"]:
		var config: Dictionary = _enemy_for_rank(rank)
		if not _expect(not config.is_empty(), "owner defines " + rank + " enemy"):
			continue
		var enemy: Node2D = spawner.call("spawn_enemy", Request.create(config.id, {"parent": main, "position": Vector2(1400, 1400), "spawn_clearance": 0.0}))
		if not _expect(enemy != null, "real spawn creates " + rank):
			continue
		_expect(String(enemy.get_meta("enemy_rank", "")) == rank, "spawn derives canonical " + rank + " classification")
		ui.call("_update_run_hud")
		var previous_kills: int = int(ui.get("_kill_count"))
		expected_souls += maxi(roundi(float(enemy.get("soul_drop")) * float(player.get("soul_gain_multiplier"))), 0)
		if int(enemy.get("dropped_experience")) > 0:
			expected_crystals += 1
		var packet: DamagePacket = _lethal_packet(player, enemy, starting_id, "restart_enemy_" + rank)
		enemy.call("take_damage", packet)
		enemy.call("take_damage", packet)
		enemy.call("_die")
		_expect(bool(enemy.get("_is_dead")) and int(ui.get("_kill_count")) == previous_kills + 1, rank + " death signal is recorded once")
		_expect(Save.get_soul_stones() == expected_souls, rank + " death awards soul once")
		_expect(get_nodes_in_group(&"experience_crystal").size() == expected_crystals, rank + " death drops experience once")
	_expect(int(tracker.get("kill_count")) == 2 and int(tracker.get("elite_kill_count")) == 1, "real tracker records normal and elite kills")
	var transient: Node2D = spawner.call("spawn_enemy", Request.create(_enemy_for_rank("normal").id, {"parent": main, "position": Vector2(1500, 1500), "spawn_clearance": 0.0}))
	var transient_id: int = transient.get_instance_id()
	await create_timer(0.25, true).timeout
	player.call("take_damage", _lethal_packet(null, player, &"", "restart_player_first"))
	if not _expect(String(ui.get("current_state")) == "RESULT_DEFEAT" and int(player.get("current_health")) == 0, "typed lethal damage enters real defeat result"):
		await _finish(app, ui)
		return
	_expect(Save.get_counter(&"total_runs") == 1 and Save.get_counter(&"defeats") == 1, "first terminal result is persisted once")
	ui.call("_refresh_result_screen", "RESULT_DEFEAT")
	ui.call("_refresh_result_screen", "RESULT_DEFEAT")
	ui.call("_on_boss_defeated", 240.0)
	_expect(Save.get_counter(&"total_runs") == 1 and String(ui.get("current_state")) == "RESULT_DEFEAT", "repeat refresh and late victory preserve first result")
	var summary: Dictionary = Save.get_last_run_summary()
	_expect(int(summary.get("kill_count", -1)) == 2, "persisted summary includes real kill signals")
	var scene_id: int = main.get_instance_id()
	await ui.call("_start_run", MAP_ID)
	_expect(coordinator.call("get_run_scene_parent", self).get_instance_id() == scene_id, "restart resets the same real scene")
	await process_frame
	_expect(String(ui.get("current_state")) == "RUNNING" and not paused, "restart re-enters running state")
	_expect(int(player.get("current_health")) == int(player.get("max_health")) and int(player.get("level")) == int(player.get("starting_level")), "restart restores loadout health and starting level")
	_expect(_skill_ids(manager) == baseline_skills and not manager.call("has_learned_skill", LEARNED_SKILL_ID), "restart clears learned skills and restores primary attack")
	_expect(not store.call("get_debug_sources").has(String(MODIFIER_SOURCE)) and is_equal_approx(float(player.get("move_speed")), baseline_speed), "restart removes first-run modifier source and numeric effect")
	_expect(not player.call("has_status", &"burning") and float(player.get("_dash_cooldown_remaining")) == 0.0, "restart clears transient status and dash cooldown")
	_expect(not is_instance_id_valid(transient_id) and get_nodes_in_group(&"enemy").is_empty() and get_nodes_in_group(&"experience_crystal").is_empty(), "restart removes transient enemies and pickups")
	_expect(int(ui.get("_kill_count")) == 0 and int(tracker.get("kill_count")) == 0 and int(tracker.get("elite_kill_count")) == 0 and tracker.get("damage_done_by_origin").is_empty(), "restart clears UI and tracker combat statistics")
	_expect(not bool(ui.get("_result_progression_recorded")) and ui.get("_last_progression_summary").is_empty(), "restart clears terminal persistence lock and summary")
	_expect(Save.get_counter(&"total_runs") == 1, "restart preserves only the first persisted run")
	player.call("take_damage", _lethal_packet(null, player, &"", "restart_player_second"))
	_expect(int(player.get("current_health")) == 0, "second run also dies through typed damage")
	ui.call("_refresh_result_screen", "RESULT_DEFEAT")
	ui.call("_on_player_died")
	_expect(String(ui.get("current_state")) == "RESULT_DEFEAT" and Save.get_counter(&"total_runs") == 2 and Save.get_counter(&"defeats") == 2, "second death records exactly the second run")
	_expect(int(Save.get_last_run_summary().get("kill_count", -1)) == 0, "second summary contains no first-run kill state")
	await _finish(app, ui)


func _lethal_packet(attacker: Node, target: Node, skill_id: StringName, identity: String) -> DamagePacket:
	return Packet.from_dictionary({"raw_amount": 1000000.0, "damage_origin": "primary_attack", "damage_type": "direct_physical", "element": "physical", "source_origin_id": identity, "source_skill_id": String(skill_id), "source_instance_id": identity, "attacker_id": str(attacker.get_instance_id()) if attacker != null else identity, "source_id": identity, "can_crit": false, "can_trigger_reaction": false, "uses_character_damage_multiplier": false, "uses_skill_level_coefficient": false, "ignore_defense": true, "ignore_resistance": true, "ignore_vulnerability": true, "ignore_min_damage": true}, attacker, target)


func _enemy_for_rank(rank: String) -> Dictionary:
	for definition: Dictionary in GameData.get_enemy_pool():
		if definition.enemy_rank == rank:
			return definition
	return {}


func _skill_ids(manager: Node) -> Array[StringName]:
	var ids: Array[StringName] = []
	for skill: RefCounted in manager.call("get_all_skills"):
		ids.append(StringName(skill.get("skill_id")))
	return ids


func _finish(app: Node, ui: Node) -> void:
	paused = false
	ui.call("_teardown_run_scene")
	app.queue_free()
	await process_frame
	_clean_save()
	print("[verify_run_restart_contract] done failed=%s" % _failed)
	quit(1 if _failed else 0)


func _clean_save() -> void:
	if _save_path != "" and FileAccess.file_exists(_save_path):
		var error: Error = DirAccess.remove_absolute(_save_path)
		_expect(error == OK or error == ERR_DOES_NOT_EXIST, "isolated save can be removed", error)


func _timeout() -> void:
	_expect(false, "real run lifecycle completes within the fixture deadline")
	_clean_save()
	quit(1)


func _expect(condition: bool, label: String, actual: Variant = null) -> bool:
	if condition:
		print("[verify_run_restart_contract] PASS " + label)
		return true
	_failed = true
	push_error("[verify_run_restart_contract] FAIL %s actual=%s" % [label, str(actual)])
	return false
