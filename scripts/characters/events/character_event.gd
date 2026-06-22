extends RefCounted
class_name CharacterEvent


const PLAYER_MOVED: StringName = &"player_moved"
const PLAYER_STOPPED: StringName = &"player_stopped"
const SKILL_CAST: StringName = &"skill_cast"
const PLAYER_DAMAGED: StringName = &"player_damaged"
const ENEMY_KILLED: StringName = &"enemy_killed"

var type: StringName = &""
var payload: Dictionary = {}


func _init(event_type: StringName = &"", event_payload: Dictionary = {}) -> void:
	type = event_type
	payload = event_payload.duplicate(true)


static func create(event_type: StringName, event_payload: Dictionary = {}) -> CharacterEvent:
	return CharacterEvent.new(event_type, event_payload)
