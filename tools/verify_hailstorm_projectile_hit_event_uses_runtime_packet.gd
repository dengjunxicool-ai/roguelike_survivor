extends SceneTree


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
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
	var last_damage_result: Dictionary = {}
	var last_damage_packet: Variant = null

	func take_damage(amount_or_packet: Variant, damage_type: Variant = &"") -> void:
		DamageApplicationServiceScript.apply_enemy_damage(self, amount_or_packet, damage_type)

	func _apply_damage_synergies(amount: int, _damage_type: Variant) -> int:
		return amount

	func _record_damage_done(amount: int, damage_result: Dictionary, source_packet: Variant) -> void:
		last_damage_amount = amount
		last_damage_result = damage_result.duplicate(true)
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
	root.add_child(caster)
	var target: TestEnemy = TestEnemy.new()
	target.add_to_group(&"enemies")
	root.add_child(target)

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
	var projectile: Node2D = ProjectileScript.new() as Node2D
	root.add_child(projectile)
	projectile.call("setup", {
		"projectile_id": &"hailstorm_projectile",
		"source_id": &"hailstorm_projectile",
		"damage": 10,
		"damage_type": &"direct_magical",
		"damage_packet": {
			"raw_amount": 10,
			"amount": 10,
			"damage_origin": "primary_attack",
			"damage_type": &"direct_magical",
			"element": &"ice",
			"source_type": "projectile",
			"source_id": &"hailstorm_projectile",
			"source_weapon_id": &"frost_staff",
			"source_skill_id": &"hailstorm",
			"source_instance_id": "hailstorm:debug:projectile:2",
			"attacker": caster,
			"attacker_id": str(caster.get_instance_id()),
			"can_crit": false,
			"uses_character_damage_multiplier": true,
			"uses_skill_level_coefficient": false,
			"skill_level_coefficient": 1.0,
			"special_final_modifier": 0.7,
			"special_final_modifier_source": "system_rule",
			"debug_attack_trace_id": trace_id
		},
		"target_group": &"enemies",
		"event_bus": event_bus,
		"skill_instance": skill_instance,
		"caster": caster,
		"source_weapon_id": &"frost_staff",
		"event_on_hit": &"on_projectile_hit",
		"debug_attack_trace_id": trace_id
	})

	projectile.call("_emit_hit_event", target)

	_expect(target.last_damage_amount == 8, "hailstorm second projectile hit event uses 70 percent runtime packet")
	var packet: Dictionary = target.last_damage_packet if target.last_damage_packet is Dictionary else {}
	_expect(_approx(float(packet.get("special_final_modifier", 1.0)), 0.7), "hit event damage packet preserves 70 percent modifier")
	var damage_record: Dictionary = _first_damage_record(DebugCombatTraceScript.get_records(root))
	_expect(not damage_record.is_empty(), "hit event writes debug damage record")
	if not damage_record.is_empty():
		_expect(int(damage_record.get("final_amount", 0)) == 8, "debug trace final damage is 8 for second hailstorm projectile")

	_write_result()
	quit(1 if _failed else 0)


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
	var file: FileAccess = FileAccess.open("res://tools/verify_hailstorm_projectile_hit_event_uses_runtime_packet.out.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
