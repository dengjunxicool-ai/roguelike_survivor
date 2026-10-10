extends SceneTree

const Service: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const WarningScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_warning.gd")
var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner: Node2D = Node2D.new()
	root.add_child(owner)
	var service: RefCounted = Service.new()
	var enemy: CharacterBody2D = _make_enemy(owner)
	service.call("_prepare_spawn_reveal", enemy)
	service.call("_begin_spawn_reveal", enemy, 0.05)
	await _wait_for_warning_cleanup(owner)
	_expect(not bool(enemy.get_meta("spawn_reveal_pending")) and enemy.process_mode == Node.PROCESS_MODE_INHERIT, "living enemy activates after reveal")
	_expect(enemy.collision_layer == 8 and enemy.collision_mask == 16 and enemy.modulate == Color.WHITE and enemy.scale.is_equal_approx(Vector2.ONE), "living enemy restores collision and presentation")
	_expect(_warning_count(owner) == 0, "completed reveal removes warning")
	enemy.queue_free()
	await process_frame
	enemy = _make_enemy(owner)
	service.call("_prepare_spawn_reveal", enemy)
	service.call("_begin_spawn_reveal", enemy, 0.05)
	_expect(_warning_count(owner) == 1, "pending reveal has a warning")
	enemy.queue_free()
	await process_frame
	await _wait_for_warning_cleanup(owner)
	_expect(_warning_count(owner) == 0, "enemy freed before tween completion still removes warning")
	for child: Node in owner.get_children():
		child.queue_free()
	await process_frame
	enemy = _make_enemy(owner)
	service.call("_prepare_spawn_reveal", enemy)
	service.call("_begin_spawn_reveal", enemy, 0.05)
	var cancelled_tween: Tween = get_processed_tweens()[0]
	for child: Node in owner.get_children():
		if child.get_script() == WarningScript:
			child.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.05).timeout
	_expect(_warning_count(owner) == 0 and not cancelled_tween.is_valid() and (not is_instance_valid(enemy) or enemy.is_queued_for_deletion()), "removed warning cancels reveal and removes disabled orphan")
	_expect(not bool(service.call("has_work")) and int(service.get("statistics").cancelled)>=1, "reveal cancellation is recorded and leaves no outstanding work")
	owner.queue_free()
	await process_frame
	service = null
	print("[SpawnRevealLifecycle] done failed=%s" % _failed)
	quit(1 if _failed else 0)


func _wait_for_warning_cleanup(parent: Node) -> void:
	# SceneTree timers fire before Tween processing; a large startup delta may
	# expire the old wall timer before the completion callback runs that frame.
	var deadline: int = Time.get_ticks_msec() + 2000
	while _warning_count(parent) > 0 and Time.get_ticks_msec() < deadline:
		await process_frame


func _make_enemy(parent: Node) -> CharacterBody2D:
	var enemy: CharacterBody2D = CharacterBody2D.new()
	enemy.collision_layer = 8
	enemy.collision_mask = 16
	parent.add_child(enemy)
	return enemy


func _warning_count(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child.get_script() == WarningScript and not child.is_queued_for_deletion():
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[SpawnRevealLifecycle] PASS " + message)
	else:
		_failed = true
		push_error("[SpawnRevealLifecycle] FAIL " + message)
