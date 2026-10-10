extends SceneTree
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var failed := false
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world := Node2D.new()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player := Node2D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	var priest: Node2D = make_priest(world, player, Vector2(350, 0))
	priest.call("_update_behavior", 0.01)
	expect(children_of(priest).is_empty() and get_nodes_in_group(&"enemies").size() == 1, "summon begins with harmless warning")
	priest.call("_update_behavior", 0.79)
	expect(children_of(priest).is_empty(), "warning lasts full 0.8 seconds")
	priest.call("_update_behavior", 0.02)
	await process_frame
	expect(children_of(priest).size() == 2, "first summon creates two owned children")
	priest.set("_summon_cooldown", 0.0)
	priest.call("_update_behavior", 0.01)
	priest.call("_update_behavior", 0.81)
	await process_frame
	expect(children_of(priest).size() == 4, "second summon reaches four including pending reveals")
	priest.set("_summon_cooldown", 0.0)
	priest.call("_update_behavior", 0.01)
	priest.call("_update_behavior", 0.81)
	await process_frame
	expect(children_of(priest).size() == 4 and priest.get("_summon_cooldown") == 0.0, "full cap neither spawns nor consumes cooldown")
	if children_of(priest).size() > 0:
		var child: Node = children_of(priest)[0]
		var policy: Dictionary = child.get_meta("reward_policy", {})
		expect(policy.get("drop_experience") == false and policy.get("award_soul") == false, "summons cannot farm experience or soul")
		child.free()
	priest.call("_update_behavior", 0.01)
	priest.call("_update_behavior", 0.81)
	await process_frame
	expect(children_of(priest).size() == 4, "one freed child can be replenished without exceeding cap")
	var other := make_priest(world, player, Vector2(-350, 0))
	other.call("_update_behavior", 0.01)
	other.call("_update_behavior", 0.81)
	await process_frame
	expect(children_of(other).size() == 2 and children_of(priest).size() == 4, "priests have separate ownership caps")
	other.set_meta("reward_policy", {"award_soul": false, "drop_experience": false, "notify_kill_events": false})
	other.set("_summon_cooldown", 0.0)
	other.call("_update_behavior", 0.01)
	other.call("_die")
	other.call("_update_behavior", 1.0)
	expect(children_of(other).size() == 2, "caster death cancels unfinished summon but preserves children")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
func make_priest(world: Node, player: Node2D, position: Vector2) -> Node2D:
	var priest: Node2D = EnemyScene.instantiate()
	priest.set("enemy_id", &"skeleton_priest")
	world.add_child(priest)
	priest.position = position
	priest.set("target", player)
	return priest
func children_of(priest: Node) -> Array[Node]:
	var children: Array[Node] = []
	for child in get_nodes_in_group(&"enemies"):
		if child.get_meta("summoner_instance_id", 0) == priest.get_instance_id() and not child.is_queued_for_deletion() and child.get("_is_dead") != true:
			children.append(child)
	return children
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[SummonLimits] FAIL " + message)
	else:
		print("[SummonLimits] PASS " + message)
