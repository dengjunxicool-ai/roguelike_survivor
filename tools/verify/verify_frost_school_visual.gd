## 生产配置/工厂路径验收：寒霜区域、状态、反馈及池化。
extends SceneTree

const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const StatusManager = preload("res://scripts/combat/status_effect_manager.gd")
var failed := false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	failed = failed or not ok

func run() -> void:
	await process_frame
	var world := Node2D.new()
	root.add_child(world)
	for id: String in ["frost_field", "frost_path", "frost_ring", "shatter_splash", "absolute_zero_field"]:
		var duration := 0.2 if id in ["frost_ring", "shatter_splash"] else 3.0
		var area: AreaEffect = Factory.create_area_effect({"parent": world, "area_id": id, "source_id": id, "duration": duration, "radius": 135.0}) as AreaEffect
		area.set_physics_process(false)
		var effect: Node2D = area.get_node_or_null("AreaVisualEffect")
		check(effect != null, id + " uses production procedural effect")
		if effect == null:
			continue
		check(not area.get_node("Sprite2D").visible, id + " hides placeholder")
		area._physics_process(duration * 0.3)
		check(is_equal_approx(effect.effect_age, duration * 0.3), id + " clock follows host")
		check(float(effect.modulate.a) > 0.4, id + " short and long profiles reach visible peak")
		area.set_effect_radius(180.0)
		check(is_equal_approx(effect.effect_radius, 180.0), id + " radius changes propagate")
		seed(79)
		var expected := randf()
		seed(79)
		effect.configure(180.0, duration, 2.0)
		effect.update_state(180.0, duration * 0.3, duration)
		check(is_equal_approx(randf(), expected), id + " runtime leaves gameplay RNG unchanged")
		area.prepare_for_pool_despawn()
		check(not effect.visible, id + " hides on recycle")
		area.prepare_for_pool_spawn({"duration": 1.0, "radius": 25.0, "visual_style": "fire_burst", "visual_mode": "programmatic"})
		area.set_physics_process(false)
		check(not effect.visible, id + " no cross-style residue")
	var enemy := Node2D.new()
	world.add_child(enemy)
	var status: Node = StatusManager.new()
	status.name = "StatusEffectManager"
	enemy.add_child(status)
	status.apply_status(&"chilled", {"stacks": 2, "duration": 6.0})
	await process_frame
	var overlay: Node2D = enemy.get_node_or_null("StatusVisualOverlay")
	var state: Node2D = overlay.get_node_or_null("ProceduralStatus") if overlay != null else null
	check(state != null, "actual chilled creates procedural overlay")
	if state != null:
		check(state.status_stacks == 2 and not state.is_frozen, "cold overlay reflects actual stacks")
		status.apply_status(&"chilled", {"stacks": 1, "duration": 8.0})
		await process_frame
		check(state.status_stacks == 3, "same status updates stacks without new nodes")
		status.apply_status(&"frozen", {"duration": 0.5})
		await process_frame
		check(state.is_frozen, "real freeze activates prison overlay")
		status.clear_statuses()
		await process_frame
		check(not overlay.visible and not state.visible, "status clearing leaves no frost residue")
	var owner := Node2D.new()
	world.add_child(owner)
	var bus := preload("res://scripts/skills/skill_event_bus.gd").new()
	bus.name = "SkillEventBus"
	owner.add_child(bus)
	var presentation: Node2D = bus.get_node("FrostCombatPresentation")
	bus.emit_skill_event(&"post_damage_hit", {"caster":owner,"position":Vector2(120,75),"damage_amount":0,"source_skill_id":&"frost_power_shatter_execute"})
	check(presentation._hits.is_empty(), "rejected damage produces no execute feedback")
	bus.emit_skill_event(&"post_damage_hit", {"caster":owner,"position":Vector2(120,75),"damage_amount":5,"source_skill_id":&"frost_power_shatter_execute"})
	check(presentation._hits.size() == 1 and presentation._hits[0].profile == 2, "confirmed execute damage plays shatter")
	var hit: Node2D = presentation._hits[0]
	owner.position += Vector2(200,0)
	check(hit.global_position.is_equal_approx(Vector2(120,55)), "impact remains at hit point when caster moves")
	for index: int in 60:
		presentation.play_hit(Vector2(index,0),0)
	check(presentation._hits.size() == 32, "impact pool has hard simultaneous budget")
	var now: float = bus.combat_seconds()
	owner.set_meta("fire_passive_shield",60)
	owner.set_meta("fire_passive_shield_expires_at",now+6)
	owner.set_meta("ice_mist_shield_expires_at",now+6)
	bus.emit_skill_event(&"shield_gained", {"caster":owner,"owner":owner,"shield_type":"fire_skill","shield_amount":20})
	check(presentation._shield == null, "non-frost shield does not show ice mist")
	bus.emit_skill_event(&"shield_gained", {"caster":owner,"owner":owner,"shield_type":"ice_mist","shield_amount":40})
	check(presentation._shield.visible and presentation._shield.shield_layers == 1, "confirmed cold shield shows first layer")
	owner.set_meta("ice_mist_shield_expires_at",now-1.0)
	owner.set_meta("fire_passive_shield_expires_at",now+8.0)
	bus.emit_skill_event(&"shield_gained", {"caster":owner,"owner":owner,"shield_type":"ice_mist","shield_amount":20})
	presentation._refresh_shield()
	check(presentation._shield.shield_layers == 2, "new grants extend old visual layers with actual shared pool deadline")
	owner.set_meta("fire_passive_shield",10)
	presentation._refresh_shield()
	check(is_equal_approx(presentation._shield.shield_fraction,1.0/6.0), "mixed shared shield pool clips cold visual to remaining protection")
	owner.set_meta("fire_passive_shield",0)
	bus.emit_skill_event(&"shield_broken", {"caster":owner,"owner":owner})
	check(not presentation._shield.visible, "real break clears ice mist immediately")
	presentation.reset_presentation()
	check(not hit.visible and presentation._cold_grants.is_empty(), "run reset clears feedback and shields")
	world.queue_free()
	await process_frame
	print("Frost school visual: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
