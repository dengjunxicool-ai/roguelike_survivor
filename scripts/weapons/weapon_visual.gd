extends Node2D
class_name WeaponVisual


const DEFAULT_TEXTURE_PATH: String = "res://icon.svg"

@export var default_offset: Vector2 = Vector2(30, 4)
@export var default_scale: Vector2 = Vector2(0.16, 0.16)

var _sprite: Sprite2D
var _weapon_id: StringName = &""


func _ready() -> void:
	_ensure_sprite()


func set_weapon(weapon_id: Variant) -> void:
	var next_weapon_id: StringName = StringName(String(weapon_id))
	if next_weapon_id == _weapon_id and _sprite != null:
		return

	_weapon_id = next_weapon_id
	_apply_weapon_visual(GameData.get_weapon(_weapon_id))


func refresh_from_player(player: Node) -> void:
	if player == null:
		return
	set_weapon(player.get("selected_weapon_id"))


func _ensure_sprite() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("WeaponSprite") as Sprite2D
		if _sprite == null:
			_sprite = Sprite2D.new()
			_sprite.name = "WeaponSprite"
			add_child(_sprite)
	_sprite.z_index = 6


func _apply_weapon_visual(weapon: Dictionary) -> void:
	_ensure_sprite()
	if _sprite == null:
		return

	visible = not weapon.is_empty()
	if weapon.is_empty():
		return

	var visual: Dictionary = _get_dictionary(weapon.get("visual", {}))
	var texture_path: String = String(visual.get("texture", DEFAULT_TEXTURE_PATH))
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture != null:
		_sprite.texture = texture

	position = _get_vector2(visual.get("offset", []), default_offset)
	z_index = int(visual.get("z_index", 0))
	_sprite.scale = _get_vector2(visual.get("scale", []), default_scale)
	_sprite.rotation_degrees = float(visual.get("rotation", visual.get("rotation_degrees", -24.0)))
	_sprite.modulate = _get_color(visual.get("modulate", []), _get_fallback_color(weapon))
	_sprite.z_index = int(visual.get("sprite_z_index", 6))
	_sprite.flip_h = bool(visual.get("flip_h", false))
	_sprite.flip_v = bool(visual.get("flip_v", false))


func _get_fallback_color(weapon: Dictionary) -> Color:
	var tags: Array = _get_array(weapon.get("tags", []))
	if _has_tag(tags, "fire"):
		return Color(1.0, 0.38, 0.16, 1.0)
	if _has_tag(tags, "ice"):
		return Color(0.42, 0.78, 1.0, 1.0)
	if _has_tag(tags, "lightning"):
		return Color(1.0, 0.9, 0.25, 1.0)
	if _has_tag(tags, "poison") or _has_tag(tags, "acid"):
		return Color(0.48, 0.9, 0.22, 1.0)
	if _has_tag(tags, "holy"):
		return Color(1.0, 0.86, 0.35, 1.0)
	return Color(0.88, 0.92, 1.0, 1.0)


func _has_tag(tags: Array, tag: String) -> bool:
	for tag_variant: Variant in tags:
		if String(tag_variant) == tag:
			return true
	return false


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var uniform_scale: float = float(value)
		return Vector2(uniform_scale, uniform_scale)
	return fallback


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			return Color(float(items[0]), float(items[1]), float(items[2]), float(items[3]) if items.size() > 3 else fallback.a)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return fallback
