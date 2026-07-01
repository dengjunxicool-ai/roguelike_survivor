extends SceneTree


const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var caster := Node2D.new()
	root.add_child(caster)

	var released_target := Node2D.new()
	root.add_child(released_target)
	released_target.free()

	var executor: RefCounted = SkillActionExecutorScript.new()
	var resolved_context: Dictionary = executor.call("_context_with_resolved_target", {
		"position_mode": "caster"
	}, {
		"caster": caster,
		"target": released_target,
		"enemy": released_target,
		"target_group": &"enemies"
	})

	_expect(not resolved_context.has("target"), "freed target is removed from resolved context", resolved_context)
	_expect(not resolved_context.has("enemy"), "freed enemy alias is removed from resolved context", resolved_context)

	caster.queue_free()
	await process_frame
	if not _failed:
		print("[verify_skill_action_freed_target_context] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_action_freed_target_context] FAIL %s actual=%s" % [label, str(actual)])
