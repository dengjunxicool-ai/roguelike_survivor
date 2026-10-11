## Fixed actual HP workload; visible/hidden presentations get identical state updates.
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const AREA_IDS := ["heavenly_wings_path", "divine_barrier_field", "judgment_hammer_area", "shield_guardian_counter_wave", "divine_punishment_strike", "counter_seal_wave", "absolution_light_burst"]
var effects: Array[Node2D] = []
var summons: Array[Node2D] = []
var targets: Array[Node2D] = []
var fields: Array[AreaEffect] = []
var projectiles: Array[Projectile] = []
var mode := "shown"
var output := "E:/codex/holy-vfx/stress/shown"

func percentile(samples: Array[float], portion: float) -> float:
	samples.sort()
	return samples[mini(int(samples.size()*portion), samples.size()-1)] if not samples.is_empty() else 0.0

func run() -> void:
	if "--parse-only" in OS.get_cmdline_user_args():
		print("HOLY_VFX_STRESS: PARSE PASS")
		quit(0)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
	if mode == "hidden" and output == "E:/codex/holy-vfx/stress/shown": output = "E:/codex/holy-vfx/stress/hidden"
	check(mode in ["shown", "hidden"], "mode is shown or hidden")
	check(output.begins_with("E:/codex/"), "stress reports remain on E drive")
	if failures:
		quit(1)
		return
	seed(17123)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	var count := 0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school", "")) == "holy" and definition.get("fusion_school") == null:
			check(Fixture.install_runtime_skill(manager, StringName(definition.id)), "learn " + String(definition.id))
			count += 1
	check(count == 14, "stress uses fourteen base holy skills only")
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	for i: int in 16:
		var enemy: Node2D = Enemy.instantiate()
		enemy.enemy_id = &"skeleton"
		parent.add_child(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.global_position = player.global_position + Vector2(-210+(i%4)*140, -150+(i/4)*100)
		enemy.max_health = 10000
		enemy.current_health = 10000
		enemy.armor = 0
		enemy.apply_status(&"judgment", {"stacks":3, "duration":20.0, "source":player})
		targets.append(enemy)
	# Use canonical skill casts to lazily create the real summon manager before scaling.
	await settle(2)
	for skill_id: StringName in [&"holy_summon_seraph", &"holy_summon_shield_guardian"]:
		bus.emit_skill_event(&"on_cast", {"caster":player, "owner":player, "skill_manager":manager, "skill_instance":manager.get_skill(skill_id), "target":targets[0], "skill_id":skill_id, "origin_skill_id":skill_id, "scheduled_cast":true, "parent":parent, "power":float(player.attack_power)})
		bus.process_pending_events()
	var sm: Node = player.get_node_or_null("SummonManager")
	check(sm != null, "canonical holy casts create actual summon manager")
	if sm == null:
		await finish()
		return
	for i: int in 14:
		var id: String = AREA_IDS[i%7]
		var area := Factory.create_area_effect({"parent":parent, "area_id":id, "source_id":id, "position":player.global_position+Vector2(-160+(i%4)*110, -100+(i/4)*100), "radius":100.0, "duration":20.0, "damage":10, "caster":player, "damage_packet":{"raw_amount":10, "amount":10, "damage_origin":"field", "damage_type":"area_direct", "element":"holy", "attacker":player, "source_skill_id":"holy_stress", "source_id":id, "source_instance_id":"holy_stress_%d" % i}}) as AreaEffect
		check(area != null and area._visual_effect_node != null, "canonical area " + id)
		if area == null or area._visual_effect_node == null: continue
		area.set_physics_process(false)
		area._age = 0.5
		area._visual_effect_node.update_state(area.radius, 0.5, 20.0)
		fields.append(area)
		effects.append(area._visual_effect_node)
		area.apply_immediate_tick_once()
	for i: int in 128:
		var id: String = "holy_ray_beam" if i%2 == 0 else "seraph_holy_bolt"
		var projectile := Factory.create_projectile({"parent":parent, "projectile_id":id, "source_id":id, "position":player.global_position+Vector2(-400+(i%16)*50, -170+(i/16)*48), "direction":Vector2.from_angle(float(i)*0.618), "speed":540.0, "lifetime":20.0}) as Projectile
		check(projectile != null and projectile._visual_effect_node != null, "canonical projectile " + id)
		if projectile == null or projectile._visual_effect_node == null: continue
		projectile.set_physics_process(false)
		projectiles.append(projectile)
		effects.append(projectile._visual_effect_node)
	for i: int in 16:
		var id: StringName = &"seraph" if i%2 == 0 else &"holy_shield_guardian"
		# Raise only the test fixture population limit; preserve canonical combat/visual data.
		var definition: Dictionary = GameData.get_summon(id).duplicate(true)
		definition["max_count"] = 8
		definition["duration"] = 20.0
		var active: Array = sm._active_by_id.get(id, [])
		var summon: Node2D = (active[0] as Node2D) if i < 2 and not active.is_empty() else sm.spawn_summon(definition, {"owner":player, "caster":player, "parent":parent, "event_bus":bus, "skill_manager":manager})
		check(summon != null and summon._summon_effect != null, "managed holy stress summon " + String(id))
		if summon == null or summon._summon_effect == null: continue
		summon.global_position = player.global_position + Vector2(-330+(i%8)*90, -100+(i/8)*190)
		summon.set_physics_process(false)
		summon._summon_effect.set_attack_target(Vector2(110, 0).rotated(float(i)*0.4))
		summons.append(summon._summon_effect)
		effects.append(summon._summon_effect)
	await settle()
	for target: Node2D in targets:
		var status: Node = target.get_node("StatusEffectManager")
		var effect: Node2D = status._status_visual_overlay.get_node_or_null("ProceduralStatus")
		check(effect != null, "actual judgment status in stress workload")
		if effect != null: effects.append(effect)
	var view: Node = bus.get_node_or_null("HolyCombatPresentation")
	check(view != null, "stress has actual holy combat presentation")
	if view != null:
		var executor := Executor.new()
		executor.execute_action({"type":"grant_shield", "params":{"amount":maxi(int(player.max_health)*2, 100), "duration":20.0, "shield_type":"holy_stress", "respect_shield_cap":true, "shield_cap_health_ratio":0.35}}, {"owner":player, "caster":player, "parent":parent, "event_bus":bus, "skill_manager":manager, "skill_instance":manager.get_skill(&"holy_passive_devotion"), "skill_id":&"holy_passive_devotion"})
		bus.process_pending_events()
		view._process(0.12)
		if view._shield != null: effects.append(view._shield)
		if view._devotion != null: effects.append(view._devotion)
	if failures:
		await finish()
		return
	var health_before: Array[int] = []
	for target: Node2D in targets: health_before.append(int(target.current_health))
	check(health_before.any(func(value: int) -> bool: return value < 10000), "stress workload applies actual enemy damage")
	var cpu: Array[float] = []
	for i: int in 360:
		if i%72 == 0:
			for effect: Node2D in summons: effect.play_attack()
		var started := Time.get_ticks_usec()
		for effect: Node2D in summons: effect.update_summon(1.0/60.0, Vector2(1.2, 0), 10.0)
		cpu.append(float(Time.get_ticks_usec()-started)/1000.0)
	if mode == "hidden":
		for effect: Node2D in effects: RenderingServer.canvas_item_set_visible(effect.get_canvas_item(), false)
	var frames: Array[float] = []
	var updates: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var frame_index := 0
	while Time.get_ticks_usec()-start < 4000000:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous = now
		var age := 0.5+float(now-start)/1000000.0
		var update_start := Time.get_ticks_usec()
		for projectile: Projectile in projectiles: projectile._visual_effect_node.update_projectile(age)
		for area: AreaEffect in fields: area._visual_effect_node.update_state(area.radius, age, 20.0)
		for effect: Node2D in summons:
			if frame_index%72 == 0: effect.play_attack()
			effect.update_summon(1.0/60.0, Vector2(1.2, 0), 10.0)
		for target: Node2D in targets:
			var status: Node = target.get_node("StatusEffectManager")
			status._status_visual_overlay.get_node("ProceduralStatus")._process(1.0/60.0)
		updates.append(float(Time.get_ticks_usec()-update_start)/1000.0)
		frame_index += 1
	var health: Array[int] = []
	for target: Node2D in targets: health.append(int(target.current_health))
	check(health == health_before, "presentation updates preserve actual HP")
	var counterpart := output.get_base_dir().path_join("hidden" if mode == "shown" else "shown").path_join("metrics.json")
	var parity := "awaiting_other_mode"
	if FileAccess.file_exists(counterpart):
		var other: Variant = JSON.parse_string(FileAccess.get_file_as_string(counterpart))
		if other is Dictionary and other.get("workload") == "holy_base_14_v1":
			var other_health: Array = other.get("enemy_health", [])
			var equal := other_health.size() == health.size()
			if equal:
				for index: int in health.size():
					if int(other_health[index]) != health[index]:
						equal = false
						break
			check(equal, "shown and hidden modes have identical actual enemy HP")
			parity = "pass" if equal else "fail"
	var result := {"workload":"holy_base_14_v1", "mode":mode, "renderer":DisplayServer.get_name(), "resolution":root.size, "areas":fields.size(), "projectiles":projectiles.size(), "managed_summons":summons.size(), "judgment_targets":targets.size(), "frames":frames.size(), "p50_ms":percentile(frames, 0.5), "p95_ms":percentile(frames, 0.95), "max_ms":frames[-1], "visual_update_p95_ms":percentile(updates, 0.95), "summon_cpu_p50_ms":percentile(cpu, 0.5), "summon_cpu_p95_ms":percentile(cpu, 0.95), "enemy_health":health, "actual_hp_parity":parity}
	DirAccess.make_dir_recursive_absolute(output)
	var report := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	report.close()
	print("[holy_stress] ", JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("holy_stress_"+mode+".png")) == OK, "stress screenshot")
	await finish()
