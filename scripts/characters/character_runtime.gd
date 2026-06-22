extends Node
class_name CharacterRuntime


const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")
const WeaponDefinitionScript: Script = preload("res://scripts/weapons/weapon_definition.gd")
const WeaponRuntimeSlotScript: Script = preload("res://scripts/weapons/weapon_runtime_slot.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")

var character_definition: RefCounted
var equipped_weapon_definition: RefCounted
var main_weapon_slot: RefCounted
var weapon_slots: Array[RefCounted] = []
var trait_runtime_state: Dictionary = {}
var _runtime_modifiers: Dictionary = {}


func initialize(character_id: String, weapon_id: String) -> bool:
	_runtime_modifiers.clear()
	trait_runtime_state.clear()
	weapon_slots.clear()
	main_weapon_slot = null

	var character_data: Dictionary = _get_character_data(StringName(character_id))
	if character_data.is_empty():
		push_warning("[CharacterRuntime] Unknown character_id: %s" % character_id)
		return false

	character_definition = CharacterDefinitionScript.new(character_data)
	var resolved_weapon_id: StringName = StringName(weapon_id)
	if resolved_weapon_id == &"":
		resolved_weapon_id = _get_first_allowed_weapon_id()

	var weapon_data: Dictionary = _get_weapon_data(resolved_weapon_id)
	if weapon_data.is_empty():
		push_warning("[CharacterRuntime] Unknown weapon_id: %s" % String(resolved_weapon_id))
		return false

	equipped_weapon_definition = WeaponDefinitionScript.new(weapon_data)
	if not bool(character_definition.call("can_equip_weapon", String(resolved_weapon_id))):
		push_warning("[CharacterRuntime] Character %s cannot equip weapon %s." % [character_id, String(resolved_weapon_id)])
		equipped_weapon_definition = null
		return false

	main_weapon_slot = WeaponRuntimeSlotScript.new()
	main_weapon_slot.call("initialize_from_weapon", equipped_weapon_definition, &"main_weapon")
	weapon_slots.append(main_weapon_slot)
	_apply_weapon_trait_modifiers()
	return true


func get_character_id() -> String:
	if character_definition == null:
		return ""
	return String(character_definition.get("id"))


func get_equipped_weapon_id() -> String:
	if main_weapon_slot != null:
		return String(main_weapon_slot.get("weapon_id"))
	if equipped_weapon_definition == null:
		return ""
	return String(equipped_weapon_definition.get("id"))


func get_equipped_weapon_skill_id() -> String:
	if main_weapon_slot != null:
		return String(main_weapon_slot.get("current_skill_id"))
	if equipped_weapon_definition == null:
		return ""
	return String(equipped_weapon_definition.get("starting_skill_id"))


func get_equipped_weapon_branch_ids() -> Array:
	if main_weapon_slot != null:
		return main_weapon_slot.get("branch_ids")
	if equipped_weapon_definition == null or not equipped_weapon_definition.has_method("get_branch_ids"):
		return []
	return equipped_weapon_definition.call("get_branch_ids")


func get_selected_weapon_branch_id() -> String:
	if main_weapon_slot != null:
		return String(main_weapon_slot.get("selected_branch_id"))
	return ""


func get_selected_weapon_branch_level() -> int:
	if main_weapon_slot != null:
		return int(main_weapon_slot.get("branch_level"))
	return 1


func get_main_weapon_slot() -> RefCounted:
	return main_weapon_slot


func get_weapon_slots() -> Array:
	return weapon_slots.duplicate()


func get_weapon_slot_debug_state() -> Dictionary:
	if main_weapon_slot != null and main_weapon_slot.has_method("to_debug_dict"):
		return main_weapon_slot.call("to_debug_dict")
	return {}


func get_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	if character_definition == null:
		return default_value

	var base_stats: Dictionary = character_definition.get("base_stats")
	var base_value: Variant = base_stats.get(stat_name, default_value)
	return SkillModifierCalculatorScript.calculate(base_value, stat_name, _runtime_modifiers)


func get_trait() -> Dictionary:
	if character_definition == null or not character_definition.has_method("get_trait"):
		return {}
	return character_definition.call("get_trait")


func add_runtime_modifier(key: Variant, value: Variant) -> void:
	var source: Dictionary = {String(key): value}
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, source)
	_sync_runtime_modifier_source()


func add_runtime_modifiers(modifiers: Dictionary) -> void:
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, modifiers)
	_sync_runtime_modifier_source()


func clear_temporary_modifiers() -> void:
	_runtime_modifiers.clear()
	_clear_runtime_modifier_source()
	_apply_weapon_trait_modifiers()


func set_selected_branch(branch_id: Variant) -> bool:
	var id: StringName = StringName(String(branch_id))
	if id == &"":
		return false
	if main_weapon_slot == null:
		return false
	var current_branch_id: StringName = StringName(String(main_weapon_slot.get("selected_branch_id")))
	if current_branch_id != &"" and current_branch_id != id:
		return false
	return bool(main_weapon_slot.call("set_selected_branch", id))


func mark_weapon_branch_level(branch_id: Variant, target_level: int) -> bool:
	if main_weapon_slot == null:
		return false
	return bool(main_weapon_slot.call("mark_branch_level", branch_id, target_level))


func _apply_weapon_trait_modifiers() -> void:
	if equipped_weapon_definition == null:
		return

	var trait_data: Dictionary = equipped_weapon_definition.call("get_weapon_trait")
	var modifiers: Dictionary = ModifierSourceScript.flatten(trait_data.get("modifiers", {}), ModifierSourceScript.SOURCE_WEAPON_TRAIT)
	var penalties: Dictionary = ModifierSourceScript.flatten(trait_data.get("penalties", {}), ModifierSourceScript.SOURCE_WEAPON_TRAIT)
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, modifiers)
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, penalties)
	_sync_runtime_modifier_source()


func _sync_runtime_modifier_source() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("set_run_modifier_source"):
		owner.call("set_run_modifier_source", &"character_runtime", _runtime_modifiers)


func _clear_runtime_modifier_source() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		owner.call("clear_run_modifier_source", &"character_runtime")


func _get_first_allowed_weapon_id() -> StringName:
	if character_definition == null or not character_definition.has_method("get_allowed_weapon_ids"):
		return &""

	var allowed: Array = character_definition.call("get_allowed_weapon_ids")
	if allowed.is_empty():
		return &""
	return StringName(String(allowed[0]))


func _get_character_data(character_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_character_definition"):
		var data: Variant = data_manager.call("get_character_definition", character_id)
		if data is Dictionary:
			return data
	return GameData.get_character(character_id)


func _get_weapon_data(weapon_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_weapon_definition"):
		var data: Variant = data_manager.call("get_weapon_definition", weapon_id)
		if data is Dictionary:
			return data
	return GameData.get_weapon(weapon_id)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
