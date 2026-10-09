## 文件用途：按来源 ID、查询作用域和生命周期保存结构化效果或聚合属性快照。
## 使用方式：挂在玩家下；set_source 覆盖、merge_source 累积，collect 根据 ModifierQuery 过滤并聚合。
extends Node
class_name ModifierStore


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")

const LIFETIME_RUN: StringName = &"run"

var _sources: Dictionary = {}


## 作用：按稳定来源 ID 覆盖属性条目、作用域与生命周期，空输入移除来源。
## 使用：source_id 为稳定效果来源 ID。
func set_source(source_id: Variant, modifiers: Variant, scopes: Array = [], lifetime: StringName = LIFETIME_RUN) -> void:
	var id: String = String(source_id)
	if id == "":
		return
	if _is_empty_modifier_value(modifiers):
		_sources.erase(id)
		return
	_sources[id] = {
		"entries": [_make_entry(modifiers)],
		"scopes": _normalize_scopes(scopes),
		"lifetime": lifetime
	}


## 作用：向既有来源追加隔离的属性条目，并更新来源作用域和生命周期。
## 使用：source_id 为稳定效果来源 ID。
func merge_source(source_id: Variant, modifiers: Variant, scopes: Array = [], lifetime: StringName = LIFETIME_RUN) -> void:
	var id: String = String(source_id)
	if id == "":
		return
	var entries: Array = []
	if _sources.has(id):
		entries = _get_dictionary(_sources[id]).get("entries", []).duplicate(true)
	if not _is_empty_modifier_value(modifiers):
		entries.append(_make_entry(modifiers))
	if entries.is_empty():
		_sources.erase(id)
		return
	_sources[id] = {"entries": entries, "scopes": _normalize_scopes(scopes), "lifetime": lifetime}


## 作用：移除指定来源的全部属性条目。
## 使用：source_id 为稳定效果来源 ID。
func clear_source(source_id: Variant) -> void:
	_sources.erase(String(source_id))


## 作用：删除与给定生命周期相符的来源，供局内效果重置使用。
## 使用：挂在玩家下；set_source 覆盖、merge_source 累积，collect 根据 ModifierQuery 过滤并聚合。
func clear_lifetime(lifetime: StringName) -> void:
	var source_ids: Array = _sources.keys()
	for source_id: String in source_ids:
		var source: Dictionary = _get_dictionary(_sources[source_id])
		if StringName(String(source.get("lifetime", LIFETIME_RUN))) == lifetime:
			_sources.erase(source_id)


## 作用：清空所有已登记属性来源。
## 使用：挂在玩家下；set_source 覆盖、merge_source 累积，collect 根据 ModifierQuery 过滤并聚合。
func clear_all() -> void:
	_sources.clear()


## 作用：按查询作用域汇总匹配属性来源，返回平铺属性快照。
## 使用：query 为携带作用域与过滤信息的属性查询。
func collect(query: RefCounted) -> Dictionary:
	var scope: StringName = ModifierQueryScript.SCOPE_PLAYER
	if query != null:
		scope = StringName(String(query.get("scope")))
	var modifiers: Dictionary = {}
	for source_id: String in _sources.keys():
		var source: Dictionary = _get_dictionary(_sources[source_id])
		if not _source_matches_scope(source, scope):
			continue
		for entry: Dictionary in source.get("entries", []):
			var values: Dictionary = entry.get("snapshot", {})
			if entry.has("effects"):
				values = ModifierSourceScript.flatten_effects(entry["effects"], ModifierSourceScript.SOURCE_UNKNOWN, query)
			SkillModifierCalculatorScript.merge_modifiers(modifiers, values)
	return modifiers


## 作用：返回属性来源库的深拷贝，供检查当前注册效果。
## 使用：挂在玩家下；set_source 覆盖、merge_source 累积，collect 根据 ModifierQuery 过滤并聚合。
func get_debug_sources() -> Dictionary:
	return _sources.duplicate(true)


## 作用：判断来源作用域是否包含查询域，未声明来源域默认仅作用于玩家。
## 使用：source 为来源数据或对象。
func _source_matches_scope(source: Dictionary, query_scope: StringName) -> bool:
	var scopes: Array[StringName] = _normalize_scopes(source.get("scopes", []))
	if scopes.is_empty():
		scopes = [ModifierQueryScript.SCOPE_PLAYER]
	return scopes.has(query_scope)


## 作用：把作用域输入转换为去空、去重的 StringName 数组。
## 使用：由本文件 set_source/merge_source 调用。
func _normalize_scopes(value: Variant) -> Array[StringName]:
	var scopes: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			var scope: StringName = StringName(String(item))
			if scope != &"" and not scopes.has(scope):
				scopes.append(scope)
	elif value != null:
		var scope: StringName = StringName(String(value))
		if scope != &"":
			scopes.append(scope)
	return scopes


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 merge_source/clear_lifetime 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：判定属性输入是否为空数组、空字典或不支持的类型。
## 使用：由本文件 set_source/merge_source 调用。
func _is_empty_modifier_value(value: Variant) -> bool:
	if value is Array:
		return (value as Array).is_empty()
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	return true


# Store inputs have two explicit internal forms: config effects and runtime snapshots.
## 作用：深拷贝输入并区分结构化 effects 与已聚合 snapshot 两种存储形式。
## 使用：由本文件 set_source/merge_source 调用。
func _make_entry(value: Variant) -> Dictionary:
	if value is Array:
		return {"effects": (value as Array).duplicate(true)}
	return {"snapshot": (value as Dictionary).duplicate(true)}
