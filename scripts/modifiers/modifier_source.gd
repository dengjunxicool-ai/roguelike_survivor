extends RefCounted
class_name ModifierSource


const SOURCE_UNKNOWN: String = "unknown"
const SOURCE_CHARACTER_TRAIT: String = "character_trait"
const SOURCE_SKILL: String = "skill"
const SOURCE_UPGRADE: String = "upgrade"
const SOURCE_RELIC: String = "relic"


static func flatten(value: Variant, default_source: String = SOURCE_UNKNOWN, query: RefCounted = null) -> Dictionary:
	var flattened: Dictionary = {}
	for source_block: Dictionary in to_source_blocks(value, default_source, query):
		merge_flat_values(flattened, _get_dictionary(source_block.get("values", {})))
	return flattened


static func to_source_blocks(value: Variant, default_source: String = SOURCE_UNKNOWN, query: RefCounted = null) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			blocks.append_array(to_source_blocks(item, default_source, query))
		return blocks

	if not (value is Dictionary):
		return blocks

	var data: Dictionary = value
	if _is_source_block(data):
		var parsed: Dictionary = _parse_source_block(data, default_source, query)
		if not _get_dictionary(parsed.get("values", {})).is_empty():
			blocks.append(parsed)
	else:
		blocks.append({
			"source": _resolve_source("", default_source),
			"values": data.duplicate(true)
		})
	return blocks


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


static func _is_source_block(data: Dictionary) -> bool:
	if data.has("source") and (data.has("values") or data.has("modifiers") or data.has("stat")):
		return true
	if data.has("stat") and data.has("value"):
		return true
	return false


static func _parse_source_block(data: Dictionary, default_source: String, query: RefCounted = null) -> Dictionary:
	var source: String = _resolve_source(String(data.get("source", "")), default_source)
	var values: Dictionary = {}

	if data.has("values"):
		values = flatten(data.get("values", {}), source, query)
	elif data.has("modifiers"):
		values = flatten(data.get("modifiers", {}), source, query)
	elif data.has("stat") and data.has("value"):
		if _effect_matches_query(data, query):
			for key: String in _get_effect_keys(data):
				values[key] = data.get("value")
	else:
		for key_variant: Variant in data.keys():
			var key: String = String(key_variant)
			if ["source", "id", "display_name", "description"].has(key):
				continue
			values[key] = data[key_variant]

	return {
		"source": source,
		"values": values
	}


static func _get_operation_key(stat: String, op: String) -> String:
	if stat == "":
		return ""
	if op == "override" and not stat.ends_with("_override"):
		return "%s_override" % stat
	if (op == "multiply" or op == "multiplier") and not stat.ends_with("_multiplier"):
		return "%s_multiplier" % stat
	if op == "multiplier_add" and not stat.ends_with("_multiplier_add"):
		return "%s_multiplier_add" % stat
	if op == "add" and not stat.ends_with("_add"):
		return "%s_add" % stat
	return stat


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


static func _effect_matches_query(effect: Dictionary, query: RefCounted = null) -> bool:
	if query == null:
		return true
	var scope: Dictionary = _get_dictionary(effect.get("scope", {}))
	if scope.is_empty():
		return true
	if scope.has("domain") and not _domain_matches(String(scope.get("domain", "")), query):
		return false
	for key: String in ["skill_id", "source_origin_id", "damage_origin", "element", "object_type", "target_type", "status_id"]:
		if scope.has(key) and not _scope_value_matches(scope.get(key), String(query.get(key))):
			return false
	if scope.has("tag") and not _tag_scope_matches(scope.get("tag"), query.get("tags")):
		return false
	return true


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


static func _scope_value_matches(scope_value: Variant, query_value: String) -> bool:
	var values: Array[String] = _scope_values(scope_value)
	if values.is_empty():
		return true
	if query_value == "":
		return false
	return values.has(query_value)


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


static func _first_scope_value(scope_value: Variant) -> String:
	var values: Array[String] = _scope_values(scope_value)
	return values[0] if not values.is_empty() else ""


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


static func _resolve_source(source: String, default_source: String) -> String:
	if source != "":
		return source
	if default_source != "":
		return default_source
	return SOURCE_UNKNOWN


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
