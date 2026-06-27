extends SceneTree


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")


class TestPlayer:
	extends Node2D

	signal health_changed(current_health: int, max_health: int)
	signal died

	var current_health: int = 100
	var max_health: int = 100
	var armor: int = 0
	var defense: int = 0
	var damage_taken_multiplier: float = 1.0
	var last_damage_taken: int = -1
	var last_damage_result: Dictionary = {}

	func _ready() -> void:
		add_to_group(&"player")

	func _is_damage_blocked_by_hit_protection(_source_packet: Variant) -> bool:
		return false

	func _apply_boss_overlap_protection(amount: int, _source_packet: Variant) -> int:
		return amount

	func _record_damage_taken(amount: int, damage_result: Dictionary, _source_packet: Variant) -> void:
		last_damage_taken = amount
		last_damage_result = damage_result.duplicate(true)

	func _show_damage_number(_amount: int, _damage_result: Dictionary) -> void:
		pass


var _failed: bool = false
var _lines: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: TestPlayer = TestPlayer.new()
	player.global_position = Vector2(64, 64)
	root.add_child(player)
	await process_frame

	var area: Node2D = SpecialDamageRuleHandlerScript.execute_protective_lava_ring_on_player_damaged({
		"protective_lava_ring_on_player_damaged": {
			"radius": 130,
			"duration": 3.0,
			"same_source_cooldown": 12.0,
			"damage_taken_multiplier_add": -0.5
		}
	}, {
		"player": player,
		"caster": player,
		"parent": root,
		"target_group": &"enemies"
	})
	_expect(area != null, "Protective lava ring spawns")
	_expect(_approx(float(player.get_meta("protective_lava_reduction_until", 0.0)) - _now_seconds(), 3.0, 0.25), "Protective lava stores 3s duration")
	_expect(float(player.get_meta("protective_lava_damage_taken_multiplier_add", 0.0)) == -0.5, "Protective lava stores damage reduction")

	var contact_result: RefCounted = DamageApplicationServiceScript.apply_player_damage(player, _enemy_packet(10, "contact"))
	_expect(int(contact_result.get("amount")) == 5, "Contact damage inside protective lava is reduced by 50%")
	_expect(player.current_health == 95, "Reduced contact damage is applied to player health")
	_expect(_approx(float(player.last_damage_result.get("trace", {}).get("protective_lava_damage_taken_multiplier", 1.0)), 0.5), "Damage trace records protective lava multiplier")

	player.current_health = 100
	player.last_damage_taken = -1
	var ranged_result: RefCounted = DamageApplicationServiceScript.apply_player_damage(player, _enemy_packet(10, "ranged"))
	_expect(int(ranged_result.get("amount")) == 5, "Ranged damage inside protective lava is reduced by 50%")
	_expect(player.current_health == 95, "Reduced ranged damage is applied to player health")

	player.current_health = 100
	player.last_damage_taken = -1
	player.global_position = Vector2(320, 64)
	var outside_result: RefCounted = DamageApplicationServiceScript.apply_player_damage(player, _enemy_packet(10, "contact"))
	_expect(int(outside_result.get("amount")) == 10, "Damage outside protective lava keeps full amount")
	_expect(player.current_health == 90, "Outside damage is applied without protective lava reduction")

	_write_result()
	quit(1 if _failed else 0)


func _enemy_packet(amount: int, source_type: String) -> Dictionary:
	return {
		"raw_amount": amount,
		"amount": amount,
		"damage_origin": "primary_attack",
		"damage_type": &"direct_physical",
		"element": &"physical",
		"source_type": source_type,
		"source_id": source_type,
		"source_origin_id": &"test_enemy",
		"source_skill_id": StringName(source_type),
		"source_instance_id": "test_enemy:%s" % source_type,
		"attacker_id": "test_enemy",
		"target_id": "",
		"can_crit": false,
		"can_trigger_reaction": false,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": []
	}


func _approx(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(actual - expected) <= tolerance


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _expect(condition: bool, message: String) -> void:
	if condition:
		_lines.append("[PASS] " + message)
	else:
		_failed = true
		_lines.append("[FAIL] " + message)


func _write_result() -> void:
	var output: String = "\n".join(_lines)
	print(output)
	var file: FileAccess = FileAccess.open("user://verify_protective_lava_contact_reduction.out.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
