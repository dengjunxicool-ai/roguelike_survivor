extends SceneTree


const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var released_node: Node = Node.new()
	released_node.free()
	var trace_id: int = DamageTraceContextScript.get_trace_id({"source": released_node})
	if trace_id != 0:
		push_error("[verify_damage_trace_context_released_object] expected released source to have no trace id, got %d" % trace_id)
		quit(1)
		return
	print("[verify_damage_trace_context_released_object] PASS")
	quit(0)
