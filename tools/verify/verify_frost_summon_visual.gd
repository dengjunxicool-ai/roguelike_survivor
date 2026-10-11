extends SceneTree

const Controller = preload("res://scripts/summons/summon_controller.gd")
const Definition = preload("res://scripts/summons/summon_definition.gd")
const Registry = preload("res://scripts/combat/combat_target_registry.gd")
const WOLF: String = "res://scenes/effects/frost_wolf_effect.tscn"
const GUARD: String = "res://scenes/effects/ice_crystal_guard_effect.tscn"

class Enemy:
	extends Node2D
	var hits: int = 0
	func take_damage(_packet: DamagePacket) -> void:
		hits += 1
	func is_dead() -> bool:
		return false

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--render-summons" in OS.get_cmdline_user_args():
		await _render_preview()
		return
	var owner: Node2D = Node2D.new()
	root.add_child(owner)
	var wolf: Node2D = _spawn(owner, WOLF)
	var effect: Node2D = wolf.get_node_or_null("SummonEffect") as Node2D
	_expect(effect != null, "effect_scene attaches a custom summon presentation")
	_expect(wolf.get_node_or_null("SummonVisual") == null, "successful custom presentation suppresses icon sprite")
	if effect != null:
		var before: float = float(effect.get("_age"))
		wolf.global_position = Vector2(80, 0)
		wolf.call("_physics_process", 0.1)
		_expect(is_equal_approx(float(effect.get("_age")), before + 0.1), "follow path advances visual exactly once")
		_expect((effect.get("_motion") as Vector2).x < 0.0, "follow movement reaches visual and faces left")
		_expect((effect.get_node("Geometry") as Node2D).scale.x < 0.0, "wolf silhouette mirrors toward actual follow motion")
		wolf.global_position = Vector2(400, 0)
		wolf.call("_physics_process", 0.1)
		_expect(String(wolf.get("state")) == "RETURN" and (effect.get("_motion") as Vector2).x < 0, "early return updates presentation motion")
		var enemy: Enemy = Enemy.new()
		root.add_child(enemy)
		enemy.add_to_group("frost_visual_targets")
		var registry: Node = Registry.get_or_create(root)
		registry.call("register_target", enemy, &"frost_visual_targets")
		wolf.global_position = Vector2.ZERO
		enemy.global_position = Vector2(180, 0)
		wolf.call("_physics_process", 0.1)
		_expect(String(wolf.get("state")) == "CHASE" and (effect.get("_motion") as Vector2).x > 0.0, "chase advances real motion and faces target")
		enemy.global_position = Vector2(24, 0)
		wolf.call("_physics_process", 0.1)
		_expect(enemy.hits == 1 and float(effect.get("_attack_remaining")) > 0.0, "confirmed melee attack starts lunge and preserves hit")
		wolf.call("_physics_process", 0.1)
		_expect(enemy.hits == 1 and float(effect.get("_attack_remaining")) < 0.3, "cooldown does not retrigger visual attack")
		registry.call("unregister_target", enemy, &"frost_visual_targets")
		enemy.free()
		var age: float = float(effect.get("_age"))
		paused = true
		await process_frame
		await process_frame
		_expect(is_equal_approx(age, float(effect.get("_age"))), "pause keeps host-driven animation frozen")
		paused = false
		wolf.set("_remaining_duration", 0.01)
		wolf.call("_physics_process", 0.1)
		_expect(wolf.is_queued_for_deletion() and effect.modulate.a <= 0.001, "authoritative expiry hides presentation")
	for path: String in [WOLF, GUARD]:
		_expect(ResourceLoader.exists(path), "frost scene exists: " + path)
		if not ResourceLoader.exists(path):
			continue
		var node: Node2D = (load(path) as PackedScene).instantiate() as Node2D
		root.add_child(node)
		for method: String in ["configure_summon", "update_summon", "face_direction", "play_attack"]:
			_expect(node.has_method(method), "presentation contract: " + method)
		seed(2419)
		var expected: int = randi()
		seed(2419)
		node.call("configure_summon", {})
		node.call("face_direction", Vector2.LEFT)
		node.call("play_attack")
		node.call("update_summon", 0.1, Vector2(100, 0), 5.0)
		_expect(randi() == expected, "visual update never consumes gameplay RNG")
		_expect(node.get_node_or_null("Geometry") != null, "scene has procedural geometry")
		if path == GUARD:
			var pulse: Line2D = node.get_node("AttackPulse") as Line2D
			_expect(pulse.default_color.a * pulse.modulate.a > 0.1, "guard actual attack cue has visible pulse opacity")
		_check_budget(node)
		node.call("update_summon", 0.1, Vector2.ZERO, 0.0)
		_expect(node.modulate.a <= 0.001, "zero remaining lifetime fades out")
		node.free()
	var legacy: Node2D = _spawn(owner, "")
	_expect(legacy.get_node_or_null("SummonVisual") is Sprite2D, "ordinary summons retain original sprite path")
	legacy.free()
	var detached: Node2D = Controller.new()
	detached.call("setup", {"owner": owner, "definition": Definition.from_dictionary({
		"id": "detached_frost_visual", "visual": {"effect_scene": WOLF, "effect_scale": 1.5}
	})})
	root.add_child(detached)
	_expect(is_equal_approx((detached.get_node("SummonEffect") as Node2D).scale.x, 1.5), "off-tree setup keeps configured scale after ready")
	detached.free()
	if is_instance_valid(wolf) and not wolf.is_queued_for_deletion():
		wolf.free()
	owner.queue_free()
	await process_frame
	if not _failed:
		print("[verify_frost_summon_visual] PASS scenes, motion, confirmed attacks, pause, expiry, budgets, RNG, legacy")
	quit(1 if _failed else 0)

func _spawn(owner: Node2D, scene_path: String) -> Node2D:
	var summon: Node2D = Controller.new()
	root.add_child(summon)
	summon.call("setup", {"owner": owner, "player_power": 10.0,
		"target_group": "frost_visual_targets", "definition": Definition.from_dictionary({
			"id": "frost_visual_fixture", "duration": 5.0,
			"attack": {"attack_range": 52.0, "attack_cooldown": 1.1, "damage_scale": 0.45},
			"visual": {"texture": "res://icon.svg", "effect_scene": scene_path, "scale": 0.16}
		})})
	summon.set_physics_process(false)
	return summon

func _check_budget(node: Node) -> void:
	for child: Node in node.get_children():
		_expect(not child is CPUParticles2D, "no CPU particles")
		if child is GPUParticles2D:
			_expect(child.amount <= 32, "GPU particles bounded to 32 per emitter")
		if child is Sprite2D:
			_expect(child.texture == null, "frost summon never uses placeholder texture")
		_check_budget(child)

func _render_preview() -> void:
	_expect(DisplayServer.get_name() != "headless", "summon preview requires GPU renderer")
	if _failed:
		quit(1)
		return
	root.size = Vector2i(800, 500)
	root.content_scale_size = Vector2i(800, 500)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.035, 0.075, 0.105)
	background.size = Vector2(800, 500)
	root.add_child(background)
	var nodes: Array[Node2D] = []
	for i: int in range(4):
		var effect: Node2D = (load(WOLF if i < 2 else GUARD) as PackedScene).instantiate() as Node2D
		root.add_child(effect)
		effect.position = Vector2(180 + (i % 2) * 420, 150 + floori(float(i) / 2.0) * 240)
		effect.call("configure_summon", {"effect_scale": 2.2})
		effect.call("face_direction", Vector2.RIGHT if i % 2 == 0 else Vector2.LEFT)
		effect.call("update_summon", 0.8, Vector2(150, 0) if i < 2 else Vector2.ZERO, 4.0)
		if i % 2 == 1:
			effect.call("play_attack")
			effect.call("update_summon", 0.12, Vector2.ZERO, 4.0)
		nodes.append(effect)
		var label: Label = Label.new()
		label.text = ["Frost wolf / running", "Frost wolf / confirmed bite", "Crystal guard / floating", "Crystal guard / confirmed pulse"][i]
		label.position = effect.position + Vector2(-125, 65)
		root.add_child(label)
	for i: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	var output: String = "E:/codex/frost-vfx/summons/rendered"
	DirAccess.make_dir_recursive_absolute(output)
	_expect(shown.save_png(output + "/summon_anatomy.png") == OK, "save summon preview on E drive")
	# Shader clock is explicit and particles inherit pause, so a held pose remains pixel stable.
	paused = true
	for i: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var pause_before: Image = root.get_texture().get_image()
	for i: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var pause_after: Image = root.get_texture().get_image()
	_expect(pause_before.get_data() == pause_after.get_data(), "GPU preview freezes every summon pixel on pause")
	paused = false
	for node: Node2D in nodes:
		node.visible = false
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	var changed: int = 0
	for y: int in range(0, 500, 2):
		for x: int in range(0, 800, 2):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.025:
				changed += 1
	_expect(changed > 1500, "wolf and guard geometry alter actual GPU pixels")
	print("[verify_frost_summon_visual] rendered changed_pixels=%d capture=%s/summon_anatomy.png" % [changed, output])
	quit(1 if _failed else 0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("[verify_frost_summon_visual] FAIL " + label)
