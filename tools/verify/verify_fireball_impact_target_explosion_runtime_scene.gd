extends Node


const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
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
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(get_tree().root)

	var impact_target: Node2D = _spawn_enemy(&"small_slime", Vector2.ZERO)
	var splash_target: Node2D = _spawn_enemy(&"small_slime", Vector2(24.0, 0.0))
	var packet: Dictionary = DamagePacketBuilderScript.from_skill_action({
		"params": {
			"source_instance_id": "fireball:test:explosion:generic_explosion_area",
			"can_crit": false,
			"uses_character_damage_multiplier": false,
			"uses_skill_level_coefficient": false,
			"ignore_defense": true,
			"ignore_resistance": true,
			"ignore_vulnerability": true
		},
		"context": {
			"skill_id": &"fireball",
			"source_origin_id": &"fire_staff",
			"debug_attack_trace_id": trace_id
		},
		"amount": 20,
		"source_type": "explosion",
		"damage_origin": "reaction",
		"damage_type": &"area_direct",
		"element": &"fire"
	})
	CombatObjectFactoryScript.create_area_effect({
		"parent": self,
		"area_id": &"generic_explosion_area",
		"source_id": &"generic_explosion_area",
		"position": Vector2.ZERO,
		"damage": 20,
		"damage_type": &"area_direct",
		"damage_packet": packet,
		"duration": 0.12,
		"tick_interval": 0.1,
		"radius": 80,
		"target_group": &"enemies",
		"impact_target_id": str(impact_target.get_instance_id()),
		"impact_target_damage_multiplier": 0.5
	})

	for _frame_index: int in range(3):
		await get_tree().process_frame

	var records: Array = DebugCombatTraceScript.get_records(get_tree().root)
	var impact_record: Dictionary = {}
	var splash_record: Dictionary = {}
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		if String(record.get("target_id", "")) == str(impact_target.get_instance_id()):
			impact_record = record
		elif String(record.get("target_id", "")) == str(splash_target.get_instance_id()):
			splash_record = record

	_expect(not impact_record.is_empty(), "records directly hit target explosion damage")
	_expect(not splash_record.is_empty(), "records splash target explosion damage")
	if not impact_record.is_empty() and not splash_record.is_empty():
		_lines.append("impact_final=%d splash_final=%d" % [int(impact_record.get("final_amount", 0)), int(splash_record.get("final_amount", 0))])
		_expect(int(impact_record.get("final_amount", 0)) == 10, "directly hit target takes 50% explosion damage")
		_expect(int(splash_record.get("final_amount", 0)) == 20, "splash target takes full explosion damage")

	_write_result()
	get_tree().quit(1 if _failed else 0)


func _spawn_enemy(enemy_id: StringName, position: Vector2) -> Node2D:
	var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate() as Node2D
	enemy.set("enemy_id", enemy_id)
	add_child(enemy)
	enemy.global_position = position
	enemy.set("max_health", 999)
	enemy.set("current_health", 999)
	return enemy


func _expect(condition: bool, message: String) -> void:
	var line: String = "[PASS] %s" % message if condition else "[FAIL] %s" % message
	_lines.append(line)
	if condition:
		return
	_failed = true


func _write_result() -> void:
	var file: FileAccess = FileAccess.open("user://verify_fireball_impact_target_explosion_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
