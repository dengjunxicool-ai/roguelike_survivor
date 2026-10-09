## Run-clock contracts and explicitly bounded combustion continuations.
extends RefCounted
const Registry = preload("res://scripts/combat/combat_target_registry.gd")
var marks: Dictionary = {}
var combustion_explosions: int = 0
func mark(target: Node, context: Dictionary, duration: float, now: float) -> void:
	var actions: Dictionary = {}
	for mode: String in ["death", "expiry"]:
		actions[mode] = preload("res://scripts/skills/skill_effect_adapter.gd").to_actions([{"type":"spawn_area", "area_id":"soul_explosion_area", "position_mode":"event", "radius":168.0, "duration":0.22, "effects_on_apply":[{"type":"damage", "damage_type":"curse", "source_type":"power", "power_scale":1.8 if mode == "death" else 0.9}]}], context.get("skill_instance") as RefCounted)
	marks[target.get_instance_id()] = {"target": weakref(target), "context": context.duplicate(true), "expires": now+duration, "actions":actions}
func update(bus: Node) -> void:
	for id: Variant in marks.keys():
		var item: Dictionary = marks[id]
		var target: Node = item.target.get_ref()
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			marks.erase(id)
		elif bus.combat_seconds() >= float(item.expires):
			settle(bus, target, false)
func settle(bus: Node, target: Node, died: bool) -> void:
	var id: int = target.get_instance_id()
	if not marks.has(id): return
	var context: Dictionary = marks[id].context
	var actions: Array = marks[id].actions["death" if died else "expiry"]
	marks.erase(id)
	target.set_meta("death_pact", false)
	if not died and target.has_method("is_dead") and target.is_dead(): return
	context["position"] = target.global_position
	context["target"] = null
	context["enemy"] = null
	bus.execute_adapted_actions(actions, context)
func death(bus: Node, context: Dictionary) -> void:
	var target: Node = context.get("target") as Node
	if target == null: return
	settle(bus, target, true)
	if target.has_meta("combustion_pending"):
		var chain: Dictionary = target.get_meta("combustion_pending")
		target.remove_meta("combustion_pending")
		if int(chain.remaining) > 0 and randf() < 0.25 and not chain.seen.has(target.get_instance_id()):
			chain.remaining -= 1
			chain.multiplier *= 0.6
			chain.seen[target.get_instance_id()] = true
			explode(bus, chain.context, target.global_position, chain)
func start(bus: Node, context: Dictionary, params: Dictionary = {}) -> bool:
	context = context.duplicate(true)
	context["combustion_radius"] = float(params.get("radius",184.8))
	context["combustion_scale"] = float(params.get("power_scale",2.4))
	var chain: Dictionary = {"remaining":2, "multiplier":1.0, "seen":{}, "context":context.duplicate(true)}
	var target: Node2D = context.get("target") as Node2D
	if target != null: chain.seen[target.get_instance_id()] = true
	explode(bus, context, context.get("position", target.global_position if target != null else Vector2.ZERO), chain)
	return true
func explode(bus: Node, context: Dictionary, position: Vector2, chain: Dictionary) -> void:
	combustion_explosions += 1
	var registry: Node = Registry.get_or_create(bus)
	for target: Node2D in registry.get_targets_in_radius(position, float(context.get("combustion_radius",184.8)), &"enemies"):
		if target.has_method("is_dead") and target.is_dead(): continue
		target.set_meta("combustion_pending", chain)
		var hit: Dictionary = context.duplicate(true)
		hit["target"] = target
		bus.execute_adapted_actions([{"type":"deal_damage", "params":{"amount":{"stat":"power", "scale":float(context.get("combustion_scale",2.4))*float(chain.multiplier)}, "damage_type":"fire", "source_type":"power"}},{"type":"apply_status", "params":{"status_id":"burning", "stacks":1, "duration":4.0}}],hit)
		if not target.has_method("is_dead") or not target.is_dead(): target.remove_meta("combustion_pending")
func clear_origin(id: StringName) -> void:
	for key: Variant in marks.keys():
		var item: Dictionary = marks[key]
		if StringName(String(item.context.get("origin_skill_id", ""))) == id:
			var target: Node = item.target.get_ref()
			if target != null: target.set_meta("death_pact", false)
			marks.erase(key)
