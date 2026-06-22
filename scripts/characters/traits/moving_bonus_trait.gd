extends CharacterTrait
class_name MovingBonusTrait


const CharacterEventScript: Script = preload("res://scripts/characters/events/character_event.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")

var _moving_time: float = 0.0
var _stopped_time: float = 0.0
var _movement_penalty_remaining: float = 0.0


func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	super.setup(trait_config, trait_context)
	_moving_time = 0.0
	_stopped_time = 0.0
	_movement_penalty_remaining = 0.0


func process(delta: float) -> void:
	_movement_penalty_remaining = maxf(_movement_penalty_remaining - delta, 0.0)


func handle_event(event: RefCounted) -> void:
	var payload: Dictionary = _get_dictionary(event.get("payload"))
	match StringName(event.get("type")):
		CharacterEventScript.PLAYER_MOVED:
			_on_player_moved(float(payload.get("delta", 0.0)))
		CharacterEventScript.PLAYER_STOPPED:
			_on_player_stopped(float(payload.get("delta", 0.0)))
		CharacterEventScript.PLAYER_DAMAGED:
			_break_moving_bonus()


func get_modifiers(_query: RefCounted) -> Dictionary:
	var params: Dictionary = _get_params()
	var required_time: float = maxf(float(params.get("moving_seconds_required", 2.5)), 0.0)
	if _moving_time >= required_time:
		return _get_modifier_values(params.get("active_modifiers", {}))
	if _movement_penalty_remaining > 0.0:
		return _get_modifier_values(params.get("penalty_modifiers", {}))
	return {}


func get_debug_state() -> Dictionary:
	return {
		"moving_time": _moving_time,
		"stopped_time": _stopped_time,
		"movement_penalty_remaining": _movement_penalty_remaining
	}


func _on_player_moved(delta: float) -> void:
	var params: Dictionary = _get_params()
	var required_time: float = maxf(float(params.get("moving_seconds_required", 2.5)), 0.0)
	_stopped_time = 0.0
	_moving_time = minf(_moving_time + delta, required_time)
	if _moving_time >= required_time:
		var tree: SceneTree = null
		if context != null:
			tree = context.get("tree") as SceneTree
		var tracker: Node = RunStatsTrackerScript.get_active(tree)
		if tracker != null and tracker.has_method("record_hunter_rhythm"):
			tracker.call("record_hunter_rhythm", delta)


func _on_player_stopped(delta: float) -> void:
	var params: Dictionary = _get_params()
	var break_seconds: float = maxf(float(params.get("stop_break_seconds", 0.0)), 0.0)
	if break_seconds > 0.0:
		_stopped_time += delta
		if _stopped_time < break_seconds:
			return
	_break_moving_bonus()


func _break_moving_bonus() -> void:
	var params: Dictionary = _get_params()
	var required_time: float = maxf(float(params.get("moving_seconds_required", 2.5)), 0.0)
	if _moving_time >= required_time:
		_movement_penalty_remaining = maxf(float(params.get("penalty_duration", 3.0)), 0.0)
	_moving_time = 0.0
	_stopped_time = 0.0
