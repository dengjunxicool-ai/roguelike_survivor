extends Sprite2D
class_name ResponsiveBackground


@export var min_world_size: Vector2 = Vector2(2560, 1440)
@export var overscan_pixels: float = 8.0


func _ready() -> void:
	centered = false
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	get_viewport().size_changed.connect(Callable(self, "refresh_layout"))
	call_deferred("refresh_layout")


func apply_texture(next_texture: Texture2D) -> void:
	texture = next_texture
	refresh_layout()


func refresh_layout() -> void:
	if texture == null:
		return

	centered = false
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	position = Vector2(-overscan_pixels, -overscan_pixels)
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var target_size: Vector2 = _get_target_world_size() + Vector2.ONE * overscan_pixels * 2.0
	var scale_value: float = maxf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	scale = Vector2.ONE * maxf(scale_value, 0.001)
	call_deferred("_refresh_player_movement_bounds")


func _get_target_world_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		var camera_zoom: Vector2 = camera.zoom.abs()
		viewport_size = Vector2(
			viewport_size.x / maxf(camera_zoom.x, 0.001),
			viewport_size.y / maxf(camera_zoom.y, 0.001)
		)

	return Vector2(
		maxf(min_world_size.x, viewport_size.x),
		maxf(min_world_size.y, viewport_size.y)
	)


func _refresh_player_movement_bounds() -> void:
	for player: Node in get_tree().get_nodes_in_group(&"player"):
		if player.has_method("refresh_movement_bounds"):
			player.call("refresh_movement_bounds")
