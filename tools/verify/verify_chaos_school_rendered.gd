## Serial GPU entry: canonical factories, actual casts/statuses and paused pixels.
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const AREA_IDS := ["chaos_rift", "void_rift_field", "chaos_weak_hit", "mutation_pulse_area", "instability_fission_burst", "chaos_exchange_line", "chaos_singularity_field", "chaos_singularity_burst"]
const AREA_DURATIONS := {"chaos_rift":4.0,"void_rift_field":4.0,"chaos_weak_hit":0.12,"mutation_pulse_area":0.24,"instability_fission_burst":0.22,"chaos_exchange_line":0.18,"chaos_singularity_field":2.0,"chaos_singularity_burst":0.28}
var output := "E:/codex/chaos-vfx/rendered"

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "screenshot " + label)

func enemy_at(offset: Vector2) -> Node2D:
	var target: Node2D = Enemy.instantiate()
	target.enemy_id = &"skeleton"
	player.get_parent().add_child(target)
	target.global_position = player.global_position + offset
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.max_health = 100000
	target.current_health = 100000
	target.armor = 0
	return target

func verify_pixels(node: CanvasItem, label: String) -> void:
	paused = true
	await settle(3)
	await RenderingServer.frame_post_draw
	var shown := root.get_texture().get_image()
	node.visible = false
	await settle(3)
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	var changed := 0
	for y: int in range(0, shown.get_height(), 3):
		for x: int in range(0, shown.get_width(), 3):
			var a := shown.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.025: changed += 1
	check(changed > 8, label + " contributes GPU pixels (%d)" % changed)
	node.visible = true
	paused = false

func cast(bus: Node, id: StringName, target: Node2D) -> void:
	var instance: RefCounted = manager.get_skill(id)
	instance.set_meta("trigger_cd_on_cast_global", 0.0)
	bus.emit_skill_event(&"on_cast", {"caster":player,"owner":player,"parent":player.get_parent(),"target":target,"event_bus":bus,"skill_manager":manager,"skill_instance":instance,"skill_id":id,"origin_skill_id":id,"scheduled_cast":true,"power":float(player.attack_power)})
	bus.process_pending_events()

func trigger_fission(target: Node2D, bus: Node) -> void:
	target.apply_status(&"instability", {"stacks":4,"duration":20.0,"source":player,"power":float(player.attack_power),"event_bus":bus,"skill_manager":manager})
	bus.process_pending_events()

func run() -> void:
	if "--parse-only" in OS.get_cmdline_user_args():
		print("CHAOS_SCHOOL_RENDERED: PARSE PASS")
		quit(0)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
	check(output.begins_with("E:/codex/"), "render outputs stay on E drive")
	check(DisplayServer.get_name() != "headless", "rendered verification requires GPU")
	if failures:
		quit(1)
		return
	await setup_run()
	var count := 0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school", "")) == "chaos" and definition.get("fusion_school") == null:
			check(Fixture.install_runtime_skill(manager, StringName(definition.id)), "learn " + String(definition.id))
			count += 1
	check(count == 14, "all fourteen base chaos skills installed")
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	var view: Node = bus.get_node_or_null("ChaosCombatPresentation")
	check(view != null, "chaos presentation attached to actual event bus")
	if view == null:
		await finish()
		return
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Show each true footprint at its canonical radius without changing combat geometry.
	for id: String in AREA_IDS:
		var tick_actions: Array = [{"type":"pull","params":{"pull_radius_r":6.0 if id == "chaos_singularity_field" else 2.5,"strength":0.32}}] if id in ["void_rift_field","chaos_singularity_field"] else []
		var area := Factory.create_area_effect({"parent":parent,"area_id":id,"source_id":id,"position":player.global_position+Vector2(0,-35),"duration":AREA_DURATIONS[id],"damage":0,"caster":player,"actions_on_tick":tick_actions}) as AreaEffect
		check(area != null and area._visual_effect_node != null, "canonical area " + id)
		if area == null or area._visual_effect_node == null: continue
		check(area.effect_shape == "circle", "base area actual circle " + id)
		area.set_physics_process(false)
		area._age = area.duration * 0.31
		area._visual_effect_node.update_state(area.radius, area._age, area.duration)
		await capture("chaos_area_" + id)
		await verify_pixels(area._visual_effect_node, id)
		area.prepare_for_pool_despawn()
	var maw_pulse := Factory.create_area_effect({"parent":parent,"area_id":"void_rift_field","source_id":"void_maw","position":player.global_position+Vector2(0,-35),"radius":168.0,"duration":0.35,"damage":0,"caster":player,"actions_on_tick":[]}) as AreaEffect
	check(maw_pulse != null and maw_pulse._visual_effect_node != null,"actual maw pulse host uses its circular damage footprint")
	if maw_pulse != null and maw_pulse._visual_effect_node != null:
		maw_pulse.set_physics_process(false)
		maw_pulse._age = 0.11
		maw_pulse._visual_effect_node.update_state(maw_pulse.radius,maw_pulse._age,maw_pulse.duration)
		check(not bool(maw_pulse._visual_effect_node.get_node("ChaosSurface").material.get_shader_parameter("has_pull")),"maw pulse cannot show inward suction")
		await capture("chaos_actual_maw_outward_pulse")
		await verify_pixels(maw_pulse._visual_effect_node,"maw outward pulse")
		maw_pulse.prepare_for_pool_despawn()
	var targets: Array[Node2D] = []
	for index: int in 3:
		var target := enemy_at(Vector2(-160+index*160,-50))
		target.apply_status(&"instability", {"stacks":index+1,"duration":20.0,"source":player,"power":float(player.attack_power)})
		targets.append(target)
	await settle()
	for target: Node2D in targets:
		var status: Node = target.get_node("StatusEffectManager")
		var mantle: Node2D = status._status_visual_overlay.get_node_or_null("ProceduralStatus")
		check(mantle != null, "actual instability creates procedural status")
		if mantle != null:
			check(mantle.status_stacks == target.get_status_stack(&"instability") and mantle.profile == 0, "instability shader follows exact actual stacks")
			mantle._process(0.12)
			await verify_pixels(mantle, "actual instability %d" % target.get_status_stack(&"instability"))
	await capture("chaos_instability_stack_comparison")
	for branch: int in 3:
		var projectile := Factory.create_projectile({"parent":parent,"projectile_id":"chaos_orb","source_id":"chaos_orb","position":player.global_position+Vector2(-210+branch*210,90),"direction":Vector2(0.8,-0.6),"speed":520.0,"lifetime":3.0,"chaos_geometry_branch":branch}) as Projectile
		check(projectile != null and projectile._visual_effect_node != null, "canonical chaos orb branch %d" % branch)
		if projectile == null or projectile._visual_effect_node == null: continue
		projectile.set_physics_process(false)
		projectile._visual_effect_node.update_projectile(0.25)
		await verify_pixels(projectile._visual_effect_node, "orb branch %d" % branch)
	await capture("chaos_actual_orb_geometry_branches")
	for id: StringName in [&"chaos_summon_chaos_clone",&"chaos_summon_void_maw"]: cast(bus, id, targets[0])
	var sm: Node = player.get_node_or_null("SummonManager")
	check(sm != null, "actual chaos casts create summon manager")
	if sm != null:
		for index: int in 2:
			var id: StringName = &"chaos_clone" if index == 0 else &"void_maw"
			var active: Array = sm._active_by_id.get(id, [])
			check(not active.is_empty(), "actual managed summon " + String(id))
			if active.is_empty(): continue
			var summon: Node2D = active[0]
			summon.global_position = player.global_position+Vector2(-210+index*420,115)
			summon.set_physics_process(false)
			check(summon._summon_effect != null, "custom chaos summon effect")
			if summon._summon_effect != null:
				summon._summon_effect.update_summon(0.22, Vector2(60,0), 10.0)
				await verify_pixels(summon._summon_effect, String(id))
	await capture("chaos_actual_clone_and_maw")
	# Successful real casts establish stability/echo; actual fissions grant positive sources.
	for index: int in 5: cast(bus, &"chaos_cast_void_rift", targets[0])
	# The 26th actual fission preserves a live progress aura after the 25th opens a field.
	for index: int in 26:
		trigger_fission(targets[0], bus)
		await settle(1)
		bus.process_pending_events()
	view._process(0.12)
	var actual: Dictionary = bus.chaos_state()
	check(bool(actual.get("stability_ready",false)), "five successful real casts charge stability")
	check(int(actual.get("pending",0)) > 0, "twenty-five actual fissions create pending singularity")
	check(not actual.get("entropy",[]).is_empty(), "actual fissions grant entropy sources")
	var visible_auras := 0
	for key: Variant in view._auras:
		if view._auras[key].visible: visible_auras += 1
	check(view._auras.size() <= 7 and visible_auras <= 5, "bounded chaos aura allocation and live sources")
	await capture("chaos_actual_entropy_stability_echo_singularity")
	for key: Variant in view._auras:
		var aura: Node2D = view._auras[key]
		if aura.visible: await verify_pixels(aura, "actual aura " + String(key))
	# Swap endpoints and clone replay gestures must come from confirmed actual actions.
	cast(bus, &"chaos_power_chaos_exchange", targets[1])
	view._process(0.04)
	await capture("chaos_confirmed_exchange")
	check(view._links.any(func(item: Node2D) -> bool: return item.visible), "successful actual exchange emits tearing thread")
	paused = true
	await settle(3)
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	await create_timer(0.2, true).timeout
	await RenderingServer.frame_post_draw
	check(before.get_data() == root.get_texture().get_image().get_data(), "chaos pixels freeze exactly during engine pause")
	await finish()
