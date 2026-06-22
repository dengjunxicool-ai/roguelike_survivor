extends RefCounted
class_name ModifierResolver


const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")


static func get_stat(context: Dictionary, stat_name: String, default_value: Variant = 0) -> Variant:
	return SkillStatServiceScript.get_effective_stat(
		context.get("skill_instance") as RefCounted,
		stat_name,
		default_value,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	)


static func resolve_value(context: Dictionary, stat_name: String, base_value: Variant) -> Variant:
	return SkillStatServiceScript.calculate_value(
		context.get("skill_instance") as RefCounted,
		stat_name,
		base_value,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	)


static func resolve_params(context: Dictionary, params: Dictionary, stat_map: Dictionary = {}) -> Dictionary:
	var resolved: Dictionary = params.duplicate(true)
	for key_variant: Variant in params.keys():
		var key: String = String(key_variant)
		var stat_name: String = String(stat_map.get(key, key))
		resolved[key] = resolve_value(context, stat_name, params[key_variant])

	return resolved
