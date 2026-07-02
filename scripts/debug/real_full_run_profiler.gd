extends Node


const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const SAMPLE_INTERVAL_SECONDS: float = 5.0
const MAX_RUN_SECONDS: float = 900.0
const REPORT_DIR: String = "res://reports/real-full-run-profile"
const SAMPLES_PATH: String = "res://reports/real-full-run-profile/latest_samples.json"
const REPORT_PATH: String = "res://reports/real-full-run-profile/report.md"
const ATTRIBUTION_PATH: String = "res://reports/real-full-run-profile/latest_attribution.json"
const BOSS_DAMAGE_STOP_AMOUNT: int = 1000
const BOSS_DAMAGE_RUN_MAX_SECONDS: float = 1200.0
const SPIKE_CONTEXT_FRAMES: int = 5
const PROFILER_ENABLED_META: StringName = &"real_full_run_profiler_enabled"
const PROFILER_STATUS_EVENT_META: StringName = &"real_full_run_profiler_status_event"

var _enabled: bool = false
var _ui: Node
var _player: Node2D
var _elapsed: float = 0.0
var _next_sample: float = 0.0
var _movement_phase: float = 0.0
var _finished: bool = false
var _last_state: String = ""
var _last_modal_state: String = ""
var _last_tick_usec: int = 0
var _frame_ms_values: Array[float] = []
var _max_frame_ms: float = 0.0
var _spike_33ms_count: int = 0
var _spike_50ms_count: int = 0
var _samples: Array[Dictionary] = []
var _node_created_total: int = 0
var _node_destroyed_total: int = 0
var _node_created_window: int = 0
var _node_destroyed_window: int = 0
var _window_start_seconds: float = 0.0
var _initial_object_count: int = -1
var _final_object_count: int = -1
var _boss_seen: bool = false
var _boss_death_time: float = -1.0
var _boss_start_health: int = -1
var _boss_damage_done: int = 0
var _status: String = "UNKNOWN"
var _failure_reason: String = ""
var _startup_actions: Array[String] = []
var _choices: Array[Dictionary] = []
var _title_reveal_sent: bool = false
var _survival_guard_enabled: bool = false
var _player_health_modified: bool = false
var _frame_index: int = 0
var _current_frame_bucket: Dictionary = {}
var _recent_frame_buckets: Array[Dictionary] = []
var _frame_event_buckets: Array[Dictionary] = []
var _spike_frames_over_50ms: Array[Dictionary] = []
var _spike_frames_over_100ms: Array[Dictionary] = []
var _created_by_key: Dictionary = {}
var _destroyed_by_key: Dictionary = {}
var _created_by_category: Dictionary = {}
var _destroyed_by_category: Dictionary = {}
var _live_by_key: Dictionary = {}
var _live_by_category: Dictionary = {}
var _node_records_by_instance_id: Dictionary = {}
var _connected_tracker_ids: Dictionary = {}
var _run_event_counts: Dictionary = {}
var _status_tick_observation: Dictionary = {
	"source": "StatusEffectManager profiler-only events routed directly to RealFullRunProfiler through root metadata",
	"normal_status_tick_events_observable": true,
	"status_tick_due": 0,
	"status_tick_applied": 0,
	"status_expired": 0,
	"status_visual_spawn": 0,
	"status_visual_update": 0,
	"status_reaction_triggered": 0,
	"status_tick_events": 0,
	"status_reaction_events": 0
}
var _damage_number_created_total: int = 0
var _damage_number_destroyed_total: int = 0
var _damage_number_selector_candidates: Dictionary = {}
var _max_live_counts_by_category: Dictionary = {}


func _ready() -> void:
	_enabled = OS.get_cmdline_args().has("--real-full-run-profile") or OS.get_cmdline_user_args().has("--real-full-run-profile")
	if not _enabled:
		set_process(false)
		return
	_survival_guard_enabled = OS.get_cmdline_args().has("--survival-guard") or OS.get_cmdline_user_args().has("--survival-guard")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	if get_tree() != null and get_tree().root != null:
		get_tree().root.set_meta(PROFILER_ENABLED_META, true)
		get_tree().root.set_meta(PROFILER_STATUS_EVENT_META, Callable(self, "_on_profiler_status_event"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if not get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.connect(_on_node_removed)
	_last_tick_usec = Time.get_ticks_usec()
	_window_start_seconds = 0.0
	_current_frame_bucket = _new_frame_bucket()
	print("[RealFullRunProfile] enabled real startup profile character=%s map=%s" % [String(CHARACTER_ID), String(MAP_ID)])


func _process(_delta: float) -> void:
	if not _enabled or _finished:
		return
	var delta_seconds: float = _record_frame_delta()
	_ui = get_parent().get_node_or_null("UIManager") if _ui == null and get_parent() != null else _ui
	if _ui == null:
		return
	var state: String = String(_ui.get("current_state"))
	if state != _last_state:
		print("[RealFullRunProfile] state %s -> %s at %.1fs" % [_last_state, state, _elapsed])
		_last_state = state
		if state == "RUNNING":
			_last_modal_state = ""
	_drive_state(state, delta_seconds)


func _drive_state(state: String, delta_seconds: float) -> void:
	match state:
		"TITLE":
			_press_start_button()
		"CHARACTER_SELECT":
			_press_named_button("CharacterCard_%s" % String(CHARACTER_ID), "select_character")
			_press_named_button("CharacterConfirmButton", "confirm_character")
		"MAP_SELECT":
			_press_named_button("MapCard_%s" % String(MAP_ID), "select_map")
			_press_named_button("MapStartButton", "start_run")
		"RUNNING":
			_player = get_tree().get_first_node_in_group(&"player") as Node2D
			_elapsed = maxf(_elapsed + delta_seconds, _runtime_elapsed_seconds())
			_connect_run_stats_tracker()
			_apply_survival_guard()
			_drive_player(delta_seconds)
			_track_boss()
			if _elapsed >= _next_sample:
				_record_sample("interval")
				_next_sample += SAMPLE_INTERVAL_SECONDS
			if _boss_seen and _boss_damage_done >= BOSS_DAMAGE_STOP_AMOUNT:
				_record_sample("boss_damage_stop")
				_failure_reason = "stopped after boss lost %d health for attribution run" % BOSS_DAMAGE_STOP_AMOUNT
				_write_outputs("BOSS_DAMAGE_REACHED")
				_finish(0)
			var max_run_seconds: float = BOSS_DAMAGE_RUN_MAX_SECONDS if _boss_seen else MAX_RUN_SECONDS
			if _elapsed >= max_run_seconds:
				_failure_reason = "exceeded %.0fs without boss death or boss damage stop" % max_run_seconds
				_write_outputs("TIMEOUT")
				_finish(1)
		"LEVEL_UP_MODAL", "RUN_REWARD_MODAL", "CURSE_CHOICE_MODAL":
			_release_movement()
			if _last_modal_state != state:
				_last_modal_state = state
				call_deferred("_choose_visible_modal_option", state)
		"RESULT_VICTORY":
			if _boss_death_time < 0.0:
				_boss_death_time = _elapsed
			_record_sample("boss_dead")
			_write_outputs("VICTORY")
			_finish(0)
		"RESULT_DEFEAT":
			_failure_reason = "player reached defeat before boss death"
			_record_sample("defeat")
			_write_outputs("DEFEAT")
			_finish(1)
		_:
			_release_movement()


func _press_start_button() -> void:
	if _startup_actions.has("press_start"):
		return
	var button: Button = _best_visible_button(["start", "adventure", "开始", "冒险"])
	if button == null and not _title_reveal_sent:
		_title_reveal_sent = true
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = true
		Input.parse_input_event(event)
		return
	if button == null:
		return
	if button != null:
		_startup_actions.append("press_start")
		button.emit_signal(&"pressed")


func _press_named_button(node_name: String, action_name: String) -> void:
	if _startup_actions.has(action_name):
		return
	var button: Button = _ui.find_child(node_name, true, false) as Button
	if button == null or button.disabled or not _is_control_visible(button):
		return
	_startup_actions.append(action_name)
	button.emit_signal(&"pressed")


func _choose_visible_modal_option(state: String) -> void:
	if _ui == null or String(_ui.get("current_state")) != state:
		return
	var buttons: Array[Button] = _collect_visible_enabled_buttons(_ui)
	if buttons.is_empty():
		_ui.call("transition_to", "RUNNING")
		_last_modal_state = ""
		return
	var best_button: Button = null
	var best_score: float = -INF
	for button: Button in buttons:
		var score: float = _score_choice_button(button)
		if score > best_score:
			best_score = score
			best_button = button
	if best_button != null:
		_choices.append({
			"time": _elapsed,
			"state": state,
			"text": _safe_text(_button_text(best_button))
		})
		best_button.emit_signal(&"pressed")
	_last_modal_state = ""


func _score_choice_button(button: Button) -> float:
	var text: String = _button_text(button).to_lower()
	var score: float = 0.0
	var hp_percent: float = _hp_percent()
	if text.contains("legendary") or text.contains("史诗") or text.contains("传说"):
		score += 20.0
	if text.contains("fire") or text.contains("flame") or text.contains("burn") or text.contains("火") or text.contains("燃"):
		score += 35.0
	if text.contains("_cast_") or text.contains("_summon_") or text.contains("vortex") or text.contains("lance") or text.contains("dragon"):
		score += 80.0
	if text.contains("boss") or text.contains("damage") or text.contains("伤害") or text.contains("增伤"):
		score += 45.0
	if text.contains("heal") or text.contains("survival") or text.contains("治疗") or text.contains("生命") or text.contains("防御"):
		score += 95.0 if hp_percent < 0.75 else 55.0
	if text.contains("fire_dash_blazing_run") or text.contains("dash") or text.contains("冲刺") or text.contains("疾行"):
		score += 20.0 if hp_percent < 0.45 else -80.0
	if text.contains("curse") or text.contains("诅咒"):
		score -= 20.0
	return score


func _drive_player(delta: float) -> void:
	_movement_phase += delta
	_release_movement()
	if _player == null:
		return
	var direction: Vector2 = _survival_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(_movement_phase * 1.3)
	if direction.x > 0.25:
		Input.action_press(&"move_right")
	elif direction.x < -0.25:
		Input.action_press(&"move_left")
	if direction.y > 0.25:
		Input.action_press(&"move_down")
	elif direction.y < -0.25:
		Input.action_press(&"move_up")
	if _nearest_enemy_distance() < 280.0:
		Input.action_press(&"dash")


func _apply_survival_guard() -> void:
	if not _survival_guard_enabled or _player == null:
		return
	var max_health: int = maxi(int(_player.get("max_health")), 1)
	var current_health: int = int(_player.get("current_health"))
	if current_health < int(float(max_health) * 0.9):
		_player.set("current_health", max_health)
		_player_health_modified = true


func _survival_direction() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var repulsion: Vector2 = Vector2.ZERO
	var attraction: Vector2 = Vector2.ZERO
	var nearest_distance: float = INF
	for enemy_node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null:
			continue
		var offset: Vector2 = _player.global_position - enemy.global_position
		var distance: float = maxf(offset.length(), 1.0)
		nearest_distance = minf(nearest_distance, distance)
		var avoid_radius: float = 680.0 if _is_boss(enemy) else 520.0
		if distance < avoid_radius:
			repulsion += offset.normalized() * pow((avoid_radius - distance) / avoid_radius, 1.1) * (avoid_radius / distance)
		if distance < 130.0:
			repulsion += offset.normalized() * 6.0
	for gem_node: Node in get_tree().get_nodes_in_group(&"experience_crystal"):
		var gem: Node2D = gem_node as Node2D
		if gem == null:
			continue
		var to_gem: Vector2 = gem.global_position - _player.global_position
		var distance_to_gem: float = to_gem.length()
		if distance_to_gem < 260.0 and nearest_distance > 220.0:
			attraction += to_gem.normalized() * ((320.0 - distance_to_gem) / 320.0)
	var orbit: Vector2 = Vector2.RIGHT.rotated(_movement_phase * 1.1)
	if _bounds_penalty(_player.global_position) > 0.25:
		var center_escape: Vector2 = _movement_bounds_center() - _player.global_position
		if center_escape != Vector2.ZERO:
			return center_escape.normalized()
	if nearest_distance < 420.0 or _hp_percent() < 0.55:
		var escape: Vector2 = _best_escape_direction()
		if escape != Vector2.ZERO:
			return escape
	var desired: Vector2 = repulsion * 2.5 + attraction * 0.4 + _movement_center_push() * 1.6 + _movement_bounds_push() * 12.0 + orbit * 0.25
	return desired.normalized() if desired != Vector2.ZERO else Vector2.ZERO


func _best_escape_direction() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var best_direction: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for index: int in range(16):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 16.0)
		var score: float = _escape_direction_score(direction)
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction


func _escape_direction_score(direction: Vector2) -> float:
	if _player == null:
		return -INF
	var next_position: Vector2 = _player.global_position + direction.normalized() * 260.0
	var nearest_after_step: float = INF
	var crowd_penalty: float = 0.0
	for item: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy == null:
			continue
		var distance: float = maxf(next_position.distance_to(enemy.global_position), 1.0)
		nearest_after_step = minf(nearest_after_step, distance)
		if distance < 460.0:
			crowd_penalty += (460.0 - distance) / 460.0
	var edge_penalty: float = _bounds_penalty(next_position)
	var center: Vector2 = _movement_bounds_center()
	var center_score: float = 0.0
	if center != Vector2.ZERO:
		center_score = -next_position.distance_to(center) * 0.018
	return nearest_after_step - crowd_penalty * 115.0 - edge_penalty * 1100.0 + center_score


func _record_frame_delta() -> float:
	var now_usec: int = Time.get_ticks_usec()
	if _last_tick_usec <= 0:
		_last_tick_usec = now_usec
		return 1.0 / 60.0
	var frame_ms: float = float(now_usec - _last_tick_usec) / 1000.0
	_last_tick_usec = now_usec
	if frame_ms > 0.0 and frame_ms < 1000.0:
		_finalize_frame_bucket(frame_ms)
		_frame_ms_values.append(frame_ms)
		_max_frame_ms = maxf(_max_frame_ms, frame_ms)
		if frame_ms >= 33.333:
			_spike_33ms_count += 1
		if frame_ms >= 50.0:
			_spike_50ms_count += 1
	return clampf(frame_ms / 1000.0, 0.0, 0.25) if frame_ms > 0.0 else 1.0 / 60.0


func _record_sample(reason: String) -> void:
	var object_count: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	if _initial_object_count < 0:
		_initial_object_count = object_count
	_final_object_count = object_count
	var window_seconds: float = maxf(_elapsed - _window_start_seconds, 0.001)
	var projectile_count: int = get_tree().get_nodes_in_group(&"projectile").size()
	var enemy_projectile_count: int = get_tree().get_nodes_in_group(&"enemy_projectile").size()
	var sample: Dictionary = {
		"reason": reason,
		"elapsed_seconds": _elapsed,
		"avg_fps": _average_fps(),
		"engine_fps": Engine.get_frames_per_second(),
		"avg_frame_ms": _average(_frame_ms_values),
		"p95_frame_ms": _percentile(_frame_ms_values, 0.95),
		"p99_frame_ms": _percentile(_frame_ms_values, 0.99),
		"max_frame_ms": _max_frame_ms,
		"frames_over_33ms": _spike_33ms_count,
		"frames_over_50ms": _spike_50ms_count,
		"process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
		"physics_process_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
		"enemy_count": get_tree().get_nodes_in_group(&"enemy").size(),
		"projectile_count": projectile_count + enemy_projectile_count,
		"player_projectile_count": projectile_count,
		"enemy_projectile_count": enemy_projectile_count,
		"area_effect_count": _count_nodes_by_script("area_effect.gd"),
		"pickup_count": get_tree().get_nodes_in_group(&"experience_crystal").size(),
		"damage_number_count": _count_nodes_by_script("damage_number_popup.gd"),
		"status_effect_instance_count": _count_status_effect_instances(),
		"nodes_created_per_minute": float(_node_created_window) / window_seconds * 60.0,
		"nodes_destroyed_per_minute": float(_node_destroyed_window) / window_seconds * 60.0,
		"node_created_total": _node_created_total,
		"node_destroyed_total": _node_destroyed_total,
		"object_count": object_count,
		"object_count_delta": object_count - _initial_object_count,
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"debug_panel": _debug_panel_snapshot(),
		"boss": _boss_snapshot(),
		"player": _player_snapshot()
	}
	_samples.append(sample)
	print("[RealFullRunProfile] t=%.1f fps=%.1f p95=%.2fms p99=%.2fms enemies=%d projectiles=%d areas=%d pickups=%d statuses=%d obj_delta=%d debug=%s" % [
		_elapsed,
		float(sample.get("avg_fps", 0.0)),
		float(sample.get("p95_frame_ms", 0.0)),
		float(sample.get("p99_frame_ms", 0.0)),
		int(sample.get("enemy_count", 0)),
		int(sample.get("projectile_count", 0)),
		int(sample.get("area_effect_count", 0)),
		int(sample.get("pickup_count", 0)),
		int(sample.get("status_effect_instance_count", 0)),
		int(sample.get("object_count_delta", 0)),
		_debug_panel_summary(_dict(sample.get("debug_panel", {})))
	])
	_node_created_window = 0
	_node_destroyed_window = 0
	_window_start_seconds = _elapsed


func _write_outputs(status: String) -> void:
	_status = status
	var payload: Dictionary = {
		"status": status,
		"failure_reason": _failure_reason,
		"character": String(CHARACTER_ID),
		"map": String(MAP_ID),
		"real_startup": true,
		"headless": DisplayServer.get_name().to_lower() == "headless",
		"time_scale": Engine.time_scale,
		"survival_guard_enabled": _survival_guard_enabled,
		"player_health_modified": _player_health_modified,
		"boss_health_modified": false,
		"elapsed_seconds": _elapsed,
		"boss_seen": _boss_seen,
		"boss_death_time": _boss_death_time,
		"frame_count": _frame_ms_values.size(),
		"avg_fps": _average_fps(),
		"avg_frame_ms": _average(_frame_ms_values),
		"p95_frame_ms": _percentile(_frame_ms_values, 0.95),
		"p99_frame_ms": _percentile(_frame_ms_values, 0.99),
		"max_frame_ms": _max_frame_ms,
		"frames_over_33ms": _spike_33ms_count,
		"frames_over_50ms": _spike_50ms_count,
		"object_count_start": _initial_object_count,
		"object_count_end": _final_object_count,
		"object_count_delta": _final_object_count - _initial_object_count,
		"node_created_total": _node_created_total,
		"node_destroyed_total": _node_destroyed_total,
		"startup_actions": _startup_actions,
		"choices": _choices,
		"samples": _samples
	}
	var file: FileAccess = FileAccess.open(SAMPLES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	_write_attribution_output(status)
	var lines: Array[String] = [
		"# Real Full Run Performance Profile",
		"",
		"- status: %s" % status,
		"- failure_reason: %s" % _failure_reason,
		"- character: %s" % String(CHARACTER_ID),
		"- map: %s" % String(MAP_ID),
		"- real_startup: true",
		"- headless: %s" % str(DisplayServer.get_name().to_lower() == "headless"),
		"- time_scale: %.1f" % Engine.time_scale,
		"- survival_guard_enabled: %s" % str(_survival_guard_enabled),
		"- player_health_modified: %s" % str(_player_health_modified),
		"- boss_health_modified: false",
		"- elapsed_seconds: %.1f" % _elapsed,
		"- boss_seen: %s" % str(_boss_seen),
		"- boss_death_time: %.1f" % _boss_death_time,
		"- frame_count: %d" % _frame_ms_values.size(),
		"- avg_fps: %.1f" % _average_fps(),
		"- avg_frame_ms: %.2f" % _average(_frame_ms_values),
		"- p95_frame_ms: %.2f" % _percentile(_frame_ms_values, 0.95),
		"- p99_frame_ms: %.2f" % _percentile(_frame_ms_values, 0.99),
		"- max_frame_ms: %.2f" % _max_frame_ms,
		"- frames_over_33ms: %d" % _spike_33ms_count,
		"- frames_over_50ms: %d" % _spike_50ms_count,
		"- object_count_start: %d" % _initial_object_count,
		"- object_count_end: %d" % _final_object_count,
		"- object_count_delta: %d" % (_final_object_count - _initial_object_count),
		"- node_created_total: %d" % _node_created_total,
		"- node_destroyed_total: %d" % _node_destroyed_total,
		"- samples_json: %s" % ProjectSettings.globalize_path(SAMPLES_PATH),
		"",
		"## Samples",
		"",
		"| t | fps | p95 ms | p99 ms | enemies | projectiles | areas | pickups | damage nums | statuses | create/min | destroy/min | objects delta | debug |",
		"| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |"
	]
	for sample: Dictionary in _samples:
		lines.append("| %.1f | %.1f | %.2f | %.2f | %d | %d | %d | %d | %d | %d | %.1f | %.1f | %d | %s |" % [
			float(sample.get("elapsed_seconds", 0.0)),
			float(sample.get("avg_fps", 0.0)),
			float(sample.get("p95_frame_ms", 0.0)),
			float(sample.get("p99_frame_ms", 0.0)),
			int(sample.get("enemy_count", 0)),
			int(sample.get("projectile_count", 0)),
			int(sample.get("area_effect_count", 0)),
			int(sample.get("pickup_count", 0)),
			int(sample.get("damage_number_count", 0)),
			int(sample.get("status_effect_instance_count", 0)),
			float(sample.get("nodes_created_per_minute", 0.0)),
			float(sample.get("nodes_destroyed_per_minute", 0.0)),
			int(sample.get("object_count_delta", 0)),
			_debug_panel_summary(_dict(sample.get("debug_panel", {})))
		])
	file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	print("[RealFullRunProfile] report=%s" % ProjectSettings.globalize_path(REPORT_PATH))


func _track_boss() -> void:
	var boss: Node2D = _boss()
	if boss != null and not _boss_seen:
		_boss_seen = true
		_boss_start_health = int(boss.get("current_health"))
		print("[RealFullRunProfile] boss_spawned hp=%d/%d at %.1fs" % [_boss_start_health, int(boss.get("max_health")), _elapsed])
	if boss != null and _boss_start_health >= 0:
		_boss_damage_done = maxi(_boss_start_health - int(boss.get("current_health")), 0)


func _runtime_elapsed_seconds() -> float:
	if _ui != null:
		var ui_seconds: float = float(_ui.get("_run_seconds"))
		if ui_seconds > 0.0:
			return ui_seconds
	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null:
		return float(spawner.get("_elapsed_time"))
	return _elapsed


func _boss() -> Node2D:
	for item: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null and _is_boss(enemy):
			return enemy
	return null


func _is_boss(enemy: Node) -> bool:
	return enemy != null and (enemy.is_in_group(&"bosses") or bool(enemy.get_meta("is_boss", false)) or String(enemy.get_meta("enemy_rank", "")) == "boss" or String(enemy.get_meta("enemy_type", "")) == "boss")


func _boss_snapshot() -> Dictionary:
	var boss: Node2D = _boss()
	if boss == null:
		return {}
	return {
		"id": String(boss.get("enemy_id")),
		"current_health": int(boss.get("current_health")),
		"max_health": int(boss.get("max_health")),
		"position": [boss.global_position.x, boss.global_position.y]
	}


func _player_snapshot() -> Dictionary:
	if _player == null:
		return {}
	return {
		"current_health": int(_player.get("current_health")),
		"max_health": int(_player.get("max_health")),
		"level": int(_player.get("level")),
		"position": [_player.global_position.x, _player.global_position.y]
	}


func _movement_bounds_push() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	var margin: float = 260.0
	var position: Vector2 = _player.global_position
	var push: Vector2 = Vector2.ZERO
	var left: float = bounds.position.x
	var top: float = bounds.position.y
	var right: float = bounds.position.x + bounds.size.x
	var bottom: float = bounds.position.y + bounds.size.y
	if position.x < left + margin:
		push.x += (left + margin - position.x) / margin
	elif position.x > right - margin:
		push.x -= (position.x - (right - margin)) / margin
	if position.y < top + margin:
		push.y += (top + margin - position.y) / margin
	elif position.y > bottom - margin:
		push.y -= (position.y - (bottom - margin)) / margin
	return push


func _movement_center_push() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.ZERO
	var to_center: Vector2 = bounds.get_center() - _player.global_position
	var max_distance: float = maxf(minf(bounds.size.x, bounds.size.y) * 0.5, 1.0)
	var strength: float = clampf(to_center.length() / max_distance, 0.0, 1.0)
	return to_center.normalized() * strength if to_center.length_squared() > 0.01 else Vector2.ZERO


func _bounds_penalty(position: Vector2) -> float:
	if _player == null:
		return 0.0
	var bounds: Rect2 = _player.get("_movement_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var margin: float = 190.0
	var left: float = bounds.position.x
	var top: float = bounds.position.y
	var right: float = bounds.position.x + bounds.size.x
	var bottom: float = bounds.position.y + bounds.size.y
	var penalty: float = 0.0
	penalty += maxf((left + margin - position.x) / margin, 0.0)
	penalty += maxf((position.x - (right - margin)) / margin, 0.0)
	penalty += maxf((top + margin - position.y) / margin, 0.0)
	penalty += maxf((position.y - (bottom - margin)) / margin, 0.0)
	return penalty


func _movement_bounds_center() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	return bounds.get_center() if bounds.size.x > 0.0 and bounds.size.y > 0.0 else Vector2.ZERO


func _nearest_enemy_distance() -> float:
	if _player == null:
		return INF
	var nearest: float = INF
	for item: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null:
			nearest = minf(nearest, _player.global_position.distance_to(enemy.global_position))
	return nearest


func _hp_percent() -> float:
	if _player == null:
		return 1.0
	return clampf(float(_player.get("current_health")) / maxf(float(_player.get("max_health")), 1.0), 0.0, 1.0)


func _count_nodes_by_script(script_name: String) -> int:
	var count: int = 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with(script_name):
			count += 1
		for child: Node in node.get_children():
			stack.append(child)
	return count


func _count_status_effect_instances() -> int:
	var count: int = 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("get_status_snapshot"):
			var snapshot: Variant = node.call("get_status_snapshot")
			if snapshot is Array:
				count += (snapshot as Array).size()
		for child: Node in node.get_children():
			stack.append(child)
	return count


func _debug_panel_snapshot() -> Dictionary:
	var count: int = 0
	var visible_count: int = 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with("dev_debug_panel.gd"):
			count += 1
			if node is CanvasItem and (node as CanvasItem).visible:
				visible_count += 1
		for child: Node in node.get_children():
			stack.append(child)
	return {"present": count > 0, "count": count, "visible_count": visible_count, "enabled": visible_count > 0}


func _connect_run_stats_tracker() -> void:
	for tracker: Node in get_tree().get_nodes_in_group(&"run_stats_tracker"):
		var instance_id: int = int(tracker.get_instance_id())
		if _connected_tracker_ids.has(instance_id):
			continue
		if tracker.has_signal("event_recorded"):
			tracker.connect("event_recorded", Callable(self, "_on_run_event_recorded"))
			_connected_tracker_ids[instance_id] = true


func _on_run_event_recorded(event_name: StringName, payload: Dictionary) -> void:
	var event_key: String = String(event_name)
	_increment_dict(_run_event_counts, event_key, 1)
	var damage_type: String = String(payload.get("damage_type", ""))
	if event_key == "damage_done" and damage_type == "status_dot":
		_add_frame_metric("status_tick", "status", 1)
		_increment_dict(_status_tick_observation, "status_tick_events", 1)
	if event_key == "shock_triggered" or damage_type == "reaction" or damage_type == "reaction_damage":
		_add_frame_metric("reaction", "status", 1)
		_increment_dict(_status_tick_observation, "status_reaction_events", 1)
	if event_key == "status_applied":
		var status_id: String = String(payload.get("status_id", ""))
		if ["overload", "combustion", "shatter", "soul_burn", "shock"].has(status_id):
			_add_frame_metric("reaction", "status", 1)
			_increment_dict(_status_tick_observation, "status_reaction_events", 1)


func _on_profiler_status_event(event_name: StringName, payload: Dictionary) -> void:
	var event_key: String = String(event_name)
	if not _is_profiler_status_event(event_key):
		return
	_increment_dict(_run_event_counts, event_key, 1)
	_record_profiler_status_event(event_key, payload)


func _is_profiler_status_event(event_key: String) -> bool:
	return [
		"status_tick_due",
		"status_tick_applied",
		"status_expired",
		"status_visual_spawn",
		"status_visual_update",
		"status_reaction_triggered"
	].has(event_key)


func _record_profiler_status_event(event_key: String, _payload: Dictionary) -> void:
	_increment_dict(_status_tick_observation, event_key, 1)
	_add_frame_metric(event_key, "status", 1)
	match event_key:
		"status_tick_applied":
			_add_frame_metric("status_tick", "status", 1)
			_increment_dict(_status_tick_observation, "status_tick_events", 1)
		"status_reaction_triggered":
			_add_frame_metric("reaction", "status", 1)
			_increment_dict(_status_tick_observation, "status_reaction_events", 1)


func _new_frame_bucket() -> Dictionary:
	return {
		"frame_index": _frame_index,
		"elapsed_seconds": _elapsed,
		"created_total": 0,
		"destroyed_total": 0,
		"created_by_category": {},
		"destroyed_by_category": {},
		"created_by_key": {},
		"destroyed_by_key": {},
		"status_tick": 0,
		"status_tick_due": 0,
		"status_tick_applied": 0,
		"status_expired": 0,
		"status_visual_spawn": 0,
		"status_visual_update": 0,
		"status_reaction_triggered": 0,
		"reaction": 0
	}


func _finalize_frame_bucket(frame_ms: float) -> void:
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	_current_frame_bucket["frame_ms"] = frame_ms
	_current_frame_bucket["category_activity"] = _spike_category_activity(_current_frame_bucket)
	var has_activity: bool = int(_current_frame_bucket.get("created_total", 0)) > 0 \
		or int(_current_frame_bucket.get("destroyed_total", 0)) > 0 \
		or int(_current_frame_bucket.get("status_tick", 0)) > 0 \
		or int(_current_frame_bucket.get("reaction", 0)) > 0 \
		or _status_profiler_activity_total(_current_frame_bucket) > 0
	if has_activity:
		_frame_event_buckets.append(_current_frame_bucket.duplicate(true))
	if frame_ms >= 50.0:
		var spike: Dictionary = _current_frame_bucket.duplicate(true)
		spike["context_previous_frames"] = _recent_frame_buckets.duplicate(true)
		if frame_ms >= 100.0:
			_spike_frames_over_100ms.append(spike.duplicate(true))
		_spike_frames_over_50ms.append(spike)
	_recent_frame_buckets.append(_current_frame_bucket.duplicate(true))
	while _recent_frame_buckets.size() > SPIKE_CONTEXT_FRAMES:
		_recent_frame_buckets.pop_front()
	_frame_index += 1
	_current_frame_bucket = _new_frame_bucket()


func _spike_category_activity(bucket: Dictionary) -> Dictionary:
	var activity: Dictionary = {}
	var created: Dictionary = _dict(bucket.get("created_by_category", {}))
	var destroyed: Dictionary = _dict(bucket.get("destroyed_by_category", {}))
	for category: String in ["aoe", "status", "pickup", "transient_vfx"]:
		activity[category] = {
			"created": int(created.get(category, 0)),
			"destroyed": int(destroyed.get(category, 0)),
			"tick": int(bucket.get("status_tick", 0)) if category == "status" else 0,
			"tick_due": int(bucket.get("status_tick_due", 0)) if category == "status" else 0,
			"tick_applied": int(bucket.get("status_tick_applied", 0)) if category == "status" else 0,
			"expired": int(bucket.get("status_expired", 0)) if category == "status" else 0,
			"visual_spawn": int(bucket.get("status_visual_spawn", 0)) if category == "status" else 0,
			"visual_update": int(bucket.get("status_visual_update", 0)) if category == "status" else 0,
			"reaction": int(bucket.get("reaction", 0)) if category == "status" else 0,
			"reaction_triggered": int(bucket.get("status_reaction_triggered", 0)) if category == "status" else 0,
			"live": int(_live_by_category.get(category, 0))
		}
	return activity


func _status_profiler_activity_total(bucket: Dictionary) -> int:
	var total: int = 0
	for key: String in [
		"status_tick_due",
		"status_tick_applied",
		"status_expired",
		"status_visual_spawn",
		"status_visual_update",
		"status_reaction_triggered"
	]:
		total += int(bucket.get(key, 0))
	return total


func _add_frame_node_event(kind: String, record: Dictionary) -> void:
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	var category: String = String(record.get("category", "other"))
	var key: String = String(record.get("key", "unknown"))
	if kind == "created":
		_current_frame_bucket["created_total"] = int(_current_frame_bucket.get("created_total", 0)) + 1
		_increment_dict(_dict(_current_frame_bucket.get("created_by_category", {})), category, 1)
		_increment_dict(_dict(_current_frame_bucket.get("created_by_key", {})), key, 1)
	else:
		_current_frame_bucket["destroyed_total"] = int(_current_frame_bucket.get("destroyed_total", 0)) + 1
		_increment_dict(_dict(_current_frame_bucket.get("destroyed_by_category", {})), category, 1)
		_increment_dict(_dict(_current_frame_bucket.get("destroyed_by_key", {})), key, 1)


func _add_frame_metric(metric: String, category: String, amount: int) -> void:
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	_current_frame_bucket[metric] = int(_current_frame_bucket.get(metric, 0)) + amount
	var key: String = "%s_%s" % [category, metric]
	_increment_dict(_run_event_counts, key, amount)


func _node_record(node: Node) -> Dictionary:
	var script: Script = node.get_script() as Script
	var script_path: String = script.resource_path if script != null else ""
	var scene_path: String = _node_scene_path(node)
	var category: String = _node_category(node, script_path, scene_path)
	var record: Dictionary = {
		"key": _node_attribution_key(node, script_path, scene_path),
		"category": category,
		"node_name": String(node.name),
		"class": node.get_class(),
		"script_path": script_path,
		"scene_path": scene_path
	}
	return record


func _node_scene_path(node: Node) -> String:
	if node.scene_file_path != "":
		return node.scene_file_path
	var owner_node: Node = node.owner
	if owner_node != null and owner_node.scene_file_path != "":
		return owner_node.scene_file_path
	return ""


func _node_attribution_key(node: Node, script_path: String, scene_path: String) -> String:
	var scene_key: String = scene_path if scene_path != "" else "no_scene"
	var script_key: String = script_path if script_path != "" else "no_script"
	return "%s|%s|%s|%s" % [scene_key, script_key, node.get_class(), String(node.name)]


func _node_category(node: Node, script_path: String, scene_path: String) -> String:
	var node_name: String = String(node.name).to_lower()
	var node_class: String = node.get_class()
	var combined_path: String = ("%s %s" % [script_path, scene_path]).to_lower()
	if script_path.ends_with("area_effect.gd") or node.is_in_group(&"area_effects") or node.is_in_group(&"areas"):
		return "aoe"
	if script_path.ends_with("status_effect_manager.gd") or node_name.contains("status"):
		return "status"
	if script_path.ends_with("exp_gem.gd") or node.is_in_group(&"experience_crystal") or combined_path.contains("experience_crystal"):
		return "pickup"
	if _is_damage_number_node(node, script_path):
		return "damage_number"
	if node.is_in_group(&"projectile") or node.is_in_group(&"enemy_projectile") or script_path.ends_with("projectile.gd") or combined_path.contains("projectile"):
		return "projectile"
	if node.is_in_group(&"enemy") or combined_path.contains("scenes/enemies"):
		return "enemy"
	if node_class.contains("Particles") or node_class == "Line2D" or node_name.contains("vfx") or node_name.contains("effect") or node_name.contains("afterimage") or combined_path.contains("visual_effect"):
		return "transient_vfx"
	if node is Control or node is CanvasLayer:
		return "ui"
	return "other"


func _is_damage_number_node(node: Node, script_path: String = "") -> bool:
	var node_name: String = String(node.name).to_lower()
	return script_path.ends_with("damage_number_popup.gd") \
		or node_name.contains("damagenumber") \
		or node_name.contains("damage_number") \
		or node_name.contains("playerdamagenumber")


func _record_live_delta(record: Dictionary, delta: int) -> void:
	var key: String = String(record.get("key", "unknown"))
	var category: String = String(record.get("category", "other"))
	_increment_dict(_live_by_key, key, delta)
	_increment_dict(_live_by_category, category, delta)
	_max_live_counts_by_category[category] = maxi(int(_max_live_counts_by_category.get(category, 0)), int(_live_by_category.get(category, 0)))


func _top_entries(source: Dictionary, limit: int = 25) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key_variant: Variant in source.keys():
		var key: String = String(key_variant)
		entries.append({"key": key, "count": int(source.get(key_variant, 0))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return entries.slice(0, mini(limit, entries.size()))


func _net_nodes_by_key() -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in _created_by_key.keys():
		var key: String = String(key_variant)
		result[key] = int(_created_by_key.get(key, 0)) - int(_destroyed_by_key.get(key, 0))
	for key_variant: Variant in _destroyed_by_key.keys():
		var key: String = String(key_variant)
		if not result.has(key):
			result[key] = -int(_destroyed_by_key.get(key, 0))
	return result


func _net_nodes_by_category() -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in _created_by_category.keys():
		var key: String = String(key_variant)
		result[key] = int(_created_by_category.get(key, 0)) - int(_destroyed_by_category.get(key, 0))
	for key_variant: Variant in _destroyed_by_category.keys():
		var key: String = String(key_variant)
		if not result.has(key):
			result[key] = -int(_destroyed_by_category.get(key, 0))
	return result


func _damage_number_diagnosis() -> Dictionary:
	var current_candidates: Array[Dictionary] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script() as Script
		var script_path: String = script.resource_path if script != null else ""
		if _is_damage_number_node(node, script_path):
			current_candidates.append(_node_record(node))
		for child: Node in node.get_children():
			stack.append(child)
	var damage_events: int = int(_run_event_counts.get("damage_done", 0)) + int(_run_event_counts.get("damage_taken", 0))
	var diagnosis: String = ""
	if _damage_number_created_total > 0 and current_candidates.is_empty():
		diagnosis = "selector can identify damage-number nodes, but their lifetime is shorter than the 5s sample interval"
	elif _damage_number_created_total > 0:
		diagnosis = "damage-number nodes were created and are selector-visible"
	elif damage_events > 0:
		diagnosis = "damage events occurred but no damage-number nodes were created; likely disabled for this path or gated by debug/display conditions"
	else:
		diagnosis = "no observed damage events and no damage-number nodes"
	return {
		"diagnosis": diagnosis,
		"created_total": _damage_number_created_total,
		"destroyed_total": _damage_number_destroyed_total,
		"current_selector_count": current_candidates.size(),
		"damage_events_observed": damage_events,
		"damage_number_selector_candidates": current_candidates,
		"historical_selector_candidates": _damage_number_selector_candidates
	}


func _object_delta_attribution() -> Dictionary:
	var object_delta: int = _final_object_count - _initial_object_count
	var node_net: Dictionary = _net_nodes_by_category()
	var node_backed_total: int = 0
	for value: Variant in node_net.values():
		node_backed_total += int(value)
	return {
		"object_count_start": _initial_object_count,
		"object_count_end": _final_object_count,
		"object_count_delta": object_delta,
		"node_backed_object_delta_attribution": node_net,
		"node_backed_net_total": node_backed_total,
		"unattributed_object_delta": object_delta - node_backed_total,
		"limitation": "Godot Performance.OBJECT_COUNT exposes total ObjectDB count but not object enumeration; non-Node RefCounted/Resource deltas are reported as unattributed."
	}


func _write_attribution_output(status: String) -> void:
	_finalize_frame_bucket(0.0)
	var payload: Dictionary = {
		"status": status,
		"failure_reason": _failure_reason,
		"character": String(CHARACTER_ID),
		"map": String(MAP_ID),
		"elapsed_seconds": _elapsed,
		"boss_seen": _boss_seen,
		"boss_start_health": _boss_start_health,
		"boss_damage_done": _boss_damage_done,
		"boss_damage_stop_amount": BOSS_DAMAGE_STOP_AMOUNT,
		"node_created_total": _node_created_total,
		"node_destroyed_total": _node_destroyed_total,
		"created_by_key": _created_by_key,
		"destroyed_by_key": _destroyed_by_key,
		"net_nodes_by_key": _net_nodes_by_key(),
		"created_by_category": _created_by_category,
		"destroyed_by_category": _destroyed_by_category,
		"net_nodes_by_category": _net_nodes_by_category(),
		"live_by_category": _live_by_category,
		"max_live_counts_by_category": _max_live_counts_by_category,
		"top_created_by_key": _top_entries(_created_by_key, 40),
		"top_destroyed_by_key": _top_entries(_destroyed_by_key, 40),
		"top_net_nodes_by_key": _top_entries(_net_nodes_by_key(), 40),
		"frame_event_buckets": _frame_event_buckets,
		"spike_frames_over_50ms": _spike_frames_over_50ms,
		"spike_frames_over_100ms": _spike_frames_over_100ms,
		"status_tick_observation": _status_tick_observation,
		"run_event_counts": _run_event_counts,
		"damage_number_diagnosis": _damage_number_diagnosis(),
		"object_delta_attribution": _object_delta_attribution()
	}
	var file: FileAccess = FileAccess.open(ATTRIBUTION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	print("[RealFullRunProfile] attribution=%s" % ProjectSettings.globalize_path(ATTRIBUTION_PATH))


func _collect_visible_enabled_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root == null:
		return buttons
	if root is Button and not (root as Button).disabled and _is_control_visible(root as Button):
		buttons.append(root as Button)
	for child: Node in root.get_children():
		buttons.append_array(_collect_visible_enabled_buttons(child))
	return buttons


func _first_visible_enabled_button(root: Node) -> Button:
	var buttons: Array[Button] = _collect_visible_enabled_buttons(root)
	return buttons[0] if not buttons.is_empty() else null


func _best_visible_button(needles: Array[String]) -> Button:
	var best: Button = null
	var best_score: int = 0
	for button: Button in _collect_visible_enabled_buttons(_ui):
		var text: String = _button_text(button).to_lower()
		var score: int = 0
		for needle: String in needles:
			if text.contains(needle.to_lower()):
				score += 1
		if score > best_score:
			best_score = score
			best = button
	return best


func _button_text(button: Button) -> String:
	var parts: Array[String] = []
	if button.text.strip_edges() != "":
		parts.append(button.text)
	_collect_label_text(button, parts)
	return " ".join(parts)


func _collect_label_text(root: Node, parts: Array[String]) -> void:
	for child: Node in root.get_children():
		if child is Label:
			var label_text: String = (child as Label).text.strip_edges()
			if label_text != "":
				parts.append(label_text)
		_collect_label_text(child, parts)


func _is_control_visible(control: Control) -> bool:
	return control != null and control.is_visible_in_tree()


func _on_node_added(_node: Node) -> void:
	if _enabled:
		_node_created_total += 1
		_node_created_window += 1
		var record: Dictionary = _node_record(_node)
		var instance_id: int = int(_node.get_instance_id())
		_node_records_by_instance_id[instance_id] = record
		_increment_dict(_created_by_key, String(record.get("key", "unknown")), 1)
		_increment_dict(_created_by_category, String(record.get("category", "other")), 1)
		_record_live_delta(record, 1)
		_add_frame_node_event("created", record)
		if String(record.get("category", "")) == "damage_number":
			_damage_number_created_total += 1
			_damage_number_selector_candidates[str(instance_id)] = record


func _on_node_removed(_node: Node) -> void:
	if _enabled:
		_node_destroyed_total += 1
		_node_destroyed_window += 1
		var instance_id: int = int(_node.get_instance_id())
		var record: Dictionary = _dict(_node_records_by_instance_id.get(instance_id, {}))
		if record.is_empty():
			record = _node_record(_node)
		_increment_dict(_destroyed_by_key, String(record.get("key", "unknown")), 1)
		_increment_dict(_destroyed_by_category, String(record.get("category", "other")), 1)
		_record_live_delta(record, -1)
		_add_frame_node_event("destroyed", record)
		if String(record.get("category", "")) == "damage_number":
			_damage_number_destroyed_total += 1
		_node_records_by_instance_id.erase(instance_id)


func _average_fps() -> float:
	var avg_ms: float = _average(_frame_ms_values)
	return 1000.0 / avg_ms if avg_ms > 0.0 else 0.0


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _debug_panel_summary(snapshot: Dictionary) -> String:
	return "on" if bool(snapshot.get("enabled", false)) else "off"


func _safe_text(value: Variant) -> String:
	return String(value).replace("\r", " ").replace("\n", " ").replace("\t", " ")


func _release_movement() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"dash"]:
		Input.action_release(action)


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	if get_tree() != null and get_tree().root != null:
		if get_tree().root.has_meta(PROFILER_ENABLED_META):
			get_tree().root.remove_meta(PROFILER_ENABLED_META)
		if get_tree().root.has_meta(PROFILER_STATUS_EVENT_META):
			get_tree().root.remove_meta(PROFILER_STATUS_EVENT_META)
	_release_movement()
	get_tree().quit(exit_code)


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _increment_dict(dictionary: Dictionary, key: Variant, amount: int) -> void:
	dictionary[key] = int(dictionary.get(key, 0)) + amount
