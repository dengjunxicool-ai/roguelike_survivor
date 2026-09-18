extends SceneTree


const PlayerControllerScript: Script = preload("res://scripts/player/player_controller.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")


class TestSlime:
	extends Node2D

	var armor: float = 0.0
	var defense: float = 0.0
	var resistances: Dictionary = {}
	var damage_taken_multiplier: float = 1.0


var _failed: bool = false


func _init() -> void:
	var player: Node2D = PlayerControllerScript.new()
	player.call("_apply_base_stats", {
		"attack_power": 24.0,
		"damage_multiplier": 1.08
	})

	var has_attack_power: bool = _has_property(player, "attack_power")
	_expect(has_attack_power, "player exposes attack_power for P-scaled skill damage")

	var executor: RefCounted = SkillActionExecutorScript.new()
	var raw_damage: float = float(executor.call("_resolve_scaled_amount", {"stat": "power", "scale": 2.2}, {"caster": player}, "damage"))
	_expect_close(raw_damage, 52.8, "2.2P resolves from player attack_power")

	var slime: TestSlime = TestSlime.new()
	var result: Dictionary = DamageSystemScript.calculate({
		"raw_amount": raw_damage,
		"amount": raw_damage,
		"attacker": player,
		"element": &"fire",
		"damage_origin": &"field",
		"damage_type": &"direct_magical",
		"source_type": "cast",
		"source_id": &"meteor_rain_meteor",
		"source_skill_id": &"fire_cast_meteor_rain",
		"uses_character_damage_multiplier": true
	}, slime)
	_expect(int(result.get("amount", 0)) == 57, "2.2P meteor impact uses player damage multiplier against small slime", result)

	player.free()
	slime.free()

	if _failed:
		quit(1)
	else:
		quit(0)


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, message: String, details: Variant = "") -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	_failed = true
	push_error("[FAIL] %s :: %s" % [message, str(details)])


func _expect_close(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_expect(absf(actual - expected) <= epsilon, message, "actual=%s expected=%s" % [actual, expected])
