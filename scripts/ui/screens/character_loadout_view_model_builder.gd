extends RefCounted
class_name CharacterLoadoutViewModelBuilder


const UIDisplayHelperScript: Script = preload("res://scripts/ui/ui_display_helper.gd")
const CharacterLoadoutTextScript: Script = preload("res://scripts/ui/screens/character_loadout_text.gd")
const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")


func build(character_id: StringName, weapon_id: StringName, carousel_index: int, sync_index_from_selected: bool) -> Dictionary:
	var characters: Array = GameData.get_character_pool()
	if characters.is_empty():
		return {
			"characters": [],
			"carousel_index": 0,
			"character": {},
			"character_id": &"",
			"weapon_id": &"",
			"weapons": [],
			"details": {},
			"action": {"text": "请选择角色", "disabled": true}
		}

	var resolved_index: int = _resolve_carousel_index(characters, character_id, carousel_index, sync_index_from_selected)
	var character: Dictionary = _get_dictionary(characters[resolved_index])
	var resolved_character_id: StringName = StringName(String(character.get("id", "")))
	var resolved_weapon_id: StringName = _resolve_weapon_id(resolved_character_id, weapon_id)
	var allowed_weapons: Array[Dictionary] = CharacterLoadoutServiceScript.get_allowed_weapons(resolved_character_id)
	var is_unlocked: bool = SaveManager.is_character_unlocked(resolved_character_id)
	return {
		"characters": characters,
		"carousel_index": resolved_index,
		"character": character,
		"character_id": resolved_character_id,
		"weapon_id": resolved_weapon_id,
		"weapons": allowed_weapons,
		"details": _build_character_details(character, resolved_weapon_id, is_unlocked),
		"action": _build_action(character, resolved_weapon_id, is_unlocked)
	}


func build_weapon_focus(weapon_id: StringName, character_id: StringName) -> Dictionary:
	var character: Dictionary = GameData.get_character(character_id)
	var is_unlocked: bool = SaveManager.is_character_unlocked(character_id)
	var labels: Dictionary = _build_weapon_details(GameData.get_weapon(weapon_id), weapon_id)
	labels["lock"] = CharacterLoadoutTextScript.selection_status_text(character, is_unlocked)
	return labels


func _resolve_carousel_index(characters: Array, character_id: StringName, carousel_index: int, sync_index_from_selected: bool) -> int:
	if sync_index_from_selected:
		for index: int in range(characters.size()):
			var character: Dictionary = _get_dictionary(characters[index])
			if StringName(String(character.get("id", ""))) == character_id:
				return index
	return clampi(carousel_index, 0, characters.size() - 1)


func _resolve_weapon_id(character_id: StringName, weapon_id: StringName) -> StringName:
	if weapon_id != &"" and CharacterLoadoutServiceScript.is_weapon_allowed(character_id, weapon_id):
		return weapon_id
	return CharacterLoadoutServiceScript.resolve_weapon_id(character_id, &"")


func _build_character_details(character: Dictionary, weapon_id: StringName, is_unlocked: bool) -> Dictionary:
	var labels: Dictionary = {
		"role": "定位：%s" % CharacterLoadoutTextScript.role_text(character),
		"stats": CharacterLoadoutTextScript.stats_text(character),
		"trait": "天赋说明：%s" % CharacterLoadoutTextScript.trait_text(character),
		"drawback": "短板：%s" % CharacterLoadoutTextScript.drawback_text(character),
		"difficulty": "操作难度：%s" % CharacterLoadoutTextScript.difficulty_text(character),
		"lock": CharacterLoadoutTextScript.selection_status_text(character, is_unlocked)
	}
	labels.merge(_build_weapon_details(GameData.get_weapon(weapon_id), weapon_id), true)
	return labels


func _build_weapon_details(weapon: Dictionary, weapon_id: StringName) -> Dictionary:
	if weapon.is_empty():
		return {
			"weapon_name": "武器：未选择",
			"weapon_description": "",
			"weapon_branch": ""
		}
	return {
		"weapon_name": "武器：%s" % UIDisplayHelperScript.weapon_name(weapon, weapon_id),
		"weapon_description": CharacterLoadoutTextScript.weapon_description_text(weapon),
		"weapon_branch": CharacterLoadoutTextScript.branch_preview_text(weapon)
	}


func _build_action(character: Dictionary, weapon_id: StringName, is_unlocked: bool) -> Dictionary:
	var character_id: StringName = StringName(String(character.get("id", "")))
	if is_unlocked:
		return {
			"text": "立刻出发" if weapon_id != &"" else "请选择武器",
			"disabled": weapon_id == &""
		}
	return {
		"text": CharacterLoadoutTextScript.action_text(character, false),
		"disabled": not SaveManager.can_purchase_character(character_id)
	}


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
