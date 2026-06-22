extends SceneTree


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")


class TestCaster:
	extends Node2D

	var damage_multiplier: float = 1.08
	var attack_speed_multiplier: float = 1.0
	var skill_area_multiplier: float = 1.0
	var status_duration_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5
	var selected_weapon_id: StringName = &"frost_staff"


class TestEnemy:
	extends Node2D

	signal health_changed(current_health: int, max_health: int)

	var enemy_id: StringName = &"debug_hail_target"
	var max_health: int = 100
	var current_health: int = 100
	var armor: int = 0
	var defense: int = 0
	var resistances: Dictionary = {}
	var damage_taken_multiplier: float = 1.0
	var _is_dead: bool = false
	var _reward_controller: Node = null
	var last_damage_amount: int = 0
	var last_damage_packet: Variant = null

	func take_damage(amount_or_packet: Variant, damage_type: Variant = &"") -> void:
		DamageApplicationServiceScript.apply_enemy_damage(self, amount_or_packet, damage_type)

	func _apply_damage_synergies(amount: int, _damage_type: Variant) -> int:
		return amount

	func _record_damage_done(amount: int, _damage_result: Dictionary, source_packet: Variant) -> void:
		last_damage_amount = amount
		last_damage_packet = source_packet

	func _show_debug_damage_number(_amount: int, _damage_result: Dictionary) -> void:
		pass

	func _update_debug_health_display() -> void:
		pass

	func _get_damage_source_key(source_packet: Variant, damage_result: Dictionary) -> String:
		if source_packet is Dictionary:
			return String((source_packet as Dictionary).get("source_instance_id", damage_result.get("source_instance_id", "debug_projectile")))
		return "debug_projectile"

	func _die() -> void:
		_is_dead = true


var _failed: bool = false
var _lines: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("developer_mode_enabled", true)
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	var caster: TestCaster = TestCaster.new()
	caster.global_position = Vector2.ZERO
	root.add_child(caster)
	var targets: Array[TestEnemy] = []
	var enemy: TestEnemy = TestEnemy.new()
	enemy.global_position = Vector2(120, 32)
	enemy.add_to_group(&"enemies")
	root.add_child(enemy)
	targets.append(enemy)

	var skill_instance: RefCounted = SkillInstanceScript.new(SkillDefinitionScript.new({
		"id": "hailstorm",
		"category": "active",
		"base": {
			"damage": 10
		},
		"events": [
			{
				"trigger": "on_projectile_hit",
				"source_id": "hailstorm_projectile",
				"actions": [
					{
						"type": "deal_damage",
						"params": {
							"amount": 10,
							"damage_origin": "primary_attack",
							"damage_type": "direct_magical",
							"element": "ice",
							"can_crit": false,
							"uses_skill_level_coefficient": false
						}
					}
				]
			}
		]
	}))
	var event_bus: Node = SkillEventBusScript.new()
	root.add_child(event_bus)
	var executor: RefCounted = SkillActionExecutorScript.new()
	var spawned: bool = bool(executor.call("execute_action", {
		"type": "spawn_projectiles_at_targets",
		"params": {
			"projectile_id": "hailstorm_projectile",
			"count": 3,
			"range": 540,
			"targeting_mode": "around_player",
			"speed": 420,
			"trajectory_mode": "curve",
			"curve_height": 72,
			"lifetime": 2,
			"collision_radius": 10,
			"damage": 10,
			"damage_multiplier_sequence": [1.0, 0.7, 0.5],
			"damage_origin": "primary_attack",
			"damage_type": "direct_magical",
			"element": "ice",
			"uses_skill_level_coefficient": false
		}
	}, {
		"caster": caster,
		"skill_instance": skill_instance,
		"skill_id": &"hailstorm",
		"source_weapon_id": &"frost_staff",
		"target_group": &"enemies",
		"event_bus": event_bus,
		"parent": root,
		"debug_attack_trace_id": trace_id
	}))

	_expect(spawned, "hailstorm debug spawn creates projectiles through runtime action")
	var projectiles: Array[Node] = _hail_projectiles()
	_expect(projectiles.size() == 3, "hailstorm debug spawn creates three projectiles against one target")
	if projectiles.size() >= 2:
		var projectile: Node = projectiles[1]
		var packet: Dictionary = projectile.get("damage_packet")
		_expect(_approx(float(packet.get("special_final_modifier", 1.0)), 0.7), "spawned second same-target projectile stores 70 percent modifier")
		projectile.call("_emit_hit_event", targets[0])
		_expect(targets[0].last_damage_amount == 8, "spawned second same-target projectile hit records 8 damage")
		var record: Dictionary = _first_damage_record(DebugCombatTraceScript.get_records(root))
		_expect(not record.is_empty(), "spawned second projectile writes debug damage record")
		if not record.is_empty():
			_expect(int(record.get("final_amount", 0)) == 8, "debug card record final amount is 8 for spawned second same-target projectile")

	_write_result()
	quit(1 if _failed else 0)


func _hail_projectiles() -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in root.get_children():
		if child.get("source_id") == &"hailstorm_projectile":
			result.append(child)
	return result


func _first_damage_record(records: Array) -> Dictionary:
	for record_variant: Variant in records:
		if record_variant is Dictionary and String((record_variant as Dictionary).get("type", "")) == "damage":
			return (record_variant as Dictionary)
	return {}


func _approx(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if condition:
		_lines.append("[PASS] " + message)
	else:
		_failed = true
		_lines.append("[FAIL] " + message)


func _write_result() -> void:
	var output: String = "\n".join(_lines)
	print(output)
	var file: FileAccess = FileAccess.open("res://tools/verify_hailstorm_spawned_projectile_second_hit_debug_trace.out.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
