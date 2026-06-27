extends RefCounted
class_name DevDebugDataSource

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")

const GODS_DATA_PATH: String = DataPathsScript.GODS_PATH
const SKILLS_DATA_PATH: String = DataPathsScript.SKILLS_PATH


static func load_json_document(path: String) -> Dictionary:
	return JsonDataLoaderScript.load_dictionary(path, "DevDebugPanel", JsonDataLoaderScript.REPORT_SILENT)


static func get_god_definitions() -> Array[Dictionary]:
	var document: Dictionary = load_json_document(GODS_DATA_PATH)
	var gods: Array[Dictionary] = []
	var god_variants: Variant = document.get("gods", [])
	if god_variants is Array:
		for god_variant: Variant in god_variants:
			if god_variant is Dictionary:
				var god: Dictionary = god_variant
				if _string_or(god.get("id", ""), "") != "":
					gods.append(god.duplicate(true))
	if not gods.is_empty():
		return gods
	return [
		{"id": "fire", "display_name": "Fire"},
		{"id": "thunder", "display_name": "Thunder"},
		{"id": "frost", "display_name": "Frost"},
		{"id": "curse", "display_name": "Curse"},
		{"id": "holy", "display_name": "Holy"},
		{"id": "chaos", "display_name": "Chaos"}
	]


static func get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var document: Dictionary = load_json_document(SKILLS_DATA_PATH)
	var definitions: Array[Dictionary] = []
	var skills_variant: Variant = document.get("skills", [])
	if not (skills_variant is Array):
		return definitions
	for skill_variant: Variant in skills_variant:
		if not (skill_variant is Dictionary):
			continue
		var skill: Dictionary = skill_variant
		if not is_god_skill_definition(skill, god_id):
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		definitions.append(skill.duplicate(true))
	return definitions


static func is_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	if StringName(_string_or(skill.get("god_id", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("school", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("fusion_school", ""), "")) == god_id:
		return true
	var tags: Array = _get_array(skill.get("tags", []))
	return tags.has(_string_or(god_id, "")) or tags.has(god_id)


static func get_status_definition_for_option(owner: Node, status_id: Variant) -> Dictionary:
	var id: StringName = StringName(_string_or(status_id, ""))
	if id == &"":
		return {}

	var data_manager: Node = null
	if owner != null:
		data_manager = owner.get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_status_definition"):
		var data: Variant = data_manager.call("get_status_definition", id)
		if data is Dictionary and not (data as Dictionary).is_empty():
			return (data as Dictionary).duplicate(true)

	for status: Dictionary in GameData.get_status_pool():
		if StringName(_string_or(status.get("id", ""), "")) == id:
			return status.duplicate(true)
	return {}


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _string_or(value: Variant, fallback: String = "") -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value)
		TYPE_NIL:
			return fallback
		_:
			return str(value)
