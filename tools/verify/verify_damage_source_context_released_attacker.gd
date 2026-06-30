extends SceneTree


const DamageSourceContextScript: Script = preload("res://scripts/combat/damage_source_context.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var released_attacker: Node = Node.new()
	released_attacker.free()
	var context: RefCounted = DamageSourceContextScript.from_dictionary({"attacker": released_attacker})
	if context.get("attacker") != null:
		push_error("[verify_damage_source_context_released_attacker] expected released attacker to become null")
		quit(1)
		return
	print("[verify_damage_source_context_released_attacker] PASS")
	quit(0)
