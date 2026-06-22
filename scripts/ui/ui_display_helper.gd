extends RefCounted
class_name UIDisplayHelper


static func character_name(character: Dictionary, fallback_id: Variant = "") -> String:
	return String(character.get("display_name", fallback_id))


static func weapon_name(weapon: Dictionary, fallback_id: Variant = "") -> String:
	return String(weapon.get("display_name", fallback_id))


static func branch_name(branch: Dictionary, fallback_id: Variant = "") -> String:
	return String(branch.get("display_name", fallback_id))


static func enemy_name(enemy: Dictionary, fallback_id: Variant = "") -> String:
	return String(enemy.get("display_name", fallback_id))


static func skill_name(skill_id: StringName) -> String:
	var skill: Dictionary = GameData.get_skill(skill_id)
	return String(skill.get("display_name", skill_id))


static func visual_texture(definition: Dictionary, preferred_key: String) -> Texture2D:
	var visual: Dictionary = dictionary(definition.get("visual", {}))
	var texture_path: String = String(visual.get(preferred_key, visual.get("texture", "")))
	return null if texture_path == "" else load(texture_path) as Texture2D


static func visual_modulate(definition: Dictionary) -> Color:
	var visual: Dictionary = dictionary(definition.get("visual", {}))
	var color_values: Array = array(visual.get("modulate", []))
	if color_values.size() < 4:
		return Color.WHITE
	return Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), float(color_values[3]))


static func clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


static func array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var typed: Dictionary = value
		return typed
	return {}


static func bilingual_name(data: Dictionary, fallback_id: Variant, local_keys: Array[String], english_keys: Array[String]) -> String:
	var local_name: String = _first_string(data, local_keys)
	var english_name: String = _first_string(data, english_keys)
	if local_name != "" and english_name != "" and local_name != english_name:
		return "%s / %s" % [local_name, english_name]
	if local_name != "":
		return local_name
	if english_name != "":
		return english_name
	return String(fallback_id)


static func _first_string(data: Dictionary, keys: Array[String]) -> String:
	for key: String in keys:
		var text: String = String(data.get(key, ""))
		if text != "":
			return text
	return ""
