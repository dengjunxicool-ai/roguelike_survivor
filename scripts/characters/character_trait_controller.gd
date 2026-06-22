extends RefCounted
class_name CharacterTraitController


const TraitRegistryScript: Script = preload("res://scripts/characters/traits/trait_registry.gd")
const CharacterTraitContextScript: Script = preload("res://scripts/characters/character_trait_context.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageAbsorbResultScript: Script = preload("res://scripts/characters/events/damage_absorb_result.gd")

var runtime: Node
var owner: Node
var trait_config: Dictionary = {}
var trait_type: String = ""
var _context: RefCounted
var _active_trait: RefCounted


func initialize(character_runtime: Node, owning_node: Node) -> void:
	runtime = character_runtime
	owner = owning_node
	trait_config = {}
	trait_type = ""
	_context = CharacterTraitContextScript.new(owner, runtime)
	_active_trait = null

	if runtime == null:
		_sync_runtime_state()
		return

	trait_config = runtime.call("get_trait")
	trait_type = String(trait_config.get("type", ""))
	_active_trait = TraitRegistryScript.create(trait_type)
	if _active_trait != null and _active_trait.has_method("setup"):
		_active_trait.call("setup", trait_config, _context)
	_sync_runtime_state()


func process(delta: float) -> void:
	if _active_trait != null and _active_trait.has_method("process"):
		_active_trait.call("process", delta)
	_sync_runtime_state()


func handle_event(event: RefCounted) -> void:
	if _active_trait != null and _active_trait.has_method("handle_event"):
		_active_trait.call("handle_event", event)
	_sync_runtime_state()


func collect_modifiers(query: RefCounted) -> Dictionary:
	if _active_trait == null or not _active_trait.has_method("get_modifiers"):
		return {}
	var raw_modifiers_variant: Variant = _active_trait.call("get_modifiers", query)
	if not (raw_modifiers_variant is Dictionary):
		return {}
	var raw_modifiers: Dictionary = raw_modifiers_variant
	if query != null and StringName(String(query.get("scope"))) == ModifierQueryScript.SCOPE_SKILL:
		return _adapt_skill_modifiers(raw_modifiers, query)
	return raw_modifiers


func request_damage_absorb(amount: int, event: RefCounted) -> RefCounted:
	if _active_trait == null or not _active_trait.has_method("absorb_damage"):
		return DamageAbsorbResultScript.unchanged(amount)
	var result: RefCounted = _active_trait.call("absorb_damage", amount, event) as RefCounted
	if result == null:
		result = DamageAbsorbResultScript.unchanged(amount)
	_sync_runtime_state()
	return result


func get_debug_state() -> Dictionary:
	var state: Dictionary = {
		"trait_id": trait_config.get("id", ""),
		"trait_type": trait_type,
		"cast_count": 0,
		"stack_count": 0,
		"moving_time": 0.0,
		"stopped_time": 0.0,
		"movement_penalty_remaining": 0.0,
		"shield_points": 0,
		"shield_remaining_seconds": 0.0,
		"shield_timer": 0.0
	}
	if _active_trait != null and _active_trait.has_method("get_debug_state"):
		var trait_state_variant: Variant = _active_trait.call("get_debug_state")
		if trait_state_variant is Dictionary:
			var trait_state: Dictionary = trait_state_variant
			for key: Variant in trait_state.keys():
				state[key] = trait_state[key]
	return state


func _adapt_skill_modifiers(raw_modifiers: Dictionary, query: RefCounted) -> Dictionary:
	if raw_modifiers.is_empty():
		return {}
	var applies_to_equipped: bool = _is_equipped_weapon_skill(query.get("skill_id"))
	var modifiers: Dictionary = {}
	for key_variant: Variant in raw_modifiers.keys():
		var key: String = String(key_variant)
		if key.begins_with("equipped_weapon_"):
			if not applies_to_equipped:
				continue
			if key == "equipped_weapon_damage_add":
				modifiers[key] = raw_modifiers[key_variant]
			else:
				modifiers[key.trim_prefix("equipped_weapon_")] = raw_modifiers[key_variant]
		else:
			modifiers[key] = raw_modifiers[key_variant]
	return modifiers


func _is_equipped_weapon_skill(skill_id: Variant) -> bool:
	if runtime == null:
		return false
	return StringName(String(skill_id)) == StringName(String(runtime.call("get_equipped_weapon_skill_id")))


func _sync_runtime_state() -> void:
	if runtime != null:
		runtime.set("trait_runtime_state", get_debug_state())
