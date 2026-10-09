## 文件用途：管理选中角色定义、临时属性快照及特性运行状态。
## 使用方式：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步。
extends Node
class_name CharacterRuntime


const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var character_definition: RefCounted
var trait_runtime_state: Dictionary = {}
var _runtime_modifiers: Dictionary = {}


## 作用：清空运行属性与特性状态，读取角色定义并同步属性来源；未知角色警告并返回 false。
## 使用：character_id 为角色 ID；返回布尔判断或执行是否成功。
func initialize(character_id: String) -> bool:
	_runtime_modifiers.clear()
	trait_runtime_state.clear()

	var character_data: Dictionary = _get_character_data(StringName(character_id))
	if character_data.is_empty():
		push_warning("[CharacterRuntime] Unknown character_id: %s" % character_id)
		return false

	character_definition = CharacterDefinitionScript.new(character_data)
	_sync_runtime_modifier_source()
	return true


## 作用：取得当前角色定义 ID，供装配和查询流程使用。
## 使用：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步。
func get_character_id() -> String:
	if character_definition == null:
		return ""
	return String(character_definition.get("id"))


## 作用：取得角色当前配置的初始技能标识，未装配角色时返回空标识。
## 使用：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步。
func get_starting_skill_id() -> String:
	if character_definition == null:
		return ""
	return String(character_definition.get("starting_skill_id"))


## 作用：从动作 context 提取技能及管理器，用统一服务计算技能定义属性。
## 使用：stat_name 为待查询属性键；default_value 为缺值备用结果。
func get_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	if character_definition == null:
		return default_value

	var base_stats: Dictionary = character_definition.get("base_stats")
	var base_value: Variant = base_stats.get(stat_name, default_value)
	return SkillModifierCalculatorScript.calculate(base_value, stat_name, _runtime_modifiers)


## 作用：返回角色特性配置副本，供控制器创建本局特性。
## 使用：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步；无适用数据时返回空字典。
func get_trait() -> Dictionary:
	if character_definition == null or not character_definition.has_method("get_trait"):
		return {}
	return character_definition.call("get_trait")


## 作用：累加同名数值运行属性，非数值或首次字段直接赋值。
## 使用：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步。
func add_runtime_modifier(key: Variant, value: Variant) -> void:
	var source: Dictionary = {String(key): value}
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, source)
	_sync_runtime_modifier_source()


## 作用：把给定快照合入角色运行属性后同步玩家属性来源。
## 使用：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步。
func add_runtime_modifiers(modifiers: Dictionary) -> void:
	SkillModifierCalculatorScript.merge_modifiers(_runtime_modifiers, modifiers)
	_sync_runtime_modifier_source()


## 作用：清空角色运行属性并移除父节点对应的属性来源。
## 使用：挂在玩家下，initialize 接收角色 ID；临时属性通过父节点的 character_runtime Modifier 来源同步。
func clear_temporary_modifiers() -> void:
	_runtime_modifiers.clear()
	_clear_runtime_modifier_source()


## 作用：将角色运行属性快照登记到玩家的 character_runtime 来源。
## 使用：由本文件 initialize/add_runtime_modifier 调用。
func _sync_runtime_modifier_source() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("set_run_modifier_source"):
		owner.call("set_run_modifier_source", &"character_runtime", _runtime_modifiers)


## 作用：移除玩家 character_runtime 属性来源。
## 使用：由本文件 clear_temporary_modifiers 调用。
func _clear_runtime_modifier_source() -> void:
	var owner: Node = get_parent()
	if owner != null and owner.has_method("clear_run_modifier_source"):
		owner.call("clear_run_modifier_source", &"character_runtime")


## 作用：通过 GameData 查询指定角色定义。
## 使用：character_id 为角色 ID。
func _get_character_data(character_id: StringName) -> Dictionary:
	return GameData.get_character(character_id)
