extends SceneTree
var failures: int=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	if "--render-summons" in OS.get_cmdline_user_args():
		await render_summons()
		return
	var effects: Array[Node2D]=[]
	for profile: String in ["bone_servant","soul_crow"]:
		var path: String="res://scenes/effects/%s_effect.tscn" % profile
		check(ResourceLoader.exists(path),profile+" custom scene exists")
		if not ResourceLoader.exists(path): continue
		var effect: Node2D=load(path).instantiate()
		root.add_child(effect)
		effects.append(effect)
		effect.configure_summon({"scale":0.13})
		check(effect.scale==Vector2.ONE,profile+" ignores legacy icon scale")
		var count: int=descendants(effect)
		check(effect.get_node("Geometry").material is ShaderMaterial,profile+" local shader material exists")
		effect.face_direction(Vector2.LEFT)
		effect.update_summon(0.2,Vector2(-170,0),6.0)
		check(effect.get_node("Geometry").scale.x<0,profile+" faces movement")
		effect.set_attack_target(Vector2(40,10))
		effect.play_attack()
		effect.update_summon(0.14,Vector2.ZERO,5.0)
		check(effect.get_node("Geometry").position.x>0,profile+" host attack target drives reach")
		if profile=="bone_servant":
			check(effect.get_node_or_null("Geometry/Body/Skull/EyeSocketNear/SoulFire")!=null,"bone eye sockets contain soul flame")
			check(effect._legs.size()==2 and effect._arms.size()==2,"bone four articulated limbs")
			check(effect.get_node_or_null("Geometry/Body/Rib3")!=null,"bone visible rib cage")
		else:
			check(effect._wings.size()==2 and effect._feathers.size()==10,"soul crow layered articulated feathers")
			check(effect.get_node_or_null("Geometry/Body/SoulCore")!=null,"soul crow green core exists")
			check(not effect._soul_stream.visible,"casting attack cannot invent soul absorption")
			check(effect._soul_orbs.size()==3,"soul crow idle collecting pearls exist")
		for index: int in 200: effect.update_summon(0.01,Vector2.ZERO,5.0)
		check(descendants(effect)==count,profile+" animation never creates nodes")
		var age: float=effect._age
		paused=true
		for frame: int in 3: await process_frame
		check(is_equal_approx(effect._age,age),profile+" clock freezes without host updates")
		paused=false
		effect.update_summon(0.1,Vector2.ZERO,0.0)
		check(effect.modulate.a==0,profile+" authoritative expiry hides effect")
		effect.configure_summon({})
		check(effect._attack_remaining==0 and effect.modulate.a==1,profile+" reconfigure resets lifecycle")
		check(descendants(effect)==count,profile+" reconfigure reuses fixed geometry")
		effect.configure_summon({"effect_scale":1.5,"scale":0.1})
		check(effect.scale.is_equal_approx(Vector2(1.5,1.5)),profile+" explicit effect_scale controls presentation size")
		effect.deactivate()
		check(not effect.visible,profile+" deactivate hides geometry")
	if effects.size()==2: check(effects[0].get_node("Geometry").material!=effects[1].get_node("Geometry").material,"curse summons use independent mutable materials")
	for effect: Node2D in effects: effect.free()
	print("[curse_summon_effect] failures=",failures)
	quit(1 if failures else 0)
func descendants(node: Node) -> int:
	var count: int=node.get_child_count()
	for child: Node in node.get_children(): count+=descendants(child)
	return count
func render_summons() -> void:
	check(DisplayServer.get_name()!="headless","summon render requires GPU")
	root.size=Vector2i(900,560)
	DisplayServer.window_set_size(root.size)
	var background: ColorRect=ColorRect.new()
	background.color=Color(0.075,0.06,0.12)
	background.size=Vector2(root.size)
	root.add_child(background)
	var effects: Array[Node2D]=[]
	for index: int in 4:
		var profile: String="bone_servant" if index%2==0 else "soul_crow"
		var effect: Node2D=load("res://scenes/effects/%s_effect.tscn" % profile).instantiate()
		root.add_child(effect)
		effect.configure_summon({"effect_scale":2.0})
		effect.position=Vector2(225 if index%2==0 else 665,200 if index<2 else 435)
		effect.update_summon(0.4,Vector2(170,0) if index<2 else Vector2.ZERO,5.0)
		if index>=2:
			effect.set_attack_target(Vector2(70,-15))
			effect.play_attack()
			effect.update_summon(0.16,Vector2.ZERO,5.0)
		effects.append(effect)
		var label: Label=Label.new()
		label.text=profile.to_upper()+ ("  FOLLOW / IDLE" if index<2 else "  ATTACK")
		label.position=effect.position+Vector2(-145,65)
		root.add_child(label)
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image=root.get_texture().get_image()
	for effect: Node2D in effects:
		effect.visible=false
		for frame: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		var hidden: Image=root.get_texture().get_image()
		var changed: int=0
		for y: int in range(0,shown.get_height(),2):
			for x: int in range(0,shown.get_width(),2):
				var a: Color=shown.get_pixel(x,y)
				var b: Color=hidden.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.035: changed+=1
		check(changed>100,"GPU silhouette pixels "+effect.visual_profile+" (%d)" % changed)
		effect.visible=true
		for frame: int in 3: await process_frame
		await RenderingServer.frame_post_draw
	paused=true
	await RenderingServer.frame_post_draw
	var before: Image=root.get_texture().get_image()
	await create_timer(0.12,true).timeout
	await RenderingServer.frame_post_draw
	check(before.get_data()==root.get_texture().get_image().get_data(),"rendered pixels freeze exactly during pause")
	var output: String="E:/codex/curse-summons/rendered"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output=argument.trim_prefix("--capture-dir=").replace("\\","/").simplify_path()
	check(output.begins_with("E:/codex/"),"render output stays E drive")
	if output.begins_with("E:/codex/"):
		DirAccess.make_dir_recursive_absolute(output)
		check(before.save_png(output.path_join("curse_summon_profiles.png"))==OK,"save curse summon profile sheet")
	print("[curse_summon_rendered] failures=",failures)
	quit(1 if failures else 0)
