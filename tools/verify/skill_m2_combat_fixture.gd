extends SceneTree
const Manager = preload("res://scripts/skills/skill_manager.gd")
const Bus = preload("res://scripts/skills/skill_event_bus.gd")
const Status = preload("res://scripts/combat/status_effect_manager.gd")
const Store = preload("res://scripts/modifiers/modifier_store.gd")
const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Registry = preload("res://scripts/combat/combat_target_registry.gd")
class Player:
	extends Node2D
	var attack_power: float = 100.0
	var max_health: int = 1000
	var current_health: int = 500
class Enemy:
	extends Node2D
	var max_health: int = 10000
	var current_health: int = 10000
	var packets: Array = []
	var hit_bus: Node = null
	func take_damage(packet: DamagePacket) -> void:
		packets.append(packet.to_dictionary())
		var before: int = current_health
		var snapshot: Array = $StatusEffectManager.get_status_snapshot()
		current_health = maxi(0, current_health - roundi(packet.raw_amount))
		if hit_bus != null:
			var context: Dictionary = {"caster":hit_bus.get_parent(), "owner":hit_bus.get_parent(), "target":self, "position":global_position, "damage_packet":packet.to_dictionary(), "damage_amount":packet.raw_amount, "target_statuses":snapshot, "skill_manager":hit_bus.get_parent().get_node("SkillManager")}
			hit_bus.emit_skill_event(&"post_damage_hit", context)
			if before > 0 and current_health == 0: hit_bus.emit_skill_event(&"on_enemy_killed",context)
	func has_status(id: Variant) -> bool:
		return $StatusEffectManager.has_status(id)
	func apply_status(id: Variant, params: Dictionary = {}) -> bool:
		return $StatusEffectManager.apply_status(id, params)
	func get_status_stack(id: Variant) -> int:
		return $StatusEffectManager.get_status_stack(id)
	func is_dead() -> bool:
		return current_health <= 0
var player: Player
var bus: Node
var manager: Node
var enemy: Enemy
var failed: int = 0
func setup() -> void:
	player = Player.new()
	root.add_child(player)
	player.add_to_group(&"player")
	var store: Node = Store.new()
	store.name = "ModifierStore"
	player.add_child(store)
	manager = Manager.new()
	manager.name = "SkillManager"
	player.add_child(manager)
	bus = Bus.new()
	bus.name = "SkillEventBus"
	player.add_child(bus)
	bus.set_physics_process(false)
	bus.get_node("RunCombatClock").set_physics_process(false)
	enemy = make_enemy(Vector2(30, 0))
func make_enemy(pos: Vector2, rank: String = "normal") -> Enemy:
	var target: Enemy = Enemy.new()
	root.add_child(target)
	target.position = pos
	target.add_to_group(&"enemies")
	target.set_meta("enemy_rank", rank)
	var status: Node = Status.new()
	status.name = "StatusEffectManager"
	target.add_child(status)
	target.hit_bus = bus
	Registry.get_or_create(root).register_enemy(target)
	return target
func install(id: StringName) -> RefCounted:
	Fixture.install_runtime_skill(manager, id)
	return manager.get_skill(id)
func ctx(target: Node, origin: RefCounted = null) -> Dictionary:
	return {"caster": player, "owner": player, "target": target, "position": target.position if target != null else player.position, "parent": root, "skill_manager": manager, "event_bus": bus, "power": 100.0, "skill_instance": origin, "skill_id": origin.skill_id if origin != null else &"primary_attack_fireball"}
func expect(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failed += 1
func advance(seconds: float) -> void:
	bus.get_node("RunCombatClock").tick(seconds)
func finish() -> void:
	quit(1 if failed > 0 else 0)
