extends RefCounted
class_name MapRuntime


const DEFAULT_MAP_ID: StringName = &"abandoned_dungeon"


static func resolve_map_id(map_id: Variant) -> StringName:
	var requested_id: StringName = StringName(String(map_id))
	if not GameData.get_map(requested_id).is_empty():
		return requested_id

	for map_data: Dictionary in GameData.get_map_pool():
		if String(map_data.get("display_name", "")) == String(map_id):
			return StringName(String(map_data.get("id", DEFAULT_MAP_ID)))

	return DEFAULT_MAP_ID


static func get_default_map_id() -> StringName:
	if not GameData.get_map(DEFAULT_MAP_ID).is_empty():
		return DEFAULT_MAP_ID

	var maps: Array[Dictionary] = GameData.get_map_pool()
	if maps.is_empty():
		return DEFAULT_MAP_ID

	return StringName(String(maps[0].get("id", DEFAULT_MAP_ID)))


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


static func get_background_path(map_data: Dictionary) -> String:
	var visual: Dictionary = _get_dictionary(map_data.get("visual", {}))
	return String(visual.get("background", ""))


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


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
