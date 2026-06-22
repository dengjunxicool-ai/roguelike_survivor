extends RefCounted
class_name EnemySkillDefinition


var id: StringName = &""
var display_name: String = ""
var runtime: String = "active"
var cooldown: float = 0.0
var actions: Array[Dictionary] = []
var _data: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	_data = data.duplicate(true)
	id = StringName(String(data.get("id", "")))
	display_name = String(data.get("display_name", String(id)))
	runtime = String(data.get("runtime", "active"))
	cooldown = maxf(float(data.get("cooldown", 0.0)), 0.0)
	actions = _get_dictionary_array(data.get("actions", []))


func has_action_type(action_type: String) -> bool:
	for action: Dictionary in actions:
		if String(action.get("type", "")) == action_type:
			return true
	return false


func get_actions_by_type(action_type: String) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for action: Dictionary in actions:
		if String(action.get("type", "")) == action_type:
			matched.append(action.duplicate(true))
	return matched


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func _get_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			result.append(item.duplicate(true))
	return result
