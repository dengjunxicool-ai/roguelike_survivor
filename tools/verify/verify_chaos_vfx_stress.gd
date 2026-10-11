## Identical seeded gameplay and visual updates; only canvas submission differs.
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const AREA_IDS := ["chaos_rift", "void_rift_field", "chaos_weak_hit", "mutation_pulse_area", "instability_fission_burst", "chaos_exchange_line", "chaos_singularity_field", "chaos_singularity_burst"]
var effects: Array[Node2D] = []
var summons: Array[Node2D] = []
var targets: Array[Node2D] = []
var fields: Array[AreaEffect] = []
var projectiles: Array[Projectile] = []
var mode := "shown"
var output := "E:/codex/chaos-vfx/stress/shown"

func percentile(samples: Array[float], portion: float) -> float:
	samples.sort()
	return samples[mini(int(samples.size()*portion), samples.size()-1)] if not samples.is_empty() else 0.0

func cast(bus: Node, id: StringName) -> void:
	var instance: RefCounted = manager.get_skill(id)
	instance.set_meta("trigger_cd_on_cast_global", 0.0)
	bus.emit_skill_event(&"on_cast", {"caster":player,"owner":player,"parent":player.get_parent(),"target":targets[0],"event_bus":bus,"skill_manager":manager,"skill_instance":instance,"skill_id":id,"origin_skill_id":id,"scheduled_cast":true,"power":float(player.attack_power)})
	bus.process_pending_events()

func snapshot(bus: Node) -> Dictionary:
	var health: Array[int] = []
	for target: Node2D in targets: health.append(int(target.current_health))
	var state: Dictionary = bus.chaos_state()
	# Startup can consume different physics frames; compare actual lifetime remaining.
	for entry: Dictionary in state.get("entropy",[]):
		entry["remaining"] = maxf(float(entry.get("expires",0.0))-float(bus.combat_seconds()),0.0)
		entry.erase("expires")
	return plain_values({"enemy_health":health,"player_health":int(player.current_health),"chaos_state":state,"modifier_sources":player.get_node("ModifierStore").get_debug_sources()})

func plain_values(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if not value[key] is Object: result[String(key)] = plain_values(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			if not item is Object: result.append(plain_values(item))
		return result
	if value is StringName: return String(value)
	return value

func same_values(first: Variant, second: Variant) -> bool:
	if (first is int or first is float) and (second is int or second is float):
		return is_equal_approx(float(first),float(second))
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size(): return false
		for key: Variant in first:
			if not second.has(key) or not same_values(first[key],second[key]): return false
		return true
	if first is Array and second is Array:
		if first.size() != second.size(): return false
		for index: int in first.size():
			if not same_values(first[index],second[index]): return false
		return true
	return first == second

func run() -> void:
	if "--parse-only" in OS.get_cmdline_user_args():
		check(same_values({"hp":[25],"state":{"fissions":1}}, {"state":{"fissions":1.0},"hp":[25.0]}),"parity handles JSON numbers and dictionary order")
		check(not same_values({"hp":[25]}, {"hp":[24.0]}),"parity rejects different actual HP")
		print("CHAOS_VFX_STRESS: PARSE PASS")
		quit(1 if failures else 0)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
	if mode == "hidden" and output == "E:/codex/chaos-vfx/stress/shown": output = "E:/codex/chaos-vfx/stress/hidden"
	check(mode in ["shown", "hidden"], "mode is shown or hidden")
	check(output.begins_with("E:/codex/"), "stress reports stay on E drive")
	if failures:
		quit(1)
		return
	seed(17123)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	var count := 0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school", "")) == "chaos" and definition.get("fusion_school") == null:
			check(Fixture.install_runtime_skill(manager, StringName(definition.id)), "learn " + String(definition.id))
			count += 1
	check(count == 14, "fourteen base chaos skills actually installed")
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	for index: int in 16:
		var enemy: Node2D = Enemy.instantiate()
		enemy.enemy_id = &"skeleton"
		parent.add_child(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.global_position = player.global_position+Vector2(-210+(index%4)*140,-150+(index/4)*100)
		enemy.max_health = 100000
		enemy.current_health = 100000
		enemy.armor = 0
		enemy.apply_status(&"instability", {"stacks":3,"duration":20.0,"source":player})
		targets.append(enemy)
	await settle(2)
	# All active base skills cast through the actual event bus; passive/core are installed.
	for id: StringName in [&"chaos_cast_void_rift",&"chaos_cast_singularity_barrage",&"chaos_cast_mutation_pulse",&"chaos_summon_chaos_clone",&"chaos_summon_void_maw",&"chaos_power_chaos_exchange"]: cast(bus,id)
	var attack: RefCounted = manager.get_skill(&"chaos_attack_chaotic")
	for index: int in 4:
		bus.emit_skill_event(&"attack_hit", {"caster":player,"owner":player,"parent":parent,"target":targets[0],"enemy":targets[0],"event_bus":bus,"skill_manager":manager,"skill_instance":attack,"skill_id":&"chaos_attack_chaotic","power":float(player.attack_power),"position":targets[0].global_position})
		bus.process_pending_events()
	for event: StringName in [&"dash_start",&"dash_end"]:
		bus.emit_skill_event(event,{"caster":player,"owner":player,"parent":parent,"event_bus":bus,"skill_manager":manager,"skill_instance":manager.get_skill(&"chaos_dash_rift_step"),"skill_id":&"chaos_dash_rift_step","power":float(player.attack_power)})
		bus.process_pending_events()
	for index: int in 25:
		targets[0].apply_status(&"instability", {"stacks":4,"duration":20.0,"source":player,"power":float(player.attack_power),"event_bus":bus,"skill_manager":manager})
		bus.process_pending_events()
		await settle(1)
		bus.process_pending_events()
	var sm: Node = player.get_node_or_null("SummonManager")
	check(sm != null, "actual casts create chaos summon manager")
	var view: Node = bus.get_node_or_null("ChaosCombatPresentation")
	check(view != null, "actual bus has chaos presentation")
	if sm == null or view == null:
		await finish()
		return
	for index: int in 16:
		var id: String = AREA_IDS[index%8]
		var damage := {"raw_amount":10,"amount":10,"damage_origin":"field","damage_type":"area_direct","element":"arcane","attacker":player,"source_skill_id":"chaos_cast_void_rift","source_origin_id":"chaos_cast_void_rift","source_id":id,"source_instance_id":"chaos_stress_%d" % index}
		check(DamagePacket.from_dictionary(damage).validate().is_empty(),"stress uses a registered strict actual damage packet")
		var area := Factory.create_area_effect({"parent":parent,"area_id":id,"source_id":id,"position":player.global_position+Vector2(-160+(index%4)*110,-100+(index/4)*100),"radius":100.0,"duration":20.0,"damage":10,"caster":player,"damage_packet":damage}) as AreaEffect
		check(area != null and area._visual_effect_node != null, "canonical area " + id)
		if area == null or area._visual_effect_node == null: continue
		area.set_physics_process(false)
		area._age = 0.5
		area._visual_effect_node.update_state(area.radius,0.5,20.0)
		fields.append(area)
		effects.append(area._visual_effect_node)
		area.apply_immediate_tick_once()
	for index: int in 128:
		var projectile := Factory.create_projectile({"parent":parent,"projectile_id":"chaos_orb","source_id":"chaos_orb","position":player.global_position+Vector2(-400+(index%16)*50,-170+(index/16)*48),"direction":Vector2.from_angle(float(index)*0.618),"speed":540.0,"lifetime":20.0,"chaos_geometry_branch":index%3}) as Projectile
		check(projectile != null and projectile._visual_effect_node != null, "actual orb stress factory")
		if projectile == null or projectile._visual_effect_node == null: continue
		projectile.set_physics_process(false)
		projectiles.append(projectile)
		effects.append(projectile._visual_effect_node)
	for index: int in 16:
		var id: StringName = &"chaos_clone" if index%2 == 0 else &"void_maw"
		var definition: Dictionary = GameData.get_summon(id).duplicate(true)
		definition["max_count"] = 8
		definition["duration"] = 20.0
		var active: Array = sm._active_by_id.get(id,[])
		var summon: Node2D = (active[0] as Node2D) if index < 2 and not active.is_empty() else sm.spawn_summon(definition,{"owner":player,"caster":player,"parent":parent,"event_bus":bus,"skill_manager":manager})
		check(summon != null and summon._summon_effect != null, "managed stress summon " + String(id))
		if summon == null or summon._summon_effect == null: continue
		summon.global_position = player.global_position+Vector2(-330+(index%8)*90,-100+(index/8)*190)
		summon.set_physics_process(false)
		summons.append(summon._summon_effect)
		effects.append(summon._summon_effect)
	await settle()
	var statuses: Array[Node2D] = []
	for target: Node2D in targets:
		var status: Node = target.get_node("StatusEffectManager")
		var effect: Node2D = status._status_visual_overlay.get_node_or_null("ProceduralStatus")
		check(effect != null,"actual instability stress target")
		if effect != null:
			effects.append(effect)
			statuses.append(effect)
	view._process(0.12)
	for key: Variant in view._auras: effects.append(view._auras[key])
	for item: Node2D in view._hits: effects.append(item)
	for item: Node2D in view._bursts: effects.append(item)
	for item: Node2D in view._links: effects.append(item)
	if failures:
		await finish()
		return
	var before := snapshot(bus)
	check(before.enemy_health.any(func(value: int) -> bool: return value < 100000),"stress applies actual enemy damage")
	var frames: Array[float] = []
	var updates: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start < 4000000:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous = now
		var age := 0.5+float(now-start)/1000000.0
		var update_start := Time.get_ticks_usec()
		for projectile: Projectile in projectiles: projectile._visual_effect_node.update_projectile(age)
		for area: AreaEffect in fields: area._visual_effect_node.update_state(area.radius,age,20.0)
		for effect: Node2D in summons: effect.update_summon(1.0/60.0,Vector2(1.2,0),10.0)
		for effect: Node2D in statuses: effect._process(1.0/60.0)
		view._process(1.0/60.0)
		if mode == "hidden":
			for effect: Node2D in effects: RenderingServer.canvas_item_set_visible(effect.get_canvas_item(),false)
		updates.append(float(Time.get_ticks_usec()-update_start)/1000.0)
	var after := snapshot(bus)
	check(same_values(after,before),"presentation updates preserve actual HP and chaos resources")
	var counterpart := output.get_base_dir().path_join("hidden" if mode == "shown" else "shown").path_join("metrics.json")
	var parity := "awaiting_other_mode"
	if FileAccess.file_exists(counterpart):
		var other: Variant = JSON.parse_string(FileAccess.get_file_as_string(counterpart))
		if other is Dictionary and other.get("workload") == "chaos_base_14_v1":
			var other_snapshot: Dictionary = other.get("combat_snapshot",{})
			var other_health: Array = other_snapshot.get("enemy_health",[])
			var current_health: Array = after.get("enemy_health",[])
			var equal := other_health.size() == current_health.size()
			if equal:
				for index: int in current_health.size():
					if int(other_health[index]) != int(current_health[index]): equal = false
				equal = equal and same_values(other_snapshot,after)
			check(equal,"shown and hidden modes have identical actual HP/resources")
			parity = "pass" if equal else "fail"
	var result := {"workload":"chaos_base_14_v1","mode":mode,"renderer":DisplayServer.get_name(),"resolution":root.size,"areas":fields.size(),"projectiles":projectiles.size(),"managed_summons":summons.size(),"instability_targets":targets.size(),"frames":frames.size(),"p50_ms":percentile(frames,0.5),"p95_ms":percentile(frames,0.95),"max_ms":frames[-1],"visual_update_p95_ms":percentile(updates,0.95),"combat_snapshot":after,"actual_hp_resource_parity":parity}
	DirAccess.make_dir_recursive_absolute(output)
	var report := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(result,"\t"))
	report.close()
	print("[chaos_stress] ",JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("chaos_stress_"+mode+".png")) == OK,"stress screenshot")
	await finish()
