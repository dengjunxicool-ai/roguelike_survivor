extends SceneTree

var failures: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	if "--render-summons" in OS.get_cmdline_user_args():
		await render_summons()
		return
	var instances: Array[Node2D] = []
	for id: String in ["seraph","holy_shield_guardian"]:
		var path: String = "res://scenes/effects/%s_effect.tscn" % id
		check(ResourceLoader.exists(path),id + " custom scene exists")
		if not ResourceLoader.exists(path): continue
		var effect: Node2D = load(path).instantiate()
		root.add_child(effect)
		instances.append(effect)
		effect.configure_summon({"scale":0.15})
		check(effect.scale == Vector2.ONE,id + " ignores legacy icon scale")
		var count: int = descendants(effect)
		check(effect.get_node("Geometry").material is ShaderMaterial,id + " has private white gold material")
		effect.face_direction(Vector2.LEFT)
		effect.update_summon(0.1,Vector2(-180,0),5.0)
		check(effect.get_node("Geometry").scale.x < 0,id + " faces actual motion")
		effect.set_attack_target(Vector2(50,-20))
		effect.play_attack()
		effect.update_summon(0.12,Vector2.ZERO,5.0)
		check(effect._attack_remaining > 0 and effect.get_node("Geometry").position.x > 0,id + " target directed confirmed launch pose")
		check(effect.get_node("Geometry/Body/LaunchLight").visible,id + " launch light during confirmed attack")
		for i: int in 200: effect.update_summon(0.01,Vector2.ZERO,5.0)
		check(descendants(effect) == count,id + " fixed geometry across updates")
		check(not effect.get_node("Geometry/Body/LaunchLight").visible,id + " launch light ends after delta duration")
		var age: float = effect._age
		paused = true
		await process_frame
		await process_frame
		check(is_equal_approx(effect._age,age),id + " animation has no autonomous clock")
		paused = false
		effect.update_summon(0.1,Vector2.ZERO,0.0)
		check(effect.modulate.a == 0,id + " authoritative lifetime fades to zero")
		effect.configure_summon({})
		check(effect._attack_remaining == 0 and effect.modulate.a == 1,id + " reuse resets attack and fade")
		if id == "seraph": check(effect._wings.size() == 6 and effect._feathers.size() >= 8,"seraph has six articulated wings and floating feather motes")
		else:
			check(effect._legs.size() == 2 and effect.get_node_or_null("Geometry/Body/Shield/RunicBorder") != null,"guardian has jointed legs and distinct runic shield")
			check(effect.has_method("play_guard"),"guardian has independent confirmed guard notification")
			if effect.has_method("play_guard"):
				effect.play_attack()
				check(effect._guard_remaining == 0,"attack launch cannot fabricate guard flash")
				effect.play_guard()
				effect.update_summon(0.1,Vector2.ZERO,5.0)
				check(effect._guard_remaining > 0 and effect.get_node("Geometry/Body/Shield/GuardLight").visible,"confirmed guard produces shield-only flash")
				effect.update_summon(0.5,Vector2.ZERO,5.0)
				check(effect._guard_remaining == 0 and not effect.get_node("Geometry/Body/Shield/GuardLight").visible,"guard flash expires through managed delta")
		effect.deactivate()
		check(not effect.visible,id + " deactivation hides presentation")
	if instances.size() == 2: check(instances[0].get_node("Geometry").material != instances[1].get_node("Geometry").material,"instances never share mutable material")
	for effect: Node2D in instances: effect.free()
	print("[holy_summon_effect] failures=",failures)
	quit(1 if failures else 0)
func descendants(node: Node) -> int:
	var count: int = node.get_child_count()
	for child: Node in node.get_children(): count += descendants(child)
	return count
func render_summons() -> void:
	check(DisplayServer.get_name() != "headless","profile sheet uses actual GPU")
	root.size = Vector2i(960,640)
	DisplayServer.window_set_size(root.size)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.055,0.065,0.095)
	background.size = Vector2(root.size)
	root.add_child(background)
	var effects: Array[Node2D] = []
	for i: int in 4:
		var id: String = "seraph" if i%2 == 0 else "holy_shield_guardian"
		var effect: Node2D = load("res://scenes/effects/%s_effect.tscn" % id).instantiate()
		root.add_child(effect)
		effect.configure_summon({"effect_scale":2.2})
		effect.position = Vector2(235 if i%2 == 0 else 710,195 if i<2 else 495)
		effect.update_summon(0.4,Vector2(150,0) if i<2 else Vector2.ZERO,5.0)
		if i >= 2:
			effect.set_attack_target(Vector2(70,-20))
			effect.play_attack()
			effect.update_summon(0.12,Vector2.ZERO,5.0)
		effects.append(effect)
		var label: Label = Label.new()
		label.text = ("SIX-WING SERAPH" if i%2 == 0 else "HOLY SHIELD GUARDIAN") + ("  FOLLOW" if i<2 else "  ATTACK LAUNCH")
		label.position = effect.position + Vector2(-155,80)
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
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.035: changed+=1
		check(changed>150,"visible GPU silhouette " + effect.visual_profile + " (%d pixels)" % changed)
		effect.visible = true
		for frame: int in 2: await process_frame
		await RenderingServer.frame_post_draw
	paused = true
	await RenderingServer.frame_post_draw
	var frozen: Image = root.get_texture().get_image()
	await create_timer(0.1,true).timeout
	await RenderingServer.frame_post_draw
	check(frozen.get_data()==root.get_texture().get_image().get_data(),"rendered pixels freeze during pause")
	var output: String = "E:/codex/holy-summons/rendered"
	DirAccess.make_dir_recursive_absolute(output)
	check(frozen.save_png(output.path_join("holy_summon_profiles.png"))==OK,"save holy summon profile sheet")
	print("[holy_summon_rendered] failures=",failures)
	quit(1 if failures else 0)
