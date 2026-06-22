extends RefCounted
class_name CharacterRunInitializer

func initialize_loadout(player: Node, loadout: RefCounted) -> bool:
	if loadout == null or not bool(loadout.call("is_valid")):
		return false
	if player == null:
		return false

	var equip_system: Node = player.get_node_or_null("WeaponEquipSystem")
	if equip_system != null and equip_system.has_method("unlock_for_new_run"):
		equip_system.call("unlock_for_new_run")

	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	if runtime == null:
		return false

	var character_id: StringName = StringName(String(loadout.get("character_id")))
	var weapon_id: StringName = StringName(String(loadout.get("weapon_id")))
	var initialized: bool = bool(runtime.call("initialize", String(character_id), String(weapon_id)))
	if not initialized:
		push_warning("[CharacterRunInitializer] Failed to initialize character runtime for %s + %s." % [String(character_id), String(weapon_id)])
		return false

	var resolved_weapon_id: StringName = StringName(String(runtime.call("get_equipped_weapon_id")))
	player.set("selected_weapon_id", resolved_weapon_id)
	_initialize_trait_system(player, runtime)
	return true


func apply_character_setup(player: Node) -> void:
	if player == null:
		return
	var character_id: StringName = StringName(String(player.get("selected_character_id")))
	var character: Dictionary = GameData.get_character(character_id)
	if not character.is_empty():
		var base_stats: Variant = character.get("base_stats", {})
		if base_stats is Dictionary and player.has_method("_apply_base_stats"):
			player.call("_apply_base_stats", base_stats)
		if player.has_method("_apply_visual_config"):
			player.call("_apply_visual_config", character)
	if player.has_method("refresh_run_modifier_snapshot"):
		player.call("refresh_run_modifier_snapshot")
	if player.has_method("_apply_run_config"):
		player.call("_apply_run_config")


func configure_starting_skills(player: Node) -> void:
	if player == null:
		return

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null:
		return
	if skill_manager.has_method("clear_skills"):
		skill_manager.call("clear_skills")

	var starting_skill_id: StringName = _resolve_starting_skill_id(player)
	if starting_skill_id != &"" and skill_manager.has_method("add_skill"):
		skill_manager.call("add_skill", starting_skill_id)
	_connect_trait_skill_events(player)

	var equip_system: Node = player.get_node_or_null("WeaponEquipSystem")
	if equip_system != null and equip_system.has_method("lock_equipped_weapon"):
		equip_system.call("lock_equipped_weapon")


func _initialize_trait_system(player: Node, runtime: Node) -> void:
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem")
	if trait_system != null and trait_system.has_method("initialize"):
		trait_system.call("initialize", runtime)


func _connect_trait_skill_events(player: Node) -> void:
	var event_bus: Node = player.get_node_or_null("SkillEventBus")
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem")
	if event_bus == null or trait_system == null:
		return
	if event_bus.has_method("subscribe") and trait_system.has_method("handle_skill_bus_event"):
		event_bus.call("subscribe", &"on_cast", Callable(trait_system, "handle_skill_bus_event").bind(&"on_cast"))


func _resolve_starting_skill_id(player: Node) -> StringName:
	var character_id: StringName = StringName(String(player.get("selected_character_id")))
	var character: Dictionary = GameData.get_character(character_id)
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id != &"":
		return starting_skill_id
	return _first_configured_starting_skill_id()


func _first_configured_starting_skill_id() -> StringName:
	var document: Dictionary = GameData._load_document("res://data/skills.json")
	var starting_skills: Variant = document.get("starting_skills", [])
	if not (starting_skills is Array):
		return &""
	for skill_variant: Variant in starting_skills:
		if not (skill_variant is Dictionary):
			continue
		var skill: Dictionary = skill_variant
		var skill_id: StringName = StringName(String(skill.get("id", "")))
		if skill_id != &"":
			return skill_id
	return &""
