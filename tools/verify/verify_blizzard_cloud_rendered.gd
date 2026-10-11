## 真实 Mobile/Vulkan 渲染验收：生产施放、暂停、到期、八云团压力；报告仅写 E:/codex。
extends "res://tools/verify/qa_app_fixture.gd"

const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var report_dir := "E:/codex/blizzard-vfx/rendered"

func measure(seconds: float) -> Dictionary:
	var frames: Array[float] = []
	var end: int = Time.get_ticks_usec() + int(seconds * 1000000)
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() < end:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
	frames.sort()
	return {"frames": frames.size(), "p50_ms": frames[int(frames.size() * 0.5)], "p95_ms": frames[mini(int(frames.size() * 0.95), frames.size() - 1)]}

func check_layer_pixels(layer: CanvasItem, label: String) -> void:
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	layer.visible = false
	await settle(3)
	await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	var changed := 0
	for y: int in range(0, shown.get_height(), 3):
		for x: int in range(0, shown.get_width(), 3):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.025:
				changed += 1
	check(changed > 100, "%s changes actual rendered pixels (%d sampled pixels)" % [label, changed])
	layer.visible = true
	await settle(3)

func run() -> void:
	check(DisplayServer.get_name() != "headless", "requires actual GPU renderer")
	if failures > 0:
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			report_dir = argument.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
	check(report_dir.begins_with("E:/codex/"), "reports stay on E drive")
	if failures > 0:
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	check(manager.add_skill(&"frost_attack_frostbite", "normal"), "learn frost school")
	check(manager.add_skill(&"frost_cast_blizzard_cloud", "normal"), "learn blizzard skill")
	var parent: Node = player.get_parent()
	var center: Vector2 = player.global_position + Vector2(145, -25)
	var enemies: Array[Node2D] = []
	for index: int in range(6):
		var enemy: Node2D = EnemyScene.instantiate()
		enemy.enemy_id = &"skeleton"
		parent.add_child(enemy)
		enemy.global_position = center + Vector2.from_angle(float(index) * TAU / 6.0) * 62.0
		enemy.current_health = 10000
		enemy.max_health = 10000
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(enemy)
	await settle(3)
	var baseline := await measure(1.0)
	var skill: RefCounted = manager.get_skill(&"frost_cast_blizzard_cloud")
	player.get_node("SkillEventBus").emit_skill_event(&"on_cast", {"caster": player, "owner": player, "skill_manager": manager, "skill_instance": skill, "target": enemies[0], "skill_id": &"frost_cast_blizzard_cloud", "origin_skill_id": &"frost_cast_blizzard_cloud", "scheduled_cast": true, "power": float(player.attack_power)})
	var area: AreaEffect
	for node: Node in get_nodes_in_group(&"area_effects"):
		if node is AreaEffect and node.source_id == &"blizzard_cloud":
			area = node
	check(area != null and area.get_node_or_null("AreaVisualEffect") != null, "actual skill cast mounts new VFX")
	if area == null:
		await finish()
		return
	area.process_mode = Node.PROCESS_MODE_PAUSABLE
	await create_timer(0.12).timeout
	await capture("blizzard_intro")
	await create_timer(1.0).timeout
	await capture("blizzard_active")
	var hp_before: int = enemies[0].current_health
	area._damage_body(enemies[0])
	check(enemies[0].current_health < hp_before, "new VFX preserves actual tick damage")
	check(enemies[0].get_node("StatusEffectManager").get_status_stack(&"chilled") > 0, "new VFX preserves Chilled")
	paused = true
	await settle(5)
	var age: float = area._age
	var effect_age: float = area.get_node("AreaVisualEffect").effect_age
	await RenderingServer.frame_post_draw
	var paused_before: Image = root.get_texture().get_image()
	await create_timer(0.25, true).timeout
	check(is_equal_approx(area._age, age) and is_equal_approx(area.get_node("AreaVisualEffect").effect_age, effect_age), "pause freezes area and cloud shader clock")
	await RenderingServer.frame_post_draw
	var paused_after: Image = root.get_texture().get_image()
	var screen_center: Vector2 = area.get_global_transform_with_canvas().origin
	var changed := 0
	for y: int in range(maxi(int(screen_center.y - area.radius), 0), mini(int(screen_center.y + area.radius), root.size.y), 2):
		for x: int in range(maxi(int(screen_center.x - area.radius), 0), mini(int(screen_center.x + area.radius), root.size.x), 2):
			if paused_before.get_pixel(x, y) != paused_after.get_pixel(x, y):
				changed += 1
	check(changed == 0, "pause freezes GPU particles and shader pixels (%d changed)" % changed)
	await check_layer_pixels(area.get_node("AreaVisualEffect/CloudCanopy"), "cloud canopy")
	await check_layer_pixels(area.get_node("AreaVisualEffect/GroundFrost"), "ground frost")
	await capture("blizzard_paused")
	paused = false
	await create_timer(maxf(area.duration - area._age - 0.20, 0.05)).timeout
	await capture("blizzard_fade")
	await create_timer(0.4).timeout
	check(not area.visible and not area.get_node("AreaVisualEffect").visible, "expiry recycles VFX without residue")
	var areas: Array[AreaEffect] = []
	for index: int in range(8):
		var cloud: AreaEffect = Factory.create_area_effect({"parent": parent, "area_id": "blizzard_cloud", "source_id": "blizzard_cloud", "position": player.global_position + Vector2((index % 4 - 1.5) * 180.0, (index / 4 - 0.5) * 220.0), "radius": 168.0, "duration": 12.0}) as AreaEffect
		cloud.process_mode = Node.PROCESS_MODE_PAUSABLE
		areas.append(cloud)
	await create_timer(1.0).timeout
	await capture("blizzard_eight_clouds")
	var pressure := await measure(3.0)
	for cloud: AreaEffect in areas:
		cloud.despawn_or_free()
	await settle(5)
	var pool: Node = root.get_node("RuntimePoolRegistry/RuntimeObjectPool")
	var stats: Dictionary = pool.get_stats()
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "resolution": str(root.size), "baseline": baseline, "eight_clouds": pressure, "gpu_particle_budget": 1536, "pool_stats": stats, "failures": failures}
	DirAccess.make_dir_recursive_absolute(report_dir)
	var output := FileAccess.open(report_dir.path_join("rendered_metrics.json"), FileAccess.WRITE)
	check(output != null, "metrics report writable")
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("RENDERED_METRICS ", JSON.stringify(report))
	await finish()
