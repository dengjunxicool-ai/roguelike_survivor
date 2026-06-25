extends RefCounted
class_name SkillInstance


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var definition: RefCounted
var skill_id: StringName = &""
var current_level: int = 1
var runtime_modifiers: Dictionary = {}
var runtime_special_rules: Dictionary = {}
var runtime_tags: Array[StringName] = []
var runtime_events: Array[Dictionary] = []
var cooldown_remaining: float = 0.0


func _init(skill_definition: RefCounted) -> void:
	definition = skill_definition
	if definition != null:
		skill_id = definition.id
		var definition_modifiers: Variant = definition.get("modifiers")
		if definition_modifiers is Dictionary:
			runtime_modifiers = (definition_modifiers as Dictionary).duplicate(true)
		var definition_special_rules: Variant = definition.get("base_special_rules")
		if definition_special_rules is Dictionary:
			add_runtime_special_rules(definition_special_rules as Dictionary)
		var definition_runtime_rules: Variant = definition.get("runtime_rules")
		if definition_runtime_rules is Dictionary:
			add_runtime_special_rules({
				"fire_runtime_rules": (definition_runtime_rules as Dictionary).duplicate(true)
			})


func level_up() -> bool:
	if not can_level_up():
		return false

	current_level += 1
	return true


func can_level_up() -> bool:
	if definition == null:
		return false

	return current_level < definition.max_level


func add_runtime_modifier(key: Variant, value: Variant) -> void:
	var modifier_key: String = String(key)
	if modifier_key == "":
		return

	if runtime_modifiers.has(modifier_key) and _is_number(runtime_modifiers[modifier_key]) and _is_number(value):
		runtime_modifiers[modifier_key] = float(runtime_modifiers[modifier_key]) + float(value)
	else:
		runtime_modifiers[modifier_key] = value


func add_runtime_tag(tag: Variant) -> void:
	var tag_id: StringName = StringName(String(tag))
	if tag_id != &"" and not runtime_tags.has(tag_id):
		runtime_tags.append(tag_id)


func add_runtime_events(events: Array) -> void:
	for event_variant: Variant in events:
		if event_variant is Dictionary:
			var event: Dictionary = event_variant
			runtime_events.append(event.duplicate(true))


func add_runtime_special_rules(rules: Dictionary) -> void:
	_merge_special_rules(runtime_special_rules, rules)


func get_effective_stat(stat_name: String) -> Variant:
	if definition == null:
		return 0

	var value: Variant = definition.get_base_stat(stat_name, 0)
	return SkillModifierCalculatorScript.calculate(value, stat_name, runtime_modifiers)


func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _merge_special_rules(target: Dictionary, source: Dictionary) -> void:
	for key_variant: Variant in source.keys():
		var key: String = String(key_variant)
		if key == "":
			continue
		var value: Variant = source[key_variant]
		if value is Dictionary:
			var existing: Dictionary = {}
			if target.get(key) is Dictionary:
				existing = (target[key] as Dictionary).duplicate(true)
			_merge_special_rules(existing, value)
			target[key] = existing
		elif value is Array:
			target[key] = (value as Array).duplicate(true)
		elif target.has(key) and _is_number(target[key]) and _is_number(value):
			target[key] = float(target[key]) + float(value)
		else:
			target[key] = value


func _match_number_type(value: float, original_value: Variant) -> Variant:
	if typeof(original_value) == TYPE_INT:
		return roundi(value)

	return value
