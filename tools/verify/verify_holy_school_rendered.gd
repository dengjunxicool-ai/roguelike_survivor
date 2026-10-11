## Real canonical factories, skill runtime and status/shield state. GPU entry only.
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Packet = preload("res://scripts/combat/damage_packet.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const AREA_IDS := ["heavenly_wings_path", "divine_barrier_field", "judgment_hammer_area", "shield_guardian_counter_wave", "divine_punishment_strike", "counter_seal_wave", "absolution_light_burst"]
var owned: Array[Node2D] = []
var output := "E:/codex/holy-vfx/rendered"

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "screenshot " + label)

func enemy_at(offset: Vector2, hp: int = 10000) -> Node2D:
	var target: Node2D = Enemy.instantiate()
	target.enemy_id = &"skeleton"
	player.get_parent().add_child(target)
	target.global_position = player.global_position + offset
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.max_health = 10000
	target.current_health = hp
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
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.025:
				changed += 1
	check(changed > 12, label + " contributes GPU pixels (%d)" % changed)
	node.visible = true
	paused = false

func cast(bus: Node, id: StringName, target: Node2D) -> void:
	bus.emit_skill_event(&"on_cast", {"caster":player, "owner":player, "parent":player.get_parent(), "target":target, "event_bus":bus, "skill_manager":manager, "skill_instance":manager.get_skill(id), "skill_id":id, "origin_skill_id":id, "power":float(player.attack_power)})

func context(bus: Node, id: StringName) -> Dictionary:
	return {"caster":player, "owner":player, "parent":player.get_parent(), "event_bus":bus, "skill_manager":manager, "skill_instance":manager.get_skill(id), "skill_id":id, "origin_skill_id":id, "power":float(player.attack_power)}

func enemy_probe(label: String) -> DamagePacket:
	var packet := Packet.from_dictionary({"raw_amount":1, "amount":1, "damage_origin":"special", "damage_type":"direct_physical", "element":"physical", "source_type":"enemy", "source_origin_id":"skeleton", "source_skill_id":label, "source_instance_id":label})
	check(packet.validate().is_empty(), "registered strict enemy packet " + label)
	return packet

func run() -> void:
	if "--parse-only" in OS.get_cmdline_user_args():
		print("HOLY_SCHOOL_RENDERED: PARSE PASS")
		quit(0)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
	check(output.begins_with("E:/codex/"), "render outputs stay on E drive")
	check(DisplayServer.get_name() != "headless", "rendered verification requires GPU")
	if failures:
		quit(1)
		return
	await setup_run()
	var count := 0
	for definition: Dictionary in GameData.get_all_skill_pool():
		if String(definition.get("school", "")) == "holy" and definition.get("fusion_school") == null:
			check(Fixture.install_runtime_skill(manager, StringName(definition.id)), "learn " + String(definition.id))
			count += 1
	check(count == 14, "all fourteen base holy skills installed")
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	var view: Node = bus.get_node_or_null("HolyCombatPresentation")
	check(view != null, "holy presentation attached to real event bus")
	if view == null:
		await finish()
		return
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Factory definitions own all base shapes/radii. Freeze host ages for clear screenshots.
	for start: int in [0, 3, 6]:
		for i: int in range(start, mini(start + 3, AREA_IDS.size())):
			var area := Factory.create_area_effect({"parent":parent, "area_id":AREA_IDS[i], "source_id":AREA_IDS[i], "position":player.global_position + Vector2(-230 + (i-start)%2*460, -100 + (i-start)/2*180), "duration":5.0 if i == 1 else 0.24, "damage":0, "caster":player}) as AreaEffect
			check(area != null and area._visual_effect_node != null, "canonical area " + AREA_IDS[i])
			if area == null or area._visual_effect_node == null: continue
			check(area.effect_shape == "circle", "base area uses actual circle " + AREA_IDS[i])
			area.set_physics_process(false)
			area._age = 0.65 if i == 1 else 0.07
			area._visual_effect_node.update_state(area.radius, area._age, area.duration)
			owned.append(area)
		await capture("holy_fields_%d" % start)
		for area: Node2D in owned: await verify_pixels(area._visual_effect_node, String(area.source_id))
		for area: Node2D in owned: area.prepare_for_pool_despawn()
		owned.clear()
	var targets: Array[Node2D] = []
	for i: int in 2:
		var target := enemy_at(Vector2(-140 + i*280, -25))
		target.apply_status(&"judgment", {"stacks":1 + i*2, "duration":8.0, "source":player, "power":float(player.attack_power)})
		targets.append(target)
	await settle()
	for target: Node2D in targets:
		var status: Node = target.get_node("StatusEffectManager")
		var mantle: Node2D = status._status_visual_overlay.get_node_or_null("ProceduralStatus")
		check(mantle != null, "actual judgment creates procedural status")
		if mantle != null:
			check(mantle.status_stacks == target.get_status_stack(&"judgment") and mantle.profile == 0, "judgment shader uses actual stack count and profile")
			mantle.process_mode = Node.PROCESS_MODE_PAUSABLE
			mantle._process(0.12)
			await verify_pixels(mantle, "%d real judgment stacks" % target.get_status_stack(&"judgment"))
	await capture("holy_judgment_stack_comparison")
	cast(bus, &"holy_summon_seraph", targets[0])
	cast(bus, &"holy_summon_shield_guardian", targets[0])
	bus.process_pending_events()
	var sm: Node = player.get_node("SummonManager")
	for i: int in 2:
		var id: StringName = &"seraph" if i == 0 else &"holy_shield_guardian"
		var active: Array = sm._active_by_id.get(id, [])
		check(not active.is_empty(), "actual managed summon " + String(id))
		if active.is_empty(): continue
		var summon: Node2D = active[0]
		summon.global_position = player.global_position + Vector2(-200 + i*400, 95)
		summon.set_physics_process(false)
		check(summon._summon_effect != null, "summon uses custom holy effect " + String(id))
		if summon._summon_effect != null:
			summon._summon_effect.update_summon(0.22, Vector2(80, 0), 10.0)
			await verify_pixels(summon._summon_effect, String(id))
		owned.append(summon)
	await capture("holy_actual_summons_and_judgment")
	var guardian: Node2D = null
	for summon: Node2D in owned:
		if String(summon.definition.id) == "holy_shield_guardian": guardian = summon
	var player_hp_before: int = player.current_health
	player.take_damage(enemy_probe("holy_render_guard"))
	bus.process_pending_events()
	if guardian != null and guardian._summon_effect != null:
		check(player.current_health == player_hp_before and guardian._summon_effect._guard_remaining > 0.0, "actual guardian absorbs damage and receives confirmed guard pose")
		guardian._summon_effect.update_summon(0.08, Vector2.ZERO, 10.0)
		await capture("holy_confirmed_guard")
		await verify_pixels(guardian._summon_effect.get_node("Geometry/Body/Shield/GuardLight"), "actual guardian shield absorption")
	var executor := Executor.new()
	var shield_context := context(bus, &"holy_passive_devotion")
	executor.execute_action({"type":"grant_shield", "params":{"amount":maxi(int(player.max_health)*2, 100), "duration":8.0, "shield_type":"holy_rendered", "respect_shield_cap":true, "shield_cap_health_ratio":0.35}}, shield_context)
	bus.process_pending_events()
	view._process(0.12)
	check(int(player.get_meta("fire_passive_shield", 0)) > 0, "real shield action writes actual shield points")
	check(view._shield != null and view._shield.visible, "actual shield points show aegis")
	check(view._devotion != null and view._devotion.visible, "real shield overflow grants devotion modifier and aura")
	await capture("holy_actual_shield_and_devotion")
	if view._shield != null: await verify_pixels(view._shield, "actual shield aegis")
	if view._devotion != null: await verify_pixels(view._devotion, "actual devotion buff")
	var shield_before := int(player.get_meta("fire_passive_shield", 0))
	player_hp_before = player.current_health
	player.take_damage(enemy_probe("holy_render_shield_absorb"))
	check(player.current_health == player_hp_before and int(player.get_meta("fire_passive_shield", 0)) < shield_before, "actual shield consumes points and preserves health")
	var absorb: Node2D = null
	for burst: Node2D in view._bursts:
		if burst.visible and int(burst._material.get_shader_parameter("profile")) == 3:
			absorb = burst
	check(absorb != null, "actual shield absorption creates confirmed aegis flash")
	if absorb != null:
		absorb._process(0.06)
		absorb.set_process(false)
		await capture("holy_confirmed_shield_absorption")
		await verify_pixels(absorb, "actual shield absorption flash")
	var hp_before: int = targets[0].current_health
	targets[0].take_damage(Packet.from_dictionary({"raw_amount":20, "amount":20, "damage_origin":"primary_attack", "damage_type":"direct_magical", "element":"holy", "attacker":player, "source_skill_id":"holy_attack_judgment", "source_origin_id":"holy_attack_judgment", "source_instance_id":"holy_render_hit"}))
	bus.process_pending_events()
	check(targets[0].current_health < hp_before, "confirmed holy hit damages actual enemy")
	check(view._hits.any(func(item: Node2D) -> bool: return item.visible), "confirmed hit creates holy feedback")
	for hit: Node2D in view._hits:
		if hit.visible:
			hit._process(0.06)
			hit.set_process(false)
	await capture("holy_confirmed_hit")
	for hit: Node2D in view._hits:
		if hit.visible: await verify_pixels(hit, "confirmed holy damage spark")
	# A fresh real recipient isolates the falling column from judgment max-stack procs.
	var ray_target := enemy_at(Vector2(190, -65))
	var ray_hp_before: int = ray_target.current_health
	var ray_packet := Packet.from_dictionary({"raw_amount":20, "amount":20, "damage_origin":"primary_attack", "damage_type":"projectile_heavy", "element":"holy", "attacker":player, "source_skill_id":"holy_cast_holy_ray", "source_origin_id":"holy_cast_holy_ray", "source_instance_id":"holy_render_confirmed_ray"})
	check(ray_packet.validate().is_empty(), "holy ray probe uses strict registered projectile hit packet")
	ray_target.take_damage(ray_packet)
	bus.process_pending_events()
	check(ray_target.current_health < ray_hp_before and ray_target.get_status_stack(&"judgment") < 5, "actual ray hit damages fresh enemy without max judgment proc")
	var column: Node2D = null
	for hit: Node2D in view._hits:
		if hit.visible and int(hit._material.get_shader_parameter("profile")) == 1:
			column = hit
	check(column != null, "confirmed holy ray creates profile-one falling column")
	if column != null:
		column._process(0.08)
		column.set_process(false)
		await capture("holy_actual_ray_confirmed_column")
		await verify_pixels(column, "actual holy ray confirmed descending column")
	# The fifth real stack drives divine punishment and core weakening through runtime.
	hp_before = targets[1].current_health
	targets[1].apply_status(&"judgment", {"stacks":2, "duration":8.0, "source":player, "power":float(player.attack_power), "event_bus":bus, "skill_manager":manager})
	bus.process_pending_events()
	view._process(0.07)
	check(targets[1].current_health < hp_before, "actual judgment max-stack proc causes holy damage")
	var visible_bursts: Array[Node2D] = []
	for burst: Node2D in view._bursts:
		if burst.visible:
			burst._process(0.06)
			burst.set_process(false)
			if burst.visible: visible_bursts.append(burst)
	await capture("holy_actual_divine_punishment")
	# Overlapping identical wards can fully occlude one another; inspect each contribution.
	for burst: Node2D in visible_bursts: burst.visible = false
	for burst: Node2D in visible_bursts:
		burst.visible = true
		await verify_pixels(burst, "confirmed holy burst")
		burst.visible = false
	for burst: Node2D in visible_bursts: burst.visible = true
	for i: int in 2:
		var id: String = ["holy_ray_beam", "seraph_holy_bolt"][i]
		var projectile := Factory.create_projectile({"parent":parent, "projectile_id":id, "source_id":id, "position":player.global_position + Vector2(-220 + i*440, -120), "direction":Vector2(0.8, -0.6), "speed":520.0, "lifetime":3.0}) as Projectile
		check(projectile != null and projectile._visual_effect_node != null, "canonical projectile " + id)
		if projectile == null or projectile._visual_effect_node == null: continue
		projectile.set_physics_process(false)
		projectile._visual_effect_node.update_projectile(0.25)
		owned.append(projectile)
		await verify_pixels(projectile._visual_effect_node, id)
	await capture("holy_projectiles")
	paused = true
	await settle(3)
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	await create_timer(0.2, true).timeout
	await RenderingServer.frame_post_draw
	check(before.get_data() == root.get_texture().get_image().get_data(), "holy pixels freeze exactly during engine pause")
	await finish()
