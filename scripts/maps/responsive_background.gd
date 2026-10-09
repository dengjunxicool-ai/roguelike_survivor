## 文件用途：让地图背景适配视口与相机并更新玩家移动边界。
## 使用方式：挂载背景节点；apply_texture 后 refresh_layout，视口变化时重算世界尺寸。

extends Sprite2D
class_name ResponsiveBackground


@export var min_world_size: Vector2 = Vector2(2560, 1440)
@export var overscan_pixels: float = 8.0


## 作用：设置背景为左上角定位与线性纹理过滤，并监听视口尺寸变化。
## 使用：由 Godot 自动调用；延迟 refresh_layout 使场景依赖准备完成。
func _ready() -> void:
	centered = false
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	get_viewport().size_changed.connect(Callable(self, "refresh_layout"))
	call_deferred("refresh_layout")


## 作用：更换背景纹理并立即重算缩放和移动边界。
## 使用：next_texture 为背景 Texture2D；无纹理时布局入口直接返回。
func apply_texture(next_texture: Texture2D) -> void:
	texture = next_texture
	refresh_layout()


## 作用：按相机可见世界尺寸和最小地图尺寸等比放大背景，并延迟刷新玩家边界。
## 使用：视口变化或换纹理后调用；overscan_pixels 提供四周覆盖余量，纹理不重复。
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


## 作用：把视口尺寸除以相机缩放，再逐轴取不小于 min_world_size 的地图尺寸。
## 使用：由布局更新调用；没有相机时直接使用视口尺寸计算；返回 Vector2 对象/值。
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


## 作用：请求 player 分组中支持该接口的节点重算移动边界。
## 使用：背景布局完成后延迟调用；只通知玩家，不直接修改其坐标。
func _refresh_player_movement_bounds() -> void:
	for player: Node in get_tree().get_nodes_in_group(&"player"):
		if player.has_method("refresh_movement_bounds"):
			player.call("refresh_movement_bounds")
