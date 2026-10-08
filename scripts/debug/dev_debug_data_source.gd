extends RefCounted
class_name DevDebugDataSource

static func get_god_definitions() -> Array[Dictionary]:
	return GameData.get_god_pool()

static func get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for skill: Dictionary in GameData.get_all_skill_pool():
		if not is_god_skill_definition(skill, god_id):
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		definitions.append(skill.duplicate(true))
	return definitions

static func is_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	return StringName(_string_or(skill.get("school", ""))) == god_id or StringName(_string_or(skill.get("fusion_school", ""))) == god_id

static func get_status_definition_for_option(_owner: Node, status_id: Variant) -> Dictionary:
	return GameData.get_status(StringName(_string_or(status_id)))

static func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
