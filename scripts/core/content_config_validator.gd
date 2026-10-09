## 文件用途：校验内容配置的 schema、ID、引用、资源路径及 Modifier 效果列表。
## 使用方式：DataManager 发布数据前调用 load_sources 和 validate_documents；错误通过数组集中返回。

extends RefCounted
class_name ContentConfigValidator

const SCHEMA_PATH := "res://data/config/content_schema.json"
const REFERENCES := {
	"starting_skill_id": "skills", "replaces_skill": "skills",
	"summon_definition_id": "summons", "status_id": "statuses",
	"status": "statuses", "max_stack_status": "statuses",
	"boss_id": "enemies", "enemy_id": "enemies",
	"character_id": "characters", "map_id": "maps",
	"target_status": "statuses", "required_status": "statuses", "boss_status_id": "statuses",
	"school": "gods"
}
const NONNEGATIVE_FIELDS := ["duration", "tick_interval", "cooldown", "max_level",
	"max_stacks", "max_count", "max_hp", "collision_radius"]


## 作用：读取 JSON 根对象并将读盘、解析或根类型错误累积到 errors。
## 使用：path 为资源路径，errors 为调用者的共享错误数组；失败返回空字典。
static func read_document(path: String, errors: Array[String]) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s: cannot read document" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		errors.append("%s: root must be an object" % path)
		return {}
	return json.data


## 作用：读取内容 schema 及其登记的所有数据文件。
## 使用：返回 schema、documents 和 errors 字典，供 owner 统一校验后发布。
static func load_sources() -> Dictionary:
	var errors: Array[String] = []
	var schema := read_document(SCHEMA_PATH, errors)
	var documents := {}
	for entry: Dictionary in schema.get("documents", []):
		var path: String = entry["path"]
		documents[path] = read_document(path, errors)
	return {"schema": schema, "documents": documents, "errors": errors}


## 作用：校验根字段、定义类型、必需字段、唯一 ID、枚举以及递归引用。
## 使用：documents 按路径索引，schema 为规则字典；返回全部错误，不发布或修改运行配置。
static func validate_documents(documents: Dictionary, schema: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var indexes := {}
	if schema.get("version", 0) != 1 or not schema.get("documents") is Array:
		errors.append("%s: invalid content schema" % SCHEMA_PATH)
		return errors
	for entry: Dictionary in schema.documents:
		var path: String = entry.path
		var document: Variant = documents.get(path)
		if not document is Dictionary:
			errors.append("%s: root must be an object" % path)
			continue
		for key: String in document:
			if not entry.keys.has(key):
				errors.append("%s.%s: unknown root field" % [path, key])
		for key: String in entry.keys:
			if not document.has(key):
				errors.append("%s.%s: missing root field" % [path, key])
			elif not entry.root_fields[key].has(_kind(document[key])):
				errors.append("%s.%s: invalid root type" % [path, key])
		for section: Dictionary in entry.sections:
			var items: Variant = document.get(section.key)
			if not items is Array:
				errors.append("%s.%s: must be an array" % [path, section.key])
				continue
			var domain: String = section.domain
			if not indexes.has(domain):
				indexes[domain] = {}
			var rule: Dictionary = schema.domains[domain]
			for i: int in items.size():
				var item: Variant = items[i]
				var where := "%s.%s[%d]" % [path, section.key, i]
				if not item is Dictionary:
					errors.append("%s: definition must be an object" % where)
					continue
				for field: String in rule.required:
					if not item.has(field) or item[field] == null or item[field] is String and item[field].is_empty():
						errors.append("%s.%s: required nonempty field" % [where, field])
				for field: String in item:
					if not rule.fields.has(field):
						errors.append("%s.%s: unknown definition field" % [where, field])
					elif not rule.fields[field].has(_kind(item[field])):
						errors.append("%s.%s: invalid type %s" % [where, field, _kind(item[field])])
				for field: String in rule.get("object_fields", {}):
					if item.get(field) is Dictionary:
						var nested_rule: Dictionary = rule.object_fields[field]
						for required_key: String in rule.get("object_required", {}).get(field, []):
							if not item[field].has(required_key):
								errors.append("%s.%s.%s: required nested field" % [where, field, required_key])
						for nested_key: String in item[field]:
							if not nested_rule.has(nested_key):
								errors.append("%s.%s.%s: unknown nested field" % [where, field, nested_key])
							elif not nested_rule[nested_key].has(_kind(item[field][nested_key])):
								errors.append("%s.%s.%s: invalid nested type" % [where, field, nested_key])
				var id_key: String = section.id_key
				if not id_key.is_empty():
					var id: Variant = item.get(id_key)
					if not id is String or id.strip_edges().is_empty():
						errors.append("%s: invalid ID" % where)
					elif indexes[domain].has(id):
						errors.append("%s: duplicate ID %s" % [where, id])
					else:
						indexes[domain][id] = true
				if domain == "skills":
					if not schema.skill_types.has(item.get("skill_type")):
						errors.append("%s.skill_type: unknown skill type" % where)
					if not ["active", "passive"].has(item.get("slot_category")):
						errors.append("%s.slot_category: unknown slot category" % where)
				if domain == "enemies" and not schema.enemy_ranks.has(item.get("enemy_rank")):
					errors.append("%s.enemy_rank: unknown rank" % where)
	for path: String in documents:
		_visit(documents[path], path, "", indexes, schema, errors)
	return errors


## 作用：递归检查配置中的引用、资源路径、数值和 Modifier 字段。
## 使用：where 用于定位错误，key 为当前字段名；错误追加至 errors。
static func _visit(value: Variant, where: String, key: String, indexes: Dictionary, schema: Dictionary, errors: Array[String]) -> void:
	if REFERENCES.has(key) and (not value is String or value.strip_edges().is_empty()):
		errors.append("%s: reference must be a nonempty string" % where)
	if key == "fusion_school" and value != null and (not value is String or not indexes.get("gods", {}).has(value)):
		errors.append("%s: unknown fusion school" % where)
	if schema.resource_fields.has(key) and (not value is String or not value.is_empty() and not value.begins_with("res://")):
		errors.append("%s: resource path must use res://" % where)
	if key == "scene_path" and value == "":
		errors.append("%s: scene path cannot be empty" % where)
	var array_domains := {"enemy_ids": "enemies", "required_skills": "skills", "required_schools": "gods"}
	if array_domains.has(key):
		if not value is Array:
			errors.append("%s: reference list must be an array" % where)
		else:
			for id: Variant in value:
				if not id is String or id.strip_edges().is_empty() or not indexes.get(array_domains[key], {}).has(id):
					errors.append("%s: unknown %s reference %s" % [where, array_domains[key], id])
	if _kind(value) == "number":
		if not is_finite(float(value)):
			errors.append("%s: nonfinite number" % where)
		if NONNEGATIVE_FIELDS.has(key) and float(value) < 0.0:
			errors.append("%s: negative %s" % [where, key])
		if key == "range_unit_px" and float(value) <= 0.0:
			errors.append("%s: range unit must be positive" % where)
	if value is String:
		if value.begins_with("res://") and not FileAccess.file_exists(value):
			errors.append("%s: missing resource %s" % [where, value])
		if not value.is_empty() and REFERENCES.has(key) and not indexes.get(REFERENCES[key], {}).has(value):
			errors.append("%s: unknown %s reference %s" % [where, REFERENCES[key], value])
		if key == "skill_id" and not value.is_empty() and not indexes.get("skills", {}).has(value) and not indexes.get("enemy_skills", {}).has(value):
			errors.append("%s: unknown skill reference %s" % [where, value])
	if key == "required_skills" and value is Array:
		for id: Variant in value:
			if not indexes.get("skills", {}).has(id):
				errors.append("%s: unknown required skill %s" % [where, id])
	if schema.modifier_fields.has(key):
		_validate_modifiers(value, where, schema, errors)
	if value is Dictionary and value.get("type") == "add_modifier":
		_validate_modifiers([value], where, schema, errors)
	if key == "level_modifiers":
		if not value is Array:
			errors.append("%s: level_modifiers must be an array" % where)
		else:
			for i: int in value.size():
				_validate_modifiers(value[i], "%s[%d]" % [where, i], schema, errors)
	if value is Array:
		for i: int in value.size():
			_visit(value[i], "%s[%d]" % [where, i], "", indexes, schema, errors)
	elif value is Dictionary:
		for field: String in value:
			_visit(value[field], "%s.%s" % [where, field], field, indexes, schema, errors)


## 作用：检查效果列表必需字段、运算类型、作用域与有限数值。
## 使用：value 应为效果数组；错误追加至传入 errors，不聚合或应用属性。
static func _validate_modifiers(value: Variant, where: String, schema: Dictionary, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("%s: Modifier configuration must be an effect list" % where)
		return
	for i: int in value.size():
		var effect: Variant = value[i]
		var loc := "%s[%d]" % [where, i]
		if not effect is Dictionary:
			errors.append("%s: effect must be an object" % loc)
			continue
		for field: String in ["stat", "op", "value", "scope", "source"]:
			if not effect.has(field):
				errors.append("%s.%s: required modifier field" % [loc, field])
		for field: String in ["stat", "source"]:
			if not effect.get(field) is String or effect[field].strip_edges().is_empty():
				errors.append("%s.%s: must be a nonempty string" % [loc, field])
		if not schema.modifier_operations.has(effect.get("op")):
			errors.append("%s.op: unknown modifier operation" % loc)
		if not schema.get("modifier_stats", []).has(effect.get("stat")):
			errors.append("%s.stat: unknown modifier stat" % loc)
		if _kind(effect.get("value")) != "number" or not is_finite(float(effect.get("value", INF))):
			errors.append("%s.value: modifier value must be finite" % loc)
		if not effect.get("scope") is Dictionary:
			errors.append("%s.scope: scope must be an object" % loc)
		else:
			for field: String in effect.scope:
				var filter: Variant = effect.scope[field]
				if not schema.modifier_scope_keys.has(field):
					errors.append("%s.scope.%s: unknown scope key" % [loc, field])
				if not filter is String and not filter is Array:
					errors.append("%s.scope.%s: expected string or string array" % [loc, field])
				if filter is Array:
					for member: Variant in filter:
						if not member is String:
							errors.append("%s.scope.%s: filter members must be strings" % [loc, field])
				if field == "domain" and not schema.modifier_domains.has(filter):
					errors.append("%s.scope.domain: unknown modifier domain" % loc)


## 作用：将 Variant 类型转换为 schema 使用的类型名称。
## 使用：校验器内部调用；返回 null/boolean/number/string/array/object 或 unsupported。
static func _kind(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "boolean"
		TYPE_INT, TYPE_FLOAT: return "number"
		TYPE_STRING: return "string"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "object"
		_: return "unsupported"
