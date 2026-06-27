extends SceneTree


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_check, CONNECT_ONE_SHOT)


func _run_check() -> void:
	var packed_scene: PackedScene = load("res://scenes/effects/fire_tornado_effect.tscn") as PackedScene
	_expect(packed_scene != null, "fire tornado effect scene loads")
	if packed_scene == null:
		_finish()
		return

	var effect: Node2D = packed_scene.instantiate() as Node2D
	_expect(effect != null, "fire tornado effect instantiates as Node2D")
	if effect == null:
		_finish()
		return

	root.add_child(effect)
	await process_frame
	await process_frame
	_expect(is_instance_valid(effect), "fire tornado effect remains valid after startup frames")
	_expect(not is_instance_valid(effect) or effect.get_node_or_null("GroundShadow") == null, "fire tornado effect does not create an oblique ground shadow")
	if is_instance_valid(effect):
		effect.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
	else:
		_failed = true
		push_error("FAIL %s" % message)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("Fire tornado runtime scene verified.")
	quit(0)
