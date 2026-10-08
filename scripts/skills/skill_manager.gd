extends Node
class_name SkillManager


const SkillDefinitionScript: Script = preload("res://scripts/skills/skill_definition.gd")
const SkillInstanceScript: Script = preload("res://scripts/skills/skill_instance.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SkillSlotPolicyScript: Script = preload("res://scripts/skills/skill_slot_policy.gd")
const RuntimeDefinitionResolverScript: Script = preload("res://scripts/skills/skill_runtime_definition_resolver.gd")
const SkillLearningPolicyScript: Script = preload("res://scripts/skills/skill_learning_policy.gd")
const MAX_LEARNED_GOD_SCHOOLS: int = 2

signal skill_added(skill_id: StringName)
signal skill_upgraded(skill_id: StringName, new_level: int)
signal skill_changed

@export_range(1, 20, 1, "or_greater") var max_active_skills: int = 5
@export_range(1, 20, 1, "or_greater") var max_passive_skills: int = 3

var active_skills: Dictionary = {}
var passive_skills: Dictionary = {}
var learned_skill_ids: Dictionary = {}
var passive_modifiers: Array = []
var _skill_effect_modifier_source_ids: Array[String] = []
var _primary_attack_method: RefCounted = null


func add_skill(skill_id: Variant, rarity: String = "") -> bool:
	var id: StringName = _to_skill_id(skill_id)
	if id == &"" or has_skill(id):
		return false

	var definition_data: Dictionary = _get_skill_definition_data(id)
	if definition_data.is_empty():
		return false
	if _is_starting_attack_method_definition(definition_data):
		return false
	var category: String = _category_from_skill_type(definition_data)
	if category != "active" and category != "passive":
		return false
	if not _can_current_character_learn(definition_data):
		return false
	if not _can_learn_god_school_definition(definition_data):
		return false
	var replaced_active_skill_id: StringName = &""
	if category == "active":
		replaced_active_skill_id = _find_replaced_active_skill_id(id, definition_data)
		if _is_attack_replacement_definition(definition_data):
			definition_data = _with_inherited_attack_runtime(definition_data, replaced_active_skill_id)
		if replaced_active_skill_id == &"" and _is_capacity_counted_active_definition(definition_data) and is_active_skill_full():
			return false
	elif category == "passive" and is_passive_skill_full():
		return false

	var definition: RefCounted = SkillDefinitionScript.new(definition_data)
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	if rarity != "":
		skill_instance.set("current_rarity", rarity)
	if replaced_active_skill_id != &"":
		_remove_active_skill(replaced_active_skill_id)
		if _get_primary_attack_id() == replaced_active_skill_id:
			_clear_primary_attack_method()

	if category == "passive":
		passive_skills[id] = skill_instance
	else:
		active_skills[id] = skill_instance
	_refresh_skill_modifier_payload(skill_instance)
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


func set_primary_attack_method(skill_id: Variant, rarity: String = "") -> bool:
	var id: StringName = _to_skill_id(skill_id)
	if id == &"":
		return false
	var definition_data: Dictionary = _get_skill_definition_data(id)
	if definition_data.is_empty() or not _is_attack_method_definition(definition_data):
		return false
	var definition: RefCounted = SkillDefinitionScript.new(definition_data)
	var skill_instance: RefCounted = SkillInstanceScript.new(definition)
	if rarity != "":
		skill_instance.set("current_rarity", rarity)
	_primary_attack_method = skill_instance
	skill_changed.emit()
	return true


func get_primary_attack_method() -> RefCounted:
	return _primary_attack_method


func get_primary_attack_id() -> StringName:
	return _get_primary_attack_id()


func get_learned_god_schools() -> Array[StringName]:
	var schools: Array[StringName] = []
	for skill_instance: RefCounted in get_all_skills():
		var school: StringName = _get_skill_instance_primary_god_school(skill_instance)
		if school != &"" and not schools.has(school):
			schools.append(school)
	return schools


func get_learned_god_school_count() -> int:
	return get_learned_god_schools().size()


func _find_replaced_active_skill_id(new_skill_id: StringName, definition_data: Dictionary) -> StringName:
	if not _is_active_slot_replacement_definition(definition_data):
		return &""
	var explicit_id: StringName = _to_skill_id(definition_data.get("replaces_skill", ""))
	if explicit_id != &"" and explicit_id != new_skill_id and active_skills.has(explicit_id):
		return explicit_id
	if _is_attack_replacement_definition(definition_data) and _get_primary_attack_id() != &"":
		return _get_primary_attack_id()
	for active_id_variant: Variant in active_skills.keys():
		var active_id: StringName = _to_skill_id(active_id_variant)
		if active_id == new_skill_id:
			continue
		if _is_attack_replacement_definition(definition_data) and _is_active_attack_slot_skill(active_id):
			return active_id
		if _is_dash_replacement_definition(definition_data) and _is_active_dash_slot_skill(active_id):
			return active_id
	return &""


func _is_active_slot_replacement_definition(definition_data: Dictionary) -> bool:
	return _is_attack_replacement_definition(definition_data) or _is_dash_replacement_definition(definition_data)


func _is_attack_replacement_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_attack(definition_data)


func _is_attack_method_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_attack(definition_data)


func _is_starting_attack_method_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_starting_attack(definition_data)


func _is_dash_replacement_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.is_dash(definition_data)


func _is_active_attack_slot_skill(skill_id: StringName) -> bool:
	var skill_instance: RefCounted = active_skills.get(skill_id, null) as RefCounted
	if skill_instance != null:
		if _string_or(skill_instance.get("exclusive_group"), "") == "attack_school":
			return true
		if _string_or(skill_instance.get("skill_type"), "") == "attack":
			return true
	var definition_data: Dictionary = _get_skill_definition_data(skill_id)
	return bool(definition_data.get("is_starting_skill", false)) or _is_attack_replacement_definition(definition_data)


func _is_active_dash_slot_skill(skill_id: StringName) -> bool:
	var skill_instance: RefCounted = active_skills.get(skill_id, null) as RefCounted
	if skill_instance != null:
		if _string_or(skill_instance.get("exclusive_group"), "") == "dash_school":
			return true
		if _string_or(skill_instance.get("skill_type"), "") == "dash":
			return true
	var definition_data: Dictionary = _get_skill_definition_data(skill_id)
	return _is_dash_replacement_definition(definition_data)


func _is_capacity_counted_active_definition(definition_data: Dictionary) -> bool:
	return SkillSlotPolicyScript.counts_active_capacity(definition_data)


func _with_inherited_attack_runtime(definition_data: Dictionary, replaced_active_skill_id: StringName) -> Dictionary:
	var source: Dictionary = _get_skill_definition_data(replaced_active_skill_id) if replaced_active_skill_id != &"" else {}
	if source.is_empty():
		source = _get_primary_starting_skill_data()
	return RuntimeDefinitionResolverScript.inherit_attack(definition_data, source)


func _get_primary_starting_skill_data() -> Dictionary:
	for skill: Dictionary in GameData.get_starting_skill_pool():
		return skill
	return {}


func _remove_active_skill(skill_id: StringName) -> void:
	if skill_id == &"":
		return
	active_skills.erase(skill_id)
	_remove_skill_effect_modifier_source(skill_id)
	_remove_passive_modifiers_for_skill(skill_id)


func _remove_passive_modifiers_for_skill(skill_id: StringName) -> void:
	var id_text: String = _string_or(skill_id, "")
	for index: int in range(passive_modifiers.size() - 1, -1, -1):
		var modifier: Variant = passive_modifiers[index]
		if modifier is Dictionary and _string_or((modifier as Dictionary).get("source_skill_id", ""), "") == id_text:
			passive_modifiers.remove_at(index)


func _remove_skill_effect_modifier_source(skill_id: StringName) -> void:
	var source_id: String = "skill:%s:effects" % _string_or(skill_id, "")
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		owner.call("clear_run_modifier_source", source_id)
	_skill_effect_modifier_source_ids.erase(source_id)


func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)


func upgrade_skill(skill_id: Variant, rarity: String = "") -> bool:
	var skill_instance: RefCounted = get_skill(skill_id)
	if skill_instance == null or not skill_instance.level_up():
		return false

	var id: StringName = StringName(skill_instance.get("skill_id"))
	var new_level: int = int(skill_instance.get("current_level"))
	if rarity != "":
		skill_instance.set("current_rarity", rarity)
	_refresh_skill_modifier_payload(skill_instance)
	skill_upgraded.emit(id, new_level)
	skill_changed.emit()
	return true


func get_all_skills() -> Array:
	var skills: Array = []
	skills.append_array(active_skills.values())
	skills.append_array(passive_skills.values())
	return skills


func get_active_skills() -> Array:
	var skills: Array = []
	if _primary_attack_method != null:
		skills.append(_primary_attack_method)
	skills.append_array(active_skills.values())
	return skills


func get_passive_skills() -> Array:
	return passive_skills.values()


func clear_skills() -> void:
	active_skills.clear()
	passive_skills.clear()
	learned_skill_ids.clear()
	passive_modifiers.clear()
	_primary_attack_method = null
	_clear_skill_effect_modifier_sources()
	skill_changed.emit()


func is_active_skill_full() -> bool:
	return _count_capacity_active_skills() >= max_active_skills


func is_passive_skill_full() -> bool:
	return passive_skills.size() >= max_passive_skills


func _count_capacity_active_skills() -> int:
	var count: int = 0
	for active_id_variant: Variant in active_skills.keys():
		var active_id: StringName = _to_skill_id(active_id_variant)
		var definition_data: Dictionary = _get_skill_definition_data(active_id)
		if _is_capacity_counted_active_definition(definition_data):
			count += 1
	return count


func add_passive_modifier(modifiers: Variant) -> void:
	if modifiers is Array:
		passive_modifiers.append_array((modifiers as Array).duplicate(true))
	elif modifiers is Dictionary:
		passive_modifiers.append((modifiers as Dictionary).duplicate(true))
	skill_changed.emit()


func _refresh_skill_modifier_payload(skill_instance: RefCounted) -> void:
	if skill_instance == null:
		return
	var skill_id: StringName = StringName(skill_instance.get("skill_id"))
	_remove_skill_effect_modifier_source(skill_id)
	_remove_passive_modifiers_for_skill(skill_id)
	_apply_skill_effect_payload(skill_instance)
	if _string_or(skill_instance.get("skill_type"), "") == "passive":
		_apply_passive_skill_payload(skill_instance)


func _apply_passive_skill_payload(skill_instance: RefCounted) -> void:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted if skill_instance != null else null
	if definition == null:
		return
	var modifiers_variant: Variant = definition.get("skill_modifiers")
	if modifiers_variant is Array and not (modifiers_variant as Array).is_empty():
		var modifiers: Array = (modifiers_variant as Array).duplicate(true)
		for modifier_variant: Variant in modifiers:
			if modifier_variant is Dictionary:
				var modifier: Dictionary = modifier_variant
				modifier["source_skill_id"] = String(skill_instance.get("skill_id"))
				_scale_modifier_source_values(modifier, skill_instance)
		add_passive_modifier(modifiers)


func _apply_skill_effect_payload(skill_instance: RefCounted) -> void:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted if skill_instance != null else null
	if definition == null:
		return
	var skill_id: StringName = StringName(skill_instance.get("skill_id"))
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
		var modifier: Dictionary = _modifier_effect_to_source(effect, skill_instance)
		if not modifier.is_empty():
			modifier["source_skill_id"] = String(skill_id)
			modifiers.append(modifier)
	if not modifiers.is_empty():
		add_passive_modifier(modifiers)
		_set_skill_effect_modifier_source(skill_id, modifiers)


func _modifier_effect_to_source(effect: Dictionary, skill_instance: RefCounted) -> Dictionary:
	var source: Dictionary = effect.duplicate(true)
	source.erase("type")
	var stat: String = String(source.get("stat", ""))
	if stat == "" or not source.has("value"):
		return {}
	source["value"] = _scale_modifier_value(stat, source["value"], skill_instance)
	return source


func _scale_modifier_source_values(modifier: Dictionary, skill_instance: RefCounted) -> void:
	if modifier.has("stat") and modifier.has("value"):
		modifier["value"] = _scale_modifier_value(String(modifier["stat"]), modifier["value"], skill_instance)


func _scale_modifier_value(key: String, value: Variant, skill_instance: RefCounted) -> Variant:
	if not _is_number(value):
		return value
	var stat_kind: String = _modifier_stat_kind(key, skill_instance)
	var scaled: float = SkillGrowthScalingScript.apply_to_number(float(value), skill_instance, stat_kind)
	return roundi(scaled) if typeof(value) == TYPE_INT else scaled


func _modifier_stat_kind(key: String, skill_instance: RefCounted) -> String:
	if key.contains("cooldown") or key.contains("interval"):
		return "cooldown"
	if key.contains("radius") or key.contains("area") or key.contains("range"):
		return "radius"
	if key.contains("duration"):
		return "duration"
	if key.contains("damage") or key.contains("attack"):
		return "damage"
	if skill_instance != null and _string_or(skill_instance.get("skill_type"), "") == "passive":
		return "modifier"
	return "damage"


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
	return GameData.get_skill(skill_id)


func _can_current_character_learn(skill_data: Dictionary) -> bool:
	var owning_node: Node = get_parent()
	var selected: Variant = owning_node.get("selected_character_id") if owning_node != null else null
	var character_id: StringName = &"" if selected == null else StringName(String(selected))
	var character: Dictionary = GameData.get_character(character_id) if character_id != &"" else {}
	return SkillLearningPolicyScript.can_current_character_learn(skill_data, character_id, character)

func _can_learn_god_school_definition(skill_data: Dictionary) -> bool:
	return SkillLearningPolicyScript.can_learn_god_school(skill_data, get_learned_god_schools(), MAX_LEARNED_GOD_SCHOOLS)

func _category_from_skill_type(skill_data: Dictionary) -> String:
	return SkillSlotPolicyScript.category(skill_data)


func _get_primary_attack_id() -> StringName:
	if _primary_attack_method == null:
		return &""
	return StringName(String(_primary_attack_method.get("skill_id")))


func _clear_primary_attack_method() -> void:
	_primary_attack_method = null


func _get_skill_instance_primary_god_school(skill_instance: RefCounted) -> StringName:
	return SkillLearningPolicyScript.instance_primary_god_school(skill_instance)

func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _to_skill_id(skill_id: Variant) -> StringName:
	return StringName(String(skill_id))
