extends RefCounted
class_name SpecialRuleCommon


const MetadataKeyScript: Script = preload("res://scripts/core/metadata_key.gd")


static func is_boss(target: Node) -> bool:
	return target != null and (target.is_in_group(&"bosses") or bool(target.get_meta("is_boss", false)) or String(target.get_meta("enemy_rank", "")) == "boss")


static func is_elite(target: Node) -> bool:
	return target != null and (target.is_in_group(&"elites") or bool(target.get_meta("is_elite", false)) or String(target.get_meta("enemy_rank", "")) == "elite")


static func is_boss_core(target: Node) -> bool:
	return target != null and (target.is_in_group(&"boss_cores") or bool(target.get_meta("is_boss_core", false)) or String(target.get_meta("enemy_type", "")) == "boss_core")


static func target_key(target: Node) -> String:
	return str(target.get_instance_id()) if target != null else "none"


static func metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "skill_rule")


static func metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "skill_rule")


static func health_ratio(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


static func is_target_moving(target: Node) -> bool:
	if target == null:
		return false
	var velocity_variant: Variant = target.get("velocity")
	if velocity_variant is Vector2:
		return (velocity_variant as Vector2).length_squared() > 1.0
	return false


static func now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
