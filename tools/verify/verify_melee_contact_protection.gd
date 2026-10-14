extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/characters/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const ChaseScript: Script = preload("res://scripts/enemies/behaviors/chase_player_behavior.gd")
const TrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var tracker: Node = TrackerScript.new()
	root.add_child(tracker)
	tracker.call("reset_run", &"mage", &"abandoned_dungeon")
	var player: CharacterBody2D = PlayerScene.instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.position = Vector2.ZERO
	player.set("max_health", 100)
	player.set("current_health", 100)
	player.set("armor", 0)
	player.set("damage_taken_multiplier", 1.0)
	player.set("_last_contact_damage_time", -100.0)
	var enemies: Array[CharacterBody2D] = []
	for index: int in range(2):
		var enemy: CharacterBody2D = EnemyScene.instantiate()
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.set("load_config_from_data", false)
		enemy.set("_behavior", {"type": "chase_player"})
		enemy.set("attack_range", 100.0)
		root.add_child(enemy)
		enemy.position = Vector2(40, index)
		enemy.set("target", player)
		enemy.set("contact_damage", 6)
		enemies.append(enemy)
	for enemy: CharacterBody2D in enemies:
		_tick_chase(enemy)
	_expect(int(player.get("current_health")) == 94, "two touching chase enemies share one 0.45-second contact protection window", player.get("current_health"))
	var summary: Dictionary = tracker.call("get_summary")
	_expect(int(summary.get("damage_taken_by_source", {}).get("contact", 0)) == 6, "chase hit records actual contact source", summary)
	_expect(not summary.get("damage_taken_by_source", {}).has("ranged"), "melee is never recorded as ranged", summary)
	# The normal physics tail also applies contact damage; it must not add a second hit.
	for enemy: CharacterBody2D in enemies:
		enemy.call("_apply_contact_damage")
	_expect(int(player.get("current_health")) == 94, "physics contact tail cannot duplicate the behavior hit")
	player.set("_last_contact_damage_time", -100.0)
	enemies[0].set("_damage_cooldown", 0.0)
	_tick_chase(enemies[0])
	_expect(int(player.get("current_health")) == 88, "contact resumes after player protection and enemy cooldown expire")
	player.set("_last_contact_damage_time", -100.0)
	enemies[0].set("_damage_cooldown", 0.0)
	enemies[0].position = Vector2(70, 0)
	_tick_chase(enemies[0])
	_expect(int(player.get("current_health")) == 88, "inside attack range but outside touching radius cannot cause melee damage")
	_expect(enemies[0].velocity.x < 0.0, "melee continues approaching until actual contact")
	# Smaller actors must use their actual collision sizes, not a default melee range.
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	player_shape.shape = player_shape.shape.duplicate()
	(player_shape.shape as CircleShape2D).radius = 10.0
	var enemy_shape: CollisionShape2D = enemies[0].get_node("CollisionShape2D")
	enemy_shape.shape = enemy_shape.shape.duplicate()
	(enemy_shape.shape as CircleShape2D).radius = 10.0
	enemies[0].position = Vector2(32, 0)
	_tick_chase(enemies[0])
	_expect(int(player.get("current_health")) == 88, "small collision shapes cannot hit across a noncontact gap")
	(player_shape.shape as CircleShape2D).radius = 24.0
	var slime: CharacterBody2D = EnemyScene.instantiate()
	slime.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(slime)
	slime.set("target", player)
	slime.position = Vector2(48, 0)
	_tick_chase(slime)
	_expect(int(player.get("current_health")) == 88, "configured slime attack range 48 cannot hit beyond real contact radius 44")
	slime.position = Vector2(44, 0)
	_tick_chase(slime)
	_expect(int(player.get("current_health")) == 82, "configured slime hits at actual 18 plus 24 plus 2 contact boundary")
	slime.free()
	var toxic_bug: CharacterBody2D = EnemyScene.instantiate()
	toxic_bug.process_mode = Node.PROCESS_MODE_DISABLED
	toxic_bug.set("enemy_id", &"toxic_bug")
	root.add_child(toxic_bug)
	toxic_bug.set("target", player)
	toxic_bug.position = Vector2(40, 0)
	player.set("_last_contact_damage_time", -100.0)
	_tick_chase(toxic_bug)
	_expect(int(player.get("current_health")) == 75, "configured toxic bug preserves its seven contact damage")
	_expect(int(tracker.call("get_summary").get("status_counts", {}).get("poison", 0)) == 1, "contact behavior applies configured poison once")
	toxic_bug.call("_apply_contact_damage")
	_expect(int(tracker.call("get_summary").get("status_counts", {}).get("poison", 0)) == 1, "physics contact tail does not duplicate configured status")
	toxic_bug.free()
	for enemy: CharacterBody2D in enemies:
		enemy.free()
	player.free()
	tracker.free()
	print("[MeleeContactProtection] done failed=%s" % _failed)
	quit(1 if _failed else 0)

func _tick_chase(enemy: CharacterBody2D) -> void:
	var behavior: RefCounted = ChaseScript.new()
	behavior.call("setup", enemy, {"type": "chase_player"})
	behavior.call("tick", 0.016)

func _expect(condition: bool, label: String, actual: Variant = null) -> void:
	if condition:
		print("[MeleeContactProtection] PASS " + label)
	else:
		_failed = true
		push_error("[MeleeContactProtection] FAIL %s actual=%s" % [label, str(actual)])
