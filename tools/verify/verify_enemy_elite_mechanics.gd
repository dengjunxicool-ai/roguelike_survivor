extends SceneTree
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var failed := false
class Receiver extends Node2D:
	var hits := 0
	var damage := 0
	func take_damage(packet: DamagePacket) -> void:
		hits += 1
		damage += int(packet.amount)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world := Node2D.new()
	root.add_child(world)
	var player := Receiver.new()
	world.add_child(player)
	player.add_to_group("player")
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=24
	collider.shape=circle
	player.add_child(collider)
	player.position = Vector2(240,0)
	var captain := make_enemy(world,player,"skeleton_captain")
	captain.call("_update_behavior",0.01)
	expect(captain.velocity == Vector2.ZERO, "charge warning stops movement immediately")
	expect(is_equal_approx(float(captain.get("_dash_warning_timer")),0.9), "captain warns for 0.9 seconds")
	player.position = Vector2(0,240)
	captain.call("_update_behavior",0.91)
	captain.call("_update_behavior",0.1)
	expect(captain.velocity.x > 400 and absf(captain.velocity.y)<0.01, "charge direction remains locked after target moves")
	player.position = captain.position
	captain.call("_apply_contact_damage")
	captain.set("_damage_cooldown",0.0)
	captain.call("_apply_contact_damage")
	expect(player.hits == 1, "charge hits each target only once")
	captain.call("_update_behavior",0.6)
	captain.call("_update_behavior",0.01)
	captain.set("_damage_cooldown",0.0)
	captain.call("_apply_contact_damage")
	expect(player.hits == 1 and captain.velocity == Vector2.ZERO, "recovery neither moves nor causes contact damage")
	var moving_captain := make_enemy(world,player,"skeleton_captain")
	moving_captain.position=Vector2(500,500)
	player.position=Vector2(740,500)
	var hits_before := player.hits
	var farthest := moving_captain.position.x
	for frame in range(128):
		await physics_frame
		moving_captain.call("_physics_process_profiled",1.0/60.0)
		farthest=maxf(farthest,moving_captain.position.x)
	expect(farthest>740 and is_equal_approx(farthest,752),"real physical charge travels 252 and passes the original target position")
	expect(player.hits==hits_before+1,"real physical charge hits a stationary target once")
	moving_captain.queue_free()
	var scaled_slime := make_enemy(world,player,"giant_slime",1.28)
	scaled_slime.position=Vector2(800,200)
	player.position=Vector2(980,200)
	scaled_slime.call("_update_behavior",0.01)
	scaled_slime.call("_update_behavior",1.01)
	scaled_slime.call("_update_behavior",0.6)
	scaled_slime.position+=scaled_slime.velocity*0.6
	scaled_slime.call("_update_behavior",0.01)
	var scaled_area := active_area(scaled_slime)
	expect(scaled_area!=null and scaled_area.get("damage")==20 and scaled_area.call("_get_damage_payload",player).amount==20,"leap DamagePacket inherits scaled contact damage exactly once")
	scaled_slime.queue_free()
	player.position=Vector2(180,0)
	var slime := make_enemy(world,player,"giant_slime")
	player.position = Vector2(180,0)
	expect(String(slime.get("_behavior").get("type")) == "leap_and_slam", "giant slime has dedicated leap behavior")
	slime.call("_update_behavior",0.01)
	player.position = Vector2(-180,0)
	slime.call("_update_behavior",1.01)
	slime.call("_update_behavior",0.6)
	slime.position += slime.velocity * 0.6
	slime.call("_update_behavior",0.01)
	var area := active_area(slime)
	expect(area != null, "leap landing creates one impact")
	if area != null:
		expect(area.global_position.x > 150 and area.get("_activation_mode") == &"single" and is_equal_approx(float(area.get("area_radius")),110), "landing stays locked and uses 110 single impact")
	var before := get_nodes_in_group("enemies").size()
	slime.set_meta("reward_policy", {"award_soul":false,"drop_experience":false})
	slime.call("_finish_death")
	slime.call("_finish_death")
	var splits := 0
	for child: Node in get_nodes_in_group("enemies"):
		if child.get_meta("summoner_instance_id",0)==slime.get_instance_id():
			splits += 1
			expect(child.get_meta("spawn_source_type","")=="death_split" and not child.get_meta("reward_policy",{}).get("drop_experience",true), "split has dedicated source and zero reward")
	expect(splits==3 and get_nodes_in_group("enemies").size()==before+3, "death splits exactly three children once")
	for id: String in ["toxic_matriarch","lava_golem"]:
		var caster := make_enemy(world,player,id)
		player.position = Vector2(250,0)
		caster.call("_update_behavior",0.01)
		area = active_area(caster)
		expect(area != null, id+" casts from distance")
		if area != null:
			var poison := id=="toxic_matriarch"
			expect(is_equal_approx(float(area.get("_warning_time")),0.9 if poison else 1.1) and is_equal_approx(float(area.get("area_radius")),96 if poison else 110), id+" warning and radius match profile")
			expect(area.get("_activation_mode")==(&"periodic" if poison else &"single"), id+" activation mode")
			expect(is_equal_approx(float(caster.get("_cast_cooldown")),7 if poison else 6), id+" successful cast cooldown")
			var initial: Node = area
			caster.set("_cast_cooldown",0.0)
			caster.call("_update_behavior",0.01)
			expect(active_area(caster)==initial and float(caster.get("_cast_cooldown"))==0, id+" failed second cast consumes no cooldown")
	world.queue_free()
	await process_frame
	await test_map_boundary()
	await test_frozen_actions()
	await test_attack_interrupt()
	quit(1 if failed else 0)

func test_attack_interrupt() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := Receiver.new()
	world.add_child(player)
	player.add_to_group("player")
	player.position = Vector2(240,0)
	var captain := make_enemy(world,player,"skeleton_captain")
	captain.call("_update_behavior",0.01)
	expect(bool(captain.call("interrupt_preparing_attack")), "skill interrupt accepts a charge warning")
	captain.call("_update_behavior",1.0)
	captain.call("_update_behavior",0.1)
	expect(float(captain.get("_dash_timer")) == 0.0 and not bool(captain.get("_special_attack_passes_target")), "interrupted charge cannot resume from private behavior state")
	captain.queue_free()
	await process_frame
	var bus: Node = preload("res://scripts/skills/skill_event_bus.gd").new()
	bus.name = "SkillEventBus"
	player.add_child(bus)
	bus.set_physics_process(false)
	var notifications := [0]
	bus.call("subscribe", &"enemy_preparing_attack", func(context: Dictionary) -> void:
		notifications[0] += 1
		context.target.call("interrupt_preparing_attack")
	)
	captain = make_enemy(world,player,"skeleton_captain")
	captain.call("_update_behavior",0.01)
	expect(notifications[0] == 1, "charge preparation reaches the real skill event bus")
	expect(float(captain.get("_dash_warning_timer")) == 0.0, "synchronous skill interruption cancels charge preparation")
	captain.call("_update_behavior",1.0)
	captain.call("_update_behavior",0.1)
	expect(float(captain.get("_dash_timer")) == 0.0 and not bool(captain.get("_special_attack_passes_target")), "synchronous interruption leaves no deferred charge")
	world.queue_free()
	await process_frame
func make_enemy(world: Node, player: Node2D, id: String, multiplier: float = 1.0) -> CharacterBody2D:
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.set("enemy_id",StringName(id))
	enemy.set("damage_multiplier",multiplier)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set("target",player)
	return enemy
func test_map_boundary() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var background := Sprite2D.new()
	background.name="DungeonBackground"
	background.centered=false
	var texture := GradientTexture2D.new()
	texture.width=800
	texture.height=600
	background.texture=texture
	world.add_child(background)
	var player := Receiver.new()
	world.add_child(player)
	player.add_to_group("player")
	for id: String in ["archer_skeleton","skeleton_captain","giant_slime"]:
		var actor := make_enemy(world,player,id)
		actor.position=Vector2(20,300) if id=="archer_skeleton" else Vector2(750,300)
		player.position=Vector2(230,300) if id=="archer_skeleton" else Vector2(780,300)
		for frame in range(110):
			await physics_frame
			actor.call("_physics_process_profiled",1.0/60.0)
			if frame==15 and id!="archer_skeleton":
				player.position=Vector2(100,100)
		var radius: float = actor.call("_get_collision_radius",actor,24.0)
		expect(actor.position.x>=radius-0.01 and actor.position.x<=800-radius+0.01,id+" physical retreat or committed attack stays inside map")
		actor.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
func active_area(enemy: Node) -> Node2D:
	var ref: WeakRef = enemy.get_meta("active_enemy_area",{}).get("node")
	return ref.get_ref() as Node2D if ref != null else null
func test_frozen_actions() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := Receiver.new()
	world.add_child(player)
	player.add_to_group("player")
	player.position=Vector2(210,0)
	for id: String in ["skeleton_captain","giant_slime"]:
		var actor := make_enemy(world,player,id)
		actor.call("_update_behavior",0.01)
		var behavior: RefCounted = actor.get("_behavior_controller").get("_behavior")
		for phase: String in ["warning","movement"]:
			var remaining: float = behavior.get("_remaining")
			var origin := actor.position
			expect(actor.call("apply_status",&"freeze",{"duration":2.0}),id+" real freeze applies during "+phase)
			for frame in range(12):
				await physics_frame
				actor.call("_physics_process_profiled",1.0/60.0)
			expect(is_equal_approx(behavior.get("_remaining"),remaining) and actor.position==origin,id+" freeze suspends "+phase+" without consuming motion time")
			actor.get("_status_facade").call("ensure_manager").call("clear_statuses")
			if phase=="warning":
				actor.call("_update_behavior",remaining+0.01)
			else:
				await physics_frame
				actor.call("_physics_process_profiled",1.0/60.0)
				expect(behavior.get("_remaining")<remaining and actor.position!=origin,id+" resumes movement without a catch-up jump")
		actor.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		push_error("[EliteMechanics] FAIL "+message)
	else:
		print("[EliteMechanics] PASS "+message)
