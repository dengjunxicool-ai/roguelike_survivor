extends SceneTree

const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner: Node2D = Node2D.new()
	root.add_child(owner)
	VisualConfigApplierScript.apply_visual_config(owner, {
		"texture": "res://assets/effect/fireball/core.png",
		"material": "res://resources/effects/fireball_flying_material.tres"
	})
	await process_frame
	print("verify_fireball_shader_visual_apply: PASS")
	quit(0)
