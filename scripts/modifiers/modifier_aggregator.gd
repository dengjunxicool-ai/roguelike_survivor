extends RefCounted
class_name ModifierAggregator


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")


static func collect(query: RefCounted, skill_manager: Node = null, relic_manager: Node = null) -> Dictionary:
	var modifiers: Dictionary = {}
	var owner: Node = _get_owner(query)
	if owner == null:
		owner = _infer_owner(skill_manager, relic_manager)
	var scope: StringName = _get_scope(query)
	_merge(modifiers, _collect_store_modifiers(query, owner))
	if scope == ModifierQueryScript.SCOPE_SKILL:
		_merge(modifiers, _collect_skill_runtime_modifiers(query))
		_merge(modifiers, _collect_skill_passive_modifiers(_resolve_skill_manager(owner, skill_manager), query))
	if scope == ModifierQueryScript.SCOPE_DAMAGE:
		_merge(modifiers, _collect_relic_damage_modifiers(query, owner, skill_manager, relic_manager))
	if scope != ModifierQueryScript.SCOPE_DAMAGE:
		_merge(modifiers, _collect_character_trait_modifiers(query, owner))
	if scope == ModifierQueryScript.SCOPE_SKILL:
		_merge(modifiers, _collect_relic_skill_modifiers(query, _resolve_relic_manager(owner, relic_manager)))
	return modifiers


static func _collect_store_modifiers(query: RefCounted, owner: Node) -> Dictionary:
	if owner == null:
		return {}
	var store: Node = owner.get_node_or_null("ModifierStore")
	if store == null or not store.has_method("collect"):
		return {}
	var store_modifiers_variant: Variant = store.call("collect", query)
	if store_modifiers_variant is Dictionary:
		return ModifierSourceScript.flatten(store_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


static func calculate(base_value: Variant, stat_name: String, query: RefCounted, skill_manager: Node = null, relic_manager: Node = null) -> Variant:
	return SkillModifierCalculatorScript.calculate(base_value, stat_name, collect(query, skill_manager, relic_manager))


static func _collect_skill_runtime_modifiers(query: RefCounted) -> Dictionary:
	if query == null:
		return {}
	var skill: RefCounted = query.get("skill_instance") as RefCounted
	if skill == null:
		return {}
	var runtime_modifiers_variant: Variant = skill.get("runtime_modifiers")
	if runtime_modifiers_variant is Dictionary:
		return ModifierSourceScript.flatten(runtime_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	if runtime_modifiers_variant is Array:
		return ModifierSourceScript.flatten(runtime_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


static func _collect_skill_passive_modifiers(skill_manager: Node, query: RefCounted) -> Dictionary:
	if skill_manager == null:
		return {}
	var passive_variant: Variant = skill_manager.get("passive_modifiers")
	if passive_variant is Dictionary:
		return ModifierSourceScript.flatten(passive_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	if passive_variant is Array:
		return ModifierSourceScript.flatten(passive_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


static func _collect_character_trait_modifiers(query: RefCounted, owner: Node) -> Dictionary:
	if owner == null:
		return {}
	var trait_system: Node = owner.get_node_or_null("CharacterTraitSystem")
	if trait_system == null or not trait_system.has_method("get_modifiers"):
		return {}
	var trait_modifiers_variant: Variant = trait_system.call("get_modifiers", query)
	if trait_modifiers_variant is Dictionary:
		return ModifierSourceScript.flatten(trait_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	if trait_modifiers_variant is Array:
		return ModifierSourceScript.flatten(trait_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


static func _collect_relic_skill_modifiers(query: RefCounted, relic_manager: Node) -> Dictionary:
	if query == null or relic_manager == null or not relic_manager.has_method("get_relic_modifiers_for_skill"):
		return {}
	var skill: RefCounted = query.get("skill_instance") as RefCounted
	if skill == null:
		return {}
	var relic_modifiers_variant: Variant = relic_manager.call("get_relic_modifiers_for_skill", skill)
	if relic_modifiers_variant is Dictionary:
		return ModifierSourceScript.flatten(relic_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	if relic_modifiers_variant is Array:
		return ModifierSourceScript.flatten(relic_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)
	return {}


static func _collect_relic_damage_modifiers(query: RefCounted, owner: Node, skill_manager: Node, relic_manager: Node) -> Dictionary:
	if query == null:
		return {}
	var resolved_relic_manager: Node = _resolve_relic_manager(owner, relic_manager)
	if resolved_relic_manager == null or not resolved_relic_manager.has_method("get_relic_modifiers_for_skill"):
		return {}
	var skill: RefCounted = query.get("skill_instance") as RefCounted
	if skill == null:
		var resolved_skill_manager: Node = _resolve_skill_manager(owner, skill_manager)
		if resolved_skill_manager != null and resolved_skill_manager.has_method("get_skill"):
			skill = resolved_skill_manager.call("get_skill", query.get("skill_id")) as RefCounted
	if skill == null:
		return {}
	var relic_modifiers_variant: Variant = resolved_relic_manager.call("get_relic_modifiers_for_skill", skill)
	return ModifierSourceScript.flatten(relic_modifiers_variant, ModifierSourceScript.SOURCE_UNKNOWN, query)


static func _resolve_skill_manager(owner: Node, fallback: Node) -> Node:
	if fallback != null:
		return fallback
	if owner == null:
		return null
	return owner.get_node_or_null("SkillManager")


static func _resolve_relic_manager(owner: Node, fallback: Node) -> Node:
	if fallback != null:
		return fallback
	if owner == null:
		return null
	return owner.get_node_or_null("RelicManager")


static func _get_owner(query: RefCounted) -> Node:
	if query == null:
		return null
	return query.get("owner") as Node


static func _infer_owner(skill_manager: Node, relic_manager: Node) -> Node:
	if skill_manager != null:
		return skill_manager.get_parent()
	if relic_manager != null:
		return relic_manager.get_parent()
	return null


static func _get_scope(query: RefCounted) -> StringName:
	if query == null:
		return ModifierQueryScript.SCOPE_PLAYER
	return StringName(String(query.get("scope")))


static func _merge(target: Dictionary, source: Dictionary) -> void:
	if source.is_empty():
		return
	SkillModifierCalculatorScript.merge_modifiers(target, source)
