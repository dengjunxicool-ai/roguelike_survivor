## 文件用途：按查询域合并 ModifierStore、技能运行属性、被动、特性及遗物贡献。
## 使用方式：collect 返回聚合快照，calculate 直接计算单项属性；可传管理器，否则从查询 owner 的子节点解析。
extends RefCounted
class_name ModifierAggregator


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")


## 作用：按查询域顺序合并仓库、运行技能、被动、角色特性与遗物属性；伤害域不再收集角色特性。
## 使用：query 为携带作用域与过滤信息的属性查询；skill_manager 为技能管理器；relic_manager 为遗物管理器。
static func collect(query: RefCounted, skill_manager: Node = null, relic_manager: Node = null) -> Dictionary:
	var modifiers: Dictionary = {}
	var owner: Node = _get_owner(query)
	if owner == null:
		owner = _infer_owner(skill_manager, relic_manager)
	var scope: StringName = _get_scope(query)
	_merge(modifiers, _collect_store_modifiers(query, owner))
	if scope == ModifierQueryScript.SCOPE_SKILL:
		_merge(modifiers, _collect_skill_runtime_modifiers(query))
		_merge(modifiers, _collect_skill_passive_modifiers(_resolve_skill_manager(owner, skill_manager), query))
	if scope == ModifierQueryScript.SCOPE_DAMAGE:
		_merge(modifiers, _collect_relic_damage_modifiers(query, owner, skill_manager, relic_manager))
	if scope != ModifierQueryScript.SCOPE_DAMAGE:
		_merge(modifiers, _collect_character_trait_modifiers(query, owner))
	if scope == ModifierQueryScript.SCOPE_SKILL:
		_merge(modifiers, _collect_relic_skill_modifiers(query, _resolve_relic_manager(owner, relic_manager)))
	return modifiers


## 作用：从玩家 ModifierStore 查询作用域效果，并返回隔离的快照。
## 使用：query 为携带作用域与过滤信息的属性查询；owner 为效果拥有者；无适用数据时返回空字典。
static func _collect_store_modifiers(query: RefCounted, owner: Node) -> Dictionary:
	if owner == null:
		return {}
	var store: Node = owner.get_node_or_null("ModifierStore")
	if store == null or not store.has_method("collect"):
		return {}
	var store_modifiers_variant: Variant = store.call("collect", query)
	if store_modifiers_variant is Dictionary:
		return (store_modifiers_variant as Dictionary).duplicate(true)
	return {}


## 作用：先收集查询范围内全部属性，再通过统一 Modifier 公式计算指定基础值。
## 使用：base_value 为修饰前数值；stat_name 为待查询属性键；query 为携带作用域与过滤信息的属性查询。
static func calculate(base_value: Variant, stat_name: String, query: RefCounted, skill_manager: Node = null, relic_manager: Node = null) -> Variant:
	return SkillModifierCalculatorScript.calculate(base_value, stat_name, collect(query, skill_manager, relic_manager))


## 作用：取得查询技能实例的运行属性，效果列表按查询过滤后展开。
## 使用：query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
static func _collect_skill_runtime_modifiers(query: RefCounted) -> Dictionary:
	if query == null:
		return {}
	var skill: RefCounted = query.get("skill_instance") as RefCounted
	if skill == null:
		return {}
	var runtime_modifiers_variant: Variant = skill.get("runtime_modifiers")
	if runtime_modifiers_variant is Dictionary:
		return (runtime_modifiers_variant as Dictionary).duplicate(true)
	if runtime_modifiers_variant is Array:
		return ModifierSourceScript.flatten_effects(runtime_modifiers_variant as Array, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


## 作用：取得技能管理器被动属性，结构化效果按查询展开。
## 使用：skill_manager 为技能管理器；query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
static func _collect_skill_passive_modifiers(skill_manager: Node, query: RefCounted) -> Dictionary:
	if skill_manager == null:
		return {}
	var passive_variant: Variant = skill_manager.get("passive_modifiers")
	if passive_variant is Dictionary:
		return (passive_variant as Dictionary).duplicate(true)
	if passive_variant is Array:
		return ModifierSourceScript.flatten_effects(passive_variant as Array, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


## 作用：向玩家特性系统请求查询属性并复制结果。
## 使用：query 为携带作用域与过滤信息的属性查询；owner 为效果拥有者；无适用数据时返回空字典。
static func _collect_character_trait_modifiers(query: RefCounted, owner: Node) -> Dictionary:
	if owner == null:
		return {}
	var trait_system: Node = owner.get_node_or_null("CharacterTraitSystem")
	if trait_system == null or not trait_system.has_method("get_modifiers"):
		return {}
	var trait_modifiers_variant: Variant = trait_system.call("get_modifiers", query)
	if trait_modifiers_variant is Dictionary:
		return (trait_modifiers_variant as Dictionary).duplicate(true)
	if trait_modifiers_variant is Array:
		return ModifierSourceScript.flatten_effects(trait_modifiers_variant as Array, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


## 作用：获取匹配查询技能标签的遗物效果并按技能查询展开。
## 使用：query 为携带作用域与过滤信息的属性查询；relic_manager 为遗物管理器；无适用数据时返回空字典。
static func _collect_relic_skill_modifiers(query: RefCounted, relic_manager: Node) -> Dictionary:
	if query == null or relic_manager == null or not relic_manager.has_method("get_relic_modifiers_for_skill"):
		return {}
	var skill: RefCounted = query.get("skill_instance") as RefCounted
	if skill == null:
		return {}
	var relic_modifiers_variant: Variant = relic_manager.call("get_relic_modifiers_for_skill", skill)
	if relic_modifiers_variant is Dictionary:
		return (relic_modifiers_variant as Dictionary).duplicate(true)
	if relic_modifiers_variant is Array:
		return ModifierSourceScript.flatten_effects(relic_modifiers_variant as Array, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


## 作用：解析伤害来源技能实例，获取对应遗物效果并按伤害查询过滤。
## 使用：query 为携带作用域与过滤信息的属性查询；owner 为效果拥有者；skill_manager 为技能管理器；无适用数据时返回空字典。
static func _collect_relic_damage_modifiers(query: RefCounted, owner: Node, skill_manager: Node, relic_manager: Node) -> Dictionary:
	if query == null:
		return {}
	var resolved_relic_manager: Node = _resolve_relic_manager(owner, relic_manager)
	if resolved_relic_manager == null or not resolved_relic_manager.has_method("get_relic_modifiers_for_skill"):
		return {}
	var skill: RefCounted = query.get("skill_instance") as RefCounted
	if skill == null:
		var resolved_skill_manager: Node = _resolve_skill_manager(owner, skill_manager)
		if resolved_skill_manager != null and resolved_skill_manager.has_method("get_skill"):
			skill = resolved_skill_manager.call("get_skill", query.get("skill_id")) as RefCounted
	if skill == null:
		return {}
	var relic_modifiers_variant: Variant = resolved_relic_manager.call("get_relic_modifiers_for_skill", skill)
	return ModifierSourceScript.flatten_effects(relic_modifiers_variant as Array, ModifierSourceScript.SOURCE_UNKNOWN, query)


## 作用：优先使用传入管理器，否则查找 owner 下的 SkillManager。
## 使用：owner 为效果拥有者；fallback 为缺值备用结果；无法解析或创建时返回 null。
static func _resolve_skill_manager(owner: Node, fallback: Node) -> Node:
	if fallback != null:
		return fallback
	if owner == null:
		return null
	return owner.get_node_or_null("SkillManager")


## 作用：优先使用传入管理器，否则查找 owner 下的 RelicManager。
## 使用：owner 为效果拥有者；fallback 为缺值备用结果；无法解析或创建时返回 null。
static func _resolve_relic_manager(owner: Node, fallback: Node) -> Node:
	if fallback != null:
		return fallback
	if owner == null:
		return null
	return owner.get_node_or_null("RelicManager")


## 作用：读取属性查询拥有者，空查询返回 null。
## 使用：query 为携带作用域与过滤信息的属性查询；无法解析或创建时返回 null。
static func _get_owner(query: RefCounted) -> Node:
	if query == null:
		return null
	return query.get("owner") as Node


## 作用：从技能管理器或遗物管理器的父节点推断玩家。
## 使用：skill_manager 为技能管理器；relic_manager 为遗物管理器；无法解析或创建时返回 null。
static func _infer_owner(skill_manager: Node, relic_manager: Node) -> Node:
	if skill_manager != null:
		return skill_manager.get_parent()
	if relic_manager != null:
		return relic_manager.get_parent()
	return null


## 作用：读取查询作用域，空查询默认玩家域。
## 使用：query 为携带作用域与过滤信息的属性查询。
static func _get_scope(query: RefCounted) -> StringName:
	if query == null:
		return ModifierQueryScript.SCOPE_PLAYER
	return StringName(String(query.get("scope")))


## 作用：按统一 Modifier 合并规则把非空来源快照追加到目标字典。
## 使用：target 为本次命中目标；source 为来源数据或对象。
static func _merge(target: Dictionary, source: Dictionary) -> void:
	if source.is_empty():
		return
	SkillModifierCalculatorScript.merge_modifiers(target, source)
