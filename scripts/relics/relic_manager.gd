## 文件用途：管理本局遗物持有、技能标签适配、事件触发次数和冷却以及属性来源注册。
## 使用方式：挂在玩家下；add_relic 注册负面属性，handle_combat_event 处理触发，技能查询读取匹配遗物效果。
extends Node
class_name RelicManager
const GameDataScript: Script = preload("res://scripts/game/game_data.gd")


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")

signal relic_added(relic_id: StringName)
signal relics_changed

@export_range(1, 20, 1, "or_greater") var max_relics: int = 3

var owned_relics: Array[StringName] = []
var _relic_definitions: Dictionary = {}
var _trigger_counts: Dictionary = {}
var _cooldown_until: Dictionary = {}


## 作用：从 GameData 遗物池重建本地 ID 索引。
## 使用：挂在玩家下；add_relic 注册负面属性，handle_combat_event 处理触发，技能查询读取匹配遗物效果。
func _ready() -> void:
	_load_relic_definitions()


## 作用：拒绝重复、超容量和无定义遗物；登记持有与负面属性后发出变更信号。
## 使用：relic_id 为遗物 ID；会发出对应变更信号；返回布尔判断或执行是否成功。
func add_relic(relic_id: Variant) -> bool:
	var id: StringName = _to_relic_id(relic_id)
	if id == &"" or has_relic(id) or not can_add_relic():
		return false

	var definition: Dictionary = _get_relic_definition(id)
	if definition.is_empty():
		return false

	owned_relics.append(id)
	_register_modifier_block("relic:%s:negative" % String(id), _get_array(definition.get("negative_modifier", [])))
	relic_added.emit(id)
	relics_changed.emit()
	_notify_skill_manager_changed()
	return true


## 作用：将输入统一为遗物 ID 后检查当前持有列表。
## 使用：relic_id 为遗物 ID。
func has_relic(relic_id: Variant) -> bool:
	return owned_relics.has(_to_relic_id(relic_id))


## 作用：遍历持有遗物并收集标签匹配技能的效果深拷贝。
## 使用：skill_instance 为技能运行实例。
func get_relic_modifiers_for_skill(skill_instance: RefCounted) -> Array:
	var modifiers: Array = []
	if skill_instance == null:
		return modifiers

	for relic_id: StringName in owned_relics:
		var relic: Dictionary = _get_relic_definition(relic_id)
		if relic.is_empty() or not _relic_applies_to_skill(relic, skill_instance):
			continue

		var relic_modifiers: Variant = relic.get("modifiers", [])
		if relic_modifiers is Array:
			modifiers.append_array((relic_modifiers as Array).duplicate(true))

	return modifiers


## 作用：判断持有遗物数量是否小于导出的容量上限。
## 使用：由本文件 add_relic 调用。
func can_add_relic() -> bool:
	return owned_relics.size() < max_relics


## 作用：按持有顺序返回所有有效遗物定义副本。
## 使用：挂在玩家下；add_relic 注册负面属性，handle_combat_event 处理触发，技能查询读取匹配遗物效果。
func get_owned_relic_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for relic_id: StringName in owned_relics:
		var definition: Dictionary = _get_relic_definition(relic_id)
		if not definition.is_empty():
			definitions.append(definition)
	return definitions


## 作用：把遗物 ID 标准化并返回定义副本。
## 使用：relic_id 为遗物 ID。
func get_relic_definition(relic_id: Variant) -> Dictionary:
	return _get_relic_definition(_to_relic_id(relic_id))


## 作用：清空本局遗物触发次数和冷却，不删除持有遗物。
## 使用：挂在玩家下；add_relic 注册负面属性，handle_combat_event 处理触发，技能查询读取匹配遗物效果。
func reset_run_effect_state() -> void:
	_trigger_counts.clear()
	_cooldown_until.clear()


## 作用：按事件名筛选持有遗物的触发条件并执行允许触发的效果。
## 使用：event_name 为统一技能事件名；payload 为事件附加字段。
func handle_combat_event(event_name: Variant, payload: Dictionary = {}) -> void:
	var event_id: String = String(event_name)
	if event_id == "":
		return
	for relic_id: StringName in owned_relics:
		var relic: Dictionary = _get_relic_definition(relic_id)
		if relic.is_empty() or not _can_trigger_relic(relic_id, relic, event_id, payload):
			continue
		_trigger_relic(relic_id, relic, payload)


## 作用：从 GameData 遗物池重建本地 ID 索引。
## 使用：由本文件 _ready/_get_relic_definition 调用。
func _load_relic_definitions() -> void:
	_relic_definitions.clear()
	for relic: Dictionary in GameDataScript.get_relic_pool():
		var relic_id: StringName = _to_relic_id(relic.get("id", ""))
		if relic_id != &"":
			_relic_definitions[relic_id] = relic


## 作用：惰性加载并缓存遗物定义，再深拷贝输出，未知 ID 返回空字典。
## 使用：relic_id 为遗物 ID；无适用数据时返回空字典。
func _get_relic_definition(relic_id: StringName) -> Dictionary:
	if _relic_definitions.is_empty():
		_load_relic_definitions()

	if not _relic_definitions.has(relic_id):
		var relic: Dictionary = GameDataScript.get_relic(relic_id)
		if not relic.is_empty():
			_relic_definitions[relic_id] = relic.duplicate(true)

	if not _relic_definitions.has(relic_id):
		return {}

	var definition: Dictionary = _relic_definitions[relic_id]
	return definition.duplicate(true)


## 作用：无标签要求时匹配所有技能，否则检查技能定义与遗物标签是否存在交集。
## 使用：skill_instance 为技能运行实例；返回布尔判断或执行是否成功。
func _relic_applies_to_skill(relic: Dictionary, skill_instance: RefCounted) -> bool:
	var required_tags: Array[String] = _get_string_array(relic.get("tags", []))
	if required_tags.is_empty():
		return true

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null or not definition.has_method("has_tag"):
		return false

	for tag: String in required_tags:
		if bool(definition.call("has_tag", tag)):
			return true

	return false


## 作用：通知同一玩家下 SkillManager 刷新技能相关展示与查询状态。
## 使用：会发出对应变更信号。
func _notify_skill_manager_changed() -> void:
	var skill_manager: Node = get_parent().get_node_or_null("SkillManager") if get_parent() != null else null
	if skill_manager != null and skill_manager.has_signal("skill_changed"):
		skill_manager.emit_signal("skill_changed")


## 作用：检查事件、状态或地图条件以及本局次数上限和实时冷却。
## 使用：relic_id 为遗物 ID；payload 为事件附加字段；返回布尔判断或执行是否成功。
func _can_trigger_relic(relic_id: StringName, relic: Dictionary, event_id: String, payload: Dictionary) -> bool:
	var condition: Dictionary = _get_dictionary(relic.get("trigger_condition", {}))
	if condition.is_empty():
		return false
	if String(condition.get("event", "")) != event_id:
		return false
	if condition.has("status_id") and String(condition.get("status_id", "")) != String(payload.get("status_id", "")):
		return false
	if condition.has("map_variable") and String(condition.get("map_variable", "")) != String(payload.get("map_variable", "")):
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	if now_seconds < float(_cooldown_until.get(relic_id, 0.0)):
		return false

	var limit_rule: Dictionary = _get_dictionary(relic.get("limit_rule", {}))
	var max_triggers: int = int(limit_rule.get("max_triggers_per_run", 1))
	if max_triggers > 0 and int(_trigger_counts.get(relic_id, 0)) >= max_triggers:
		return false
	return true


## 作用：叠加遗物触发属性，累计触发次数和下次可用时间，并通知技能变更。
## 使用：relic_id 为遗物 ID。
func _trigger_relic(relic_id: StringName, relic: Dictionary, _payload: Dictionary) -> void:
	_register_modifier_block("relic:%s:trigger" % String(relic_id), relic.get("modifiers", []), true)
	_trigger_counts[relic_id] = int(_trigger_counts.get(relic_id, 0)) + 1
	var cooldown: float = maxf(float(relic.get("cooldown", 0.0)), 0.0)
	if cooldown > 0.0:
		_cooldown_until[relic_id] = float(Time.get_ticks_msec()) / 1000.0 + cooldown
	_notify_skill_manager_changed()


## 作用：校验遗物效果列表后向玩家设置或合并稳定属性来源，非法输入拒绝注册。
## 使用：source_id 为稳定效果来源 ID；effects 为配置效果列表。
func _register_modifier_block(source_id: String, effects: Array, merge_existing: bool = false) -> void:
	if effects.is_empty():
		return
	var errors: Array[String] = ModifierSourceScript.validate_effects(effects)
	if not errors.is_empty():
		push_error("Invalid relic Modifier effects: " + "; ".join(errors))
		return
	var owning_node: Node = get_parent()
	if owning_node == null:
		return
	if merge_existing and owning_node.has_method("merge_run_modifier_source"):
		owning_node.call("merge_run_modifier_source", source_id, effects)
	elif owning_node.has_method("set_run_modifier_source"):
		owning_node.call("set_run_modifier_source", source_id, effects)


## 作用：将调用方遗物标识统一为 StringName。
## 使用：relic_id 为遗物 ID。
func _to_relic_id(relic_id: Variant) -> StringName:
	return StringName(String(relic_id))


## 作用：仅接受 Dictionary；深拷贝输出以隔离调用方修改，其余类型返回空字典。
## 使用：由本文件 _can_trigger_relic 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 add_relic 调用；无匹配项时返回空数组。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：按输入数组顺序转换元素为字符串，返回独立的强类型数组。
## 使用：由本文件 _relic_applies_to_skill 调用。
func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if not (value is Array):
		return strings

	var items: Array = value
	for item: Variant in items:
		strings.append(String(item))

	return strings
