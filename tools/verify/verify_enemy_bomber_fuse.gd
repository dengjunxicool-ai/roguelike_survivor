extends SceneTree

var _failed := false
class DamageTarget:
	extends Node2D
	var hits := 0
	func take_damage(_packet: DamagePacket) -> void:
		hits += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	var player := DamageTarget.new()
	player.add_to_group(&"player")
	owner.add_child(player)
	var scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var bomber: Node2D = scene.instantiate()
	bomber.set("enemy_id", &"bomber")
	owner.add_child(bomber)
	bomber.position = Vector2(40, 0)
	bomber.set("target", player)
	var sprite: AnimatedSprite2D = bomber.get_node("AnimatedSprite2D")
	var original_color := sprite.modulate
	bomber.call("_update_behavior", 0.1)
	bomber.call("_apply_contact_damage")
	_expect(player.hits == 0, "fusing bomber causes no regular contact damage")
	_expect(sprite.visible and sprite.modulate != original_color, "fuse flash affects the visible animated sprite")
	_expect(bomber.get_node_or_null("FuseTelegraph") != null, "fuse shows the actual blast boundary")
	bomber.call("_update_behavior", 0.69)
	_expect(player.hits == 0, "fuse must finish before explosion")
	bomber.call("_update_behavior", 0.02)
	_expect(player.hits == 1, "completed fuse deals one explosion")
	bomber.call("_run_self_explosion_action")
	_expect(player.hits == 1, "self explosion is idempotent")
	var killed: Node2D = scene.instantiate()
	killed.set("enemy_id", &"bomber")
	owner.add_child(killed)
	killed.position = Vector2(40, 0)
	killed.set("target", player)
	killed.call("_update_behavior", 0.1)
	killed.set_meta("reward_policy", {"award_soul": false, "drop_experience": false, "notify_kill_events": false})
	killed.call("_die")
	killed.call("_run_self_explosion_action")
	_expect(player.hits == 1, "death during fuse cancels explosion")
	var orphaned: Node2D = scene.instantiate()
	orphaned.set("enemy_id", &"bomber")
	owner.add_child(orphaned)
	orphaned.process_mode = Node.PROCESS_MODE_PAUSABLE
	orphaned.set_physics_process(false)
	orphaned.set("target", player)
	orphaned.position = Vector2(40, 0)
	orphaned.set_meta("reward_policy", {"award_soul": false, "drop_experience": false, "notify_kill_events": false})
	orphaned.call("_update_behavior", 0.1)
	await physics_frame
	await physics_frame
	player.free()
	orphaned.call("_physics_process_profiled", 0.8)
	_expect(orphaned.get("_is_dead") == true, "real update keeps lit fuse progressing after target removal")
	owner.queue_free()
	await process_frame
	print("[EnemyBomberFuse] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyBomberFuse] PASS " + message)
	else:
		_failed = true
		push_error("[EnemyBomberFuse] FAIL " + message)
