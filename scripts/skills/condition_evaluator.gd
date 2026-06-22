extends RefCounted
class_name ConditionEvaluator


static func evaluate(condition: Dictionary, context: Dictionary) -> bool:
	var condition_type: String = String(condition.get("type", ""))
	var params: Dictionary = _get_dictionary(condition.get("params", {}))

	match condition_type:
		"target_has_status":
			var target: Node = context.get("target") as Node
			return target != null and target.has_method("has_status") and bool(target.call("has_status", params.get("status_id", "")))
		"target_has_tag":
			var target_node: Node = context.get("target") as Node
			return target_node != null and target_node.is_in_group(StringName(String(params.get("tag", ""))))
		"owner_has_skill":
			var skill_manager: Node = context.get("skill_manager") as Node
			return skill_manager != null and skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", params.get("skill_id", "")))
		"owner_has_relic":
			var relic_manager: Node = context.get("relic_manager") as Node
			return relic_manager != null and relic_manager.has_method("has_relic") and bool(relic_manager.call("has_relic", params.get("relic_id", "")))
		"skill_has_tag":
			return _skill_has_tag(context.get("skill_instance") as RefCounted, String(params.get("tag", "")))
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


static func evaluate_all(conditions: Array, context: Dictionary) -> bool:
	for condition_variant: Variant in conditions:
		if not (condition_variant is Dictionary):
			continue
		var condition: Dictionary = condition_variant
		if not evaluate(condition, context):
			return false

	return true


static func _skill_has_tag(skill_instance: RefCounted, tag: String) -> bool:
	if skill_instance == null:
		return false
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	return definition != null and definition.has_method("has_tag") and bool(definition.call("has_tag", tag))


static func _target_hp_percent(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


static func _enemy_count_in_radius(context: Dictionary, params: Dictionary) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var origin_node: Node2D = context.get("target") as Node2D
	if origin_node == null:
		origin_node = context.get("caster") as Node2D
	if tree == null or origin_node == null:
		return 0

	var radius: float = float(params.get("radius", 120.0))
	var radius_squared: float = radius * radius
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy != null and origin_node.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			count += 1

	return count


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
