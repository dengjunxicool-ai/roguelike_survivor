extends SceneTree


const TrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const ResultStateScript: Script = preload("res://scripts/ui/run_result_state_builder.gd")
const ViewModelScript: Script = preload("res://scripts/ui/screens/result_screen_view_model_builder.gd")
const DiagnosticScript: Script = preload("res://scripts/game/run_diagnostic_service.gd")
const EnemyScript: Script = preload("res://scripts/enemies/enemy_base.gd")
const DamageApplicationScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const PlayerScene: PackedScene = preload("res://scenes/characters/player.tscn")
const CommandDispatcherScript: Script = preload("res://scripts/ui/ui_command_dispatcher.gd")
const UICommandScript: Script = preload("res://scripts/ui/ui_command.gd")
const SkillLearnDefinitionScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const SkillLearnOptionScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path: String = ProjectSettings.globalize_path("user://save.cfg").replace("\\", "/")
	if not save_path.to_lower().begins_with("e:/codex/"):
		_expect(false, "verification user directory must be isolated under E:/codex", save_path)
		quit(1)
		return
	_verify_real_combat_result_chain()
	_verify_empty_and_no_damage_results()
	_verify_run_termination_and_source_labels()
	_verify_dynamic_skill_learning_result_chain()
	print("[verify_run_result_diagnostics] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _verify_real_combat_result_chain() -> void:
	var tracker: Node = TrackerScript.new()
	root.add_child(tracker)
	tracker.call("reset_run", &"mage", &"abandoned_dungeon", "地下城")
	var player: Node = PlayerScene.instantiate()
	root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var manager: Node = player.get_node("SkillManager")
	var primary: RefCounted = manager.call("get_primary_attack_method")
	_expect(primary != null, "real mage has a primary attack")
	if primary != null:
		primary.call("level_up")
		primary.call("level_up")
	_expect(bool(manager.call("add_skill", &"fire_cast_meteor_rain")), "real manager learns meteor skill")
	_expect(bool(manager.call("upgrade_skill", &"fire_cast_meteor_rain")), "real manager upgrades meteor skill")
	player.connect("upgrade_applied", Callable(tracker, "record_upgrade_applied"))
	player.call("apply_upgrade", &"skill_level_up:fire_cast_meteor_rain:3:rare")
	var boss: Node = EnemyScript.new()
	boss.set("load_config_from_data", false)
	boss.set("max_health", 200)
	boss.set("_behavior", {"type": "chase_player"})
	boss.set_meta("enemy_rank", "boss")
	root.add_child(boss)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	tracker.call("set_run_time", 100.0)
	tracker.call("update_boss_snapshot", boss)
	var field_packet: DamagePacket = _packet(40, "field", "direct_magical", "field_test")
	boss.call("take_damage", field_packet)
	var special_packet: DamagePacket = _packet(20, "special", "true_damage", "special_test")
	boss.call("take_damage", special_packet)
	var incoming_packet: DamagePacket = _packet(12, "special", "true_damage", "boss_test")
	incoming_packet.set_value("source_id", "boss")
	DamageApplicationScript.apply_player_damage(player, incoming_packet)
	tracker.call("set_run_time", 110.0)
	var summary: Dictionary = tracker.call("get_summary")
	_expect(int(summary.get("damage_done_total", 0)) == 54, "real damage pipeline records post-mitigation damage", summary)
	_expect(int(summary.get("damage_done_by_origin", {}).get("field", 0)) == 34, "typed packet retains field origin", summary)
	_expect(int(summary.get("damage_done_by_origin", {}).get("special", 0)) == 20, "typed packet retains special origin", summary)
	_expect(int(summary.get("damage_taken_by_source", {}).get("boss", 0)) == 12, "typed packet retains boss damage source", summary)
	player.set("current_health", 0)
	var result_state: Dictionary = ResultStateScript.build_result_state({
		"tree": self, "run_stats_tracker": tracker, "selected_character_id": &"mage",
		"selected_map_id": &"abandoned_dungeon", "selected_map_name": "地下城", "run_seconds": 110.0
	})
	_expect(result_state.get("player_dead", null) == true, "result snapshots real player death", result_state)
	_expect(int(result_state.get("main_attack_level", 0)) == 3, "result gets actual primary attack level", result_state)
	var skill_snapshot: Array = result_state.get("skills_snapshot", [])
	_expect(_snapshot_has(skill_snapshot, "fireball", 3), "result includes primary attack snapshot", skill_snapshot)
	_expect(_snapshot_has(skill_snapshot, "fire_cast_meteor_rain", 3), "result includes final learned skill level", skill_snapshot)
	var view_model: Dictionary = ViewModelScript.new().call("build", "RESULT_DEFEAT", result_state, [] as Array[String])
	var diagnostic: Dictionary = view_model.get("diagnostic", {})
	var labels: Dictionary = view_model.get("labels", {})
	_expect(is_equal_approx(float(diagnostic.get("boss_dps", 0.0)), 5.4), "boss DPS survives diagnostic boundary", diagnostic)
	_expect(is_equal_approx(float(diagnostic.get("damage_share", {}).get("field", 0.0)), 34.0 / 54.0), "damage share uses recorded amounts", diagnostic)
	_expect(is_equal_approx(float(diagnostic.get("damage_taken_share", {}).get("boss", 0.0)), 1.0), "taken share uses recorded source", diagnostic)
	_expect(String(labels.get("summary", "")).contains("流星火雨") and String(labels.get("summary", "")).contains("Lv.3"), "build label displays final skills", labels)
	_expect(String(labels.get("upgrades", "")).begins_with("已选升级：") and String(labels.get("upgrades", "")).contains("流星火雨"), "upgrade label displays real selected skill upgrade", labels)
	_expect(String(labels.get("damage", "")).contains("区域") and not String(labels.get("damage", "")).contains("暂无"), "damage label displays populated structure", labels)
	_expect(String(labels.get("taken", "")).contains("Boss 100%"), "taken label displays boss source", labels)
	_expect(String(labels.get("cause", "")).contains("Boss"), "death cause uses last recorded damage source", labels)
	_expect(String(labels.get("diagnosis", "")).length() > 3 and String(labels.get("suggestion", "")).length() > 5 and String(view_model.get("reason", "")).length() > 5, "diagnosis suggestion and reason are populated", view_model)
	# Direct health mutation used by autoplay assistance must not become recorded damage.
	boss.set("current_health", 1)
	_expect(int(tracker.call("get_summary").get("boss_damage_done", 0)) == 54, "health-only autoplay assistance does not inflate real damage")
	primary = null
	player.free()
	boss.free()
	tracker.free()


func _verify_empty_and_no_damage_results() -> void:
	var empty_state: Dictionary = {"selected_character_id": &"mage", "selected_map_id": &"abandoned_dungeon"}
	var empty_view: Dictionary = ViewModelScript.new().call("build", "RESULT_DEFEAT", empty_state, [] as Array[String])
	var empty_labels: Dictionary = empty_view.get("labels", {})
	_expect(String(empty_labels.get("summary", "")).length() > "构筑摘要：".length(), "empty build has explicit fallback", empty_labels)
	_expect(String(empty_labels.get("damage", "")).contains("未造成伤害"), "zero outgoing damage has explicit fallback", empty_labels)
	_expect(String(empty_labels.get("taken", "")).contains("未受到伤害"), "no-hit run has explicit fallback", empty_labels)
	_expect(String(empty_labels.get("cause", "")).contains("未记录"), "no recorded hit does not fabricate death cause", empty_labels)
	var victory_view: Dictionary = ViewModelScript.new().call("build", "RESULT_VICTORY", {
		"run_stats": {"last_damage_source": "boss", "damage_taken_total": 12, "damage_taken_by_source": {"boss": 12}}
	}, [] as Array[String])
	_expect(String(victory_view.get("labels", {}).get("cause", "")).contains("未死亡"), "victory does not show last hit as death cause", victory_view)
	var recommendation: Dictionary = DiagnosticScript.build_diagnostic({"run_stats": {"damage_taken_total": 50, "damage_done_total": 10}})
	_expect(String(recommendation.get("next_run_suggestion", "")).contains("生存"), "existing survival recommendation remains available", recommendation)


func _verify_run_termination_and_source_labels() -> void:
	var player: Node = PlayerScene.instantiate()
	root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var living_state: Dictionary = ResultStateScript.build_result_state({"tree": self})
	living_state["run_stats"] = {"last_damage_source": "boss", "damage_taken_by_source": {"boss": 12}}
	_expect(living_state.get("player_dead", null) == false, "result snapshots living player on abandonment", living_state)
	var living_view: Dictionary = ViewModelScript.new().call("build", "RESULT_DEFEAT", living_state, [] as Array[String])
	_expect(String(living_view.get("labels", {}).get("cause", "")).contains("主动结束"), "living abandonment does not report previous hit as death", living_view)
	player.free()
	var unknown_state: Dictionary = ResultStateScript.build_result_state({"tree": self})
	unknown_state["run_stats"] = {"last_damage_source": "boss"}
	_expect(unknown_state.get("player_dead", null) == null, "missing player death state remains unknown", unknown_state)
	var unknown_view: Dictionary = ViewModelScript.new().call("build", "RESULT_DEFEAT", unknown_state, [] as Array[String])
	_expect(String(unknown_view.get("labels", {}).get("cause", "")).contains("未记录"), "unknown player state does not invent death or abandonment", unknown_view)
	for fixture: Dictionary in [{"source": "map_toxic_fog", "label": "毒雾"}, {"source": "ranged", "label": "远程伤害"}]:
		var source: String = String(fixture["source"])
		var result: Dictionary = ViewModelScript.new().call("build", "RESULT_DEFEAT", {
			"player_dead": true, "run_stats": {"last_damage_source": source, "damage_taken_by_source": {source: 20}, "damage_taken_total": 20}
		}, [] as Array[String])
		var labels: Dictionary = result.get("labels", {})
		_expect(String(labels.get("cause", "")).contains(String(fixture["label"])), "death cause localizes %s" % source, labels)
		_expect(String(labels.get("taken", "")).contains(String(fixture["label"])), "taken share localizes %s" % source, labels)


func _verify_dynamic_skill_learning_result_chain() -> void:
	var tracker: Node = TrackerScript.new()
	root.add_child(tracker)
	tracker.call("reset_run", &"mage", &"abandoned_dungeon")
	var player: Node = PlayerScene.instantiate()
	root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.connect("upgrade_applied", Callable(tracker, "record_upgrade_applied"))
	var skill: Dictionary = GameData.get_skill(&"fire_cast_lava_rift")
	var upgrade: Dictionary = SkillLearnDefinitionScript.resolve_upgrade(&"learn_skill_fire_cast_lava_rift")
	var option: Dictionary = SkillLearnOptionScript.build_option_data(skill, upgrade, "rare")
	CommandDispatcherScript.new().call("dispatch", UICommandScript.apply_choice_option(option), {"player": player, "tree": self})
	var manager: Node = player.get_node("SkillManager")
	var learned: RefCounted = manager.call("get_skill", &"fire_cast_lava_rift") as RefCounted
	_expect(learned != null, "UI learning card adds real lava skill")
	_expect(learned != null and String(learned.get("current_rarity")) == "rare", "UI learning card preserves rarity")
	var summary: Dictionary = tracker.call("get_summary")
	_expect(int(summary.get("upgrade_counts", {}).get("level_up_upgrade:learn_skill_fire_cast_lava_rift:rare", 0)) == 1, "successful UI learning records selected upgrade", summary)
	var state: Dictionary = ResultStateScript.build_result_state({"tree": self, "run_stats_tracker": tracker})
	_expect(_snapshot_has(state.get("skills_snapshot", []), "fire_cast_lava_rift", 1), "learned lava reaches final build snapshot", state)
	var diagnostic: Dictionary = DiagnosticScript.build_diagnostic(state)
	_expect(String(diagnostic.get("upgrade_summary", "")).contains("熔岩裂涌") and not String(diagnostic.get("upgrade_summary", "")).contains("learn_skill_"), "learning upgrade summary uses actual Chinese name", diagnostic)
	learned = null
	player.free()
	tracker.free()


func _packet(amount: int, origin: String, damage_type: String, source_instance_id: String) -> DamagePacket:
	return DamagePacket.from_dictionary({
		"raw_amount": amount, "amount": amount, "damage_origin": origin, "damage_type": damage_type,
		"element": "fire", "source_instance_id": source_instance_id, "source_origin_id": "diagnostic_test", "can_crit": false,
		"uses_character_damage_multiplier": false, "uses_skill_level_coefficient": false,
		"ignore_defense": true, "ignore_resistance": true, "ignore_vulnerability": true
	})


func _snapshot_has(snapshot: Array, skill_id: String, level: int) -> bool:
	for item: Dictionary in snapshot:
		if String(item.get("skill_id", "")) == skill_id and int(item.get("level", 0)) == level:
			return true
	return false


func _expect(condition: bool, label: String, actual: Variant = null) -> void:
	if condition:
		print("[verify_run_result_diagnostics] PASS %s" % label)
		return
	_failed = true
	push_error("[verify_run_result_diagnostics] FAIL %s actual=%s" % [label, str(actual)])
