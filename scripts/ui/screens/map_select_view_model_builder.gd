extends RefCounted
class_name MapSelectViewModelBuilder


const MapRuntimeScript: Script = preload("res://scripts/maps/map_runtime.gd")


func build(character_id: StringName, weapon_id: StringName, selected_map_id: StringName) -> Dictionary:
	var selected_map: Dictionary = GameData.get_map(selected_map_id)
	var character: Dictionary = GameData.get_character(character_id)
	var weapon: Dictionary = GameData.get_weapon(weapon_id)
	var can_start: bool = _can_start(character, weapon_id, selected_map)
	return {
		"maps": GameData.get_map_pool(),
		"selected_map": selected_map,
		"souls": SaveManager.get_soul_stones(),
		"loadout": {
			"character": "角色\n%s" % _display_name(character, character_id),
			"weapon": "武器\n%s" % _display_name(weapon, weapon_id),
			"skill": "初始技能\n%s" % _skill_name(StringName(String(weapon.get("starting_skill_id", "")))),
			"threat": "威胁等级\n1（已锁定，仅 UI）"
		},
		"start_button": {
			"can_start": can_start,
			"text": "开始挑战" if can_start else _get_start_blocked_text(character, weapon_id, selected_map)
		}
	}


func _can_start(character: Dictionary, weapon_id: StringName, map_data: Dictionary) -> bool:
	if character.is_empty() or weapon_id == &"" or map_data.is_empty():
		return false
	if not _is_weapon_allowed_for_character(weapon_id, character):
		return false
	return MapRuntimeScript.is_map_unlocked(map_data)


func _get_start_blocked_text(character: Dictionary, weapon_id: StringName, map_data: Dictionary) -> String:
	if character.is_empty() or weapon_id == &"":
		return "请选择角色和武器"
	if not _is_weapon_allowed_for_character(weapon_id, character):
		return "武器不可用"
	if not MapRuntimeScript.is_map_unlocked(map_data):
		return "地图未解锁"
	return "暂不可开始"


func _is_weapon_allowed_for_character(weapon_id: StringName, character: Dictionary) -> bool:
	var allowed: Array = character.get("allowed_weapon_ids", [])
	if allowed.is_empty():
		return true
	for id_variant: Variant in allowed:
		if StringName(String(id_variant)) == weapon_id:
			return true
	return false


func _display_name(data: Dictionary, fallback: Variant) -> String:
	return String(data.get("display_name", fallback)) if not data.is_empty() else String(fallback)


func _skill_name(skill_id: StringName) -> String:
	if skill_id == &"":
		return "未配置"
	var skill: Dictionary = GameData.get_skill(skill_id)
	return String(skill.get("display_name", skill_id))
