## 文件用途：编排玩家开局的角色运行时、特性、基础属性和初始技能装配顺序。
## 使用方式：玩家创建组件后先 initialize_loadout，再 apply_character_setup 与 configure_starting_skills；技能事件接入特性桥。
extends RefCounted
class_name CharacterRunInitializer
const DEFAULT_STARTING_DASH_SKILL_ID: StringName = &"fire_dash_blazing_run"

## 作用：校验装配与玩家组件，先初始化角色运行时，再初始化特性系统。
## 使用：player 为玩家节点；返回布尔判断或执行是否成功。
func initialize_loadout(player: Node, loadout: RefCounted) -> bool:
	if loadout == null or not bool(loadout.call("is_valid")):
		return false
	if player == null:
		return false

	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	if runtime == null:
		return false

	var character_id: StringName = StringName(String(loadout.get("character_id")))
	var initialized: bool = bool(runtime.call("initialize", String(character_id)))
	if not initialized:
		push_warning("[CharacterRunInitializer] Failed to initialize character runtime for %s." % String(character_id))
		return false

	_initialize_trait_system(player, runtime)
	return true


## 作用：按选中角色应用玩家基础属性与外观，再刷新局内属性并应用本局配置。
## 使用：player 为玩家节点。
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


## 作用：清空技能后装配角色初始攻击和冲刺，并订阅施法事件到特性系统。
## 使用：player 为玩家节点。
func configure_starting_skills(player: Node) -> void:
	if player == null:
		return

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null:
		return
	if skill_manager.has_method("clear_skills"):
		skill_manager.call("clear_skills")

	var starting_skill_id: StringName = _resolve_starting_skill_id(player)
	if starting_skill_id != &"":
		if skill_manager.has_method("set_primary_attack_method"):
			skill_manager.call("set_primary_attack_method", starting_skill_id)
		elif skill_manager.has_method("add_skill"):
			skill_manager.call("add_skill", starting_skill_id)
	var starting_dash_skill_id: StringName = _resolve_starting_dash_skill_id(player)
	if starting_dash_skill_id != &"" and skill_manager.has_method("add_skill"):
		skill_manager.call("add_skill", starting_dash_skill_id)
	_connect_trait_skill_events(player)

## 作用：查找玩家 CharacterTraitSystem 并把已初始化的角色运行时交给它。
## 使用：player 为玩家节点。
func _initialize_trait_system(player: Node, runtime: Node) -> void:
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem")
	if trait_system != null and trait_system.has_method("initialize"):
		trait_system.call("initialize", runtime)


## 作用：把 on_cast 总线订阅绑定到特性系统，以转发施法事件。
## 使用：player 为玩家节点。
func _connect_trait_skill_events(player: Node) -> void:
	var event_bus: Node = player.get_node_or_null("SkillEventBus")
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem")
	if event_bus == null or trait_system == null:
		return
	if event_bus.has_method("subscribe") and trait_system.has_method("handle_skill_bus_event"):
		event_bus.call("subscribe", &"on_cast", Callable(trait_system, "handle_skill_bus_event").bind(&"on_cast"))


## 作用：优先取选中角色的初始技能，缺失时取配置初始技能池首项。
## 使用：player 为玩家节点。
func _resolve_starting_skill_id(player: Node) -> StringName:
	var character_id: StringName = StringName(String(player.get("selected_character_id")))
	var character: Dictionary = GameData.get_character(character_id)
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id != &"":
		return starting_skill_id
	return _first_configured_starting_skill_id()


## 作用：优先取角色配置的初始冲刺，否则使用默认火系冲刺。
## 使用：player 为玩家节点。
func _resolve_starting_dash_skill_id(player: Node) -> StringName:
	var character_id: StringName = StringName(String(player.get("selected_character_id")))
	var character: Dictionary = GameData.get_character(character_id)
	var configured_dash_id: StringName = StringName(String(character.get("starting_dash_skill_id", "")))
	if configured_dash_id != &"":
		return configured_dash_id
	return DEFAULT_STARTING_DASH_SKILL_ID


## 作用：按 GameData 初始技能池顺序返回第一个非空技能 ID。
## 使用：由本文件 _resolve_starting_skill_id 调用。
func _first_configured_starting_skill_id() -> StringName:
	for skill: Dictionary in GameData.get_starting_skill_pool():
		var skill_id: StringName = StringName(String(skill.get("id", "")))
		if skill_id != &"":
			return skill_id
	return &""
