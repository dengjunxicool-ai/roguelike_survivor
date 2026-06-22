extends RefCounted
class_name EnemyStateController


const STATE_IDLE: String = "idle"
const STATE_CHASE: String = "chase"
const STATE_ATTACK: String = "attack"
const STATE_HURT: String = "hurt"
const STATE_WARNING: String = "warning"
const STATE_CONTROLLED: String = "controlled"
const STATE_DEAD: String = "dead"

var _owner: CharacterBody2D
var _transient_states: Dictionary = {}
var _forced_state: String = ""


func setup(owner: CharacterBody2D) -> void:
	_owner = owner
	_transient_states.clear()
	_forced_state = ""


func update(delta: float) -> void:
	for state: String in _transient_states.keys():
		var remaining: float = maxf(float(_transient_states[state]) - delta, 0.0)
		if remaining <= 0.0:
			_transient_states.erase(state)
		else:
			_transient_states[state] = remaining


func mark(state: String, duration: float) -> void:
	if duration <= 0.0:
		return
	_transient_states[state] = maxf(float(_transient_states.get(state, 0.0)), duration)


func set_forced_state(state: String) -> void:
	if _is_forcible_state(state):
		_forced_state = state


func clear_forced_state() -> void:
	_forced_state = ""


func has_state(state: String) -> bool:
	return _get_state() == state or _transient_states.has(state)


func get_snapshot() -> Dictionary:
	var state: String = _get_state()
	var moving: bool = _owner != null and _owner.velocity.length_squared() > 1.0
	return {
		"state": state,
		"is_dead": state == STATE_DEAD,
		"is_hurt": state == STATE_HURT,
		"is_attacking": state == STATE_ATTACK,
		"is_warning": state == STATE_WARNING,
		"is_controlled": state == STATE_CONTROLLED,
		"is_moving": moving,
		"move_direction": _owner.velocity.normalized() if moving else Vector2.ZERO
	}


func _get_state() -> String:
	if _owner == null:
		return STATE_IDLE
	if bool(_owner.get("_is_dead")):
		return STATE_DEAD
	if _forced_state != "":
		return _forced_state
	if _transient_states.has(STATE_HURT):
		return STATE_HURT
	if _transient_states.has(STATE_ATTACK) or float(_owner.get("_dash_timer")) > 0.0:
		return STATE_ATTACK
	if float(_owner.get("_ranged_warning_timer")) > 0.0 or float(_owner.get("_dash_warning_timer")) > 0.0:
		return STATE_WARNING
	if _owner.has_method("_is_movement_frozen") and bool(_owner.call("_is_movement_frozen")):
		return STATE_CONTROLLED
	if _owner.velocity.length_squared() > 1.0:
		return STATE_CHASE
	return STATE_IDLE


func _is_forcible_state(state: String) -> bool:
	return state == STATE_IDLE or state == STATE_CHASE or state == STATE_ATTACK or state == STATE_HURT or state == STATE_DEAD
