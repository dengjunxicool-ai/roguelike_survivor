extends RefCounted
class_name WeaponRuntimeSlot


var slot_id: StringName = &"main_weapon"
var weapon_id: StringName = &""
var base_skill_id: StringName = &""
var current_skill_id: StringName = &""
var selected_branch_id: StringName = &""
var branch_level: int = 1
var branch_ids: Array[StringName] = []


func initialize_from_weapon(weapon_definition: RefCounted, target_slot_id: StringName = &"main_weapon") -> void:
	slot_id = target_slot_id
	selected_branch_id = &""
	branch_level = 1
	branch_ids.clear()

	if weapon_definition == null:
		weapon_id = &""
		base_skill_id = &""
		current_skill_id = &""
		return

	weapon_id = StringName(String(weapon_definition.get("id")))
	base_skill_id = StringName(String(weapon_definition.get("starting_skill_id")))
	current_skill_id = base_skill_id
	if weapon_definition.has_method("get_branch_ids"):
		for branch_id_variant: Variant in weapon_definition.call("get_branch_ids"):
			var branch_id: StringName = StringName(String(branch_id_variant))
			if branch_id != &"":
				branch_ids.append(branch_id)


func set_selected_branch(branch_id: Variant) -> bool:
	var id: StringName = StringName(String(branch_id))
	if id == &"":
		return false
	if selected_branch_id != &"" and selected_branch_id != id:
		return false
	selected_branch_id = id
	branch_level = maxi(branch_level, 2)
	return true


func mark_branch_level(branch_id: Variant, target_level: int) -> bool:
	var id: StringName = StringName(String(branch_id))
	if id == &"":
		return false
	if selected_branch_id == &"":
		selected_branch_id = id
	if selected_branch_id != id:
		return false
	branch_level = maxi(branch_level, target_level)
	return true


func to_debug_dict() -> Dictionary:
	return {
		"slot_id": slot_id,
		"weapon_id": weapon_id,
		"base_skill_id": base_skill_id,
		"current_skill_id": current_skill_id,
		"selected_branch_id": selected_branch_id,
		"branch_level": branch_level,
		"branch_ids": branch_ids.duplicate()
	}
