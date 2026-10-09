extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var protocol: Script = load("res://tools/verify/skill_balance_protocol.gd")
	if protocol == null:
		push_error("Missing normal-viewport sampling protocol")
		quit(1)
		return
	root.size = Vector2i(64,64)
	protocol.configure_viewport(self)
	await process_frame
	assert(root.size == Vector2i(1280,720), "Sampling must preserve normal camera targeting viewport")
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var enemy := Node2D.new()
	enemy.position = Vector2(230,0)
	root.add_child(enemy)
	assert(preload("res://scripts/skills/targeting_service.gd").is_valid_target(enemy))
	enemy.free()
	camera.free()
	print("[verify_skill_balance_protocol] PASS normal viewport keeps 230px enemy targetable")
	quit(0)
