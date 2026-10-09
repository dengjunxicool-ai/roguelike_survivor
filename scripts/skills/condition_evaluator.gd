## 文件用途：解释技能动作条件中的标签、血量、状态、元素、元数据及周围敌人数判断。
## 使用方式：动作执行前用 evaluate_all 按全部条件判断，context 提供技能、来源、目标及场景树。
extends RefCounted
class_name ConditionEvaluator


const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

## 作用：按条件 type 解释目标状态、来源标签、元素、血量或概率判断，未知类型警告并返回 false。
## 使用：context 携带 target/status_id/status/shield_overflowed；返回布尔判断或执行是否成功。
static func evaluate(condition: Dictionary, context: Dictionary) -> bool:
	var condition_type: String = str(condition.get("type", ""))
	var params: Dictionary = _get_dictionary(condition.get("params", {}))
	if params.is_empty():
		params = condition.duplicate(true)
		params.erase("type")

	match condition_type:
		"origin_skill_type":
			var origin: RefCounted = context.get("origin_skill_instance") as RefCounted
			return origin != null and String(origin.get("skill_type")) == String(params.get("skill_type", ""))
		"fire_ground":
			var area: Node = context.get("area") as Node
			return area != null and String(area.get("source_id")) in ["meteor_burning_ground", "lava_rift", "fire_ground", "inferno_fire_ground"]
		"target_has_status":
			var target: Node = context.get("target") as Node
			if context.has("target_statuses"):
				for status: Dictionary in context.target_statuses:
					if String(status.get("id", "")) == String(params.get("status_id", params.get("status", ""))): return true
				return false
			return target != null and target.has_method("has_status") and bool(target.call("has_status", params.get("status_id", params.get("status", ""))))
		"target_missing_status":
			return not _target_has_any_status(context.get("target") as Node, [params.get("status_id", params.get("status", ""))])
		"event_status_is":
			return StringName(str(context.get("status_id", context.get("status", "")))) == StringName(str(params.get("status_id", params.get("status", ""))))
		"damage_element_is":
			return _damage_element_is(context, StringName(str(params.get("element", ""))))
		"target_has_meta":
			return _target_has_meta(context.get("target") as Node, str(params.get("key", params.get("meta", ""))))
		"shield_overflowed":
			return bool(context.get("shield_overflowed", false))
		"target_has_any_status":
			return _target_has_any_status(context.get("target") as Node, _get_array(params.get("statuses", [])))
		"target_has_tag":
			var target_node: Node = context.get("target") as Node
			return target_node != null and target_node.is_in_group(StringName(str(params.get("tag", ""))))
		"owner_has_skill":
			var skill_manager: Node = context.get("skill_manager") as Node
			return skill_manager != null and skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", params.get("skill_id", "")))
		"owner_has_relic":
			var relic_manager: Node = context.get("relic_manager") as Node
			return relic_manager != null and relic_manager.has_method("has_relic") and bool(relic_manager.call("has_relic", params.get("relic_id", "")))
		"skill_has_tag":
			return _skill_has_tag(context.get("origin_skill_instance", context.get("skill_instance")) as RefCounted, str(params.get("tag", "")))
		"source_has_tag":
			return _source_has_tag(context, str(params.get("tag", "")))
		"random_chance":
			return randf() <= clampf(float(params.get("chance", 1.0)), 0.0, 1.0)
		"target_hp_below":
			return _target_hp_percent(context.get("target") as Node) <= float(params.get("percent", 1.0))
		"is_critical_hit":
			return bool(context.get("is_critical_hit", false))
		"enemy_count_in_radius":
			return _enemy_count_in_radius(context, params) >= int(params.get("count", 1))
		"", "always":
			return true
		_:
			push_warning("[ConditionEvaluator] Unsupported condition type: %s" % condition_type)
			return false


## 作用：按顺序判断字典条件，任一失败立即返回 false，非字典项跳过。
## 使用：context 为施放或命中上下文；返回布尔判断或执行是否成功。
static func evaluate_all(conditions: Array, context: Dictionary) -> bool:
	for condition_variant: Variant in conditions:
		if not (condition_variant is Dictionary):
			continue
		var condition: Dictionary = condition_variant
		if not evaluate(condition, context):
			return false

	return true


## 作用：检查技能定义是否含指定标签。
## 使用：skill_instance 为技能运行实例；返回布尔判断或执行是否成功。
static func _skill_has_tag(skill_instance: RefCounted, tag: String) -> bool:
	if skill_instance == null:
		return false
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	return definition != null and definition.has_method("has_tag") and bool(definition.call("has_tag", tag))


## 作用：依次检查事件显式标签、来源节点分组与元数据，来源名称不用于推断标签。
## 使用：context 携带 source/area/source_id/source_key；返回布尔判断或执行是否成功。
static func _source_has_tag(context: Dictionary, tag: String) -> bool:
	if tag == "":
		return false
	for key: String in ["source_tags", "area_tags", "tags"]:
		for tag_variant: Variant in _get_array(context.get(key, [])):
			if str(tag_variant) == tag:
				return true
	var source: Node = context.get("source", context.get("area")) as Node
	if source != null:
		if source.is_in_group(StringName(tag)):
			return true
		if source.has_meta("tags") and _get_array(source.get_meta("tags")).has(tag):
			return true
		if source.has_meta(tag) and bool(source.get_meta(tag)):
			return true
	return false


## 作用：读取目标当前血量比例，缺目标时按满血处理。
## 使用：target 为本次命中目标。
static func _target_hp_percent(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


## 作用：检查目标公开状态入口或 StatusEffectManager 是否含任一指定状态。
## 使用：target 为本次命中目标；返回布尔判断或执行是否成功。
static func _target_has_any_status(target: Node, statuses: Array) -> bool:
	if target == null:
		return false
	for status_variant: Variant in statuses:
		var status_id: StringName = StringName(str(status_variant))
		if status_id == &"":
			continue
		if target.has_method("has_status") and bool(target.call("has_status", status_id)):
			return true
		var status_manager: Node = target.get_node_or_null("StatusEffectManager")
		if status_manager != null and status_manager.has_method("has_status") and bool(status_manager.call("has_status", status_id)):
			return true
	return false


## 作用：判断目标元数据条件：布尔用原值、数字必须大于零、其他必须非 null。
## 使用：target 为本次命中目标；返回布尔判断或执行是否成功。
static func _target_has_meta(target: Node, key: String) -> bool:
	if target == null or key == "":
		return false
	if not target.has_meta(key):
		return false
	var value: Variant = target.get_meta(key)
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return float(value) > 0.0
	return value != null


## 作用：以事件目标或施法者为圆心从目标注册表查询并统计半径内敌人。
## 使用：context 携带 target/caster；params 读取 radius。
static func _enemy_count_in_radius(context: Dictionary, params: Dictionary) -> int:
	var origin_node: Node2D = context.get("target") as Node2D
	if origin_node == null:
		origin_node = context.get("caster") as Node2D
	if origin_node == null:
		return 0

	var radius: float = float(params.get("radius", 120.0))
	var radius_squared: float = radius * radius
	var count: int = 0
	var registry: Node = CombatTargetRegistryScript.get_or_create(null)
	var targets: Array = registry.call("get_targets_in_radius", origin_node.global_position, radius, &"enemies") if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var enemy: Node2D = node as Node2D
		if enemy != null and origin_node.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			count += 1

	return count


## 作用：优先比较伤害包元素，再处理冰、闪电与奥术元素别名。
## 使用：context 携带 damage_packet/element/damage_type；返回布尔判断或执行是否成功。
static func _damage_element_is(context: Dictionary, expected: StringName) -> bool:
	if expected == &"":
		return false
	var packet: Dictionary = _get_dictionary(context.get("damage_packet", {}))
	var element: StringName = StringName(str(packet.get("element", context.get("element", ""))))
	if element == expected:
		return true
	var damage_type: StringName = StringName(str(packet.get("damage_type", context.get("damage_type", ""))))
	if expected == &"lightning" and (damage_type == &"thunder" or damage_type == &"lightning" or element == &"thunder"):
		return true
	if expected == &"ice" and (damage_type == &"frost" or damage_type == &"ice" or element == &"frost"):
		return true
	if expected == &"curse" and (damage_type == &"curse" or element == &"arcane"):
		return true
	if expected == &"arcane" and (damage_type == &"curse" or damage_type == &"arcane" or element == &"curse"):
		return true
	return false


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 evaluate/_damage_element_is 调用；无适用数据时返回空字典。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 evaluate/_source_has_tag 调用；无匹配项时返回空数组。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
