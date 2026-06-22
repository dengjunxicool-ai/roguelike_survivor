extends RefCounted
class_name CharacterLoadoutService


const RunLoadoutScript: Script = preload("res://scripts/characters/run_loadout.gd")


static func resolve_weapon_id(character_id: Variant, weapon_id: Variant = &"") -> StringName:
	var requested_weapon_id: StringName = StringName(String(weapon_id))
	if requested_weapon_id != &"":
		return requested_weapon_id

	var allowed: Array[StringName] = get_allowed_weapon_ids(character_id)
	if allowed.is_empty():
		return &""
	return allowed[0]


static func is_weapon_allowed(character_id: Variant, weapon_id: Variant) -> bool:
	var target_weapon_id: StringName = StringName(String(weapon_id))
	if target_weapon_id == &"":
		return false
	return get_allowed_weapon_ids(character_id).has(target_weapon_id)


static func get_allowed_weapon_ids(character_id: Variant) -> Array[StringName]:
	var character: Dictionary = GameData.get_character(StringName(String(character_id)))
	var allowed: Array[StringName] = []
	for weapon_id_variant: Variant in _get_array(character.get("allowed_weapon_ids", [])):
		var weapon_id: StringName = StringName(String(weapon_id_variant))
		if weapon_id != &"" and not allowed.has(weapon_id):
			allowed.append(weapon_id)
	return allowed


static func get_allowed_weapons(character_id: Variant) -> Array[Dictionary]:
	var weapons: Array[Dictionary] = []
	for weapon_id: StringName in get_allowed_weapon_ids(character_id):
		var weapon: Dictionary = GameData.get_weapon(weapon_id)
		if not weapon.is_empty():
			weapons.append(weapon)
	return weapons


static func validate_loadout(character_id: Variant, weapon_id: Variant) -> bool:
	return get_validation_errors(character_id, weapon_id).is_empty()


static func get_validation_errors(character_id: Variant, weapon_id: Variant) -> Array[String]:
	var errors: Array[String] = []
	var resolved_character_id: StringName = StringName(String(character_id))
	var resolved_weapon_id: StringName = StringName(String(weapon_id))
	if resolved_character_id == &"":
		errors.append("Missing character_id.")
		return errors

	var character: Dictionary = GameData.get_character(resolved_character_id)
	if character.is_empty():
		errors.append("Unknown character_id: %s" % String(resolved_character_id))
		return errors

	if resolved_weapon_id == &"":
		errors.append("Missing weapon_id.")
		return errors

	var weapon: Dictionary = GameData.get_weapon(resolved_weapon_id)
	if weapon.is_empty():
		errors.append("Unknown weapon_id: %s" % String(resolved_weapon_id))
		return errors

	if not is_weapon_allowed(resolved_character_id, resolved_weapon_id):
		errors.append("Weapon %s is not allowed for character %s." % [String(resolved_weapon_id), String(resolved_character_id)])

	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id == &"":
		errors.append("Character %s has no starting_skill_id." % String(resolved_character_id))
	elif GameData.get_skill(starting_skill_id).is_empty():
		errors.append("Character %s references missing starting_skill_id: %s" % [String(resolved_character_id), String(starting_skill_id)])

	return errors


static func build_loadout(character_id: Variant, weapon_id: Variant = &"") -> RefCounted:
	var resolved_character_id: StringName = StringName(String(character_id))
	var resolved_weapon_id: StringName = resolve_weapon_id(resolved_character_id, weapon_id)
	if not validate_loadout(resolved_character_id, resolved_weapon_id):
		return null
	return RunLoadoutScript.new(GameData.get_character(resolved_character_id), GameData.get_weapon(resolved_weapon_id))


static func warn_if_invalid(character_id: Variant, weapon_id: Variant, prefix: String = "[CharacterLoadoutService]") -> bool:
	var errors: Array[String] = get_validation_errors(character_id, weapon_id)
	for error: String in errors:
		push_warning("%s %s" % [prefix, error])
	return errors.is_empty()


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
