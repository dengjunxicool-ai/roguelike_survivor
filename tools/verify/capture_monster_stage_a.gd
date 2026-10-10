## 使用：以真实渲染运行；仅在 E:/codex 隔离目录生成三阶段 30 秒采样与 PNG。
extends SceneTree

const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const AreaScene = preload("res://scenes/combat/damage_area.tscn")
const RunEnvironment = preload("res://tools/verify/verification_run_environment.gd")
var _environment: Dictionary
var _world: Node2D
var _boss: Node2D
var _player: Node2D
var _elapsed := 0.0
var _phase := 0
var _maximum := 0
var _maximum_areas := 0
var _samples: Array = []
var _label: Label
var _ready_to_sample := false

class Arena:
	extends Node2D
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("171d2a"))
		for x in range(0, 1280, 40):
			draw_line(Vector2(x, 0), Vector2(x, 720), Color("263044"))
		for y in range(0, 720, 40):
			draw_line(Vector2(0, y), Vector2(1280, y), Color("263044"))

class Target:
	extends CharacterBody2D
	var hits := 0
	func take_damage(_packet: DamagePacket) -> void:
		hits += 1
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 20, Color("8cddff"))
		draw_arc(Vector2.ZERO, 24, 0, TAU, 32, Color.WHITE, 2, true)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_environment = RunEnvironment.initialize("E:/codex/monster-system/stage-a-render")
	if _environment.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Rendered capture requires isolated E drive storage and real display")
		quit(1)
		return
	if not await RunEnvironment.configure_rendered_viewport():
		quit(1)
		return
	_world = Arena.new()
	root.add_child(_world)
	_player = Target.new()
	_player.add_to_group(&"player")
	var collision := CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 24.0
	_player.add_child(collision)
	_world.add_child(_player)
	_player.position = Vector2(970, 360)
	_boss = EnemyScene.instantiate()
	_boss.set("enemy_id", &"dungeon_heart")
	_world.add_child(_boss)
	_boss.position = Vector2(620, 360)
	_boss.set("target", _player)
	_boss.set("move_speed", 0.0)
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 22)
	_world.add_child(_label)
	for phase_index in range(3):
		_phase = phase_index
		_elapsed = 0.0
		_maximum = 0
		_maximum_areas = 0
		_boss.set("current_health", [5000, 2500, 1000][phase_index])
		_ready_to_sample = true
		var phase_frames: Array = []
		for frame_index in range(4):
			await create_timer(0.25 if frame_index == 0 else 0.3 if frame_index < 3 else 14.15).timeout
			var path: String = _environment.report_dir.path_join("phase_%d_frame_%d.png" % [phase_index + 1, frame_index + 1])
			await _capture(path)
			phase_frames.append({"seconds": _elapsed, "path": path})
		await create_timer(maxf(30.0 - _elapsed, 0.0)).timeout
		_samples.append({"phase": phase_index + 1, "seconds": _elapsed, "max_mechanics": _maximum, "max_area_denial": _maximum_areas, "frames": phase_frames, "hits_received": _player.get("hits")})
		if _maximum > (1 if phase_index == 0 else 2) or _maximum_areas > 1:
			push_error("Rendered live sample exceeded concurrency cap")
			quit(1)
			return
	_ready_to_sample = false
	_boss.set_physics_process(false)
	_boss.get("_boss_mechanic_scheduler").call("reset")
	_player.hide()
	_label.text = "Stage A - Bomber fuse / ring sector / dense area boundary samples"
	var bomber: Node2D = EnemyScene.instantiate()
	bomber.set("enemy_id", &"bomber")
	_world.add_child(bomber)
	bomber.position = Vector2(120, 220)
	bomber.set_physics_process(false)
	_player.position = Vector2(160, 220)
	bomber.set("target", _player)
	bomber.call("_update_behavior", 0.45)
	var telegraph: Node2D = preload("res://scripts/enemies/combat/enemy_attack_telegraph.gd").new()
	_world.add_child(telegraph)
	telegraph.position = Vector2(370, 230)
	telegraph.call("configure", &"ring", {"radius": 150.0, "projectile_count": 12, "safe_gap_count": 2, "safe_gap_start": 11})
	telegraph.call("set_progress", 0.6)
	for index in range(12):
		var area: Node2D = AreaScene.instantiate()
		_world.add_child(area)
		area.position = Vector2(650 + (index % 4) * 140, 210 + (index / 4) * 150)
		area.call("setup", {"use_enemy_lifecycle": true, "warning_time": 0.8, "duration": 2.5, "activation_mode": &"periodic", "area_radius": 78.0, "visual_color": Color(1, 0.15, 0.08, 0.9)})
		area.set_physics_process(false)
		area.call("_physics_process", 0.3 if index % 2 == 0 else 0.81)
	await _capture(_environment.report_dir.path_join("fuse_ring_density.png"))
	var report := FileAccess.open(_environment.report_dir.path_join("samples.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"seed": _environment.seed, "mode": "rendered real enemy/area/projectile nodes; automated invulnerable moving receiver in a synthetic arena", "phase_samples": _samples}, "\t"))
	report.close()
	RunEnvironment.cleanup_save(_environment)
	_world.queue_free()
	await process_frame
	print("[MonsterStageARender] PASS three 30-second phases and real rendered screenshots")
	quit(0)

func _process(delta: float) -> bool:
	if _ready_to_sample:
		_elapsed += delta
		_player.position = Vector2(620, 360) + Vector2.RIGHT.rotated(_elapsed * 0.65) * 380
		var scheduler: RefCounted = _boss.get("_boss_mechanic_scheduler")
		var tokens: Dictionary = scheduler.get("_tokens")
		_maximum = maxi(_maximum, tokens.size())
		var areas := 0
		for record: Dictionary in tokens.values():
			if record.group == &"area_denial":
				areas += 1
		_maximum_areas = maxi(_maximum_areas, areas)
		_label.text = "Stage A | Boss phase %d | %.1fs | mechanisms %d | area denial %d\nAutomated moving receiver; damage counted, no gameplay balance verdict" % [_phase + 1, _elapsed, tokens.size(), areas]
	return false

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(path) != OK:
		push_error("Rendered capture failed: " + path)
	print("[MonsterStageARender] " + path)
