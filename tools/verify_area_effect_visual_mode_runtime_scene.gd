extends Node


var _failed: bool = false
var _lines: Array[String] = []


func _ready() -> void:
	_run_check()


func _run_check() -> void:
	await get_tree().process_frame

	var asset_area: AreaEffect = _create_area_effect("AssetArea", {
		"radius": 80,
		"visual_mode": "asset",
		"visual_style": "fire_burst",
		"visual": {
			"texture": "res://icon.svg",
			"scale": [1.25, 1.25]
		}
	})
	var asset_sprite: Sprite2D = asset_area.get_node_or_null("Sprite2D") as Sprite2D
	var asset_animated: AnimatedSprite2D = asset_area.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_expect(asset_sprite != null and asset_sprite.visible, "asset visual mode shows configured Sprite2D")
	_expect(asset_animated == null or not asset_animated.visible, "asset visual mode does not force animated fallback without sprite_frames")
	_expect(absf(asset_area.radius - 80.0) <= 0.01, "asset visual mode preserves configured area radius")

	var programmatic_area: AreaEffect = _create_area_effect("ProgrammaticArea", {
		"radius": 80,
		"visual_mode": "programmatic",
		"visual_style": "fire_burst",
		"visual": {
			"texture": "res://icon.svg"
		}
	})
	var programmatic_sprite: Sprite2D = programmatic_area.get_node_or_null("Sprite2D") as Sprite2D
	_expect(programmatic_sprite != null and not programmatic_sprite.visible, "programmatic visual mode keeps fire_burst drawing active")

	_write_result()
	get_tree().quit(1 if _failed else 0)


func _create_area_effect(node_name: String, params: Dictionary) -> AreaEffect:
	var area: AreaEffect = load("res://scenes/area_effect.tscn").instantiate() as AreaEffect
	area.name = node_name
	add_child(area)
	area.setup(params)
	return area


func _expect(condition: bool, message: String) -> void:
	var line: String = "[PASS] %s" % message if condition else "[FAIL] %s" % message
	_lines.append(line)
	if condition:
		return
	_failed = true


func _write_result() -> void:
	var file: FileAccess = FileAccess.open("res://tools/verify_area_effect_visual_mode_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
