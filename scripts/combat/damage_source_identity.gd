## 文件用途：为投射物、区域、环绕、状态DOT和反应生成可复用的来源身份字符串。
## 使用方式：构建伤害包时使用，持续伤害必须保持同一来源稳定以共用小数池与限制计数。
extends RefCounted
class_name DamageSourceIdentity


## 作用：组合施放实例、可选来源和投射物序号为身份。
## 使用：同次施放的不同投射物序号应各不相同。
static func for_projectile(cast_instance_id: String, projectile_index: int, source_id: Variant = "") -> String:
	var source_text: String = String(source_id)
	if source_text == "":
		return "%s:projectile:%d" % [cast_instance_id, projectile_index]
	return "%s:projectile:%s:%d" % [cast_instance_id, source_text, projectile_index]


## 作用：组合施放实例、区域来源类型与可选配置ID。
## 使用：source_type 区分场地/区域等持续对象。
static func for_area(cast_instance_id: String, source_type: String, source_id: Variant = "") -> String:
	var source_text: String = String(source_id)
	if source_text == "":
		return "%s:%s" % [cast_instance_id, source_type]
	return "%s:%s:%s" % [cast_instance_id, source_type, source_text]


## 作用：组合拥有者实例、技能和可选环绕物配置ID。
## 使用：owner 为空使用 no_owner；同一环绕来源可跨tick复用。
static func for_orbit(owner: Node, skill_id: Variant, source_id: Variant = "") -> String:
	var owner_key: String = str(owner.get_instance_id()) if owner != null else "no_owner"
	var skill_text: String = String(skill_id)
	var source_text: String = String(source_id)
	if source_text == "":
		return "%s:orbit:%s" % [owner_key, skill_text]
	return "%s:orbit:%s:%s" % [owner_key, skill_text, source_text]


## 作用：组合受击目标、状态与可选施加者来源身份。
## 使用：同一状态相同施加者持续tick复用，避免小数余数丢失。
static func for_status_dot(target: Node, status_id: Variant, applier_source: Variant = "") -> String:
	var status_text: String = String(status_id)
	var target_key: String = str(target.get_instance_id()) if target != null else "no_target"
	var applier_text: String = String(applier_source)
	if applier_text == "":
		return "%s:%s" % [target_key, status_text]
	return "%s:%s:%s" % [target_key, status_text, applier_text]


## 作用：从原来源派生反应类型和深度身份。
## 使用：原来源为空时以 reaction 前缀生成；反应包不再触发递归反应。
static func for_reaction(base_source_instance_id: Variant, reaction_type: String, depth: int) -> String:
	var base_text: String = String(base_source_instance_id)
	if base_text == "":
		return "reaction:%s:%d" % [reaction_type, depth]
	return "%s:reaction:%s:%d" % [base_text, reaction_type, depth]
