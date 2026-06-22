extends RefCounted
class_name CharacterEventBridge


const CharacterEventScript: Script = preload("res://scripts/characters/events/character_event.gd")

var _controller: RefCounted


func setup(controller: RefCounted) -> void:
	_controller = controller


func emit_movement(is_moving: bool, delta: float) -> void:
	var event_type: StringName = CharacterEventScript.PLAYER_MOVED if is_moving else CharacterEventScript.PLAYER_STOPPED
	_emit(event_type, {"delta": delta})


func emit_skill_event(event_name: StringName, event: Dictionary) -> void:
	if event_name != &"on_cast":
		return
	_emit(CharacterEventScript.SKILL_CAST, event)


func emit_player_damaged(event: Dictionary) -> void:
	_emit(CharacterEventScript.PLAYER_DAMAGED, event)


func emit_enemy_killed(event: Dictionary) -> void:
	_emit(CharacterEventScript.ENEMY_KILLED, event)


func make_event(event_type: StringName, payload: Dictionary = {}) -> RefCounted:
	return CharacterEventScript.new(event_type, payload)


func _emit(event_type: StringName, payload: Dictionary) -> void:
	if _controller == null or not _controller.has_method("handle_event"):
		return
	_controller.call("handle_event", CharacterEventScript.new(event_type, payload))
