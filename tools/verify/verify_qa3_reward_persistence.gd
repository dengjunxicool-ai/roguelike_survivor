extends "res://tools/verify/qa_app_fixture.gd"
const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")
const PacketBuilder = preload("res://scripts/combat/damage_packet_builder.gd")
var evidence: Dictionary = {}
var out_dir: String = ""
var inject: bool = true
var death_signals: int = 0
var card_souls: int = 0
var soul_multiplier: float = 1.0
var balance_before_enemy: int = 100

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): out_dir = argument.trim_prefix("--evidence-dir=")
		if argument == "--inject-failure": inject = true
		if argument == "--control": inject = false
		if argument == "--card": card_souls = 20
		if argument == "--gain2": soul_multiplier = 2.0
	if out_dir == "": out_dir = ProjectSettings.globalize_path("user://").replace("\\", "/")
	var save_path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH).replace("\\", "/")
	check(save_path.begins_with("E:/codex/") and out_dir.begins_with("E:/codex/"), "all QA output isolated on E drive")
	check(SaveManager.reset_progress() and SaveManager.add_soul_stones(100) == 100, "seed legitimate currency 100")
	await setup_run()
	player.set("soul_gain_multiplier", soul_multiplier)
	if card_souls > 0:
		var dispatcher: RefCounted = ui._run_choice_modal_controller.get("_command_dispatcher")
		var card_result: Dictionary = dispatcher.call("dispatch", UICommand.apply_choice_option({"id": "reward_soul_stones", "payload": {"reward_kind": "elite", "amount": card_souls}}), {"player": player, "tree": self})
		check(bool(card_result.get("consumed_reward", false)) and SaveManager.get_soul_stones() == 100 + card_souls, "real soul card commits before enemy save failure")
	balance_before_enemy = SaveManager.get_soul_stones()
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.set("enemy_id", &"skeleton_captain")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(enemy)
	enemy.set("target", player)
	enemy.connect("died", func() -> void: death_signals += 1)
	check(enemy.get("soul_drop") == 35 and enemy.get("current_health") == 1150, "production skeleton captain loads 35 soul drop and 1150 HP")
	var drop: int = maxi(roundi(float(enemy.get("soul_drop")) * float(player.get("soul_gain_multiplier"))), 0)
	evidence["expected_drop"] = drop
	evidence["balance_before"] = SaveManager.get_soul_stones()
	evidence["enemy_id"] = String(enemy.get("enemy_id"))
	evidence["enemy_rank"] = String(enemy.get_meta("enemy_rank", "normal"))
	evidence["inject_failure"] = inject
	var before_bytes: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var temporary_path: String = save_path + ".tmp"
	var old_print_errors: bool = Engine.print_error_messages
	if inject:
		check(DirAccess.make_dir_absolute(temporary_path) == OK, "inject temporary-file directory collision")
		Engine.print_error_messages = false
		check(SaveManager.add_soul_stones(1) == -1, "fault probe confirms failed currency write")
	var packet: DamagePacket = PacketBuilder.from_skill_action_object({"amount": 1000000, "damage_type": &"direct_physical", "element": &"physical", "params": {"can_crit": false, "can_trigger_reaction": false, "uses_character_damage_multiplier": false, "uses_skill_level_coefficient": false, "ignore_defense": true, "ignore_resistance": true}, "context": {"caster": player, "target": enemy, "skill_id": &"fireball", "source_instance_id": &"qa_reward:1"}})
	enemy.call("take_damage", packet)
	evidence["death_signals_immediate"] = death_signals
	evidence["dead_immediate"] = enemy.call("is_dead")
	evidence["hp_immediate"] = enemy.get("current_health")
	evidence["queued_for_deletion"] = enemy.is_queued_for_deletion()
	evidence["balance_after_death"] = SaveManager.get_soul_stones()
	evidence["save_unchanged_after_death"] = FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == before_bytes
	check(death_signals == 1 and bool(enemy.call("is_dead")), "actual typed damage enters production death pipeline once")
	ui._on_boss_defeated(0.0)
	await settle()
	var result_labels: Dictionary = ui._result_controller.get("_labels_by_state")["RESULT_VICTORY"]
	check(ui._get_result_state().get("run_souls_earned", -1) == drop + card_souls and String(result_labels["soul"].text).begins_with("本局获得：%d /" % (drop + card_souls)), "same-run result displays earned captain and committed card souls exactly once")
	await settle(6)
	Engine.print_error_messages = old_print_errors
	evidence["enemy_released"] = not is_instance_valid(enemy)
	check(not is_instance_valid(enemy), "production death releases reward owner")
	if inject:
		check(DirAccess.remove_absolute(temporary_path) == OK, "remove storage fault")
		check(SaveManager.save_value("qa", "recovered_probe", true), "storage recovers")
		await create_timer(1.3, true).timeout
		evidence["balance_after_recovery"] = SaveManager.get_soul_stones()
		check(SaveManager.get_soul_stones() == balance_before_enemy + drop, "recovery retains dead enemy reward exactly once")
	else:
		check(SaveManager.get_soul_stones() == balance_before_enemy + drop, "control saves actual production enemy reward")
	ui._refresh_result_screen("RESULT_VICTORY")
	await settle()
	check(SaveManager.get_last_run_summary().get("run_souls_earned", -1) == drop + card_souls, "saved summary retains earned captain and card souls after recovery or normal commit")
	check(String(result_labels["soul"].text).begins_with("本局获得：%d /" % (drop + card_souls)), "repeated result refresh preserves earned souls")
	print("REWARD_EVIDENCE ", JSON.stringify(evidence))
	var file := FileAccess.open(out_dir.path_join("evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	await finish()
