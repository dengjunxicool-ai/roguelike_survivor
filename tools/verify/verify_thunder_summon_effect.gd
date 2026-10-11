extends SceneTree

var failures: int = 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	if "--render-summons" in OS.get_cmdline_user_args():
		await render_summons()
		return
	var instances: Array[Node2D] = []
	for profile: String in ["lynx", "crow"]:
		var path: String = "res://scenes/effects/storm_%s_effect.tscn" % profile
		check(ResourceLoader.exists(path), profile + " custom scene exists")
		if not ResourceLoader.exists(path): continue
		var effect: Node2D = load(path).instantiate()
		root.add_child(effect)
		instances.append(effect)
		effect.configure_summon({"scale":0.14})
		check(effect.scale == Vector2.ONE, profile + " ignores legacy icon scale")
		var count: int = descendants(effect)
		var material: ShaderMaterial = effect.get_node("Geometry").material
		check(material != null, profile + " has independent electric material")
		effect.face_direction(Vector2.LEFT)
		effect.update_summon(0.1, Vector2(-180,0), 5.0)
		check(effect.get_node("Geometry").scale.x < 0, profile + " mirrors toward movement")
		effect.set_attack_target(Vector2(40,0))
		effect.play_attack()
		effect.update_summon(0.14, Vector2.ZERO, 5.0)
		check(effect.get_node("Geometry").position.x > 0, profile + " launches actual directional attack pose")
		for i: int in 200: effect.update_summon(0.01, Vector2.ZERO, 5.0)
		check(descendants(effect) == count, profile + " fixed geometry through repeated updates")
		var age: float = effect._age
		paused = true
		await process_frame
		await process_frame
		check(is_equal_approx(effect._age,age), profile + " host driven clock freezes during pause")
		paused = false
		effect.update_summon(0.1, Vector2.ZERO, 0.0)
		check(effect.modulate.a == 0, profile + " authoritative expiry hides effect")
		effect.configure_summon({})
		check(effect._attack_remaining == 0 and effect.modulate.a == 1, profile + " reconfigure resets attack and fade")
		if profile == "lynx":
			check(effect.get_node_or_null("Geometry/Body/LynxHead/EarTuftNear") != null, "lynx ear tuft silhouette exists")
			check(effect._legs.size() == 4, "lynx has four animated limbs")
		else:
			check(effect._wings.size() == 2 and effect._feathers.size() >= 8, "crow has articulated wings and floating electric feathers")
	if instances.size() == 2:
		check(instances[0].get_node("Geometry").material != instances[1].get_node("Geometry").material, "summons never share mutable shader material")
	for node: Node2D in instances: node.free()
	print("[thunder_summon_effect] failures=",failures)
	quit(1 if failures else 0)
func descendants(node: Node) -> int:
	var count: int = node.get_child_count()
	for child: Node in node.get_children(): count += descendants(child)
	return count

func render_summons() -> void:
	check(DisplayServer.get_name() != "headless", "summon rendered test uses GPU")
	root.size = Vector2i(800,480)
	DisplayServer.window_set_size(root.size)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.06,0.08,0.14)
	background.size = Vector2(root.size)
	root.add_child(background)
	var effects: Array[Node2D] = []
	for i: int in 4:
		var profile: String = "lynx" if i%2 == 0 else "crow"
		var effect: Node2D = load("res://scenes/effects/storm_%s_effect.tscn" % profile).instantiate()
		root.add_child(effect)
		effect.configure_summon({"effect_scale":2.0})
		effect.position = Vector2(180 if i%2==0 else 590,180 if i<2 else 370)
		effect.update_summon(0.4,Vector2(150,0) if i<2 else Vector2.ZERO,5.0)
		if i >= 2:
			effect.set_attack_target(Vector2(70,-20))
			effect.play_attack()
			effect.update_summon(0.16,Vector2.ZERO,5.0)
		effects.append(effect)
		var label: Label = Label.new()
		label.text = profile.to_upper()+ ("  FOLLOW / HOVER" if i<2 else "  CONFIRMED ATTACK")
		label.position = effect.position + Vector2(-120,40)
		root.add_child(label)
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	for effect: Node2D in effects:
		effect.visible = false
		for frame: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		var hidden: Image = root.get_texture().get_image()
		var changed: int = 0
		for y: int in range(0,shown.get_height(),2):
			for x: int in range(0,shown.get_width(),2):
				var a: Color = shown.get_pixel(x,y)
				var b: Color = hidden.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.035: changed+=1
		check(changed>100,"actual GPU silhouette pixels "+effect.visual_profile+" (%d)" % changed)
		effect.visible = true
		for frame: int in 3: await process_frame
		await RenderingServer.frame_post_draw
	paused = true
	await RenderingServer.frame_post_draw
	var before: Image = root.get_texture().get_image()
	await create_timer(0.12,true).timeout
	await RenderingServer.frame_post_draw
	check(before.get_data()==root.get_texture().get_image().get_data(),"rendered summon pixels freeze exactly during pause")
	var output: String = "E:/codex/thunder-summons/rendered"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output=argument.trim_prefix("--capture-dir=").replace("\\","/").simplify_path()
	check(output.begins_with("E:/codex/"),"render output stays in E:/codex")
	if output.begins_with("E:/codex/"):
		DirAccess.make_dir_recursive_absolute(output)
		check(before.save_png(output.path_join("thunder_summon_profiles.png"))==OK,"save thunder summon profile sheet")
	print("[thunder_summon_rendered] failures=",failures)
	quit(1 if failures else 0)
