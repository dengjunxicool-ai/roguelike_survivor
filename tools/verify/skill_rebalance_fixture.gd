extends RefCounted

const Store = preload("res://scripts/modifiers/modifier_store.gd")
const Manager = preload("res://scripts/skills/skill_manager.gd")
const Bus = preload("res://scripts/skills/skill_event_bus.gd")
const Statuses = preload("res://scripts/combat/status_effect_manager.gd")
const Definition = preload("res://scripts/skills/skill_definition.gd")
const Instance = preload("res://scripts/skills/skill_instance.gd")

class Player:
	extends Node2D
	var attack_power: float = 100.0
	var max_health: int = 100
	var current_health: int = 100
	var attack_speed_multiplier: float = 1.0
	var skill_area_multiplier: float = 1.0
	var status_duration_multiplier: float = 1.0
	var selected_character_id: StringName = &""
	func set_run_modifier_source(id: Variant, effects: Variant) -> void:
		get_node("ModifierStore").set_source(id, effects, [&"player", &"damage"])
	func clear_run_modifier_source(id: Variant) -> void:
		get_node("ModifierStore").clear_source(id)

class Target:
	extends Node2D
	var max_health: int = 100000
	var current_health: int = 100000
	var enemy_type: StringName = &"normal"
	var is_boss: bool = false
	var is_elite: bool = false
	var packets: Array[Dictionary] = []
	var hit_event_bus: Node = null
	func take_damage(packet: DamagePacket) -> void:
		packets.append(packet.to_dictionary())
		current_health = maxi(current_health - roundi(packet.raw_amount), 0)
		if hit_event_bus != null:
			hit_event_bus.emit_skill_event(&"post_damage_hit", {"damage_packet": packet.to_dictionary(), "target": self, "caster": hit_event_bus.get_parent(), "owner": hit_event_bus.get_parent(), "skill_manager": hit_event_bus.get_parent().get_node("SkillManager"), "damage_amount": packet.raw_amount, "event_bus": hit_event_bus})
	func apply_status(id: Variant, params: Dictionary = {}) -> bool:
		return get_node("StatusEffectManager").apply_status(id, params)
	func get_status_stack(id: Variant) -> int:
		return get_node("StatusEffectManager").get_status_stack(id)
	func has_status(id: Variant) -> bool:
		return get_status_stack(id) > 0
	func consume_status_stack(id: Variant, count: int = 1) -> bool:
		return get_node("StatusEffectManager").consume_status_stack(id, count)

static func build(tree: SceneTree) -> Dictionary:
	var player := Player.new()
	player.name = "RebalancePlayer"
	player.add_to_group(&"player")
	tree.root.add_child(player)
	var store := Store.new()
	store.name = "ModifierStore"
	player.add_child(store)
	store.set_physics_process(false)
	var manager := Manager.new()
	manager.name = "SkillManager"
	player.add_child(manager)
	var bus := Bus.new()
	bus.name = "SkillEventBus"
	player.add_child(bus)
	bus.set_process(false)
	bus.set_physics_process(false)
	var clock: Node = bus.get_node_or_null("RunCombatClock")
	if clock != null:
		clock.set_physics_process(false)
	var target := Target.new()
	target.name = "RebalanceTarget"
	target.add_to_group(&"enemies")
	tree.root.add_child(target)
	var statuses := Statuses.new()
	statuses.name = "StatusEffectManager"
	target.add_child(statuses)
	return {"caster": player, "owner": player, "target": target, "skill_manager": manager, "event_bus": bus, "store": store, "statuses": statuses, "power": 100.0}

static func skill(type: String = "cast", id: String = "fixture_cast", rules: Array = []) -> RefCounted:
	return Instance.new(Definition.new({"id": id, "display_name": id, "school": "fire", "skill_type": type, "max_level": 5, "rarity": "normal", "tags": [type, "fire"], "trigger_rules": rules}))

static func damage_total(target: Node) -> float:
	var result: float = 0.0
	for packet: Dictionary in target.packets:
		result += float(packet.get("raw_amount", 0.0))
	return result
