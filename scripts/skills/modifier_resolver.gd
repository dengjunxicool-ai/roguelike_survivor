## 文件用途：将动作上下文中的技能、玩家和管理器接入统一技能属性计算。
## 使用方式：动作执行器用 get_stat 读定义基础属性，resolve_value 修饰传入值，resolve_params 返回按 stat_map 重算的参数副本。
extends RefCounted
class_name ModifierResolver


const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")


## 作用：从动作 context 提取技能及管理器，用统一服务计算技能定义属性。
## 使用：context 携带 skill_instance/skill_manager/relic_manager/caster；stat_name 为待查询属性键；default_value 为缺值备用结果。
static func get_stat(context: Dictionary, stat_name: String, default_value: Variant = 0) -> Variant:
	return SkillStatServiceScript.get_effective_stat(
		context.get("skill_instance") as RefCounted,
		stat_name,
		default_value,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	)


## 作用：把指定基础值交给统一技能属性服务计算。
## 使用：context 携带 skill_instance/skill_manager/relic_manager/caster；stat_name 为待查询属性键；base_value 为修饰前数值。
static func resolve_value(context: Dictionary, stat_name: String, base_value: Variant) -> Variant:
	return SkillStatServiceScript.calculate_value(
		context.get("skill_instance") as RefCounted,
		stat_name,
		base_value,
		context.get("skill_manager") as Node,
		context.get("relic_manager") as Node,
		context.get("caster") as Node
	)


## 作用：深拷贝动作参数，并按可选 stat_map 对各字段应用技能属性修正。
## 使用：context 为施放或命中上下文；params 为动作或状态参数。
static func resolve_params(context: Dictionary, params: Dictionary, stat_map: Dictionary = {}) -> Dictionary:
	var resolved: Dictionary = params.duplicate(true)
	for key_variant: Variant in params.keys():
		var key: String = String(key_variant)
		var stat_name: String = String(stat_map.get(key, key))
		resolved[key] = resolve_value(context, stat_name, params[key_variant])

	return resolved
