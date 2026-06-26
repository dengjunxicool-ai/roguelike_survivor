extends RefCounted
class_name ConditionEvaluator


static func evaluate(condition: Dictionary, context: Dictionary) -> bool:
	var condition_type: String = str(condition.get("type", ""))
	var params: Dictionary = _get_dictionary(condition.get("params", {}))
	if params.is_empty():
		params = condition.duplicate(true)
		params.erase("type")

	match condition_type:
		"target_has_status":
			var target: Node = context.get("target") as Node
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
			return _skill_has_tag(context.get("skill_instance") as RefCounted, str(params.get("tag", "")))
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
	var source_id: String = str(context.get("source_id", context.get("source_key", "")))
	match tag:
		"fire_area":
			return source_id.contains("fire") or source_id.contains("burn") or source_id.contains("lava") or source_id.contains("ember") or source_id.contains("flame")
		"frost_area":
			return source_id.contains("frost") or source_id.contains("ice") or source_id.contains("blizzard") or source_id.contains("snow")
		"thunder_area":
			return source_id.contains("thunder") or source_id.contains("lightning") or source_id.contains("storm") or source_id.contains("conductive")
		"curse_area":
			return source_id.contains("curse") or source_id.contains("cursed") or source_id.contains("soul") or source_id.contains("black")
		"holy_area":
			return source_id.contains("holy") or source_id.contains("judgment") or source_id.contains("divine") or source_id.contains("barrier")
		"chaos_area":
			return source_id.contains("chaos") or source_id.contains("rift") or source_id.contains("void") or source_id.contains("instability")
		_:
			return source_id == tag or source_id.contains(tag)


static func _target_hp_percent(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


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


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
