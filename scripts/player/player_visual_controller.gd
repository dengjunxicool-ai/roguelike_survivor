extends RefCounted
class_name PlayerVisualController


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")

var _owner: Node2D
var _visual_config: Dictionary = {}
var _visual_state: String = ""
var _hurt_timer: float = 0.0


func setup(owner: Node2D) -> void:
	_owner = owner


func apply_character_config(character: Dictionary) -> void:
	var visual_variant: Variant = character.get("visual", {})
	if not (visual_variant is Dictionary):
		return

	var visual: Dictionary = visual_variant
	_visual_config = visual.duplicate(true)
	play_state("idle", true)


func show_hurt(duration: float = 0.16) -> void:
	_hurt_timer = duration
	play_state("hurt")


func update(input_direction: Vector2, current_health: int, delta: float) -> void:
	if _visual_config.is_empty():
		return

	if _hurt_timer > 0.0:
		_hurt_timer = maxf(_hurt_timer - delta, 0.0)
		if _hurt_timer > 0.0:
			return


	## direction.x > 0   # 向右
	## direction.x < 0   # 向左
	## direction.y > 0   # 向下
	## direction.y < 0   # 向上
	## direction == Vector2.ZERO # 没动

	if current_health <= 0:
		play_state("death")
	elif input_direction.length_squared() > 0.001:
		play_state(get_move_animation_name(input_direction))
	else:
		play_state("idle")


func get_move_animation_name(direction: Vector2) -> String:
	var preferred_state: String = "walk"
	if absf(direction.y) >= absf(direction.x):
		preferred_state = "walk_down" if direction.y > 0.0 else "walk_up"
	else:
		preferred_state = "walk_right" if direction.x > 0.0 else "walk_left"
	return _first_available_state([preferred_state, "walk", "idle"])


func play_state(state: String, force: bool = false) -> void:
	if _owner == null or _visual_config.is_empty():
		return
	if not force and _visual_state == state:
		return
	_visual_state = state
	VisualConfigApplierScript.play_state(_owner, _visual_config, state, "idle")


func _first_available_state(states: Array[String]) -> String:
	for state: String in states:
		if VisualConfigApplierScript.has_state_visual(_visual_config, state):
			return state
	return states[0] if not states.is_empty() else "idle"
