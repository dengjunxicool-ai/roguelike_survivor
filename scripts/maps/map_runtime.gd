## 文件用途：解析地图选择、解锁信息和背景资源并应用到运行场景。
## 使用方式：开局编排通过静态入口解析 map_id 与应用背景，UI 查询锁定提示。

extends RefCounted
class_name MapRuntime


const DEFAULT_MAP_ID: StringName = &"abandoned_dungeon"


## 作用：优先匹配地图 ID，再匹配展示名，最后回退默认地图。
## 使用：map_id 接受 UI 或配置值；返回标准 StringName，不检查解锁条件。
static func resolve_map_id(map_id: Variant) -> StringName:
	var requested_id: StringName = StringName(String(map_id))
	if not GameData.get_map(requested_id).is_empty():
		return requested_id

	for map_data: Dictionary in GameData.get_map_pool():
		if String(map_data.get("display_name", "")) == String(map_id):
			return StringName(String(map_data.get("id", DEFAULT_MAP_ID)))

	return DEFAULT_MAP_ID


## 作用：获取默认地图ID，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 StringName 文本/标识。
static func get_default_map_id() -> StringName:
	if not GameData.get_map(DEFAULT_MAP_ID).is_empty():
		return DEFAULT_MAP_ID

	var maps: Array[Dictionary] = GameData.get_map_pool()
	if maps.is_empty():
		return DEFAULT_MAP_ID

	return StringName(String(maps[0].get("id", DEFAULT_MAP_ID)))


## 作用：判断地图已解锁，返回布尔判断结果。
## 使用：本文件由 get_lock_or_clear_text 调用；输入 map_data（地图数据）。
static func is_map_unlocked(map_data: Dictionary) -> bool:
	var unlock: Dictionary = _get_dictionary(map_data.get("unlock", {}))
	match String(unlock.get("type", "default")):
		"default":
			return true
		"clear_map":
			var required_map_id: StringName = StringName(String(unlock.get("map_id", "")))
			return SaveManager.is_map_cleared(required_map_id)
		"legacy_unlock":
			var map_id: StringName = StringName(String(map_data.get("id", "")))
			return SaveManager.is_unlocked("map", map_id)
		_:
			return false


## 作用：获取锁定或清除文本，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 map_data（地图数据）；返回 String 文本/标识。
static func get_lock_or_clear_text(map_data: Dictionary) -> String:
	var map_id: StringName = StringName(String(map_data.get("id", "")))
	if SaveManager.is_map_cleared(map_id):
		return "状态：已通关"
	if is_map_unlocked(map_data):
		return "状态：已解锁"

	var unlock: Dictionary = _get_dictionary(map_data.get("unlock", {}))
	if String(unlock.get("type", "")) == "clear_map":
		var required_map_id: StringName = StringName(String(unlock.get("map_id", "")))
		var required_map: Dictionary = GameData.get_map(required_map_id)
		return "解锁条件：通关 %s" % _get_map_display_name(required_map, required_map_id)
	return "状态：未解锁"


## 作用：获取背景路径，供当前模块后续逻辑使用。
## 使用：本文件由 apply_background 调用；输入 map_data（地图数据）；返回 String 文本/标识。
static func get_background_path(map_data: Dictionary) -> String:
	var visual: Dictionary = _get_dictionary(map_data.get("visual", {}))
	return String(visual.get("background", ""))


## 作用：获取地图展示名称，供当前模块后续逻辑使用。
## 使用：本文件由 get_lock_or_clear_text 调用；输入 map_data（地图数据）、fallback_id（回退ID）；返回 String 文本/标识。
static func _get_map_display_name(map_data: Dictionary, fallback_id: StringName) -> String:
	match String(map_data.get("id", fallback_id)):
		"abandoned_dungeon":
			return "废弃地牢"
		"toxic_fog_graveyard":
			return "瘟毒墓园"
		"lava_temple":
			return "熔火神殿"
		"abyss_corridor":
			return "深渊回廊"
		_:
			return String(map_data.get("display_name", fallback_id))


## 作用：寻找 DungeonBackground 并加载地图背景纹理。
## 使用：tree/map_data 来自开局编排；若背景提供 apply_texture 优先委托，加载失败保持现状。
static func apply_background(tree: SceneTree, map_data: Dictionary) -> void:
	if tree == null:
		return

	var background: Sprite2D = tree.root.find_child("DungeonBackground", true, false) as Sprite2D
	if background == null:
		return

	var texture: Texture2D = load_texture(get_background_path(map_data))
	if texture == null:
		return

	if background.has_method("apply_texture"):
		background.call("apply_texture", texture)
		return

	background.texture = texture
	background.centered = false
	background.position = Vector2.ZERO
	background.scale = Vector2.ONE


## 作用：优先使用资源加载器，失败再从图像文件创建 ImageTexture。
## 使用：path 为纹理路径；空路径或图像加载失败返回 null。
static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null

	if ResourceLoader.exists(path, "Texture2D"):
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			return texture

	var image: Image = Image.new()
	if image.load(path) != OK:
		return null

	return ImageTexture.create_from_image(image)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 is_map_unlocked、get_lock_or_clear_text、get_background_path 调用；输入 value（值）。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
