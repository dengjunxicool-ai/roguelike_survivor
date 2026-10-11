extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const DRAGON: String = "res://scenes/effects/fire_dragon_effect.tscn"
const FOX: String = "res://scenes/effects/fire_fox_effect.tscn"
const Definition = preload("res://scripts/summons/summon_definition.gd")
const SummonManager = preload("res://scripts/summons/summon_manager.gd")
const Registry = preload("res://scripts/combat/combat_target_registry.gd")
const RuleAdapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")

func run() -> void:
	if "--render-summons" in OS.get_cmdline_user_args():
		await _render_preview()
		return
	_check_geometry()
	await setup_run()
	check(Fixture.install_runtime_skill(manager, &"fire_summon_ember_fox_pack"), "learn production ember fox skill")
	check(Fixture.install_runtime_skill(manager, &"fire_summon_crimson_dragon"), "learn dragon alongside fox for isolated rule regression")
	var parent: Node = player.get_parent()
	var enemy: EnemyBase = EnemyScene.instantiate()
	enemy.enemy_id = &"skeleton"
	parent.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.max_health = 10000
	enemy.current_health = 10000
	enemy.armor = 0
	enemy.global_position = player.global_position + Vector2(60,0)
	var bus: Node = player.get_node("SkillEventBus")
	var fox_skill: RefCounted = manager.get_skill(&"fire_summon_ember_fox_pack")
	var context: Dictionary = {"caster":player,"owner":player,"parent":parent,
		"skill_manager":manager,"event_bus":bus,"skill_instance":fox_skill,
		"skill_id":&"fire_summon_ember_fox_pack","origin_skill_id":&"fire_summon_ember_fox_pack",
		"target":enemy,"power":float(player.attack_power),"status_id":&"burning"}
	enemy.apply_status(&"burning", {"duration":4.0,"stack":1,"source":player})
	var before: int = enemy.current_health
	for i: int in range(8):
		bus.emit_skill_event(&"status_applied", context)
	var foxes: Array[Node2D] = []
	for node: Node in parent.get_children():
		if node is Node2D and String(node.get_meta("action_summon_id", "")) == "ember_fox":
			foxes.append(node)
	check(foxes.size() == 2, "eight actual rule events create canonical pair of foxes")
	print("[fire_fox_production] health_before=%d health_after=%d burning=%d foxes=%d" % [before,enemy.current_health,enemy.get_status_stack(&"burning"),foxes.size()])
	check(enemy.current_health < before, "canonical fox attack reduces actual EnemyBase health")
	check(enemy.get_status_stack(&"burning") > 1, "canonical fox burst preserves burning application")
	var bursts: int = 0
	for node: Node in parent.get_children():
		if node is Node2D and String(node.get_meta("source_id", "")) == "ember_fox_burst" and (node as Node2D).visible:
			bursts += 1
	check(bursts == 2, "canonical fox pair creates one actual burst area each")
	var dragon_skill: RefCounted = manager.get_skill(&"fire_summon_crimson_dragon")
	check(not dragon_skill.has_meta("trigger_cd_summon_attack_hit_global"), "fox attacks never dispatch learned dragon attack rule")
	for fox: Node2D in foxes:
		var effect: Node2D = fox.get_node_or_null("FireSummonEffect") as Node2D
		check(effect != null and fox.get_node_or_null("SummonParticles") == null, "fox has anatomy and suppresses legacy particle cloud")
		if effect != null:
			check(float(effect.get("_attack_remaining")) > 0.0, "actual fox attack starts lunge")
			var attack_timer: Timer
			for child: Node in fox.get_children():
				if child is Timer:
					attack_timer = child as Timer
			check(attack_timer != null and is_equal_approx(attack_timer.wait_time,1.2), "canonical fox attack interval preserved")
			var age: float = float(effect.get("_age"))
			fox.process_mode = Node.PROCESS_MODE_PAUSABLE
			paused = true
			await create_timer(0.1,true).timeout
			check(is_instance_valid(fox) and is_equal_approx(float(effect.get("_age")),age), "engine pause freezes generic fox age and lifetime")
			paused = false
			fox.process_mode = Node.PROCESS_MODE_DISABLED
	if not foxes.is_empty():
		_check_no_damage_cue(foxes[0],bus,context)
	await _check_pause_expiry(bus, fox_skill, context)
	var summon_manager: Node = SummonManager.new()
	player.add_child(summon_manager)
	var dragon: Node2D = summon_manager.spawn_summon(Definition.from_id("crimson_dragon"), {
		"owner":player,"caster":player,"parent":parent,"player_power":float(player.attack_power),
		"target_group":&"enemies","event_bus":bus,"skill_manager":manager,
		"skill_id":&"fire_summon_crimson_dragon","origin_skill_id":&"fire_summon_crimson_dragon"})
	dragon.set_physics_process(false)
	dragon.global_position = player.global_position + Vector2(80,0)
	enemy.global_position = dragon.global_position + Vector2(-90,60)
	var dragon_before: int = enemy.current_health
	dragon.call("_physics_process",0.05)
	var dragon_effect: Node2D = dragon.get_node_or_null("SummonEffect") as Node2D
	check(enemy.current_health < dragon_before, "production dragon damages actual typed health target")
	check(dragon_effect != null, "production dragon attaches fire scene")
	if dragon_effect != null:
		check((dragon_effect.get("_target_offset") as Vector2).is_equal_approx(enemy.global_position-dragon.global_position), "dragon breath reads actual attack target offset")
		check(float(dragon_effect.get("_attack_remaining")) > 0.0, "dragon breath starts only on successful attack")
		var after: int = enemy.current_health
		dragon.call("_physics_process",0.05)
		check(enemy.current_health == after, "dragon cooldown prevents extra visual damage")
		var age: float = float(dragon_effect.get("_age"))
		var lifetime: float = float(dragon.get("_remaining_duration"))
		dragon.process_mode = Node.PROCESS_MODE_PAUSABLE
		dragon.set_physics_process(true)
		paused = true
		await create_timer(0.1,true).timeout
		check(is_equal_approx(float(dragon_effect.get("_age")), age) and is_equal_approx(float(dragon.get("_remaining_duration")), lifetime), "engine pause freezes managed dragon age and lifetime")
		dragon.set_physics_process(false)
		paused = false
		dragon.set("_remaining_duration",0.01)
		dragon.call("_physics_process",0.05)
		check(dragon.is_queued_for_deletion() and dragon_effect.modulate.a <= 0.001, "host lifetime hides dragon")
	await finish()

func _check_no_damage_cue(fox: Node2D, bus: Node, context: Dictionary) -> void:
	var invalid_target: Node2D = Node2D.new()
	root.add_child(invalid_target)
	invalid_target.global_position = fox.global_position + Vector2(20,0)
	invalid_target.add_to_group(&"fire_fox_non_damage_target")
	var registry: Node = Registry.get_or_create(root)
	registry.register_target(invalid_target,&"fire_fox_non_damage_target")
	var effect: Node2D = fox.get_node("FireSummonEffect") as Node2D
	effect.call("configure_summon",{})
	var family: RefCounted = bus.get("_action_executor").get("_families").get("summon")
	family.call("_summon_tick",fox,{"summon_id":"ember_fox","target_group":"fire_fox_non_damage_target"},context)
	check(float(effect.get("_attack_remaining"))==0.0,"fox refuses lunge for target without actual health damage")
	registry.unregister_target(invalid_target,&"fire_fox_non_damage_target")
	invalid_target.free()

func _check_pause_expiry(bus: Node, skill: RefCounted, context: Dictionary) -> void:
	var params: Dictionary = {}
	for event: Dictionary in RuleAdapter.to_events(skill,skill.get("definition")):
		for action: Dictionary in event.get("actions",[]):
			if String(action.get("type","")) == "spawn_summon":
				params = action.params.duplicate(true)
	params["count"] = 1
	params["duration"] = 0.05
	params["attack_interval"] = 0.05
	var short_context: Dictionary = context.duplicate(true)
	short_context["parent"] = root
	bus.execute_adapted_actions([{"type":"spawn_summon","params":params}],short_context)
	var short_fox: Node2D
	for node: Node in root.get_children():
		if node is Node2D and String(node.get_meta("action_summon_id","")) == "ember_fox":
			short_fox = node
	check(short_fox != null,"short canonical fox fixture exists")
	if short_fox == null:
		return
	var effect: Node2D = short_fox.get_node("FireSummonEffect") as Node2D
	var age: float = float(effect.get("_age"))
	paused = true
	await create_timer(0.12,true).timeout
	check(is_instance_valid(short_fox) and is_equal_approx(float(effect.get("_age")),age),"fox lifetime survives pause longer than its full duration")
	paused = false
	await create_timer(0.12,true).timeout
	check(not is_instance_valid(short_fox),"fox cleans up only after active lifetime expires")

func _check_geometry() -> void:
	for scene: String in [DRAGON,FOX]:
		var effect: Node2D = (load(scene) as PackedScene).instantiate() as Node2D
		root.add_child(effect)
		if scene == DRAGON:
			_check_idle_geometry(effect)
		seed(6161)
		var expected: int = randi()
		seed(6161)
		effect.call("configure_summon",{})
		effect.call("set_attack_target",Vector2(-120,90))
		effect.call("play_attack")
		effect.call("update_summon",0.12,Vector2(100,0),3.0)
		check(randi()==expected,"fire summon presentation preserves gameplay RNG")
		check((effect.get_node("Geometry") as Node2D).scale.x<0,"fire anatomy mirrors actual left target")
		var count: int = effect.get_child_count()
		var other: Node2D = (load(scene) as PackedScene).instantiate() as Node2D
		root.add_child(other)
		other.call("configure_summon",{})
		check(effect.get("_fire_material")!=other.get("_fire_material"),"per-summon material isolated")
		effect.call("deactivate")
		check(not effect.visible and float(effect.get("_attack_remaining"))==0.0,"deactivation stops all attack presentation")
		effect.call("configure_summon",{})
		check(effect.visible and effect.get_child_count()==count and float(effect.get("_age"))==0.0,"reuse resets clocks without geometry allocation")
		check((effect.get("_target_offset") as Vector2)==Vector2.ZERO,"reuse removes old target offset")
		check(_count_nodes(effect)<90,"fire anatomy and deterministic embers stay within node budget")
		if scene==DRAGON:
			effect.call("set_attack_target",Vector2(1000,0))
			check(is_equal_approx((effect.get("_target_offset") as Vector2).length(),336.0),"dragon breath limited to actual maximum range")
		other.free()
		effect.free()

func _check_idle_geometry(effect: Node2D) -> void:
	effect.call("configure_summon", {})
	var breath: Line2D = effect.get_node("Breath0") as Line2D
	var ring: Line2D = effect.get_node("ConfirmedImpact/SparkRing") as Line2D
	var cached_ring: PackedVector2Array = ring.points
	check(breath.points.is_empty(), "idle dragon never constructs unused breath geometry")
	check(cached_ring.size() == 25, "impact ring geometry exists once before attacks")
	effect.call("set_attack_target", Vector2(120, 80))
	effect.call("play_attack")
	effect.call("update_summon", 0.12, Vector2.ZERO, 4.0)
	var active_points: PackedVector2Array = breath.points
	check(active_points.size() == 13 and breath.visible, "confirmed attack constructs actual breath geometry")
	effect.call("update_summon", 0.4, Vector2.ZERO, 4.0)
	for frame: int in range(30):
		effect.call("update_summon", 1.0 / 60.0, Vector2.ZERO, 4.0)
	check(not breath.visible and breath.points == active_points, "expired dragon keeps hidden breath geometry unchanged across idle frames")
	check(not (effect.get_node("ConfirmedImpact") as Node2D).visible and ring.points == cached_ring, "inactive impact hides cached ring without rebuilding its points")

func _count_nodes(node: Node) -> int:
	var result: int = 1
	if node is CPUParticles2D or node is GPUParticles2D:
		check(false,"fire summon must use bounded deterministic geometry")
	for child: Node in node.get_children():
		result += _count_nodes(child)
	return result

func _render_preview() -> void:
	check(DisplayServer.get_name()!="headless","fire summon preview uses GPU renderer")
	if failures>0:
		quit(1)
		return
	root.size=Vector2i(1000,620)
	var background: ColorRect=ColorRect.new()
	background.color=Color(0.035,0.028,0.04)
	background.size=Vector2(1000,620)
	root.add_child(background)
	for i: int in range(4):
		var effect: Node2D=(load(DRAGON if i<2 else FOX) as PackedScene).instantiate() as Node2D
		root.add_child(effect)
		effect.position=Vector2(230+(i%2)*510,180+(i/2)*260)
		effect.call("configure_summon",{"effect_scale":2.1})
		effect.call("update_summon",0.83,Vector2(100,0),4.0)
		if i%2==1:
			effect.call("set_attack_target",Vector2(-130,65))
			effect.call("play_attack")
			effect.call("update_summon",0.12,Vector2.ZERO,4.0)
		var label: Label=Label.new()
		label.text=["Crimson dragon / wing membranes","Dragon / confirmed targeted breath","Ember fox / flame tail","Fox / confirmed lunge and impact"][i]
		label.position=effect.position+Vector2(-170,90)
		root.add_child(label)
	await settle(8)
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var output: String="E:/codex/fire-vfx/summons/rendered"
	DirAccess.make_dir_recursive_absolute(output)
	check(image.save_png(output+"/summon_anatomy.png")==OK,"save fire summon GPU capture on E drive")
	paused=true
	await settle(4)
	await RenderingServer.frame_post_draw
	var before: Image=root.get_texture().get_image()
	await settle(8)
	await RenderingServer.frame_post_draw
	check(before.get_data()==root.get_texture().get_image().get_data(),"GPU fire summon pixels freeze on pause")
	print("[fire_summon_render] capture="+output+"/summon_anatomy.png failures="+str(failures))
	quit(1 if failures else 0)
