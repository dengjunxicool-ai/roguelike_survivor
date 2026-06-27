extends RefCounted
class_name DataDefinitionIndex


static func index_definitions(document: Dictionary, key: String, id_key: String, target: Dictionary, path: String, report_name: String = "DataManager") -> void:
	for item: Dictionary in get_dictionary_array(document, key, path, report_name):
		var item_id: StringName = StringName(str(item.get(id_key, "")))
		if item_id == &"":
			push_error("[%s] Definition in %s.%s is missing a non-empty %s." % [report_name, path, key, id_key])
			continue
		target[item_id] = item.duplicate(true)


static func index_upgrade_definitions(document: Dictionary, key: String, path: String, upgrade_definitions: Dictionary, level_up_upgrade_definitions: Dictionary, report_name: String = "DataManager") -> void:
	for item: Dictionary in get_dictionary_array(document, key, path, report_name):
		var item_id: StringName = StringName(str(item.get("id", "")))
		if item_id == &"":
			push_error("[%s] Definition in %s.%s is missing a non-empty id." % [report_name, path, key])
			continue

		var item_copy: Dictionary = item.duplicate(true)
		upgrade_definitions[item_id] = item_copy
		if key == "level_up_upgrades":
			level_up_upgrade_definitions[item_id] = item_copy.duplicate(true)


static func get_dictionary_array(document: Dictionary, key: String, path: String, report_name: String = "DataManager") -> Array[Dictionary]:
	if document.is_empty():
		return []

	var value: Variant = document.get(key, [])
	if not (value is Array):
		push_error("[%s] Expected %s.%s to be an array." % [report_name, path, key])
		return []

	var items: Array[Dictionary] = []
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			items.append(item)
		else:
			push_error("[%s] Expected every item in %s.%s to be an object." % [report_name, path, key])
	return items


static func get_definition(source: Dictionary, definition_id: Variant) -> Dictionary:
	var key: StringName = StringName(str(definition_id))
	if not source.has(key):
		return {}
	var definition: Dictionary = source[key]
	return definition.duplicate(true)


static func get_definition_values(source: Dictionary) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for value_variant: Variant in source.values():
		if value_variant is Dictionary:
			var value: Dictionary = value_variant
			values.append(value.duplicate(true))
	return values
