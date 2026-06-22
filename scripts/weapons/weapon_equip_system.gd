extends Node
class_name WeaponEquipSystem


const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")

var _weapon_locked: bool = false


func can_equip(character_id: Variant, weapon_id: Variant) -> bool:
	return CharacterLoadoutServiceScript.is_weapon_allowed(character_id, weapon_id)


func equip_weapon(player: Node, weapon_id: Variant) -> bool:
	if _weapon_locked:
		push_warning("[WeaponEquipSystem] Cannot switch weapon after combat has started.")
		return false
	if player == null:
		return false

	var character_id: StringName = _get_player_character_id(player)
	var target_weapon_id: StringName = StringName(String(weapon_id))
	if target_weapon_id == &"" or not can_equip(character_id, target_weapon_id):
		push_warning("[WeaponEquipSystem] Weapon %s is not allowed for character %s." % [String(target_weapon_id), String(character_id)])
		return false

	player.set("selected_weapon_id", target_weapon_id)
	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	if runtime != null:
		return bool(runtime.call("initialize", String(character_id), String(target_weapon_id)))
	return true


func lock_equipped_weapon() -> void:
	_weapon_locked = true


func unlock_for_new_run() -> void:
	_weapon_locked = false


func is_weapon_locked() -> bool:
	return _weapon_locked


func _get_player_character_id(player: Node) -> StringName:
	var value: Variant = player.get("selected_character_id")
	return StringName(String(value))
