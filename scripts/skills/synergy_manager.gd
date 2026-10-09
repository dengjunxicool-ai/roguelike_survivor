## 文件用途：根据已有技能标签激活配置协同并向伤害、击杀、施放和状态事件响应。
## 使用方式：挂在玩家下，refresh_active_synergies 更新匹配集合；事件回调应用协同属性，状态 tick 可查询间隔倍率。
extends Node
class_name SynergyManager
const GameDataScript: Script = preload("res://scripts/game/game_data.gd")

signal synergies_changed(active_synergy_ids: Array[StringName])

var active_synergies: Array[StringName] = []
var recognized_synergies: Array[StringName] = []
var _synergy_definitions: Dictionary = {}


## 作用：加载协同定义并按父节点玩家的持有技能刷新激活集合。
## 使用：挂在玩家下，refresh_active_synergies 更新匹配集合；事件回调应用协同属性，状态 tick 可查询间隔倍率。
func _ready() -> void:
	_load_synergy_definitions()
	refresh_active_synergies(get_parent())


## 作用：重算持有技能标签满足的协同集合，并发出副本形式的变更信号。
## 使用：player 为玩家节点；会发出对应变更信号。
func refresh_active_synergies(player: Node) -> void:
	_load_synergy_definitions()
	active_synergies.clear()
	recognized_synergies.clear()

	var owned_tags: Dictionary = _get_owned_skill_tags(player)
	for synergy_id_variant: Variant in _synergy_definitions.keys():
		var synergy_id: StringName = StringName(String(synergy_id_variant))
		var synergy: Dictionary = _synergy_definitions[synergy_id]
		recognized_synergies.append(synergy_id)
		if _requirements_met(synergy, owned_tags):
			active_synergies.append(synergy_id)

	synergies_changed.emit(active_synergies.duplicate())


## 作用：检查当前已激活协同 ID。
## 使用：由本文件 on_damage_dealt/on_status_applied 调用。
func has_synergy(synergy_id: Variant) -> bool:
	return active_synergies.has(StringName(String(synergy_id)))


## 作用：复制伤害事件；冻结物理协同激活且目标冻结时，把伤害乘以一点四。
## 使用：event 为当前事件或规则载荷。
func on_damage_dealt(event: Dictionary) -> Dictionary:
	var adjusted_event: Dictionary = event.duplicate(true)
	if not has_synergy(&"frozen_physical_bonus"):
		return adjusted_event

	var damage_type: StringName = StringName(String(adjusted_event.get("damage_type", "")))
	var element: StringName = StringName(String(adjusted_event.get("element", "")))
	if damage_type != &"direct_physical" and damage_type != &"physical" and element != &"physical":
		return adjusted_event

	var target: Node = adjusted_event.get("target") as Node
	if not _target_has_status(target, &"freeze"):
		return adjusted_event

	var amount: int = int(adjusted_event.get("amount", 0))
	adjusted_event["amount"] = maxi(roundi(float(amount) * 1.4), 0)
	adjusted_event["synergy_id"] = &"frozen_physical_bonus"
	return adjusted_event


## 作用：返回击杀事件深拷贝，当前入口没有额外协同行为。
## 使用：event 为当前事件或规则载荷。
func on_enemy_killed(event: Dictionary) -> Dictionary:
	var adjusted_event: Dictionary = event.duplicate(true)
	return adjusted_event


## 作用：返回施放事件深拷贝，当前入口没有额外协同行为。
## 使用：event 为当前事件或规则载荷。
func on_skill_cast(event: Dictionary) -> Dictionary:
	return event.duplicate(true)


## 作用：毒与减速协同激活且目标同时带两状态时，附加毒 tick 间隔零点七五倍语义。
## 使用：event 为当前事件或规则载荷。
func on_status_applied(event: Dictionary) -> Dictionary:
	var adjusted_event: Dictionary = event.duplicate(true)
	if not has_synergy(&"poison_slow_bonus"):
		return adjusted_event

	var target: Node = adjusted_event.get("target") as Node
	if _target_has_status(target, &"poison") and _target_has_status(target, &"slow"):
		adjusted_event["poison_tick_interval_multiplier"] = 0.75
		adjusted_event["synergy_id"] = &"poison_slow_bonus"

	return adjusted_event


## 作用：仅对满足毒与减速协同的中毒目标返回零点七五，其余返回一。
## 使用：target 为本次命中目标；status_id 为标准状态 ID。
func get_status_tick_interval_multiplier(target: Node, status_id: Variant) -> float:
	if StringName(String(status_id)) != &"poison" or not has_synergy(&"poison_slow_bonus"):
		return 1.0
	if not (_target_has_status(target, &"poison") and _target_has_status(target, &"slow")):
		return 1.0

	return 0.75


## 作用：索引为空时从 GameData 协同池惰性加载。
## 使用：由本文件 _ready/refresh_active_synergies 调用。
func _load_synergy_definitions() -> void:
	if not _synergy_definitions.is_empty():
		return

	_index_synergy_definitions(GameDataScript.get_synergy_pool())


## 作用：深拷贝有效 ID 的协同定义建立索引，缺 ID 输出错误。
## 使用：由本文件 _load_synergy_definitions 调用。
func _index_synergy_definitions(synergies: Array) -> void:
	for synergy_variant: Variant in synergies:
		if not (synergy_variant is Dictionary):
			continue

		var synergy: Dictionary = synergy_variant
		var synergy_id: StringName = StringName(String(synergy.get("id", "")))
		if synergy_id == &"":
			push_error("[SynergyManager] Synergy definition is missing id.")
			continue

		_synergy_definitions[synergy_id] = synergy.duplicate(true)


## 作用：要求持有标签集合包含配置 required_skill_tags 全部成员。
## 使用：由本文件 refresh_active_synergies 调用；返回布尔判断或执行是否成功。
func _requirements_met(synergy: Dictionary, owned_tags: Dictionary) -> bool:
	var required_tags: Array[String] = _get_string_array(synergy.get("required_skill_tags", []))
	for tag: String in required_tags:
		if not owned_tags.has(tag):
			return false

	return true


## 作用：从玩家持有技能定义收集去重标签集合。
## 使用：player 为玩家节点。
func _get_owned_skill_tags(player: Node) -> Dictionary:
	var tags: Dictionary = {}
	if player == null:
		return tags

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var skill_instances_variant: Variant = skill_manager.call("get_all_skills")
		if skill_instances_variant is Array:
			for skill_instance_variant: Variant in skill_instances_variant:
				var skill_instance: RefCounted = skill_instance_variant as RefCounted
				if skill_instance == null:
					continue

				var definition: RefCounted = skill_instance.get("definition") as RefCounted
				_add_definition_tags(tags, definition)

	return tags


## 作用：把技能定义标签写入集合字典，不读取运行标签。
## 使用：target 为本次命中目标；definition 为技能定义。
func _add_definition_tags(target: Dictionary, definition: RefCounted) -> void:
	if definition == null:
		return

	var tags_variant: Variant = definition.get("tags")
	if not (tags_variant is Array):
		return

	for tag_variant: Variant in tags_variant:
		target[String(tag_variant)] = true


## 作用：通过目标状态公开方法或 StatusEffectManager 检查指定状态。
## 使用：target 为本次命中目标；status_id 为标准状态 ID；返回布尔判断或执行是否成功。
func _target_has_status(target: Node, status_id: StringName) -> bool:
	if target == null:
		return false
	if target.has_method("has_status"):
		return bool(target.call("has_status", status_id))

	var status_manager: Node = target.get_node_or_null("StatusEffectManager")
	if status_manager != null and status_manager.has_method("has_status"):
		return bool(status_manager.call("has_status", status_id))

	return false


## 作用：按输入数组顺序转换元素为字符串，返回独立的强类型数组。
## 使用：由本文件 _requirements_met 调用。
func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if not (value is Array):
		return strings

	var items: Array = value
	for item: Variant in items:
		strings.append(String(item))

	return strings
