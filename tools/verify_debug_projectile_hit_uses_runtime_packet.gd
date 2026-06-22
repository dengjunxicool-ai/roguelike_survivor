extends SceneTree


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const ProjectileScript: Script = preload("res://scripts/combat/projectile.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")


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
	var projectile: Node2D = ProjectileScript.new() as Node2D
	projectile.set_meta("debug_attack_trace_id", trace_id)
	projectile.set_meta("cast_instance_id", "hailstorm:debug")
	projectile.set("name", "DebugHailProjectile")
	root.add_child(projectile)

	var runtime_packet: Dictionary = {
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
		"target_id": str(target.get_instance_id()),
		"can_crit": false,
		"can_trigger_reaction": true,
		"reaction_depth": 0,
		"uses_character_damage_multiplier": true,
		"uses_skill_level_coefficient": false,
		"skill_level_coefficient": 1.0,
		"ignore_defense": false,
		"ignore_resistance": false,
		"ignore_vulnerability": false,
		"ignore_min_damage": false,
		"special_rule_tags": [],
		"special_final_modifier": 0.5,
		"special_final_modifier_source": "system_rule",
		"debug_attack_trace_id": trace_id
	}
	projectile.set("damage_packet", runtime_packet)

	var executor: RefCounted = SkillActionExecutorScript.new()
	executor.call("execute_action", {
		"type": "deal_damage",
		"params": {
			"amount": 10,
			"damage_origin": "primary_attack",
			"damage_type": "direct_magical",
			"element": "ice",
			"can_crit": false,
			"uses_skill_level_coefficient": false
		}
	}, {
		"caster": caster,
		"target": target,
		"projectile": projectile,
		"source_id": &"hailstorm_projectile",
		"skill_id": &"hailstorm",
		"source_weapon_id": &"frost_staff",
		"debug_attack_trace_id": trace_id
	})

	_expect(target.last_damage_amount == 5, "debug projectile hit uses runtime projectile damage multiplier")
	var packet: Dictionary = target.last_damage_packet if target.last_damage_packet is Dictionary else {}
	_expect(_approx(float(packet.get("special_final_modifier", 1.0)), 0.5), "debug damage packet preserves projectile special modifier")
	_expect(String(packet.get("source_type", "")) == "projectile", "debug damage packet preserves projectile source type")
	var records: Array = DebugCombatTraceScript.get_records(root)
	var damage_record: Dictionary = _first_damage_record(records)
	_expect(not damage_record.is_empty(), "debug trace records projectile damage")
	if not damage_record.is_empty():
		_expect(int(damage_record.get("final_amount", 0)) == 5, "debug trace final damage keeps projectile multiplier")
		_expect(String(damage_record.get("source_instance_id", "")) == "hailstorm:debug:projectile:2", "debug trace keeps projectile source instance")

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
	var file: FileAccess = FileAccess.open("res://tools/verify_debug_projectile_hit_uses_runtime_packet.out.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
