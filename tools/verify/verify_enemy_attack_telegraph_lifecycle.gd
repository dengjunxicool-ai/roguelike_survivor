extends SceneTree
const EnemyScene: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var _failed := false
class DamageTarget:
	extends CharacterBody2D
	var hits := 0
	func take_damage(_packet: DamagePacket) -> void:
		hits += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var target := DamageTarget.new()
	target.add_to_group(&"player")
	var collision := CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 24.0
	target.add_child(collision)
	owner.add_child(target)
	var scene: PackedScene = load("res://scenes/combat/damage_area.tscn")
	var area: Node2D = scene.instantiate()
	owner.add_child(area)
	area.process_mode = Node.PROCESS_MODE_DISABLED
	var counts := {"finished": 0}
	_expect(area.has_signal("enemy_attack_finished"), "area provides generation-aware finish notification")
	if area.has_signal("enemy_attack_finished"):
		area.connect("enemy_attack_finished", func(_generation: int): counts.finished += 1)
	area.call("setup", {"damage": 10, "duration": 2.5, "tick_interval": 1.0, "area_radius": 80.0, "warning_time": 1.2, "activation_mode": &"periodic", "use_enemy_lifecycle": true, "attack_owner": owner})
	await physics_frame
	await physics_frame
	area.call("_physics_process", 1.0)
	_expect(target.hits == 0, "configured gaze warning prevents early tick")
	area.call("_physics_process", 0.19)
	_expect(target.hits == 0, "entire warning phase is harmless")
	area.call("_physics_process", 0.02)
	_expect(target.hits == 1, "activation deals first periodic hit")
	area.call("_physics_process", 1.0)
	_expect(target.hits == 2, "active time drives periodic ticks")
	area.call("prepare_for_pool_despawn")
	area.call("prepare_for_pool_despawn")
	_expect(counts.finished == 1, "pool return finishes a generation exactly once")
	area.call("prepare_for_pool_spawn", {"damage": 10, "duration": 1.0, "tick_interval": 1.0, "area_radius": 80.0, "warning_time": 0.9, "activation_mode": &"single", "use_enemy_lifecycle": true, "attack_owner": owner})
	area.call("_physics_process", 0.89)
	_expect(target.hits == 2, "pooled single attack gets a fresh warning")
	area.call("_physics_process", 0.02)
	_expect(target.hits == 3 and counts.finished == 2, "single activation hits and finishes once")
	area.call("_physics_process", 0.3)
	_expect(target.hits == 3, "finished single attack cannot hit again")
	await process_frame
	var cancelled: Node2D = scene.instantiate()
	owner.add_child(cancelled)
	cancelled.process_mode = Node.PROCESS_MODE_DISABLED
	var caster := Node2D.new()
	owner.add_child(caster)
	cancelled.call("setup", {"damage": 10, "warning_time": 0.5, "activation_mode": &"single", "use_enemy_lifecycle": true, "attack_owner": caster})
	caster.free()
	cancelled.call("_physics_process", 0.6)
	_expect(target.hits == 3, "caster removal cancels a pending warning")
	await process_frame
	var sustained: Node2D = scene.instantiate()
	owner.add_child(sustained)
	sustained.process_mode = Node.PROCESS_MODE_DISABLED
	var active_caster := Node2D.new()
	owner.add_child(active_caster)
	sustained.call("setup", {"damage": 10, "duration": 2.0, "tick_interval": 1.0, "warning_time": 0.5, "activation_mode": &"periodic", "use_enemy_lifecycle": true, "attack_owner": active_caster})
	await physics_frame
	await physics_frame
	sustained.call("_physics_process", 0.5)
	active_caster.free()
	sustained.call("_physics_process", 1.0)
	_expect(target.hits == 5, "activated independent field survives caster removal")
	sustained.call("_physics_process", 1.0)
	_expect(target.hits == 5, "expiration boundary never adds a tick")
	await process_frame
	var paused_area: Node2D = scene.instantiate()
	owner.add_child(paused_area)
	paused_area.call("setup", {"warning_time": 0.5, "use_enemy_lifecycle": true, "attack_owner": owner})
	paused = true
	await create_timer(0.12, true).timeout
	_expect(paused_area.get("_warning_elapsed") == 0.0, "tree pause freezes warning")
	paused = false
	paused_area.process_mode = Node.PROCESS_MODE_DISABLED
	target.free()
	paused_area.call("_physics_process", 0.5)
	_expect(paused_area.get("_attack_finished") == true, "target removal permits harmless single completion")
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	var caster_enemy: Node2D = EnemyScene.instantiate()
	caster_enemy.set("enemy_id", &"toxic_matriarch")
	owner.add_child(caster_enemy)
	var controller: RefCounted = caster_enemy.get("_skill_controller")
	var locked := Vector2(200, 150)
	_expect(controller.call("execute_action_type", "damage_area", {"position": locked}), "configured enemy creates a telegraphed area through the real registry")
	await process_frame
	var registered: Node2D = caster_enemy.get_meta("active_enemy_area").node.get_ref()
	_expect(registered.get("_use_enemy_lifecycle") == true and registered.get("_warning_time") == 0.9, "enemy config and registry preserve explicit warning")
	_expect(not controller.call("execute_action_type", "damage_area", {"position": Vector2.ZERO}), "ordinary caster cannot stack a second live area")
	caster_enemy.position = Vector2(300, 300)
	_expect(registered.global_position == locked, "area stays at its locked cast position")
	registered.call("_physics_process", 0.4)
	caster_enemy.free()
	registered.call("_physics_process", 0.41)
	_expect(registered.get("_attack_finished") == true, "real caster removal cancels pending area")
	var validator: Script = load("res://scripts/core/content_config_validator.gd")
	var sources: Dictionary = validator.load_sources()
	var documents: Dictionary = sources.documents.duplicate(true)
	documents["res://data/enemies/enemy_skills.json"].enemy_skills[0].actions.append({"type": "damage_area", "params": 42})
	_expect(not validator.validate_documents(documents, sources.schema).is_empty(), "malformed warning params reject without script failure")
	controller = null
	owner.queue_free()
	await process_frame
	print("[EnemyAttackTelegraphLifecycle] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyAttackTelegraphLifecycle] PASS " + message)
	else:
		_failed = true
		push_error("[EnemyAttackTelegraphLifecycle] FAIL " + message)
