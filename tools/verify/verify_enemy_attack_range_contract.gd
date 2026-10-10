extends SceneTree

const Validator = preload("res://scripts/core/content_config_validator.gd")
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
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 24.0
	player.add_child(shape)
	owner.add_child(player)
	var scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var boss: Node2D = scene.instantiate()
	boss.set("enemy_id", &"dungeon_heart")
	owner.add_child(boss)
	boss.set("target", player)
	boss.position = Vector2(500, 0)
	boss.set("_behavior", {"type": "boss_dungeon_heart", "skill_range": 760.0, "phases": []})
	for _index in range(3):
		boss.call("_update_enemy_action_cooldowns", 1.0)
		boss.call("_update_behavior", 1.0)
		boss.call("_apply_contact_damage")
	_expect(player.hits == 0, "Boss skill range does not cause direct damage")
	boss.position = Vector2(80, 0)
	boss.set("_damage_cooldown", 0.0)
	boss.call("_apply_contact_damage")
	_expect(player.hits == 1, "Boss real collision contact still deals damage")
	var archer: Node2D = scene.instantiate()
	archer.set("enemy_id", &"archer_skeleton")
	owner.add_child(archer)
	archer.set("target", player)
	archer.position = Vector2(47, 0)
	archer.call("_apply_contact_damage")
	_expect(player.hits == 1, "base attack range does not enlarge contact radius")
	for entry in [["skeleton_priest", 400.0], ["toxic_matriarch", 360.0], ["lava_golem", 280.0], ["skeleton_captain", 260.0]]:
		var enemy: Node2D = scene.instantiate()
		enemy.set("enemy_id", StringName(entry[0]))
		owner.add_child(enemy)
		_expect(is_equal_approx(float(enemy.call("_get_behavior_attack_range")), entry[1]), "dedicated range: " + entry[0])
	var sources := Validator.load_sources()
	var documents: Dictionary = sources.documents.duplicate(true)
	var monsters: Array = documents["res://data/enemies/enemies.json"].monsters
	for monster: Dictionary in monsters:
		if monster.id == "skeleton_priest":
			monster.behavior.erase("summon_range")
	var errors: Array[String] = Validator.validate_documents(documents, sources.schema)
	_expect(_contains(errors, "skeleton_priest") and _contains(errors, "summon_range"), "missing behavior range rejected with monster ID")
	owner.queue_free()
	await process_frame
	print("[EnemyAttackRangeContract] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _contains(errors: Array[String], value: String) -> bool:
	for error in errors:
		if error.contains(value):
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[EnemyAttackRangeContract] PASS " + message)
	else:
		_failed = true
		push_error("[EnemyAttackRangeContract] FAIL " + message)
