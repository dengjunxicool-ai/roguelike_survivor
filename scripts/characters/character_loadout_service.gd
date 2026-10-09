## 文件用途：校验角色及初始技能引用，并生成单局角色装配对象。
## 使用方式：开局前调用 build_loadout；无效角色返回 null，get_validation_errors 可用于展示校验原因。
extends RefCounted
class_name CharacterLoadoutService


const RunLoadoutScript: Script = preload("res://scripts/characters/run_loadout.gd")


## 作用：判断角色和初始技能引用是否全部有效。
## 使用：character_id 为角色 ID。
static func validate_loadout(character_id: Variant) -> bool:
	return get_validation_errors(character_id).is_empty()


## 作用：收集角色 ID 缺失、角色未知或初始技能引用无效的具体原因。
## 使用：character_id 为角色 ID。
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


## 作用：为通过校验的角色创建 RunLoadout 快照，校验失败返回 null。
## 使用：character_id 为角色 ID；无法解析或创建时返回 null。
static func build_loadout(character_id: Variant) -> RefCounted:
	var resolved_character_id: StringName = StringName(String(character_id))
	if not validate_loadout(resolved_character_id):
		return null
	return RunLoadoutScript.new(GameData.get_character(resolved_character_id))


## 作用：输出装配校验警告并返回是否有效，警告加上调用方前缀。
## 使用：character_id 为角色 ID。
static func warn_if_invalid(character_id: Variant, prefix: String = "[CharacterLoadoutService]") -> bool:
	var errors: Array[String] = get_validation_errors(character_id)
	for error: String in errors:
		push_warning("%s %s" % [prefix, error])
	return errors.is_empty()
