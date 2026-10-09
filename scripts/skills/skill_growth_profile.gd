## 稳定 effect_id 的不可变基础覆盖，之后再由 EffectAdapter 应用一次成长。
extends RefCounted
class_name SkillGrowthProfile
static func resolve_actions(definition: Dictionary, level: int) -> Array:
	var result: Array = []
	for rule: Dictionary in definition.get("trigger_rules",[]):
		result.append_array(resolve_effects(rule.get("effects",[]),definition.get("level_overrides",[]),level))
	return result
static func resolve_effects(effects: Array, overrides: Array, level: int) -> Array:
	var result: Array = effects.duplicate(true)
	for milestone: Dictionary in overrides:
		if int(milestone.get("level",99)) > level: continue
		for patch: Dictionary in milestone.get("patches",[]): _patch(result,patch)
	return result
static func _patch(value: Variant, patch: Dictionary) -> void:
	if value is Array:
		for item: Variant in value: _patch(item,patch)
	elif value is Dictionary:
		# Walk existing children first; a newly appended effect is never patched twice.
		for child: Variant in value.values():
			if child is Array or child is Dictionary: _patch(child,patch)
		if value.get("effect_id","") != patch.get("effect_id",""): return
		for key: String in patch.get("set",{}): value[key] = patch["set"][key].duplicate(true) if patch["set"][key] is Array or patch["set"][key] is Dictionary else patch["set"][key]
		for key: String in patch.get("multiply",{}): value[key] = float(value.get(key,0.0))*float(patch["multiply"][key])
		for key: String in patch.get("append",{}):
			if not value.has(key): value[key] = []
			value[key].append_array(patch["append"][key].duplicate(true))
static func describe_next_milestone(definition: Dictionary, level: int) -> Dictionary:
	for item: Dictionary in definition.get("level_overrides",[]):
		if int(item.level) > level: return item.duplicate(true)
	return {}
