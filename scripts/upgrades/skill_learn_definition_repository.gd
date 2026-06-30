extends RefCounted
class_name SkillLearnDefinitionRepository


static func get_skill_learn_definitions(skill_pool: Array, offer_rule_key: String = "offer_rule") -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill: Dictionary in skill_pool:
		var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
		if skill_id == &"":
			continue
		if skill_id == &"fireball" or bool(skill.get("is_starting_skill", false)):
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get(offer_rule_key, {})).is_empty():
			continue
		skills.append(skill.duplicate(true))
	return skills


static func make_god_skill_learn_upgrade(skill: Dictionary, god_id: StringName, upgrade_prefix: String) -> Dictionary:
	var skill_id: String = _string_or(skill.get("id", ""), "")
	if skill_id == "":
		return {}
	var tags: Array[String] = to_string_array(_get_array(skill.get("tags", [])))
	if not tags.has("skill"):
		tags.push_front("skill")
	var god_text: String = _string_or(god_id, "")
	if god_text != "" and not tags.has(god_text):
		tags.push_front(god_text)
	var description: String = _string_or(skill.get("description", "Learn %s." % skill_id), "Learn %s." % skill_id)
	return {
		"id": "%s%s" % [upgrade_prefix, skill_id],
		"display_name": _string_or(skill.get("display_name", skill_id), skill_id),
		"description": description,
		"rarity": _string_or(skill.get("rarity", "common"), "common"),
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": StringName(skill_id),
		"god_id": god_id,
		"level_descriptions": [description]
	}


static func is_debug_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	if skill.is_empty():
		return false
	if StringName(_string_or(skill.get("id", ""), "")) == &"":
		return false
	if StringName(_string_or(skill.get("god_id", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("school", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("fusion_school", ""), "")) == god_id:
		return true
	if god_id == &"fire" and to_string_array(_get_array(skill.get("tags", []))).has("fire"):
		return true
	return false


static func to_string_array(value: Array) -> Array[String]:
	var strings: Array[String] = []
	for item: Variant in value:
		strings.append(_string_or(item, ""))
	return strings


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
