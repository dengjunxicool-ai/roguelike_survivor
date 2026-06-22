extends Node
class_name CharacterTraitSystem


const CharacterTraitControllerScript: Script = preload("res://scripts/characters/character_trait_controller.gd")
const CharacterEventBridgeScript: Script = preload("res://scripts/characters/character_event_bridge.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageAbsorbResultScript: Script = preload("res://scripts/characters/events/damage_absorb_result.gd")

var character_runtime: Node
var _controller: RefCounted = CharacterTraitControllerScript.new()
var _event_bridge: RefCounted = CharacterEventBridgeScript.new()


func _ready() -> void:
	_event_bridge.call("setup", _controller)


func _process(delta: float) -> void:
	if _controller != null and _controller.has_method("process"):
		_controller.call("process", delta)


func initialize(runtime: Node) -> void:
	character_runtime = runtime
	if _event_bridge == null:
		_event_bridge = CharacterEventBridgeScript.new()
	if _controller == null:
		_controller = CharacterTraitControllerScript.new()
	_event_bridge.call("setup", _controller)
	_controller.call("initialize", character_runtime, get_parent())


func handle_movement(is_moving: bool, delta: float) -> void:
	_event_bridge.call("emit_movement", is_moving, delta)


func handle_skill_event(event_name: StringName, event: Dictionary) -> void:
	_event_bridge.call("emit_skill_event", event_name, event)


func handle_skill_bus_event(event: Dictionary, event_name: StringName) -> void:
	handle_skill_event(event_name, event)


func handle_enemy_killed(event: Dictionary) -> void:
	_event_bridge.call("emit_enemy_killed", event)


func handle_player_damaged(event: Dictionary) -> void:
	_event_bridge.call("emit_player_damaged", event)


func request_damage_absorb(amount: int, event: Dictionary = {}) -> RefCounted:
	if _controller == null or not _controller.has_method("request_damage_absorb"):
		return DamageAbsorbResultScript.unchanged(amount)
	var character_event: RefCounted = _event_bridge.call("make_event", &"damage_absorb_requested", event) as RefCounted
	return _controller.call("request_damage_absorb", amount, character_event) as RefCounted


func get_modifiers(query: RefCounted) -> Dictionary:
	if _controller == null or not _controller.has_method("collect_modifiers"):
		return {}
	var modifiers: Variant = _controller.call("collect_modifiers", query)
	if modifiers is Dictionary:
		return modifiers
	return {}


func get_player_modifiers(scope: StringName = &"player") -> Dictionary:
	return get_modifiers(ModifierQueryScript.for_player(get_parent(), scope))


func get_debug_state() -> Dictionary:
	if _controller != null and _controller.has_method("get_debug_state"):
		var state: Variant = _controller.call("get_debug_state")
		if state is Dictionary:
			return state
	return {}
