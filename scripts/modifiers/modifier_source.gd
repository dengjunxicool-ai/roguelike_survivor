## 文件用途：验证结构化 Modifier 配置并转换为战斗和属性系统消费的平铺快照。
## 使用方式：配置输入使用效果列表，已聚合 Dictionary 可直接复制；flatten_effects 可按查询过滤 scope。
extends RefCounted
class_name ModifierSource


const SOURCE_UNKNOWN: String = "unknown"
const SOURCE_CHARACTER_TRAIT: String = "character_trait"
const SOURCE_SKILL: String = "skill"
const SOURCE_UPGRADE: String = "upgrade"
const SOURCE_RELIC: String = "relic"


# Dictionary values here are already aggregated runtime snapshots.
## 作用：把效果列表转换为快照，已聚合字典则深拷贝，其他输入返回空字典。
## 使用：query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
static func flatten(value: Variant, default_source: String = SOURCE_UNKNOWN, query: RefCounted = null) -> Dictionary:
	if value is Array:
		return flatten_effects(value, default_source, query)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：逐项检查 Modifier 必需字段、操作类型、有限数值、作用域与来源，返回错误列表。
## 使用：由本文件 flatten_effects 调用。
static func validate_effects(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not (value is Array):
		errors.append("Modifier configuration must be an effect list")
		return errors
	for index: int in range(value.size()):
		var effect: Variant = value[index]
		if not (effect is Dictionary):
			errors.append("Effect %d must be a Dictionary" % index)
			continue
		for key: String in ["stat", "op", "value", "scope", "source"]:
			if not effect.has(key):
				errors.append("Effect %d missing %s" % [index, key])
		if not (effect.get("stat") is String) or String(effect.get("stat", "")) == "":
			errors.append("Effect %d has invalid stat" % index)
		if not ["add", "multiply", "multiplier_add", "override", "raw"].has(effect.get("op")):
			errors.append("Effect %d has unknown operation" % index)
		if not _is_number(effect.get("value")) or not is_finite(float(effect.get("value", 0))):
			errors.append("Effect %d has invalid value" % index)
		if not (effect.get("scope") is Dictionary):
			errors.append("Effect %d has invalid scope" % index)
		if not (effect.get("source") is String) or String(effect.get("source", "")) == "":
			errors.append("Effect %d has invalid source" % index)
	return errors


## 作用：先验证效果列表，再按查询作用域过滤并转换属性键后合并。
## 使用：effects 为配置效果列表；query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
static func flatten_effects(effects: Array, _default_source: String = SOURCE_UNKNOWN, query: RefCounted = null) -> Dictionary:
	var errors: Array[String] = validate_effects(effects)
	if not errors.is_empty():
		push_error("Invalid Modifier effects: " + "; ".join(errors))
		return {}
	var flattened: Dictionary = {}
	for effect: Dictionary in effects:
		if not _effect_matches_query(effect, query):
			continue
		var values: Dictionary = {}
		for key: String in _get_effect_keys(effect):
			values[key] = effect["value"]
		merge_flat_values(flattened, values)
	return flattened


## 作用：原地合并快照：覆盖键替换、倍率键相乘、其余数值相加。
## 使用：target 为本次命中目标；source 为来源数据或对象。
static func merge_flat_values(target: Dictionary, source: Dictionary) -> Dictionary:
	for source_key_variant: Variant in source.keys():
		var key: String = String(source_key_variant)
		if key == "":
			continue
		var value: Variant = source[source_key_variant]

		if key.ends_with("_override"):
			target[key] = value
		elif key.ends_with("_multiplier") and not key.ends_with("_multiplier_add") and target.has(key) and _is_number(target[key]) and _is_number(value):
			target[key] = float(target[key]) * float(value)
		elif target.has(key) and _is_number(target[key]) and _is_number(value):
			target[key] = float(target[key]) + float(value)
		else:
			target[key] = value
	return target


## 作用：把配置操作 add、multiply、multiplier_add 或 override 转为对应属性键后缀。
## 使用：由本文件 _get_effect_keys 调用。
static func _get_operation_key(stat: String, op: String) -> String:
	if stat == "":
		return ""
	if op == "override" and not stat.ends_with("_override"):
		return "%s_override" % stat
	if op == "multiply" and not stat.ends_with("_multiplier"):
		return "%s_multiplier" % stat
	if op == "multiplier_add" and not stat.ends_with("_multiplier_add"):
		return "%s_multiplier_add" % stat
	if op == "add" and not stat.ends_with("_add"):
		return "%s_add" % stat
	return stat


## 作用：按属性、操作和作用域映射效果键，包含伤害、区域、状态与 Boss 特例。
## 使用：由本文件 flatten_effects 调用；无匹配项时返回空数组。
static func _get_effect_keys(effect: Dictionary) -> Array[String]:
	var stat: String = String(effect.get("stat", ""))
	var op: String = String(effect.get("op", "add"))
	var scope: Dictionary = _get_dictionary(effect.get("scope", {}))
	var domain: String = String(scope.get("domain", ""))
	if stat == "":
		return []

	if stat == "damage" and op == "multiplier_add":
		var damage_keys: Array[String] = _get_damage_effect_keys(scope)
		if not damage_keys.is_empty():
			return damage_keys

	if stat == "radius":
		if domain == "player":
			return [_get_operation_key("skill_area", op)]
		var object_type: String = _first_scope_value(scope.get("object_type", ""))
		if object_type == "explosion":
			return [_get_operation_key("explosion_radius", op)]
		if object_type == "area":
			return [_get_operation_key("area_radius", op)]
		if object_type != "":
			return [_get_operation_key("%s_radius" % object_type, op)]
		if domain == "skill":
			return [_get_operation_key("area_radius", op)]

	if stat == "max_targets":
		var object_type_for_targets: String = _first_scope_value(scope.get("object_type", ""))
		if object_type_for_targets != "":
			return [_get_operation_key("%s_max_targets" % object_type_for_targets, op)]
		return [_get_operation_key("max_targets", op)]

	if stat == "heal" and op == "add":
		return ["heal"]

	if stat == "duration":
		var object_id: String = _first_scope_value(scope.get("object_type", ""))
		if object_id != "":
			return [_get_operation_key("%s_duration" % object_id, op)]

	if domain == "status":
		var status_id: String = _first_scope_value(scope.get("status_id", ""))
		if status_id != "":
			match stat:
				"status_damage":
					return [_get_operation_key("%s_damage" % status_id, op)]
				"status_duration":
					return [_get_operation_key("%s_duration" % status_id, op)]
				"status_max_stacks":
					if _first_scope_value(scope.get("target_type", "")) == "boss":
						return [_get_operation_key("boss_%s_max_stacks" % status_id, op)]
					return [_get_operation_key("%s_max_stacks" % status_id, op)]
				"status_move_speed":
					if String(effect.get("application", "")) == "per_stack":
						return [_get_operation_key("%s_move_speed" % status_id, op) + "_per_stack"]
					return [_get_operation_key("%s_move_speed" % status_id, op)]

	return [_get_operation_key(stat, op)]


## 作用：把伤害作用域转换为元素、对象、强敌或伤害来源的加成键列表。
## 使用：由本文件 _get_effect_keys 调用。
static func _get_damage_effect_keys(scope: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var element: String = _first_scope_value(scope.get("element", ""))
	if element != "":
		keys.append("%s_damage_multiplier_add" % element)
	var object_type: String = _first_scope_value(scope.get("object_type", ""))
	if object_type != "":
		keys.append("%s_damage_multiplier_add" % object_type)
	var target_type: String = _first_scope_value(scope.get("target_type", ""))
	if target_type == "boss":
		keys.append("boss_damage_multiplier_add")
	elif target_type == "elite":
		keys.append("elite_damage_multiplier_add")
	var origin: String = _first_scope_value(scope.get("damage_origin", ""))
	match origin:
		"primary_attack":
			keys.append("primary_attack_damage_multiplier_add")
		"status_dot":
			keys.append("dot_damage_multiplier_add")
		"reaction":
			keys.append("reaction_damage_multiplier_add")
		"field":
			keys.append("field_damage_multiplier_add")
		"trap":
			keys.append("trap_damage_multiplier_add")
	if keys.is_empty():
		keys.append("damage_multiplier_add")
	return keys


## 作用：依次检查效果 domain、技能身份、元素、对象、目标、状态和标签是否匹配查询。
## 使用：query 为携带作用域与过滤信息的属性查询；返回布尔判断或执行是否成功。
static func _effect_matches_query(effect: Dictionary, query: RefCounted = null) -> bool:
	if query == null:
		return true
	var scope: Dictionary = _get_dictionary(effect.get("scope", {}))
	if scope.is_empty():
		return true
	if scope.has("domain") and not _domain_matches(String(scope.get("domain", "")), query):
		return false
	if String(scope.get("owner_has_shield", "")) == "true":
		var owner: Node = query.get("owner") as Node
		if owner == null or preload("res://scripts/skills/skill_shield_state.gd").amount(owner) <= 0:
			return false
	for key: String in ["skill_id", "skill_type", "source_origin_id", "damage_origin", "element", "object_type", "target_type", "status_id"]:
		if scope.has(key) and not _scope_value_matches(scope.get(key), String(query.get(key))):
			return false
	if scope.has("tag") and not _tag_scope_matches(scope.get("tag"), query.get("tags")):
		return false
	return true


## 作用：把配置 domain 对应到玩家、技能或伤害查询域。
## 使用：query 为携带作用域与过滤信息的属性查询。
static func _domain_matches(domain: String, query: RefCounted) -> bool:
	var query_scope: String = String(query.get("scope"))
	match domain:
		"player", "economy", "enemy_spawn", "progression":
			return ["player", "movement", "pickup"].has(query_scope)
		"skill", "object", "status":
			return query_scope == "skill"
		"damage":
			return query_scope == "damage"
	return true


## 作用：判断查询字段是否属于效果允许值集合，空集合不限制。
## 使用：由本文件 _effect_matches_query 调用；返回布尔判断或执行是否成功。
static func _scope_value_matches(scope_value: Variant, query_value: String) -> bool:
	var values: Array[String] = _scope_values(scope_value)
	if values.is_empty():
		return true
	if query_value == "":
		return false
	return values.has(query_value)


## 作用：检查效果标签集合与技能查询标签是否至少存在一项交集。
## 使用：由本文件 _effect_matches_query 调用；返回布尔判断或执行是否成功。
static func _tag_scope_matches(scope_value: Variant, query_tags_variant: Variant) -> bool:
	var values: Array[String] = _scope_values(scope_value)
	if values.is_empty():
		return true
	if not (query_tags_variant is Array):
		return false
	for tag_variant: Variant in query_tags_variant:
		if values.has(String(tag_variant)):
			return true
	return false


## 作用：返回作用域值集合首项，供配置字段到运行键映射。
## 使用：由本文件 _get_effect_keys/_get_damage_effect_keys 调用。
static func _first_scope_value(scope_value: Variant) -> String:
	var values: Array[String] = _scope_values(scope_value)
	return values[0] if not values.is_empty() else ""


## 作用：把单值或数组转为非空去重的字符串作用域值。
## 使用：由本文件 _scope_value_matches/_tag_scope_matches 调用。
static func _scope_values(scope_value: Variant) -> Array[String]:
	var values: Array[String] = []
	if scope_value is Array:
		for item: Variant in scope_value:
			var text: String = String(item)
			if text != "" and not values.has(text):
				values.append(text)
	elif scope_value != null:
		var text: String = String(scope_value)
		if text != "":
			values.append(text)
	return values


## 作用：仅接受 Dictionary；深拷贝输出以隔离调用方修改，其余类型返回空字典。
## 使用：由本文件 _get_effect_keys/_effect_matches_query 调用；无适用数据时返回空字典。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 作用：严格判断 Variant 是否为 int 或 float，不把布尔或字符串当数值。
## 使用：由本文件 validate_effects/merge_flat_values 调用。
static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
