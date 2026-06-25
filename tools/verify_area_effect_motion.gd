extends SceneTree


const AreaEffectScript: Script = preload("res://scripts/combat/area_effect.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var area := Area2D.new()
	area.set_script(AreaEffectScript)
	area.name = "MovingAreaEffect"
	area.global_position = Vector2.ZERO
	root.add_child(area)
	area.call("setup", {
		"damage": 0,
		"radius": 32.0,
		"duration": 1.0,
		"tick_interval": 0.5,
		"target_group": &"enemies",
		"move_direction": Vector2.RIGHT,
		"move_speed": 120.0
	})
	await physics_frame
	area.call("_physics_process", 0.25)
	_expect(area.global_position.x > 20.0, "area effect moves along configured direction", area.global_position)
	_expect(absf(area.global_position.y) <= 0.01, "area effect does not drift sideways", area.global_position)
	area.queue_free()
	await process_frame
	if not _failed:
		print("[verify_area_effect_motion] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_area_effect_motion] FAIL %s actual=%s" % [label, str(actual)])
