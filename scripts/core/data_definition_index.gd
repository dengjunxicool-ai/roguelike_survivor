## 文件用途：将已校验配置整理为 ID 索引和定义列表。
## 使用方式：由 DataManager 调用静态索引函数；查询结果以深拷贝隔离调用者。

extends RefCounted
class_name DataDefinitionIndex


## 作用：把指定数组的有效定义按 StringName ID 深拷贝写入 target。
## 使用：document/key/id_key 指定来源与索引字段；空 ID 报错并跳过，target 就地更新。
static func index_definitions(document: Dictionary, key: String, id_key: String, target: Dictionary, path: String, report_name: String = "DataManager") -> void:
	for item: Dictionary in get_dictionary_array(document, key, path, report_name):
		var item_id: StringName = StringName(str(item.get(id_key, "")))
		if item_id == &"":
			push_error("[%s] Definition in %s.%s is missing a non-empty %s." % [report_name, path, key, id_key])
			continue
		target[item_id] = item.duplicate(true)


## 作用：建立通用升级索引，并额外建立局内升级索引。
## 使用：key 为 level_up_upgrades 时更新两份独立字典；path/report_name 用于定位报错。
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


## 作用：读取指定字段并复制数组中的字典条目。
## 使用：字段不是数组或成员不是字典时报告错误；返回有效成员的深拷贝列表。
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
			items.append(item.duplicate(true))
		else:
			push_error("[%s] Expected every item in %s.%s to be an object." % [report_name, path, key])
	return items


## 作用：用统一 StringName 键读取单个定义并返回深拷贝。
## 使用：source 为 ID 索引；definition_id 未找到返回 {}。
static func get_definition(source: Dictionary, definition_id: Variant) -> Dictionary:
	var key: StringName = StringName(str(definition_id))
	if not source.has(key):
		return {}
	var definition: Dictionary = source[key]
	return definition.duplicate(true)


## 作用：将 ID 索引的字典值输出为独立定义列表。
## 使用：复制每个有效定义；调用者修改结果不会污染数据 owner；返回 Array[Dictionary] 列表。
static func get_definition_values(source: Dictionary) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for value_variant: Variant in source.values():
		if value_variant is Dictionary:
			var value: Dictionary = value_variant
			values.append(value.duplicate(true))
	return values
