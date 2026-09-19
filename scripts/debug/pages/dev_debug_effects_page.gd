extends VBoxContainer
class_name DevDebugEffectsPage

signal log_requested(level: StringName, message: String)

const FIRE_TORNADO_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/fire_tornado_effect.tscn")
const MARS_SPARK_MISSILE_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/mars_spark_missile_effect.tscn")
const UIButtonSkinScript: Script = preload("res://scripts/ui/ui_button_skin.gd")

var _get_player_callback: Callable
var _get_nearest_enemy_callback: Callable
var _effect_option: OptionButton
var _built: bool = false


func setup(get_player: Callable, get_nearest_enemy: Callable) -> void:
	_get_player_callback = get_player
	_get_nearest_enemy_callback = get_nearest_enemy


func build() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 7)

	var option_row: HBoxContainer = _add_row()
	var label: Label = Label.new()
	label.text = "Effect"
	label.custom_minimum_size = Vector2(104, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	option_row.add_child(label)
	_effect_option = OptionButton.new()
	_effect_option.custom_minimum_size = Vector2(300, 30)
	_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_row.add_child(_effect_option)

	var actions_row: HBoxContainer = _add_row()
	_add_button(actions_row, "持续发射", Callable(self, "start_continuous_effect"), 116.0)
	_add_button(actions_row, "单次发射", Callable(self, "fire_single_effect"), 116.0)
	populate_options()


func populate_options() -> void:
	if not _built:
		build()
	if _effect_option == null:
		return
	_effect_option.clear()
	_add_option_item("Fire Tornado", "fire_tornado")
	_add_option_item("火星飞弹", "mars_spark_missile")
	_effect_option.select(0)


func get_effect_option() -> OptionButton:
	return _effect_option


func start_continuous_effect() -> void:
	trigger_selected_effect(true)


func fire_single_effect() -> void:
	trigger_selected_effect(false)


func trigger_selected_effect(continuous: bool) -> void:
	match _get_selected_effect_id():
		&"fire_tornado":
			spawn_fire_tornado_effect()
		&"mars_spark_missile":
			spawn_mars_spark_missile_effect(continuous)
		_:
			_emit_log(&"warning", "No effect selected.")


func spawn_fire_tornado_effect() -> void:
	var player: Node2D = _resolve_player()
	if player == null:
		_emit_log(&"warning", "Cannot spawn Fire Tornado: player not found.")
		return
	if FIRE_TORNADO_EFFECT_SCENE == null:
		_emit_log(&"error", "Cannot spawn Fire Tornado: scene failed to load.")
		return

	var effect: Node2D = FIRE_TORNADO_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		_emit_log(&"error", "Cannot spawn Fire Tornado: scene root is not Node2D.")
		return

	var parent: Node = _resolve_spawn_parent(player)
	if parent == null:
		effect.queue_free()
		_emit_log(&"error", "Cannot spawn Fire Tornado: no scene parent available.")
		return

	parent.add_child(effect)
	effect.global_position = resolve_fire_tornado_spawn_position(player)
	_emit_log(&"info", "Spawned Fire Tornado VFX.")


func spawn_mars_spark_missile_effect(continuous: bool) -> void:
	var player: Node2D = _resolve_player()
	if player == null:
		_emit_log(&"warning", "Cannot spawn Mars Spark Missile: player not found.")
		return
	if MARS_SPARK_MISSILE_EFFECT_SCENE == null:
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: scene failed to load.")
		return

	var effect: Variant = MARS_SPARK_MISSILE_EFFECT_SCENE.instantiate()
	if not (effect is Node2D):
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: scene root is not MarsSparkMissileEffect.")
		return

	var parent: Node = _resolve_spawn_parent(player)
	if parent == null:
		(effect as Node).queue_free()
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: no scene parent available.")
		return

	parent.add_child(effect)
	var origin: Vector2 = resolve_mars_spark_missile_spawn_position(player)
	var target: Vector2 = resolve_mars_spark_missile_target_position(player, origin)
	effect.configure(origin, target, false)
	effect.set_continuous(continuous)
	_emit_log(&"info", "Spawned %s Mars Spark Missile VFX." % ("continuous" if continuous else "single"))


func resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		var to_enemy: Vector2 = nearest_enemy.global_position - player.global_position
		if to_enemy.length_squared() > 0.0001:
			direction = to_enemy.normalized()
	return player.global_position + direction * 96.0


func resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		direction = player.global_position.direction_to(nearest_enemy.global_position)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return player.global_position + direction.normalized() * 32.0


func resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		return nearest_enemy.global_position
	var direction: Vector2 = Vector2.RIGHT
	if player != null:
		direction = player.global_position.direction_to(origin)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return origin + direction.normalized() * 360.0


func _add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	return row


func _add_button(parent: HBoxContainer, text: String, action: Callable, width: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 30)
	UIButtonSkinScript.apply(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_option_item(text: String, id: String) -> void:
	var index: int = _effect_option.item_count
	_effect_option.add_item(text)
	_effect_option.set_item_metadata(index, StringName(id))


func _resolve_player() -> Node2D:
	if not _get_player_callback.is_valid():
		return null
	var candidate: Variant = _get_player_callback.call()
	if candidate is Node2D and is_instance_valid(candidate):
		return candidate as Node2D
	return null


func _resolve_nearest_enemy() -> Node2D:
	if not _get_nearest_enemy_callback.is_valid():
		return null
	var candidate: Variant = _get_nearest_enemy_callback.call()
	if candidate is Node2D and is_instance_valid(candidate):
		return candidate as Node2D
	return null


func _resolve_spawn_parent(player: Node2D) -> Node:
	if player != null and player.get_parent() != null:
		return player.get_parent()
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return null


func _get_selected_effect_id() -> StringName:
	if _effect_option == null or _effect_option.item_count <= 0:
		return &""
	var selected_index: int = clampi(_effect_option.selected, 0, _effect_option.item_count - 1)
	return StringName(String(_effect_option.get_item_metadata(selected_index)))


func _emit_log(level: StringName, message: String) -> void:
	log_requested.emit(level, message)
