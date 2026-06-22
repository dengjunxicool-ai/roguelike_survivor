extends Node
class_name ModifierStore


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")

const LIFETIME_RUN: StringName = &"run"

var _sources: Dictionary = {}


func set_source(source_id: Variant, modifiers: Variant, scopes: Array = [], lifetime: StringName = LIFETIME_RUN) -> void:
	var id: String = String(source_id)
	if id == "":
		return
	if _is_empty_modifier_value(modifiers):
		_sources.erase(id)
		return
	_sources[id] = {
		"modifiers": _duplicate_modifier_value(modifiers),
		"scopes": _normalize_scopes(scopes),
		"lifetime": lifetime
	}


func merge_source(source_id: Variant, modifiers: Variant, scopes: Array = [], lifetime: StringName = LIFETIME_RUN) -> void:
	var id: String = String(source_id)
	if id == "":
		return
	var merged: Array = []
	if _sources.has(id):
		var source: Dictionary = _get_dictionary(_sources[id])
		var existing: Variant = source.get("modifiers", [])
		if existing is Array:
			merged.append_array((existing as Array).duplicate(true))
		elif existing is Dictionary:
			merged.append((existing as Dictionary).duplicate(true))
	if modifiers is Array:
		merged.append_array((modifiers as Array).duplicate(true))
	elif modifiers is Dictionary:
		merged.append((modifiers as Dictionary).duplicate(true))
	set_source(id, merged, scopes, lifetime)


func clear_source(source_id: Variant) -> void:
	_sources.erase(String(source_id))


func clear_lifetime(lifetime: StringName) -> void:
	var source_ids: Array = _sources.keys()
	for source_id: String in source_ids:
		var source: Dictionary = _get_dictionary(_sources[source_id])
		if StringName(String(source.get("lifetime", LIFETIME_RUN))) == lifetime:
			_sources.erase(source_id)


func clear_all() -> void:
	_sources.clear()


func collect(query: RefCounted) -> Dictionary:
	var scope: StringName = ModifierQueryScript.SCOPE_PLAYER
	if query != null:
		scope = StringName(String(query.get("scope")))
	var modifiers: Dictionary = {}
	for source_id: String in _sources.keys():
		var source: Dictionary = _get_dictionary(_sources[source_id])
		if not _source_matches_scope(source, scope):
			continue
		SkillModifierCalculatorScript.merge_modifiers(modifiers, ModifierSourceScript.flatten(source.get("modifiers", {}), ModifierSourceScript.SOURCE_UNKNOWN, query))
	return modifiers


func get_debug_sources() -> Dictionary:
	return _sources.duplicate(true)


func _source_matches_scope(source: Dictionary, query_scope: StringName) -> bool:
	var scopes: Array[StringName] = _normalize_scopes(source.get("scopes", []))
	if scopes.is_empty():
		scopes = [ModifierQueryScript.SCOPE_PLAYER]
	return scopes.has(query_scope)


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


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _is_empty_modifier_value(value: Variant) -> bool:
	if value is Array:
		return (value as Array).is_empty()
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	return true


func _duplicate_modifier_value(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value
