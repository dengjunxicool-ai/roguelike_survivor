extends RefCounted
class_name SkillLearningPolicy

const GOD_SCHOOLS: Array[StringName] = [&"fire", &"frost", &"thunder", &"curse", &"holy", &"chaos"]

static func can_current_character_learn(skill_data: Dictionary, character_id: StringName, character: Dictionary) -> bool:
	if is_pool_learnable_skill(skill_data) or bool(skill_data.get("is_starting_skill", false)) or character_id == &"":
		return true
	return StringName(String(character.get("starting_skill_id", ""))) == StringName(String(skill_data.get("id", "")))


static func can_learn_god_school(skill_data: Dictionary, learned_schools: Array[StringName], maximum_schools: int) -> bool:
	if is_fusion_definition(skill_data):
		return learned_schools.size() >= maximum_schools
	var school: StringName = definition_primary_god_school(skill_data)
	return school == &"" or learned_schools.has(school) or learned_schools.size() < maximum_schools


static func is_pool_learnable_skill(skill_data: Dictionary) -> bool:
	return (
		bool(skill_data.get("learnable_from_pool", false))
		or bool(skill_data.get("offer_in_upgrade_pool", false))
		or not _get_dictionary(skill_data.get("offer_rule", {})).is_empty()
	)


static func is_fusion_definition(skill_data: Dictionary) -> bool:
	return _string_or(skill_data.get("skill_type", ""), "") == "fusion"


static func instance_primary_god_school(skill_instance: RefCounted) -> StringName:
	if skill_instance == null:
		return &""
	if _string_or(skill_instance.get("skill_type"), "") == "fusion":
		return &""
	var school: StringName = StringName(_string_or(skill_instance.get("school"), ""))
	if GOD_SCHOOLS.has(school):
		return school
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return &""
	school = StringName(_string_or(definition.get("school"), ""))
	return school if GOD_SCHOOLS.has(school) else &""


static func definition_primary_god_school(skill_data: Dictionary) -> StringName:
	if is_fusion_definition(skill_data):
		return &""
	var school: StringName = StringName(_string_or(skill_data.get("school", ""), ""))
	if GOD_SCHOOLS.has(school):
		return school
	return &""


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)
