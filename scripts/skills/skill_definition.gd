extends RefCounted
class_name SkillDefinition


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")

var id: StringName = &""
var name: String = ""
var display_name: String = ""
var school: StringName = &""
var fusion_school: Variant = null
var skill_type: String = ""
var rarity: String = "normal"
var exclusive_group: String = ""
var mechanic_family: String = ""
var offer_rule: Dictionary = {}
var trigger_rules: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var category: String = ""
var tags: Array[String] = []
var max_level: int = 1
var base: Dictionary = {}
var damage_scaling: Dictionary = {}
var modifiers: Dictionary = {}
var skill_modifiers: Array[Dictionary] = []
var base_special_rules: Dictionary = {}
var runtime_rules: Dictionary = {}
var components: Array[Dictionary] = []
var events: Array[Dictionary] = []


func _init(data: Dictionary = {}) -> void:
	id = StringName(String(data.get("id", "")))
	name = String(data.get("name", data.get("display_name", "")))
	display_name = String(data.get("display_name", name))
	school = StringName(String(data.get("school", data.get("god_id", ""))))
	var fusion_value: Variant = data.get("fusion_school", null)
	fusion_school = null if fusion_value == null else StringName(String(fusion_value))
	skill_type = String(data.get("type", _category_to_skill_type(String(data.get("category", "")))))
	rarity = String(data.get("rarity", "normal"))
	exclusive_group = String(data.get("exclusive_group", ""))
	mechanic_family = String(data.get("mechanic_family", ""))
	offer_rule = _parse_dictionary(data.get("offer_rule", {}))
	trigger_rules = _parse_dictionary_array(data.get("trigger_rules", []))
	effects = _parse_dictionary_array(data.get("effects", []))
	category = String(data.get("category", ""))
	tags = _parse_string_array(data.get("tags", []))
	max_level = maxi(int(data.get("max_level", 1)), 1)
	base = _parse_dictionary(data.get("base", {}))
	damage_scaling = _parse_dictionary(data.get("damage_scaling", {}))
	modifiers = ModifierSourceScript.flatten(data.get("modifiers", {}), ModifierSourceScript.SOURCE_SKILL)
	skill_modifiers = _parse_dictionary_array(data.get("skill_modifiers", []))
	base_special_rules = _parse_dictionary(data.get("base_special_rules", {}))
	runtime_rules = _parse_runtime_rules(data.get("runtime_rules", {}))
	components = _parse_dictionary_array(data.get("components", []))
	events = _parse_dictionary_array(data.get("events", []))


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	return base.get(stat_name, default_value)


func _parse_string_array(value: Variant) -> Array[String]:
	var parsed: Array[String] = []
	if not (value is Array):
		return parsed

	var source: Array = value
	for item: Variant in source:
		parsed.append(String(item))

	return parsed


func _parse_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


func _parse_dictionary_array(value: Variant) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	if not (value is Array):
		return parsed

	var source: Array = value
	for item_variant: Variant in source:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			parsed.append(item.duplicate(true))

	return parsed


func _category_to_skill_type(value: String) -> String:
	match value:
		"active":
			return "cast"
		"passive":
			return "passive"
		_:
			return value


func _parse_runtime_rules(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return {
			"rules": _parse_dictionary_array(value)
		}
	return {}
