extends Node
class_name WeaponBranchSystem


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")


func has_selected_branch(player: Node) -> bool:
	var runtime: Node = _get_runtime(player)
	return _get_selected_branch_id_from_runtime(runtime) != &""


func get_selected_branch_id(player: Node) -> StringName:
	var runtime: Node = _get_runtime(player)
	return _get_selected_branch_id_from_runtime(runtime)


func get_available_branches(player: Node) -> Array[Dictionary]:
	var runtime: Node = _get_runtime(player)
	var skill_instance: RefCounted = _get_equipped_weapon_skill_instance(player)
	if runtime == null or skill_instance == null:
		return []
	if _get_selected_branch_id_from_runtime(runtime) != &"":
		return []
	if int(skill_instance.get("current_level")) != 1:
		return []

	var branch_ids: Array = runtime.call("get_equipped_weapon_branch_ids")
	var branches: Array[Dictionary] = []
	for branch_id_variant: Variant in branch_ids:
		var branch: Dictionary = _get_branch_definition(StringName(String(branch_id_variant)))
		if branch.is_empty():
			continue
		if _branch_matches_current_weapon(runtime, branch):
			branches.append(branch)
	return branches


func apply_branch(player: Node, branch_id: Variant, dev_enabled: bool = false) -> bool:
	var runtime: Node = _get_runtime(player)
	var skill_instance: RefCounted = _get_equipped_weapon_skill_instance(player)
	if runtime == null or skill_instance == null:
		return false

	var target_branch_id: StringName = StringName(String(branch_id))
	var branch: Dictionary = _get_branch_definition(target_branch_id)
	if branch.is_empty() or not _branch_matches_current_weapon(runtime, branch):
		return false
	if not dev_enabled and not bool(runtime.call("set_selected_branch", target_branch_id)):
		return false

	if int(skill_instance.get("current_level")) < 2:
		skill_instance.set("current_level", 2)

	var applied: bool = _apply_branch_level_config(runtime, skill_instance, branch, 2, dev_enabled)
	if dev_enabled:
		applied = true

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager != null:
		if skill_manager.has_signal("skill_upgraded"):
			skill_manager.emit_signal("skill_upgraded", StringName(String(skill_instance.get("skill_id"))), int(skill_instance.get("current_level")))
		if skill_manager.has_signal("skill_changed"):
			skill_manager.emit_signal("skill_changed")
	return applied


func apply_selected_branch_level(player: Node, target_level: int, dev_branch_id: Variant = &"", dev_enabled: bool = false) -> bool:
	var runtime: Node = _get_runtime(player)
	var skill_instance: RefCounted = _get_equipped_weapon_skill_instance(player)
	if runtime == null or skill_instance == null or target_level < 3 or target_level > 5:
		return false

	var branch_id: StringName = _get_selected_branch_id_from_runtime(runtime)
	if dev_enabled and StringName(String(dev_branch_id)) != &"":
		branch_id = StringName(String(dev_branch_id))
	if branch_id == &"":
		return false

	var branch: Dictionary = _get_branch_definition(branch_id)
	if branch.is_empty() or not _branch_matches_current_weapon(runtime, branch):
		return false

	return _apply_branch_level_config(runtime, skill_instance, branch, target_level, dev_enabled)


func has_applied_selected_branch_level(player: Node, target_level: int) -> bool:
	var runtime: Node = _get_runtime(player)
	var skill_instance: RefCounted = _get_equipped_weapon_skill_instance(player)
	if runtime == null or skill_instance == null:
		return false
	var branch_id: StringName = _get_selected_branch_id_from_runtime(runtime)
	if branch_id == &"" or not skill_instance.has_method("has_applied_branch_level"):
		return false
	return bool(skill_instance.call("has_applied_branch_level", branch_id, target_level))


func get_selected_branch(player: Node) -> Dictionary:
	var branch_id: StringName = get_selected_branch_id(player)
	if branch_id == &"":
		return {}
	return _get_branch_definition(branch_id)


func _get_equipped_weapon_skill_instance(player: Node) -> RefCounted:
	if player == null:
		return null
	var runtime: Node = _get_runtime(player)
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null or not skill_manager.has_method("get_skill"):
		return null
	return skill_manager.call("get_skill", StringName(String(runtime.call("get_equipped_weapon_skill_id")))) as RefCounted


func _branch_matches_current_weapon(runtime: Node, branch: Dictionary) -> bool:
	if runtime == null:
		return false
	return StringName(String(branch.get("weapon_id", ""))) == StringName(String(runtime.call("get_equipped_weapon_id")))


func _get_runtime(player: Node) -> Node:
	return player.get_node_or_null("CharacterRuntime") if player != null else null


func _get_selected_branch_id_from_runtime(runtime: Node) -> StringName:
	if runtime == null:
		return &""
	return StringName(String(runtime.call("get_selected_weapon_branch_id")))


func _get_branch_definition(branch_id: StringName) -> Dictionary:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_weapon_branch_definition"):
		var branch: Variant = data_manager.call("get_weapon_branch_definition", branch_id)
		if branch is Dictionary:
			return branch
	return GameData.get_weapon_branch(branch_id)


func _apply_branch_level_config(runtime: Node, skill_instance: RefCounted, branch: Dictionary, target_level: int, dev_enabled: bool = false) -> bool:
	var branch_id: StringName = StringName(String(branch.get("id", "")))
	if branch_id == &"":
		return false
	if skill_instance.has_method("has_applied_branch_level") and bool(skill_instance.call("has_applied_branch_level", branch_id, target_level)):
		return false

	var level_config: Dictionary = _get_branch_level_config(branch, target_level)
	if level_config.is_empty():
		return false

	var modifiers: Dictionary = ModifierSourceScript.flatten(level_config.get("modifiers", {}), ModifierSourceScript.SOURCE_WEAPON_BRANCH)
	var runtime_modifiers: Dictionary = _get_dictionary(skill_instance.get("runtime_modifiers"))
	SkillModifierCalculatorScript.merge_modifiers(runtime_modifiers, modifiers)
	skill_instance.set("runtime_modifiers", runtime_modifiers)

	if skill_instance.has_method("add_runtime_events"):
		skill_instance.call("add_runtime_events", _get_array(level_config.get("events_added", [])))
	if skill_instance.has_method("add_runtime_special_rules"):
		skill_instance.call("add_runtime_special_rules", _get_dictionary(level_config.get("special_rules", {})))
	if skill_instance.has_method("add_runtime_tag"):
		for tag: Variant in _get_array(level_config.get("tags_added", [])):
			skill_instance.call("add_runtime_tag", tag)

	if skill_instance.has_method("mark_branch_level_applied"):
		skill_instance.call("mark_branch_level_applied", branch_id, target_level)
	if not dev_enabled:
		runtime.call("mark_weapon_branch_level", branch_id, target_level)
	return true


func _get_branch_level_config(branch: Dictionary, target_level: int) -> Dictionary:
	var level_path: Dictionary = _get_dictionary(branch.get("level_path", {}))
	var key: String = str(target_level)
	var config: Dictionary = _get_dictionary(level_path.get(key, level_path.get(target_level, {})))
	if not config.is_empty():
		return config

	if target_level == 2:
		return {
			"modifiers": branch.get("modifiers", {}),
			"events_added": _get_array(branch.get("events_added", [])),
			"tags_added": _get_array(branch.get("tags_added", [])),
			"special_rules": _get_dictionary(branch.get("special_rules", {}))
		}
	return {}


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
