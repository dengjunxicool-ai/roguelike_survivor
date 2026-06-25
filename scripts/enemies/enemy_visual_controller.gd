extends RefCounted
class_name EnemyVisualController


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const FULL_ANIMATION_DISTANCE_SQUARED: float = 900.0 * 900.0
const HIDE_DISTANCE_SQUARED: float = 1800.0 * 1800.0

var _owner: Node2D
var _visual_config: Dictionary = {}
var _visual_state: String = ""
var _last_move_state: String = "move_right"
var _hurt_flash_item: CanvasItem
var _hurt_flash_modulate: Color = Color.WHITE


func setup(owner: Node2D) -> void:
	_owner = owner


func apply_enemy_config(enemy_config: Dictionary) -> void:
	var visual_variant: Variant = enemy_config.get("visual", {})
	if not (visual_variant is Dictionary):
		return

	var visual: Dictionary = visual_variant
	_visual_config = visual.duplicate(true)
	play_state("idle", true)


func show_hurt(duration: float = 0.12) -> void:
	if _get_lod() != 0:
		return
	if _visual_config.is_empty() or _is_normal_enemy():
		_start_hurt_flash()
		return
	play_state("hurt")


func update(state: Dictionary, delta: float) -> void:
	if _visual_config.is_empty():
		if bool(state.get("is_hurt", false)):
			_start_hurt_flash()
		else:
			_end_hurt_flash()
		return

	if _apply_lod(state):
		return

	if bool(state.get("is_hurt", false)):
		if _is_normal_enemy():
			_start_hurt_flash()
		else:
			play_state("hurt")
			return
	else:
		_end_hurt_flash()

	if bool(state.get("is_dead", false)):
		play_state("death")
		return

	if _is_normal_enemy():
		play_state("attack" if bool(state.get("is_attacking", false)) else _get_move_state(state))
		return

	var status_state: String = String(state.get("status_state", ""))
	if status_state != "":
		play_state(status_state)
		return

	if bool(state.get("is_attacking", false)):
		play_state("attack")
	elif bool(state.get("is_moving", false)):
		play_state(_get_move_state(state))
	else:
		play_state("idle")


func play_state(state: String, force: bool = false) -> void:
	if _owner == null or _visual_config.is_empty():
		return
	if not force and _visual_state == state:
		return
	_visual_state = state
	VisualConfigApplierScript.play_state(_owner, _visual_config, state, "idle")


func _is_normal_enemy() -> bool:
	return _owner != null and String(_owner.get_meta("enemy_rank", _owner.get_meta("enemy_type", "normal"))) == "normal"


func _start_hurt_flash() -> void:
	if _hurt_flash_item != null and is_instance_valid(_hurt_flash_item):
		return
	_hurt_flash_item = _owner.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if _hurt_flash_item == null:
		_hurt_flash_item = _owner.get_node_or_null("Sprite2D") as CanvasItem
	if _hurt_flash_item == null:
		return
	_hurt_flash_modulate = _hurt_flash_item.modulate
	_hurt_flash_item.modulate = Color.WHITE


func _end_hurt_flash() -> void:
	if _hurt_flash_item != null and is_instance_valid(_hurt_flash_item):
		_hurt_flash_item.modulate = _hurt_flash_modulate
	_hurt_flash_item = null


func _get_move_state(state: Dictionary) -> String:
	var direction: Vector2 = state.get("move_direction", Vector2.ZERO) as Vector2
	if direction.length_squared() <= 0.0001:
		return _last_move_state

	var preferred_state: String = "move_right"
	if absf(direction.y) >= absf(direction.x):
		preferred_state = "move_down" if direction.y > 0.0 else "move_up"
	else:
		preferred_state = "move_right" if direction.x > 0.0 else "move_left"
	_last_move_state = _first_available_state([preferred_state, "move_right", "move_left", "idle"])
	return _last_move_state


func _first_available_state(states: Array[String]) -> String:
	for state: String in states:
		if VisualConfigApplierScript.has_state_visual(_visual_config, state):
			return state
	return states[0] if not states.is_empty() else "idle"


func _apply_lod(state: Dictionary) -> bool:
	var lod: int = _get_lod()
	if lod == 0:
		_set_ground_shadow_visible(true)
		_resume_animation()
		return false
	if lod == 2:
		_set_visual_visible(false)
		_set_ground_shadow_visible(false)
		_stop_animation()
		_visual_state = ""
		return true
	play_state(_get_move_state(state) if bool(state.get("is_moving", false)) else "idle")
	_set_ground_shadow_visible(true)
	_stop_animation()
	return true


func _get_lod() -> int:
	if _owner == null or not _is_on_screen():
		return 2
	var target: Node2D = _owner.get("target") as Node2D
	if target == null:
		return 0
	var distance_squared: float = _owner.global_position.distance_squared_to(target.global_position)
	if distance_squared > HIDE_DISTANCE_SQUARED:
		return 2
	if distance_squared > FULL_ANIMATION_DISTANCE_SQUARED:
		return 1
	return 0


func _is_on_screen() -> bool:
	if _owner == null or _owner.get_viewport() == null:
		return true
	return _owner.get_viewport().get_visible_rect().grow(96.0).has_point(_owner.get_global_transform_with_canvas().origin)


func _set_visual_visible(visible: bool) -> void:
	for name: String in ["Sprite2D", "AnimatedSprite2D"]:
		var node: CanvasItem = _owner.get_node_or_null(name) as CanvasItem
		if node != null:
			node.visible = visible


func _set_ground_shadow_visible(visible: bool) -> void:
	var shadow: CanvasItem = _owner.get_node_or_null("GroundShadow") as CanvasItem
	if shadow != null:
		shadow.visible = visible


func _stop_animation() -> void:
	var animated_sprite: AnimatedSprite2D = _owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.stop()


func _resume_animation() -> void:
	var animated_sprite: AnimatedSprite2D = _owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null and animated_sprite.visible and not animated_sprite.is_playing():
		animated_sprite.play()
