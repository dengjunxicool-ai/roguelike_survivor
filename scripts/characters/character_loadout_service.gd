extends RefCounted
class_name CharacterLoadoutService


const RunLoadoutScript: Script = preload("res://scripts/characters/run_loadout.gd")


static func validate_loadout(character_id: Variant) -> bool:
	return get_validation_errors(character_id).is_empty()


static func get_validation_errors(character_id: Variant) -> Array[String]:
	var errors: Array[String] = []
	var resolved_character_id: StringName = StringName(String(character_id))
	if resolved_character_id == &"":
		errors.append("Missing character_id.")
		return errors

	var character: Dictionary = GameData.get_character(resolved_character_id)
	if character.is_empty():
		errors.append("Unknown character_id: %s" % String(resolved_character_id))
		return errors

	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id == &"":
		errors.append("Character %s has no starting_skill_id." % String(resolved_character_id))
	elif GameData.get_skill(starting_skill_id).is_empty():
		errors.append("Character %s references missing starting_skill_id: %s" % [String(resolved_character_id), String(starting_skill_id)])

	return errors


static func build_loadout(character_id: Variant) -> RefCounted:
	var resolved_character_id: StringName = StringName(String(character_id))
	if not validate_loadout(resolved_character_id):
		return null
	return RunLoadoutScript.new(GameData.get_character(resolved_character_id))


static func warn_if_invalid(character_id: Variant, prefix: String = "[CharacterLoadoutService]") -> bool:
	var errors: Array[String] = get_validation_errors(character_id)
	for error: String in errors:
		push_warning("%s %s" % [prefix, error])
	return errors.is_empty()
