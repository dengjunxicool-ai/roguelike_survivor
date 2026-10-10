## E 盘隔离的真实渲染采样；实际敌人/区域/投放服务，合成场景无敌移动受击体。
extends SceneTree
const RunEnvironment = preload("res://tools/verify/verification_run_environment.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const SpawnService = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
var environment: Dictionary
var world: Node2D
var player: CharacterBody2D
var label: Label
var camera: Camera2D
var samples: Array = []
var failed := false
var elapsed := 0.0
var move_receiver := false
var center := Vector2.ZERO
var dimensions := Vector2i(1280,720)
class Receiver extends CharacterBody2D:
	var hits := 0
	func take_damage(_packet: DamagePacket) -> void:
		hits+=1
	func _draw() -> void:
		draw_circle(Vector2.ZERO,24,Color(0.3,0.8,1))
		draw_arc(Vector2.ZERO,27,0,TAU,32,Color.WHITE,2,true)
class Arena extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-4000,-4000,8000,8000),Color(0.055,0.075,0.1))
		for x in range(-2000,4000,80):
			draw_line(Vector2(x,-2000),Vector2(x,4000),Color(0.11,0.14,0.18))
		for y in range(-2000,4000,80):
			draw_line(Vector2(-2000,y),Vector2(4000,y),Color(0.11,0.14,0.18))
func _init() -> void:
	call_deferred("run")
func run() -> void:
	environment=RunEnvironment.initialize("E:/codex/monster-system/stage-b-render")
	if environment.is_empty() or DisplayServer.get_name()=="headless":
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			dimensions=Vector2i(int(parts[0]),int(parts[1]))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await process_frame
	await process_frame
	DisplayServer.window_set_size(dimensions)
	await create_timer(0.2).timeout
	if root.size!=dimensions:
		push_error("Requested render viewport did not settle: "+str(root.size))
		quit(1)
		return
	root.set_meta("debug_manual_spawn_only",true)
	center=Vector2(dimensions)*0.5
	for mixed: bool in [false,true]:
		for id: String in ["giant_slime","skeleton_captain","toxic_matriarch","lava_golem"]:
			await sample_elite(id,mixed)
	await sample_spawn(1.0,Vector2.ZERO)
	await sample_spawn(0.75,Vector2(110,-35))
	await sample_spawn(1.5,Vector2(-100,40))
	var report := FileAccess.open(environment.report_dir.path_join("samples.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"viewport":dimensions,"seed":environment.seed,"mode":"real OpenGL rendering; actual enemy/area/spawn nodes; synthetic arena, automated invulnerable receiver","samples":samples},"\t"))
	report.close()
	RunEnvironment.cleanup_save(environment)
	root.remove_meta("debug_manual_spawn_only")
	print("[MonsterStageBRender] done failed=",failed," viewport=",dimensions)
	quit(1 if failed else 0)
func prepare_world() -> void:
	world=Arena.new()
	root.add_child(world)
	player=Receiver.new()
	player.add_to_group("player")
	player.collision_layer=2
	player.collision_mask=0
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=24
	collider.shape=circle
	player.add_child(collider)
	world.add_child(player)
	player.position=center+Vector2(180,0)
	camera=Camera2D.new()
	world.add_child(camera)
	camera.position=center
	camera.force_update_scroll()
	var layer := CanvasLayer.new()
	world.add_child(layer)
	label=Label.new()
	label.position=Vector2(24,20)
	label.add_theme_font_size_override("font_size",18)
	layer.add_child(label)
func enemy(id: String,position: Vector2) -> Node2D:
	var node: Node2D = EnemyScene.instantiate()
	node.set("enemy_id",StringName(id))
	world.add_child(node)
	node.position=position
	node.set("target",player)
	return node
func sample_elite(id: String,mixed: bool) -> void:
	prepare_world()
	var main := enemy(id,center)
	if mixed:
		enemy("skeleton",center+Vector2(-170,-100))
		enemy("war_drum_goblin",center+Vector2(-160,80))
		enemy("archer_skeleton",center+Vector2(-250,160))
		enemy("skeleton_priest",center+Vector2(-200,-160))
	label.text="Stage B | %s | %s | %dx%d\nActual attacks / automated moving receiver / no balance verdict" % [id,"mixed" if mixed else "single",dimensions.x,dimensions.y]
	elapsed=0
	move_receiver=true
	var frames: Array = []
	for index in range(4):
		await create_timer([0.3,0.45,0.9,1.85][index]).timeout
		var path: String = environment.report_dir.path_join("%s_%s_%d.png" % [id,"mixed" if mixed else "single",index])
		await capture(path)
		frames.append(path)
	move_receiver=false
	samples.append({"enemy":id,"mixed":mixed,"duration":elapsed,"hits":player.get("hits"),"frames":frames,"alive":main.get("_is_dead")!=true})
	world.queue_free()
	await process_frame
func sample_spawn(zoom: float,offset: Vector2) -> void:
	prepare_world()
	camera.zoom=Vector2.ONE*zoom
	camera.offset=offset
	camera.force_update_scroll()
	var rng := RandomNumberGenerator.new()
	rng.seed=int(environment.seed)+int(zoom*100)
	var service: RefCounted = SpawnService.new()
	service.call("setup",world,EnemyScene,null,&"player",rng)
	service.call("set_visible_spawn_rules",true,48,120,1.5)
	var born: Node2D = service.call("spawn",{"enemy_id":&"small_slime","position":center+Vector2(-120,0),"source_type":"wave","parent":world})
	if born==null:
		push_error("Rendered spawn fixture could not find safe position")
		failed=true
		world.queue_free()
		await process_frame
		return
	label.text="Stage B birth safety | zoom %.2f | offset %s | %dx%d\nReceiver enters warning center; full warning must restart at relocated position" % [zoom,offset,dimensions.x,dimensions.y]
	await create_timer(0.35).timeout
	var original := born.global_position
	player.global_position=original
	var prefix: String = "spawn_%d" % int(zoom*100)
	await capture(environment.report_dir.path_join(prefix+"_entered.png"))
	await create_timer(1.22).timeout
	var relocated: bool = born.global_position.distance_to(original)>50 and bool(born.get_meta("spawn_reveal_pending",false))
	if not relocated:
		push_error("Rendered player entered warning but full relocation warning was missing")
		failed=true
	await capture(environment.report_dir.path_join(prefix+"_relocated.png"))
	await create_timer(1.55).timeout
	born.set_physics_process(false)
	var activated: bool = not bool(born.get_meta("spawn_reveal_pending",true))
	if not activated:
		push_error("Relocated birth did not activate after its full warning")
		failed=true
	await capture(environment.report_dir.path_join(prefix+"_active.png"))
	samples.append({"source":"wave","zoom":zoom,"camera_offset":offset,"relocated_full_warning":relocated,"activated":activated,"statistics":service.get("statistics").duplicate(true)})
	world.queue_free()
	await process_frame
func _process(delta: float) -> bool:
	if move_receiver and is_instance_valid(player):
		elapsed+=delta
		player.position=center+Vector2(180,sin(elapsed*1.6)*70)
	return false
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture==null or picture.is_empty() or picture.save_png(path)!=OK:
		failed=true
		push_error("Failed rendered screenshot "+path)
