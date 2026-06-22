extends SceneTree


const PlayerVisualControllerScript: Script = preload("res://scripts/player/player_visual_controller.gd")
const WeaponVisualScript: Script = preload("res://scripts/weapons/weapon_visual.gd")

var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	_check_player_visual_resets_from_oblique_state()
	await _check_weapon_visual_resets_from_oblique_state()
	_finish()


func _check_player_visual_resets_from_oblique_state() -> void:
	var player: Node2D = Node2D.new()
	player.name = "PlayerVisualResetProbe"
	root.add_child(player)

	var controller: RefCounted = PlayerVisualControllerScript.new()
	controller.call("setup", player)
	controller.call("apply_character_config", {
		"visual": {
			"texture": "res://icon.svg",
			"scale": [0.1, 0.1],
			"offset": [0.0, -15.0],
			"rotation_degrees": 12.0,
			"z_index": 4
		}
	})
	controller.call("apply_character_config", {
		"visual": {
			"texture": "res://icon.svg",
			"scale": [0.1, 0.1]
		}
	})

	var sprite: Sprite2D = player.get_node_or_null("Sprite2D") as Sprite2D
	_assert(sprite != null, "player sprite exists")
	_assert(sprite != null and sprite.position == Vector2.ZERO, "player visual offset resets to top-down origin")
	_assert(sprite != null and is_zero_approx(sprite.rotation_degrees), "player visual rotation resets to top-down rotation")
	_assert(sprite != null and sprite.z_index == 0, "player visual z index resets to top-down default")
	player.queue_free()


func _check_weapon_visual_resets_from_oblique_state() -> void:
	var weapon_visual: Node2D = WeaponVisualScript.new()
	weapon_visual.name = "WeaponVisualResetProbe"
	root.add_child(weapon_visual)
	await process_frame

	weapon_visual.position = Vector2(15.0, -6.0)
	weapon_visual.z_index = 8
	var sprite: Sprite2D = weapon_visual.get_node_or_null("WeaponSprite") as Sprite2D
	if sprite != null:
		sprite.z_index = -1
		sprite.flip_h = true
		sprite.scale = Vector2(0.2, 0.08)

	weapon_visual.call("set_weapon", &"fire_staff")
	sprite = weapon_visual.get_node_or_null("WeaponSprite") as Sprite2D
	_assert(sprite != null, "weapon sprite exists")
	_assert(weapon_visual.position == Vector2(30.0, 4.0), "weapon visual returns to top-down default offset")
	_assert(weapon_visual.z_index == 0, "weapon visual root z index resets to top-down default")
	_assert(sprite != null and sprite.z_index == 6, "weapon sprite z index resets to top-down default")
	_assert(sprite != null and not sprite.flip_h, "weapon sprite horizontal flip resets")
	weapon_visual.queue_free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[TopDownVisualResetCheck] PASS %s" % message)
	else:
		_failed = true
		push_error("[TopDownVisualResetCheck] FAIL %s" % message)


func _finish() -> void:
	print("[TopDownVisualResetCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)
