## Diagnostic A/B harness: keeps combat and Node.visible authoritative; only canvas visibility differs.
extends "res://tools/verify/qa_app_fixture.gd"

const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const EFFECT_SCRIPTS: Array[String] = [
	"res://scripts/effects/frost_projectile_effect.gd", "res://scripts/effects/frost_area_effect.gd",
	"res://scripts/effects/frost_status_effect.gd", "res://scripts/effects/frost_hit_effect.gd"
]
var mode: String = "shown"
var report_dir: String = "E:/codex/frost-vfx/stress-ab/shown"
var sample_seconds: float = 4.0
var sample_active: bool = false
var hide_effects: bool = false
var cache_resources: bool = false
var no_projectile_vfx: bool = false
var retained_resources: Array[Resource] = []
var effects: Array[CanvasItem] = []
var totals: Dictionary = {}
var frame_hot_paths: Dictionary = {}
var timed_frames: Array[Dictionary] = []
var peak_projectiles: int = 0


func _register_effect(node: Node) -> void:
	if not node is CanvasItem:
		return
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path in EFFECT_SCRIPTS:
		effects.append(node as CanvasItem)


func _sync_canvases() -> void:
	for index: int in range(effects.size() - 1, -1, -1):
		var effect: CanvasItem = effects[index]
		if not is_instance_valid(effect):
			effects.remove_at(index)
			continue
		RenderingServer.canvas_item_set_visible(effect.get_canvas_item(), effect.visible and not hide_effects)


func _hot_path(section: StringName, duration_us: int) -> void:
	if not sample_active:
		return
	var key: String = String(section)
	if not totals.has(key):
		totals[key] = {"calls": 0, "total_us": 0, "max_us": 0}
	var row: Dictionary = totals[key]
	row.calls += 1
	row.total_us += duration_us
	row.max_us = maxi(row.max_us, duration_us)
	frame_hot_paths[key] = int(frame_hot_paths.get(key, 0)) + duration_us


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--capture-dir="):
			report_dir = argument.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
		elif argument.begins_with("--sample-seconds="):
			sample_seconds = float(argument.trim_prefix("--sample-seconds="))
	hide_effects = mode == "hidden"
	cache_resources = mode == "cached"
	no_projectile_vfx = mode == "no-projectile-vfx"
	check(mode in ["shown", "hidden", "cached", "no-projectile-vfx"], "recognized A/B mode")
	check(DisplayServer.get_name() != "headless", "A/B uses real GPU")
	check(report_dir.begins_with("E:/codex/frost-vfx/stress-ab/"), "diagnostics stay under E drive stress-ab")
	if failures:
		quit(1)
		return
	seed(20261011)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	if cache_resources:
		for path: String in ["res://scenes/effects/frost_projectile_effect.tscn", "res://scenes/effects/frost_field_effect.tscn", "res://scenes/effects/frost_path_effect.tscn", "res://scenes/effects/frost_status_effect.tscn"]:
			if ResourceLoader.exists(path):
				retained_resources.append(load(path))
	node_added.connect(_register_effect)
	root.set_meta(&"real_full_run_profiler_enabled", true)
	root.set_meta(&"real_full_run_profiler_hot_path_event", Callable(self, "_hot_path"))
	var parent: Node = player.get_parent()
	var bus: Node = player.get_node("SkillEventBus")
	bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	bus.get_node("FrostCombatPresentation").process_mode = Node.PROCESS_MODE_PAUSABLE
	var enemies: Array[Node2D] = []
	for index: int in range(16):
		var enemy: Node2D = EnemyScene.instantiate()
		enemy.enemy_id = &"skeleton"
		parent.add_child(enemy)
		enemy.global_position = player.global_position + Vector2.from_angle(float(index) * TAU / 16.0) * 210.0
		enemy.max_health = 10000
		enemy.current_health = 10000
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(enemy)
	var live_areas: Array[AreaEffect] = []
	for index: int in range(8):
		var object_id: String = "frost_field" if index % 2 == 0 else "frost_path"
		var area: AreaEffect = Factory.create_area_effect({
			"parent": parent, "area_id": object_id, "source_id": object_id,
			"position": player.global_position + Vector2.from_angle(float(index) * TAU / 8.0) * 170.0,
			"radius": 134.4, "duration": 9.0, "tick_interval": 0.5, "damage": 4,
			"damage_type": "area_direct", "damage_packet": {"element": "ice", "attacker": player},
			"caster": player, "event_bus": bus, "skill_manager": manager,
			"status_on_hit": &"chilled", "status_params": {"stacks": 1, "duration": 4.0}
		}) as AreaEffect
		area.process_mode = Node.PROCESS_MODE_PAUSABLE
		live_areas.append(area)
	var frames: Array[float] = []
	var spawn_times: Array[float] = []
	var end: int = Time.get_ticks_usec() + int(sample_seconds * 1000000)
	var last: int = Time.get_ticks_usec()
	var burst_at: int = last
	var spawns: int = 0
	sample_active = true
	while Time.get_ticks_usec() < end:
		var now: int = Time.get_ticks_usec()
		var burst_ms: float = 0.0
		if now >= burst_at:
			var burst_start: int = Time.get_ticks_usec()
			burst_at = now + 250000
			for index: int in range(8):
				var angle: float = float(index) * TAU / 8.0 + float(spawns) * 0.015
				var object_id: String = "glacial_lance_projectile" if index % 3 == 0 else ("ice_shard_projectile" if index % 3 == 1 else "ice_crack_shard")
				var params: Dictionary = {
					"parent": parent, "projectile_id": object_id, "position": player.global_position,
					"direction": Vector2.from_angle(angle), "speed": 300.0, "lifetime": 1.6, "pierce": 2,
					"damage": 3, "damage_type": "projectile_small", "damage_packet": {"element": "ice", "attacker": player},
					"caster": player, "event_bus": bus, "skill_manager": manager,
					"status_on_hit": &"chilled", "status_params": {"stacks": 1, "duration": 4.0}
				}
				if no_projectile_vfx:
					params["visual_effect_scene"] = ""
				var projectile: Projectile = Factory.create_projectile(params) as Projectile
				projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
				spawns += 1
			var active: int = 0
			for child: Node in parent.get_children():
				if child is Projectile and child.visible:
					active += 1
			peak_projectiles = maxi(peak_projectiles, active)
			burst_ms = float(Time.get_ticks_usec() - burst_start) / 1000.0
			spawn_times.append(burst_ms)
		_sync_canvases()
		await process_frame
		now = Time.get_ticks_usec()
		var elapsed_ms: float = float(now - last) / 1000.0
		frames.append(elapsed_ms)
		timed_frames.append({"elapsed_ms": elapsed_ms, "burst_ms": burst_ms,
			"time_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"time_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"hot_paths_us": frame_hot_paths.duplicate()})
		frame_hot_paths.clear()
		last = now
	sample_active = false
	var damaged: int = 0
	var healths: Array[int] = []
	for enemy: Node2D in enemies:
		healths.append(enemy.current_health)
		if enemy.current_health < 10000:
			damaged += 1
	check(damaged > 0, "A/B workload applies actual enemy damage")
	check(peak_projectiles >= 24, "A/B retains concurrent moving projectiles")
	var presentation: Node2D = bus.get_node("FrostCombatPresentation")
	check(presentation._hits.size() > 0 and presentation._hits.size() <= 32, "A/B preserves bounded confirmed hit feedback")
	check(live_areas[0]._age > 3.0, "A/B preserves live area clock")
	var report: Dictionary = {
		"mode": mode, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": str(root.size),
		"sample_seconds": sample_seconds, "frames": _summarize(frames), "spawns": spawns,
		"peak_projectiles": peak_projectiles, "spawn_cost": _summarize(spawn_times),
		"targets_damaged": damaged, "target_healths": healths, "hit_pool_nodes": presentation._hits.size(),
		"hot_paths": totals, "timed_frames": timed_frames, "failures": failures
	}
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file: FileAccess = FileAccess.open(report_dir.path_join("stress_ab.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"mode": mode, "frames": report.frames, "spawn_cost": report.spawn_cost, "spawns": spawns, "failures": failures}))
	root.remove_meta(&"real_full_run_profiler_enabled")
	root.remove_meta(&"real_full_run_profiler_hot_path_event")
	await finish()


func _summarize(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	var slow: int = 0
	for value: float in sorted:
		total += value
		if value > 16.67:
			slow += 1
	return {"count": sorted.size(), "mean_ms": total / sorted.size(), "p50_ms": sorted[int(sorted.size() * 0.5)],
		"p95_ms": sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)], "max_ms": sorted[-1], "over_16_ms": slow}
