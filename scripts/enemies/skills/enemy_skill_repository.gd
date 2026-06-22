extends RefCounted
class_name EnemySkillRepository


const EnemySkillDefinitionScript: Script = preload("res://scripts/enemies/skills/enemy_skill_definition.gd")
const ENEMY_SKILLS_PATH: String = "res://data/enemy_skills.json"

var _definitions: Dictionary = {}
var _loaded: bool = false


func get_skill(skill_id: Variant) -> RefCounted:
	_ensure_loaded()
	var id: StringName = StringName(String(skill_id))
	if not _definitions.has(id):
		return null
	return _definitions[id] as RefCounted


func get_all_skills() -> Array[RefCounted]:
	_ensure_loaded()
	var result: Array[RefCounted] = []
	for definition: Variant in _definitions.values():
		if definition is RefCounted:
			result.append(definition)
	return result


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_definitions.clear()
	for data: Dictionary in _load_skill_data():
		var definition: RefCounted = EnemySkillDefinitionScript.new(data)
		var id: StringName = StringName(String(definition.get("id")))
		if id != &"":
			_definitions[id] = definition


func _load_skill_data() -> Array[Dictionary]:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_enemy_skill_definitions"):
		var managed: Variant = data_manager.call("get_enemy_skill_definitions")
		if managed is Array:
			return _to_dictionary_array(managed)

	var file: FileAccess = FileAccess.open(ENEMY_SKILLS_PATH, FileAccess.READ)
	if file == null:
		push_warning("[EnemySkillRepository] Could not open %s." % ENEMY_SKILLS_PATH)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("[EnemySkillRepository] Could not parse %s." % ENEMY_SKILLS_PATH)
		return []

	var document: Dictionary = parsed
	return _to_dictionary_array(document.get("enemy_skills", []))


func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("DataManager")


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			result.append(item.duplicate(true))
	return result
