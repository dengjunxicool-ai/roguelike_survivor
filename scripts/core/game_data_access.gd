extends RefCounted
class_name GameDataAccess

const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


static func load_document(cache: Dictionary, path: String, report_name: String = "GameData") -> Dictionary:
	if cache.has(path):
		var cached_document: Dictionary = cache[path]
		return cached_document

	var document: Dictionary = JsonDataLoaderScript.load_dictionary(path, report_name, JsonDataLoaderScript.REPORT_WARNING)
	cache[path] = document
	return document


static func get_array(cache: Dictionary, path: String, key: String) -> Array:
	var document: Dictionary = load_document(cache, path)
	var value: Variant = document.get(key, [])
	return get_array_from_value(value)


static func get_dictionary_array(cache: Dictionary, path: String, key: String) -> Array[Dictionary]:
	var source_items: Array = get_array(cache, path, key)
	var dictionary_items: Array[Dictionary] = []
	for item_variant: Variant in source_items:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			dictionary_items.append(item)
	return dictionary_items


static func find_by_id(items: Array, target_id: StringName) -> Dictionary:
	for item_variant: Variant in items:
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		var item_id: StringName = StringName(str(item.get("id", "")))
		if item_id == target_id:
			return item
	return {}


static func get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("DataManager")


static func get_definition_from_data_manager(method_name: String, definition_id: Variant) -> Dictionary:
	var data_manager: Node = get_data_manager()
	if data_manager == null or not data_manager.has_method(method_name):
		return {}

	var data: Variant = data_manager.call(method_name, definition_id)
	if data is Dictionary:
		var definition: Dictionary = data
		return definition
	return {}


static func get_pool_from_data_manager(method_name: String) -> Array[Dictionary]:
	var data_manager: Node = get_data_manager()
	if data_manager == null or not data_manager.has_method(method_name):
		return []

	var data: Variant = data_manager.call(method_name)
	if not (data is Array):
		return []

	var items: Array[Dictionary] = []
	for item_variant: Variant in data:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			items.append(item)
	return items


static func get_array_from_value(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


static func get_dictionary_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
