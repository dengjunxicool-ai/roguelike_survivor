extends SceneTree


const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")
const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SummonManagerScript: Script = preload("res://scripts/summons/summon_manager.gd")


class SmokePlayer:
	extends Node2D

	var attack_power: float = 20.0
	var range: float = 540.0


class SmokeEnemy:
	extends Node2D

	var damage_packets: Array = []

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet)


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: SmokePlayer = SmokePlayer.new()
	player.name = "Player"
	player.global_position = Vector2.ZERO
	root.add_child(player)

	var manager: Node = SummonManagerScript.new()
	player.add_child(manager)
	var definition: RefCounted = SummonDefinitionScript.from_id("crimson_dragon")
	_expect(definition != null, "loads crimson_dragon summon definition")
	if definition == null:
		quit(1)
		return

	var dragon: Node2D = manager.call("spawn_summon", definition, {
		"owner": player,
		"player_power": player.attack_power,
		"parent": root,
		"target_group": &"enemies"
	}) as Node2D
	_expect(dragon != null, "spawns crimson dragon through SummonManager")
	if dragon == null:
		quit(1)
		return

	var enemy: SmokeEnemy = SmokeEnemy.new()
	enemy.name = "InsidePlayerRange"
	enemy.global_position = Vector2(535.0, 0.0)
	root.add_child(enemy)
	var registry: Node = CombatTargetRegistryScript.get_or_create(root)
	registry.call("register_enemy", enemy)

	dragon.global_position = Vector2(540.0, 0.0)
	dragon.call("_physics_process", 0.25)
	_expect(String(dragon.get("state")) == "ATTACK", "dragon can attack while inside the player's 540px activity circle", dragon.get("state"))
	_expect(enemy.damage_packets.size() > 0, "dragon attacks an enemy inside the activity circle", enemy.damage_packets.size())

	enemy.damage_packets.clear()
	player.global_position = Vector2(-50.0, 0.0)
	dragon.call("_physics_process", 0.1)
	_expect(String(dragon.get("state")) == "RETURN", "dragon abandons actions and returns when player movement leaves it outside the activity circle", dragon.get("state"))
	_expect(dragon.get("target") == null, "dragon clears target while returning")
	_expect(enemy.damage_packets.is_empty(), "dragon does not attack while returning to the activity circle", enemy.damage_packets.size())
	_expect(dragon.global_position.x < 540.0, "dragon moves back toward the player instead of teleporting", dragon.global_position)

	dragon.queue_free()
	player.queue_free()
	registry.call("unregister_enemy", enemy)
	enemy.queue_free()
	await process_frame
	if not _failed:
		print("[verify_crimson_dragon_summon_behavior] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_crimson_dragon_summon_behavior] FAIL %s actual=%s" % [label, str(actual)])
