extends Node
class_name WeaponSkillBinding


func bind_starting_skill(player: Node) -> bool:
	if player == null:
		return false

	var starting_skill_id: StringName = _resolve_starting_skill_id(player)
	if starting_skill_id == &"":
		push_error("[WeaponSkillBinding] Character has no starting_skill_id.")
		return false

	if _get_skill_definition(starting_skill_id).is_empty():
		push_error("[WeaponSkillBinding] Starting skill does not exist: %s" % String(starting_skill_id))
		return false

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("add_skill"):
		push_error("[WeaponSkillBinding] Player is missing SkillManager.")
		return false

	var added: bool = bool(skill_manager.call("add_skill", starting_skill_id))
	if not added and not bool(skill_manager.call("has_skill", starting_skill_id)):
		push_error("[WeaponSkillBinding] Failed to add starting skill: %s" % String(starting_skill_id))
		return false

	return true


func _resolve_starting_skill_id(player: Node) -> StringName:
	var character_id: StringName = StringName(String(player.get("selected_character_id")))
	var character: Dictionary = GameData.get_character(character_id)
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id != &"":
		return starting_skill_id

	for skill: Dictionary in GameData.get_skill_pool():
		if bool(skill.get("is_starting_skill", false)):
			var id: StringName = StringName(String(skill.get("id", "")))
			if id != &"":
				return id
	return &""


func _get_skill_definition(skill_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_skill_definition"):
		var definition: Variant = data_manager.call("get_skill_definition", skill_id)
		if definition is Dictionary:
			return definition
	return GameData.get_skill(skill_id)
