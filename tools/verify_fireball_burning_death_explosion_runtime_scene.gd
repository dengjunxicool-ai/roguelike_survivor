extends Node


const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")

var _failed: bool = false
var _lines: Array[String] = []


func _ready() -> void:
	_run_check()


func _run_check() -> void:
	await get_tree().process_frame
	get_tree().root.set_meta("developer_mode_enabled", true)
	get_tree().root.set_meta("debug_control_mode", true)

	var main: Node2D = Node2D.new()
	main.name = "RuntimeVerifierMain"
	add_child(main)

	var player: Node2D = load("res://scenes/player.tscn").instantiate() as Node2D
	main.add_child(player)
	await get_tree().process_frame
	player.call("reset_for_loadout", CharacterLoadoutServiceScript.build_loadout(&"mage", &"fire_staff"))
	player.set("crit_chance", 0.0)
	await get_tree().process_frame

	var branch_system: Node = player.get_node_or_null("WeaponBranchSystem")
	_expect(branch_system != null, "player has WeaponBranchSystem")
	if branch_system != null:
		_expect(bool(branch_system.call("apply_branch", player, &"fire_staff_branch_burst", true)), "applies burst fireball branch")
		_expect(bool(branch_system.call("apply_selected_branch_level", player, 3, &"fire_staff_branch_burst", true)), "applies burst fireball Lv3")
		_expect(bool(branch_system.call("apply_selected_branch_level", player, 4, &"fire_staff_branch_burst", true)), "applies burst fireball Lv4")
		_expect(bool(branch_system.call("apply_selected_branch_level", player, 5, &"fire_staff_branch_burst", true)), "applies burst fireball Lv5")

	var source_enemy: Node2D = _spawn_enemy(main, &"small_slime", Vector2(120.0, 0.0), 10)
	var target_enemy: Node2D = _spawn_enemy(main, &"small_slime", Vector2(130.0, 0.0), 999)
	await get_tree().process_frame

	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(get_tree().root)
	_expect(source_enemy.call("apply_status", &"burn", {
		"damage": 1,
		"duration": 3.0,
		"tick_interval": 1.0,
		"debug_attack_trace_id": trace_id
	}), "source enemy accepts traced burn status")

	var fatal_packet: Dictionary = DamagePacketBuilderScript.from_status_dot({
		"target": source_enemy,
		"amount": 999,
		"element": &"fire",
		"damage_type": &"status_dot",
		"debug_attack_trace_id": trace_id
	})
	source_enemy.call("take_damage", fatal_packet)

	var visual_area: Node = _find_area_effect(main, &"fireball_burning_death_explosion")
	_expect(visual_area != null, "creates circular fireball_burning_death_explosion area")
	if visual_area != null:
		_expect(absf(float(visual_area.get("radius")) - 80.0) <= 0.01, "death explosion visual area radius matches explosion radius")
		_expect(String(visual_area.get("_visual_style")) == "fire_burst", "death explosion uses fire burst circular visual style")

	for _frame_index: int in range(10):
		await get_tree().process_frame

	var records: Array = DebugCombatTraceScript.get_records(get_tree().root)
	var explosion_records: int = 0
	var death_explosion_damage_records: int = 0
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "explosion" and String(record.get("source_skill_id", record.get("skill_id", ""))) == "fireball_burning_death_explosion":
			explosion_records += 1
		if String(record.get("type", "")) == "damage" and String(record.get("source_skill_id", "")) == "fireball_burning_death_explosion":
			death_explosion_damage_records += 1

	_expect(explosion_records == 1, "records one fireball_burning_death_explosion explosion event")
	_expect(death_explosion_damage_records >= 1, "records fireball_burning_death_explosion damage")
	_expect(int(target_enemy.get("current_health")) < 999, "death explosion damages nearby target")
	_write_result()
	get_tree().quit(1 if _failed else 0)


func _spawn_enemy(parent: Node, enemy_id: StringName, position: Vector2, health: int) -> Node2D:
	var enemy: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
	enemy.set("enemy_id", enemy_id)
	parent.add_child(enemy)
	enemy.global_position = position
	enemy.set("max_health", health)
	enemy.set("current_health", health)
	return enemy


func _find_area_effect(parent: Node, source_id: StringName) -> Node:
	for child: Node in parent.get_children():
		if child is AreaEffect and StringName(String(child.get("source_id"))) == source_id:
			return child
		var nested: Node = _find_area_effect(child, source_id)
		if nested != null:
			return nested
	return null


func _expect(condition: bool, message: String) -> void:
	var line: String = "[PASS] %s" % message if condition else "[FAIL] %s" % message
	_lines.append(line)
	if condition:
		return
	_failed = true


func _write_result() -> void:
	var file: FileAccess = FileAccess.open("res://tools/verify_fireball_burning_death_explosion_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
