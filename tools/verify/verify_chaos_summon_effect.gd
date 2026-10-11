extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func count_nodes(node: Node) -> int:
	var count: int = node.get_child_count()
	for child: Node in node.get_children(): count += count_nodes(child)
	return count
func run() -> void:
	if "--render-summons" in OS.get_cmdline_user_args():
		await render_summons()
		return
	var effects: Array[Node2D] = []
	for id: String in ["chaos_clone", "void_maw"]:
		var path: String = "res://scenes/effects/%s_effect.tscn" % id
		check(ResourceLoader.exists(path), id + " custom scene exists")
		if not ResourceLoader.exists(path): continue
		seed(4201)
		var expected_rng: int = randi()
		seed(4201)
		var effect: Node2D = load(path).instantiate()
		root.add_child(effect)
		effects.append(effect)
		effect.configure_summon({"scale": 0.15})
		check(effect.scale == Vector2.ONE, id + " ignores legacy icon scale")
		var count: int = count_nodes(effect)
		check(count >= 30, id + " readable fixed multi-part silhouette")
		check(effect.get_node("Geometry").material is ShaderMaterial, id + " private procedural material")
		effect.face_direction(Vector2.LEFT)
		effect.update_summon(0.1, Vector2(-180,0), 4.0)
		if id == "chaos_clone":
			check(effect.get_node("Geometry").scale.x < 0, "clone follows actual facing")
			check(effect.get_node_or_null("Geometry/Body/Head") != null and effect.get_node_or_null("Geometry/Body/CastingArm") != null, "clone has articulated humanoid head and arm")
		else:
			check(effect.position == Vector2.ZERO and effect.get_node("Geometry").position == Vector2.ZERO, "maw presentation remains stationary")
			check(effect.get_node("Geometry/Teeth").get_child_count() >= 16, "maw has distinct tooth ring")
		effect.set_attack_target(Vector2(80,-20))
		effect.play_attack()
		effect.update_summon(0.10, Vector2.ZERO, 4.0)
		check(effect._attack_remaining > 0 and effect.get_node("Geometry/ConfirmedPulse").visible, id + " confirmed attack produces gesture")
		for i: int in 200: effect.update_summon(0.01, Vector2.ZERO, 4.0)
		check(count_nodes(effect) == count, id + " does not build per frame")
		check(not effect.get_node("Geometry/ConfirmedPulse").visible, id + " gesture expires with host delta")
		check(randi() == expected_rng, id + " does not consume gameplay RNG")
		var age: float = effect._age
		paused = true
		await process_frame
		await process_frame
		check(is_equal_approx(effect._age,age), id + " host pause freezes visual age")
		paused = false
		effect.update_summon(0.1, Vector2.ZERO, 0.0)
		check(effect.modulate.a == 0.0, id + " host lifetime fades to zero")
		effect.configure_summon({"effect_scale": 1.2})
		check(effect._age == 0.0 and effect._attack_remaining == 0.0 and effect.modulate.a == 1.0 and count_nodes(effect) == count, id + " reuse resets clock gesture and fade without rebuilding")
		effect.deactivate()
		check(not effect.visible and not effect.get_node("Geometry/ConfirmedPulse").visible, id + " deactivate hides all confirmed gesture")
	if effects.size() == 2: check(effects[0].get_node("Geometry").material != effects[1].get_node("Geometry").material, "summons do not share mutable material")
	for effect: Node2D in effects: effect.free()
	print("[chaos_summon_effect] failures=", failures)
	quit(1 if failures else 0)
func render_summons() -> void:
	check(DisplayServer.get_name() != "headless", "summon profile sheet uses actual GPU")
	root.size = Vector2i(960,640)
	DisplayServer.window_set_size(root.size)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.045,0.052,0.073)
	background.size = Vector2(root.size)
	root.add_child(background)
	var effects: Array[Node2D] = []
	for i: int in 4:
		var id: String = "chaos_clone" if i%2 == 0 else "void_maw"
		var effect: Node2D = load("res://scenes/effects/%s_effect.tscn" % id).instantiate()
		root.add_child(effect)
		effect.configure_summon({"effect_scale": 2.3})
		effect.position = Vector2(235 if i%2 == 0 else 710,205 if i<2 else 485)
		effect.update_summon(0.4,Vector2(150,0) if i<2 else Vector2.ZERO,5.0)
		if i >= 2:
			effect.set_attack_target(Vector2(70,-20))
			effect.play_attack()
			effect.update_summon(0.13,Vector2.ZERO,5.0)
		effects.append(effect)
		var label: Label = Label.new()
		label.text = id.to_upper().replace("_"," ") + ("  IDLE" if i<2 else "  CONFIRMED CAST")
		label.position = effect.position + Vector2(-125,85)
		root.add_child(label)
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	for effect: Node2D in effects:
		effect.visible = false
		for frame: int in 2: await process_frame
		await RenderingServer.frame_post_draw
		var hidden: Image = root.get_texture().get_image()
		var changed: int = 0
		for y: int in range(0,shown.get_height(),2):
			for x: int in range(0,shown.get_width(),2):
				var a: Color = shown.get_pixel(x,y)
				var b: Color = hidden.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.035: changed += 1
		check(changed > 150, "visible GPU summon silhouette " + effect.visual_profile + " (%d pixels)" % changed)
		effect.visible = true
		for frame: int in 2: await process_frame
		await RenderingServer.frame_post_draw
	paused = true
	await RenderingServer.frame_post_draw
	var frozen: Image = root.get_texture().get_image()
	await create_timer(0.1,true).timeout
	await RenderingServer.frame_post_draw
	check(frozen.get_data() == root.get_texture().get_image().get_data(), "rendered summon pixels freeze during pause")
	var output: String = "E:/codex/chaos-summons/rendered"
	DirAccess.make_dir_recursive_absolute(output)
	check(frozen.save_png(output.path_join("chaos_summon_profiles.png")) == OK, "save chaos summon profile sheet")
	print("[chaos_summon_rendered] failures=",failures)
	quit(1 if failures else 0)
