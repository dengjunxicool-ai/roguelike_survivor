## 文件用途：将配置中的静态贴图或动画帧/精灵图应用到宿主Sprite2D/AnimatedSprite2D，并缓存帧资源。
## 使用方式：角色、状态overlay及战斗对象静态调用play_state/apply_visual_config；自动创建所需sprite子节点。
extends RefCounted
class_name VisualConfigApplier


const SPRITE_NODE_NAME: String = "Sprite2D"
const ANIMATED_NODE_NAME: String = "AnimatedSprite2D"

static var _sprite_frames_cache: Dictionary = {}


## 作用：合并状态专属覆盖与基础视觉，再按是否配置动画帧选择静态或动画sprite。
## 使用：owner为宿主节点，visual非空才应用，state默认idle。
static func apply_visual_config(owner: Node, visual: Dictionary, state: String = "idle") -> void:
	if owner == null or visual.is_empty():
		return

	var state_visual: Dictionary = _get_state_visual(visual, state)
	var merged_visual: Dictionary = visual.duplicate(true)
	for key: Variant in state_visual.keys():
		merged_visual[key] = state_visual[key]

	if _has_sprite_frames(merged_visual):
		_apply_animated_sprite(owner, merged_visual, state)
	else:
		_apply_sprite(owner, merged_visual)


## 作用：请求状态不存在且有fallback时选择fallback，再应用视觉。
## 使用：用于状态切换，默认回退idle。
static func play_state(owner: Node, visual: Dictionary, state: String, fallback_state: String = "idle") -> void:
	if owner == null or visual.is_empty():
		return

	var target_state: String = state
	if not _has_state_visual(visual, target_state) and fallback_state != "":
		target_state = fallback_state
	apply_visual_config(owner, visual, target_state)


## 作用：显示选用的sprite并隐藏另一种；静态模式同时停止动画。
## 使用：prefer_animated控制二选一，缺节点无操作。
static func hide_unused_visual_node(owner: Node, prefer_animated: bool) -> void:
	if owner == null:
		return

	var sprite: Sprite2D = owner.get_node_or_null(SPRITE_NODE_NAME) as Sprite2D
	var animated_sprite: AnimatedSprite2D = owner.get_node_or_null(ANIMATED_NODE_NAME) as AnimatedSprite2D
	if sprite != null:
		sprite.visible = not prefer_animated
	if animated_sprite != null:
		animated_sprite.visible = prefer_animated
		if not prefer_animated:
			animated_sprite.stop()


## 作用：取得或创建静态sprite，应用通用样式并按配置路径加载贴图。
## 使用：无有效贴图时不覆盖已有texture。
static func _apply_sprite(owner: Node, visual: Dictionary) -> void:
	var sprite: Sprite2D = owner.get_node_or_null(SPRITE_NODE_NAME) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = SPRITE_NODE_NAME
		owner.add_child(sprite)

	hide_unused_visual_node(owner, false)
	_apply_common_canvas_item(sprite, visual)

	var texture_path: String = String(visual.get("texture", ""))
	if texture_path != "":
		var texture: Texture2D = load(texture_path) as Texture2D
		if texture != null:
			sprite.texture = texture


## 作用：加载帧资源并配置动画节点，找不到帧时警告并回退静态。
## 使用：动画名按指定/fallback/首项回退，切换动画时重置帧与进度。
static func _apply_animated_sprite(owner: Node, visual: Dictionary, state: String) -> void:
	var sprite_frames: SpriteFrames = _load_sprite_frames(visual)
	if sprite_frames == null:
		push_warning("[VisualConfigApplier] Could not load sprite_frames for %s: %s" % [owner.name, String(visual.get("sprite_frames", ""))])
		_apply_sprite(owner, visual)
		return

	var animated_sprite: AnimatedSprite2D = owner.get_node_or_null(ANIMATED_NODE_NAME) as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = ANIMATED_NODE_NAME
		owner.add_child(animated_sprite)

	hide_unused_visual_node(owner, true)
	_apply_common_canvas_item(animated_sprite, visual)
	animated_sprite.sprite_frames = sprite_frames

	var animation_name: StringName = StringName(String(visual.get("animation", state)))
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		animation_name = StringName(String(visual.get("fallback_animation", "idle")))
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		var names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
		if names.is_empty():
			return
		animation_name = StringName(names[0])

	if animated_sprite.animation != animation_name:
		animated_sprite.animation = animation_name
		animated_sprite.frame = 0
		animated_sprite.frame_progress = 0.0
	if bool(visual.get("autoplay", true)):
		animated_sprite.play()


## 作用：应用颜色、缩放、偏移、旋转、层级、可选材质与翻转。
## 使用：item为sprite节点；缺配置值使用对应默认或现有值。
static func _apply_common_canvas_item(item: Node2D, visual: Dictionary) -> void:
	item.modulate = _get_color(visual.get("modulate", []), item.modulate)
	item.scale = _get_vector2(visual.get("scale", []), item.scale)
	item.position = _get_vector2(visual.get("offset", []), Vector2.ZERO)
	item.rotation_degrees = float(visual.get("rotation_degrees", 0.0))
	item.z_index = int(visual.get("z_index", 0))
	var material_path: String = String(visual.get("material", ""))
	if material_path != "":
		var configured_material: Material = load(material_path) as Material
		if configured_material != null:
			item.material = configured_material
	if item is Sprite2D:
		(item as Sprite2D).flip_h = bool(visual.get("flip_h", false))
		(item as Sprite2D).flip_v = bool(visual.get("flip_v", false))
	if item is AnimatedSprite2D:
		(item as AnimatedSprite2D).flip_h = bool(visual.get("flip_h", false))
		(item as AnimatedSprite2D).flip_v = bool(visual.get("flip_v", false))


## 作用：优先从animations状态字典取覆盖，否则从states取。
## 使用：返回深复制，找不到返回空字典。
static func _get_state_visual(visual: Dictionary, state: String) -> Dictionary:
	var animations: Dictionary = _get_dictionary(visual.get("animations", {}))
	if animations.has(state) and animations[state] is Dictionary:
		return (animations[state] as Dictionary).duplicate(true)

	var states: Dictionary = _get_dictionary(visual.get("states", {}))
	if states.has(state) and states[state] is Dictionary:
		return (states[state] as Dictionary).duplicate(true)

	return {}


## 作用：查询状态配置或帧资源是否存在对应动画。
## 使用：返回布尔值，可能从缓存/资源加载帧。
static func has_state_visual(visual: Dictionary, state: String) -> bool:
	return _has_state_visual(visual, state)


## 作用：先查状态覆盖，再查外部sprite_frames是否含动画。
## 使用：只有sprite_sheet且未显式状态覆盖时不会加载查询动画。
static func _has_state_visual(visual: Dictionary, state: String) -> bool:
	if not _get_state_visual(visual, state).is_empty():
		return true

	if String(visual.get("sprite_frames", "")) != "":
		var sprite_frames: SpriteFrames = _load_sprite_frames(visual)
		return sprite_frames != null and sprite_frames.has_animation(StringName(state))

	return false


## 作用：检查外部帧资源路径或sprite_sheet字段。
## 使用：只看配置，不验证资源加载成功。
static func _has_sprite_frames(visual: Dictionary) -> bool:
	return String(visual.get("sprite_frames", "")) != "" or visual.has("sprite_sheet")


## 作用：优先读缓存，再加载外部帧或由sprite_sheet构建并缓存。
## 使用：失败返回null，无缓存键时不缓存。
static func _load_sprite_frames(visual: Dictionary) -> SpriteFrames:
	var cache_key: String = _get_sprite_frames_cache_key(visual)
	if cache_key != "" and _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key] as SpriteFrames

	var frames: SpriteFrames = null
	var sprite_frames_path: String = String(visual.get("sprite_frames", ""))
	if sprite_frames_path != "":
		frames = load(sprite_frames_path) as SpriteFrames
	else:
		var sprite_sheet: Dictionary = _get_dictionary(visual.get("sprite_sheet", {}))
		if not sprite_sheet.is_empty():
			frames = _build_sprite_frames_from_sheet(visual, sprite_sheet)

	if frames != null and cache_key != "":
		_sprite_frames_cache[cache_key] = frames
	return frames


## 作用：外部帧使用路径，精灵图使用贴图、sheet与animations序列化组合键。
## 使用：无帧配置返回空键。
static func _get_sprite_frames_cache_key(visual: Dictionary) -> String:
	var sprite_frames_path: String = String(visual.get("sprite_frames", ""))
	if sprite_frames_path != "":
		return sprite_frames_path
	if visual.has("sprite_sheet"):
		return "%s:%s:%s" % [String(visual.get("texture", "")), var_to_str(visual.get("sprite_sheet", {})), var_to_str(visual.get("animations", {}))]
	return ""


## 作用：加载贴图，按单帧大小/网格/间距生成各动画AtlasTexture并设置fps/loop。
## 使用：animations须非空，无法加载贴图返回null。
static func _build_sprite_frames_from_sheet(visual: Dictionary, sprite_sheet: Dictionary) -> SpriteFrames:
	var texture_path: String = String(visual.get("texture", sprite_sheet.get("texture", "")))
	if texture_path == "":
		return null

	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return null

	var columns: int = maxi(int(sprite_sheet.get("columns", 1)), 1)
	var rows: int = maxi(int(sprite_sheet.get("rows", 1)), 1)
	var frame_size: Vector2 = _get_vector2(sprite_sheet.get("frame_size", []), Vector2.ZERO)
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		frame_size = Vector2(
			float(texture.get_width()) / float(columns),
			float(texture.get_height()) / float(rows)
		)

	var origin: Vector2 = _get_vector2(sprite_sheet.get("origin", []), Vector2.ZERO)
	var spacing: Vector2 = _get_vector2(sprite_sheet.get("spacing", []), Vector2.ZERO)
	var animations: Dictionary = _get_dictionary(visual.get("animations", sprite_sheet.get("animations", {})))
	if animations.is_empty():
		return null

	var frames: SpriteFrames = SpriteFrames.new()
	for animation_key: Variant in animations.keys():
		var animation_data: Dictionary = _get_dictionary(animations[animation_key])
		var animation_name: StringName = StringName(String(animation_key))
		if animation_name == &"":
			continue

		if not frames.has_animation(animation_name):
			frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(animation_data.get("fps", sprite_sheet.get("fps", 8.0))))
		frames.set_animation_loop(animation_name, bool(animation_data.get("loop", true)))

		var frame_specs: Array = _get_array(animation_data.get("cells", animation_data.get("frames", [])))
		if frame_specs.is_empty() and animation_data.has("row"):
			frame_specs = _build_row_frame_specs(
				int(animation_data.get("row", 0)),
				int(animation_data.get("start_column", 0)),
				int(animation_data.get("count", columns))
			)

		for frame_spec: Variant in frame_specs:
			var region: Rect2 = _get_frame_region(frame_spec, frame_size, origin, spacing)
			if region.size.x <= 0.0 or region.size.y <= 0.0:
				continue

			var atlas_frame: AtlasTexture = AtlasTexture.new()
			atlas_frame.atlas = texture
			atlas_frame.region = region
			frames.add_frame(animation_name, atlas_frame)

	return frames


## 作用：从行号、起始列和帧数生成连续二维cell列表。
## 使用：count负值生成空数组，列顺序保持。
static func _build_row_frame_specs(row: int, start_column: int, count: int) -> Array:
	var specs: Array = []
	for column_offset in range(maxi(count, 0)):
		specs.append([start_column + column_offset, row])
	return specs


## 作用：解析显式rect、列行字典、四数矩形或双数cell并换算贴图区域。
## 使用：origin/spacing/frame_size决定网格坐标，非法spec返回空Rect2。
static func _get_frame_region(frame_spec: Variant, frame_size: Vector2, origin: Vector2, spacing: Vector2) -> Rect2:
	if frame_spec is Dictionary:
		var frame_data: Dictionary = frame_spec
		if frame_data.has("rect"):
			return _get_rect2(frame_data["rect"], Rect2())
		var column: int = int(frame_data.get("column", frame_data.get("col", 0)))
		var row: int = int(frame_data.get("row", 0))
		return Rect2(origin + Vector2(column, row) * (frame_size + spacing), frame_size)
	if frame_spec is Array:
		var items: Array = frame_spec
		if items.size() >= 4:
			return Rect2(float(items[0]), float(items[1]), float(items[2]), float(items[3]))
		if items.size() >= 2:
			var column_from_array: int = int(items[0])
			var row_from_array: int = int(items[1])
			return Rect2(origin + Vector2(column_from_array, row_from_array) * (frame_size + spacing), frame_size)

	return Rect2()


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回深复制，嵌套修改不会污染输入。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回输入数组本身。
static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []


## 作用：读取Rect2或至少四个成员的[x,y,w,h]数组。
## 使用：无法解析返回fallback。
static func _get_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 4:
			return Rect2(float(items[0]), float(items[1]), float(items[2]), float(items[3]))
	return fallback


## 作用：解析Color、RGB/RGBA数组或HTML颜色字符串。
## 使用：无法解析时返回fallback；三成员RGB数组沿用fallback透明度。
static func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			var alpha: float = float(items[3]) if items.size() > 3 else fallback.a
			return Color(float(items[0]), float(items[1]), float(items[2]), alpha)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return fallback


## 作用：将Vector2或至少两个成员的[x,y]数组，数值则扩为同值双轴解析为二维值。
## 使用：无法解析时返回fallback；不修改输入。
static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var scalar: float = float(value)
		return Vector2(scalar, scalar)
	return fallback
