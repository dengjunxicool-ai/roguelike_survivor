extends Node
class_name SkillManager


const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SKILLS_DATA_PATH: String = "res://data/skills.json"

signal skill_added(skill_id: StringName)
signal skill_upgraded(skill_id: StringName, new_level: int)
signal skill_changed

@export_range(1, 20, 1, "or_greater") var max_active_skills: int = 999

var active_skills: Dictionary = {}
var passive_skills: Dictionary = {}
var learned_skill_ids: Dictionary = {}
var passive_modifiers: Array = []
var _skill_effect_modifier_source_ids: Array[String] = []


func add_skill(skill_id: Variant) -> bool:
	var id: StringName = _to_skill_id(skill_id)
	if id == &"" or has_skill(id):
		return false

	var definition_data: Dictionary = _get_skill_definition_data(id)
	var category: String = _category_from_skill_type(definition_data)
	if definition_data.is_empty():
		return false
	if category != "active" and category != "passive":
		return false
	if not _can_current_character_learn(definition_data):
		return false
	if category == "active" and is_active_skill_full():
		return false

	var definition: RefCounted = SkillDefinitionScript.new(definition_data)
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	_apply_skill_effect_payload(id, definition)
	if category == "passive":
		passive_skills[id] = skill_instance
		_apply_passive_skill_payload(definition)
	else:
		active_skills[id] = skill_instance
	learned_skill_ids[id] = true
	skill_added.emit(id)
	skill_changed.emit()
	return true


func has_skill(skill_id: Variant) -> bool:
	var id: StringName = _to_skill_id(skill_id)
	return active_skills.has(id) or passive_skills.has(id)


func has_learned_skill(skill_id: Variant) -> bool:
	return learned_skill_ids.has(_to_skill_id(skill_id))


func mark_skill_learned(skill_id: Variant) -> void:
	var id: StringName = _to_skill_id(skill_id)
	if id != &"":
		learned_skill_ids[id] = true


func get_skill(skill_id: Variant) -> RefCounted:
	var id: StringName = _to_skill_id(skill_id)
	if active_skills.has(id):
		return active_skills[id] as RefCounted
	if passive_skills.has(id):
		return passive_skills[id] as RefCounted

	return null


func upgrade_skill(skill_id: Variant) -> bool:
	var skill_instance: RefCounted = get_skill(skill_id)
	if skill_instance == null or not skill_instance.level_up():
		return false

	var id: StringName = StringName(skill_instance.get("skill_id"))
	var new_level: int = int(skill_instance.get("current_level"))
	skill_upgraded.emit(id, new_level)
	skill_changed.emit()
	return true


func get_all_skills() -> Array:
	var skills: Array = []
	skills.append_array(active_skills.values())
	skills.append_array(passive_skills.values())
	return skills


func get_active_skills() -> Array:
	return active_skills.values()


func get_passive_skills() -> Array:
	return passive_skills.values()


func clear_skills() -> void:
	active_skills.clear()
	passive_skills.clear()
	learned_skill_ids.clear()
	passive_modifiers.clear()
	_clear_skill_effect_modifier_sources()
	skill_changed.emit()


func is_active_skill_full() -> bool:
	return active_skills.size() >= max_active_skills


func add_passive_modifier(modifiers: Variant) -> void:
	if modifiers is Array:
		passive_modifiers.append_array((modifiers as Array).duplicate(true))
	elif modifiers is Dictionary:
		passive_modifiers.append((modifiers as Dictionary).duplicate(true))
	skill_changed.emit()


func _apply_passive_skill_payload(definition: RefCounted) -> void:
	if definition == null:
		return
	var modifiers_variant: Variant = definition.get("skill_modifiers")
	if modifiers_variant is Array and not (modifiers_variant as Array).is_empty():
		add_passive_modifier((modifiers_variant as Array).duplicate(true))


func _apply_skill_effect_payload(skill_id: StringName, definition: RefCounted) -> void:
	if definition == null:
		return
	var effects_variant: Variant = definition.get("effects")
	if not (effects_variant is Array):
		return
	var modifiers: Array[Dictionary] = []
	for effect_variant: Variant in effects_variant:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if String(effect.get("type", "")) != "add_modifier":
			continue
		var modifier: Dictionary = _modifier_effect_to_source(effect)
		if not modifier.is_empty():
			modifiers.append(modifier)
	if not modifiers.is_empty():
		add_passive_modifier(modifiers)
		_set_skill_effect_modifier_source(skill_id, modifiers)


func _modifier_effect_to_source(effect: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	if effect.has("stat") and effect.has("value"):
		values[String(effect.get("stat", ""))] = effect.get("value")
	else:
		var modifier_name: String = String(effect.get("modifier", ""))
		if modifier_name == "" or not effect.has("value"):
			return {}
		var value: Variant = effect.get("value")
		match modifier_name:
			"attack_damage_multiplier":
				values["primary_attack_damage_multiplier_add"] = value
				var damage_type: String = String(effect.get("damage_type", ""))
				if damage_type != "":
					values["%s_damage_multiplier_add" % damage_type] = value
			"burning_damage_multiplier":
				values["dot_damage_multiplier_add"] = value
			"burning_duration_multiplier":
				values["status_duration_multiplier_add"] = value
			_:
				var key: String = modifier_name
				if key.ends_with("_multiplier") and not key.ends_with("_multiplier_add"):
					key = "%s_add" % key
				values[key] = value
	if values.is_empty():
		return {}
	return {
		"source": "skill",
		"values": values
	}


func _set_skill_effect_modifier_source(skill_id: StringName, modifiers: Array[Dictionary]) -> void:
	if skill_id == &"" or modifiers.is_empty():
		return
	var owner: Node = get_parent()
	if owner == null or not owner.has_method("set_run_modifier_source"):
		return
	var source_id: String = "skill:%s:effects" % String(skill_id)
	owner.call("set_run_modifier_source", source_id, modifiers)
	if not _skill_effect_modifier_source_ids.has(source_id):
		_skill_effect_modifier_source_ids.append(source_id)


func _clear_skill_effect_modifier_sources() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		for source_id: String in _skill_effect_modifier_source_ids:
			owner.call("clear_run_modifier_source", source_id)
	_skill_effect_modifier_source_ids.clear()


func _get_skill_definition_data(skill_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_skill_definition"):
		var definition_variant: Variant = data_manager.call("get_skill_definition", skill_id)
		if definition_variant is Dictionary:
			var definition: Dictionary = definition_variant
			if not definition.is_empty():
				return definition

	var game_data_definition: Dictionary = GameData.get_skill(skill_id)
	if not game_data_definition.is_empty():
		return game_data_definition

	var skills_document: Dictionary = _load_skills_document()
	for section_name: String in ["starting_skills", "skills"]:
		var section_variant: Variant = skills_document.get(section_name, [])
		if not (section_variant is Array):
			continue
		for skill_variant: Variant in section_variant:
			if not (skill_variant is Dictionary):
				continue
			var skill: Dictionary = skill_variant
			if StringName(String(skill.get("id", ""))) == skill_id:
				return skill.duplicate(true)
	return {}


func _load_skills_document() -> Dictionary:
	if not FileAccess.file_exists(SKILLS_DATA_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SKILLS_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _can_current_character_learn(skill_data: Dictionary) -> bool:
	if _is_pool_learnable_skill(skill_data):
		return true

	var owning_node: Node = get_parent()
	if owning_node == null:
		return true
	if bool(skill_data.get("is_starting_skill", false)):
		return true

	var selected_character_variant: Variant = owning_node.get("selected_character_id")
	var character_id: StringName = &"" if selected_character_variant == null else StringName(String(selected_character_variant))
	if character_id == &"":
		return true

	var character: Dictionary = GameData.get_character(character_id)
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id == StringName(String(skill_data.get("id", ""))):
		return true

	return false


func _is_pool_learnable_skill(skill_data: Dictionary) -> bool:
	return (
		bool(skill_data.get("learnable_from_pool", false))
		or bool(skill_data.get("offer_in_upgrade_pool", false))
		or not _get_dictionary(skill_data.get("offer_rule", {})).is_empty()
	)


func _category_from_skill_type(skill_data: Dictionary) -> String:
	var category: String = String(skill_data.get("category", ""))
	if category == "active" or category == "passive":
		return category

	var skill_type: String = String(skill_data.get("skill_type", skill_data.get("type", "")))
	match skill_type:
		"passive":
			return "passive"
		"attack", "dash", "cast", "summon", "power", "core", "fusion":
			return "active"
		_:
			return category


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _to_skill_id(skill_id: Variant) -> StringName:
	return StringName(String(skill_id))
