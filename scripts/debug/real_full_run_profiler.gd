## 文件用途：从真实标题界面自动开局，采集帧时长、节点与状态归因、热点耗时及 AOE tick 统计，输出整局性能报告。
## 使用方式：挂在 app_bootstrap 的 RealFullRunProfiler 节点；启动用户参数 --real-full-run-profile，可加 --survival-guard 或 --profile-force-skill=<逗号分隔ID>。写入 reports/real-full-run-profile 下四份报告并结束进程；运行前使用 E:/codex 下隔离的 APPDATA、LOCALAPPDATA、TEMP、TMP。
extends Node


const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const SAMPLE_INTERVAL_SECONDS: float = 5.0
const MAX_RUN_SECONDS: float = 900.0
const REPORT_DIR: String = "res://reports/real-full-run-profile"
const SAMPLES_PATH: String = "res://reports/real-full-run-profile/latest_samples.json"
const REPORT_PATH: String = "res://reports/real-full-run-profile/report.md"
const ATTRIBUTION_PATH: String = "res://reports/real-full-run-profile/latest_attribution.json"
const HOT_PATH_PATH: String = "res://reports/real-full-run-profile/latest_hot_path.json"
const BOSS_DAMAGE_STOP_AMOUNT: int = 1000
const BOSS_DAMAGE_RUN_MAX_SECONDS: float = 1200.0
const SPIKE_CONTEXT_FRAMES: int = 5
const PROFILER_ENABLED_META: StringName = &"real_full_run_profiler_enabled"
const PROFILER_STATUS_EVENT_META: StringName = &"real_full_run_profiler_status_event"
const PROFILER_HOT_PATH_EVENT_META: StringName = &"real_full_run_profiler_hot_path_event"
const PROFILER_AOE_TICK_EVENT_META: StringName = &"real_full_run_profiler_aoe_tick_event"
const SOURCE_ATTRIBUTION_FOCUS_SKILLS: Array[String] = [
	"chaos_attack_chaotic",
	"chaos_cast_singularity_barrage"
]
const HOT_PATH_SECTIONS: Array[String] = [
	"skill_update_total",
	"skill_cast_tick",
	"status_update_total",
	"status_apply",
	"status_tick",
	"status_reaction",
	"status_visual_update",
	"area_effect_update",
	"area_effect_tick",
	"projectile_update",
	"projectile_targeting",
	"summon_update",
	"summon_targeting",
	"enemy_update",
	"enemy_movement",
	"enemy_ai_update",
	"enemy_attack_update",
	"enemy_neighbor_check",
	"enemy_animation_update",
	"enemy_status_visual_update",
	"pickup_update",
	"pickup_idle_check",
	"pickup_active_update",
	"pickup_reward_flush",
	"ui_update"
]

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
var _forced_profile_skill_ids: Array[StringName] = []
var _forced_profile_skill_results: Dictionary = {}
var _title_reveal_sent: bool = false
var _survival_guard_enabled: bool = false
var _player_health_modified: bool = false
var _frame_index: int = 0
var _current_frame_bucket: Dictionary = {}
var _recent_frame_buckets: Array[Dictionary] = []
var _frame_event_buckets: Array[Dictionary] = []
var _spike_frames_over_50ms: Array[Dictionary] = []
var _spike_frames_over_100ms: Array[Dictionary] = []
var _ui_modal_spike_frames: Array[Dictionary] = []
var _runtime_spike_frames_over_50ms: Array[Dictionary] = []
var _runtime_spike_frames_over_100ms: Array[Dictionary] = []
var _created_by_key: Dictionary = {}
var _destroyed_by_key: Dictionary = {}
var _created_by_category: Dictionary = {}
var _destroyed_by_category: Dictionary = {}
var _created_by_source_skill_id: Dictionary = {}
var _destroyed_by_source_skill_id: Dictionary = {}
var _created_by_source_id: Dictionary = {}
var _destroyed_by_source_id: Dictionary = {}
var _status_events_by_status_id: Dictionary = {}
var _status_events_by_source_skill_id: Dictionary = {}
var _status_events_by_source_id: Dictionary = {}
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
var _hot_path_window_start_seconds: float = 0.0
var _hot_path_window_start_frame: int = 0
var _hot_path_window_sections: Dictionary = {}
var _hot_path_run_sections: Dictionary = {}
var _hot_path_windows: Array[Dictionary] = []
var _area_effect_tick_stats: Dictionary = {}


## 作用：仅在 --real-full-run-profile 下启用采样与自动驱动，注册根节点状态/热点/AOE 回调，创建报告目录并监听节点生命周期。
## 使用：由 Godot 入树后调用；启动必须携带用户参数 --real-full-run-profile，--survival-guard 会补血，--profile-force-skill= 会授予指定技能。
func _ready() -> void:
	_enabled = OS.get_cmdline_args().has("--real-full-run-profile") or OS.get_cmdline_user_args().has("--real-full-run-profile")
	if not _enabled:
		set_process(false)
		return
	_survival_guard_enabled = OS.get_cmdline_args().has("--survival-guard") or OS.get_cmdline_user_args().has("--survival-guard")
	_forced_profile_skill_ids = _parse_forced_profile_skill_ids()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	if get_tree() != null and get_tree().root != null:
		get_tree().root.set_meta(PROFILER_ENABLED_META, true)
		get_tree().root.set_meta(PROFILER_STATUS_EVENT_META, Callable(self, "_on_profiler_status_event"))
		get_tree().root.set_meta(PROFILER_HOT_PATH_EVENT_META, Callable(self, "_on_hot_path_event"))
		get_tree().root.set_meta(PROFILER_AOE_TICK_EVENT_META, Callable(self, "_on_area_effect_tick_event"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if not get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.connect(_on_node_removed)
	_last_tick_usec = Time.get_ticks_usec()
	_window_start_seconds = 0.0
	_current_frame_bucket = _new_frame_bucket()
	_area_effect_tick_stats = _new_area_effect_tick_stats()
	_reset_hot_path_window(0.0)
	print("[RealFullRunProfile] enabled real startup profile character=%s map=%s" % [String(CHARACTER_ID), String(MAP_ID)])


## 作用：用真实墙钟帧时长采样，定位 UIManager 并记录状态变化，随后按 UI 状态推进流程。
## 使用：由 Godot 每处理帧调用，delta 参数以秒为单位。 入参：_delta: float。
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


## 作用：按标题、角色、地图、战斗、弹窗或终局驱动自动流程，定期记录样本，满足 Boss 伤害阈值、胜负或超时时写报告并退出。
## 使用：由已启用的整局采样流程调用。 入参：state: String, delta_seconds: float。
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
			_apply_forced_profile_skills()
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


## 作用：查找可见开始按钮并点击一次；标题未展开时先模拟 Enter，避免重复开局。
## 使用：由已启用的整局采样流程调用。
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


## 作用：按 node_name 查找可见启用按钮，记录 action_name 后发射 pressed，使此启动操作至多执行一次。
## 使用：由已启用的整局采样流程调用。 入参：node_name: String, action_name: String。
func _press_named_button(node_name: String, action_name: String) -> void:
	if _startup_actions.has(action_name):
		return
	var button: Button = _ui.find_child(node_name, true, false) as Button
	if button == null or button.disabled or not _is_control_visible(button):
		return
	_startup_actions.append(action_name)
	button.emit_signal(&"pressed")


## 作用：收集当前弹窗可见按钮，按生存与火系偏好评分选择一项，保存选择日志；空选项退回战斗。
## 使用：由已启用的整局采样流程调用。 入参：state: String。
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


## 作用：依据按钮文本、稀有度、火系、施放/召唤、伤害和玩家血量，为升级选项计算自动选择分数。
## 使用：由已启用的整局采样流程调用。 入参：button: Button。 返回 float；具体值及空输入行为见作用说明。
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


## 作用：从引擎及用户参数解析 --profile-force-skill= 的逗号列表，去空白和重复后返回技能 ID 数组。
## 使用：由已启用的整局采样流程调用。 返回 Array[StringName]；具体值及空输入行为见作用说明。
func _parse_forced_profile_skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg_variant: Variant in args:
		var arg: String = String(arg_variant)
		if not arg.begins_with("--profile-force-skill="):
			continue
		var skill_text: String = arg.trim_prefix("--profile-force-skill=").strip_edges()
		for item: String in skill_text.split(",", false):
			var skill_id: StringName = StringName(item.strip_edges())
			if skill_id != &"" and not result.has(skill_id):
				result.append(skill_id)
	return result


## 作用：对尚未处理的强制技能尝试 add_skill，记录授予前后持有状态、主攻击 ID 与耗时，不重复尝试。
## 使用：由已启用的整局采样流程调用。
func _apply_forced_profile_skills() -> void:
	if _forced_profile_skill_ids.is_empty() or _player == null:
		return
	var manager: Node = _player.get_node_or_null("SkillManager")
	if manager == null:
		return
	for skill_id: StringName in _forced_profile_skill_ids:
		var key: String = String(skill_id)
		if _forced_profile_skill_results.has(key):
			continue
		var already_owned: bool = manager.has_method("has_skill") and bool(manager.call("has_skill", skill_id))
		var added: bool = false
		if not already_owned and manager.has_method("add_skill"):
			added = bool(manager.call("add_skill", skill_id))
		var owned_after: bool = manager.has_method("has_skill") and bool(manager.call("has_skill", skill_id))
		var primary_attack_id: String = ""
		if manager.has_method("get_primary_attack_id"):
			primary_attack_id = String(manager.call("get_primary_attack_id"))
		_forced_profile_skill_results[key] = {
			"skill_id": key,
			"already_owned": already_owned,
			"added": added,
			"owned_after": owned_after,
			"primary_attack_id": primary_attack_id,
			"elapsed_seconds": _elapsed
		}
		print("[RealFullRunProfile] force_skill skill=%s added=%s owned_after=%s primary_attack=%s" % [
			key,
			str(added),
			str(owned_after),
			primary_attack_id
		])


## 作用：根据生存方向模拟移动，距离敌人较近时按下 dash，每帧先释放旧输入。
## 使用：由已启用的整局采样流程调用。 入参：delta: float。
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


## 作用：仅 survival-guard 开关启用时，将低于九成最大血量的玩家直接补满并记录修改标志。
## 使用：由已启用的整局采样流程调用。
func _apply_survival_guard() -> void:
	if not _survival_guard_enabled or _player == null:
		return
	var max_health: int = maxi(int(_player.get("max_health")), 1)
	var current_health: int = int(_player.get("current_health"))
	if current_health < int(float(max_health) * 0.9):
		_player.set("current_health", max_health)
		_player_health_modified = true


## 作用：综合敌人排斥、经验吸引、边界回推和旋转趋势选择移动方向，危险时优先使用离敌脱困方向。
## 使用：由已启用的整局采样流程调用。 返回 Vector2；具体值及空输入行为见作用说明。
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


## 作用：枚举十六个等角方向，选择逃生评分最高者，无玩家返回零向量。
## 使用：由已启用的整局采样流程调用。 返回 Vector2；具体值及空输入行为见作用说明。
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


## 作用：对前进 260 像素后的敌距、人群、地图边缘和距中心代价评分，返回越高越安全的分数。
## 使用：由已启用的整局采样流程调用。 入参：direction: Vector2。 返回 float；具体值及空输入行为见作用说明。
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


## 作用：用微秒时钟记录有效帧时长并结算事件桶，累计慢帧计数；返回最多 0.25 秒的驱动 delta。
## 使用：由已启用的整局采样流程调用。 返回 float；具体值及空输入行为见作用说明。
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


## 作用：收集引擎对象数、帧分位、实体、状态、Boss 和玩家快照，存入样本并结算热点窗口、重置节点窗口计数。
## 使用：由已启用的整局采样流程调用。 入参：reason: String。
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
	_snapshot_hot_path_window(reason)
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


## 作用：结算最后热点窗口，覆盖写样本 JSON、归因 JSON、热点 JSON 和 Markdown 报告，打印报告路径。
## 使用：传入终局/停止 status；覆盖 REPORT_DIR 中 latest_samples.json、latest_attribution.json、latest_hot_path.json 与 report.md，目录由 _ready 建立。
func _write_outputs(status: String) -> void:
	_status = status
	_snapshot_hot_path_window("final")
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
		"forced_profile_skills": _forced_profile_skill_report(),
		"final_skills": _skills_snapshot(),
		"startup_actions": _startup_actions,
		"choices": _choices,
		"samples": _samples
	}
	var file: FileAccess = FileAccess.open(SAMPLES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	_write_attribution_output(status)
	_write_hot_path_output(status)
	var hot_path_top: Array[Dictionary] = _top_hot_path_entries(_hot_path_run_sections, _frame_ms_values.size(), 10)
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
		"- forced_profile_skills: %s" % JSON.stringify(_forced_profile_skill_report()),
		"- final_skills: %s" % JSON.stringify(_skills_snapshot()),
		"- samples_json: %s" % ProjectSettings.globalize_path(SAMPLES_PATH),
		"- hot_path_json: %s" % ProjectSettings.globalize_path(HOT_PATH_PATH),
		"",
		"## Hot Path Top 10",
		"",
		"| rank | section | total ms | avg ms | p95 ms | max ms | calls | calls/frame |",
		"| ---: | :--- | ---: | ---: | ---: | ---: | ---: | ---: |"
	]
	var rank: int = 1
	for entry: Dictionary in hot_path_top:
		lines.append("| %d | %s | %.3f | %.4f | %.4f | %.4f | %d | %.3f |" % [
			rank,
			String(entry.get("section", "")),
			float(entry.get("total_ms", 0.0)),
			float(entry.get("avg_ms", 0.0)),
			float(entry.get("p95_ms", 0.0)),
			float(entry.get("max_ms", 0.0)),
			int(entry.get("call_count", 0)),
			float(entry.get("calls_per_frame", 0.0))
		])
		rank += 1
	lines.append_array([
		"",
		"## Samples",
		"",
		"| t | fps | p95 ms | p99 ms | enemies | projectiles | areas | pickups | damage nums | statuses | create/min | destroy/min | objects delta | debug |",
		"| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |"
	])
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


## 作用：首次发现 Boss 时保存初始血量，后续更新已损失血量用于停止条件。
## 使用：由已启用的整局采样流程调用。
func _track_boss() -> void:
	var boss: Node2D = _boss()
	if boss != null and not _boss_seen:
		_boss_seen = true
		_boss_start_health = int(boss.get("current_health"))
		print("[RealFullRunProfile] boss_spawned hp=%d/%d at %.1fs" % [_boss_start_health, int(boss.get("max_health")), _elapsed])
	if boss != null and _boss_start_health >= 0:
		_boss_damage_done = maxi(_boss_start_health - int(boss.get("current_health")), 0)


## 作用：优先读 UIManager 局时，再读生成器累计时间，均不可用时用采样器当前时间。
## 使用：由已启用的整局采样流程调用。 返回 float；具体值及空输入行为见作用说明。
func _runtime_elapsed_seconds() -> float:
	if _ui != null:
		var ui_seconds: float = float(_ui.get("_run_seconds"))
		if ui_seconds > 0.0:
			return ui_seconds
	var spawner: Node = get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null:
		return float(spawner.get("_elapsed_time"))
	return _elapsed


## 作用：返回 enemy 组中首个 enemy_rank=boss 的 Node2D，无 Boss 返回 null。
## 使用：由已启用的整局采样流程调用。 返回 Node2D；具体值及空输入行为见作用说明。
func _boss() -> Node2D:
	for item: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null and _is_boss(enemy):
			return enemy
	return null


## 作用：根据 enemy_rank 元数据判断目标是否为 Boss。
## 使用：由已启用的整局采样流程调用。 入参：enemy: Node。 返回 bool；具体值及空输入行为见作用说明。
func _is_boss(enemy: Node) -> bool:
	return enemy != null and String(enemy.get_meta("enemy_rank", "")) == "boss"


## 作用：返回当前 Boss 的 ID、血量和二维位置快照，无 Boss 返回空字典。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：返回玩家血量、等级与二维位置快照，无玩家返回空字典。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _player_snapshot() -> Dictionary:
	if _player == null:
		return {}
	return {
		"current_health": int(_player.get("current_health")),
		"max_health": int(_player.get("max_health")),
		"level": int(_player.get("level")),
		"position": [_player.global_position.x, _player.global_position.y]
	}


## 作用：在玩家距地图四边 260 像素内计算向内推力，地图边界无效时返回零向量。
## 使用：由已启用的整局采样流程调用。 返回 Vector2；具体值及空输入行为见作用说明。
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


## 作用：根据玩家到地图中心的距离计算归一方向与强度，用于自动移动回中。
## 使用：由已启用的整局采样流程调用。 返回 Vector2；具体值及空输入行为见作用说明。
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


## 作用：按给定世界坐标距地图四边 190 像素安全带的超出程度求边界惩罚。
## 使用：由已启用的整局采样流程调用。 入参：position: Vector2。 返回 float；具体值及空输入行为见作用说明。
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


## 作用：返回玩家有效运动边界的中心，缺玩家或边界无效时返回零向量。
## 使用：由已启用的整局采样流程调用。 返回 Vector2；具体值及空输入行为见作用说明。
func _movement_bounds_center() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var bounds: Rect2 = _player.get("_movement_bounds")
	return bounds.get_center() if bounds.size.x > 0.0 and bounds.size.y > 0.0 else Vector2.ZERO


## 作用：计算玩家到 enemy 组实体的最短距离，无玩家或无敌人时为 INF。
## 使用：由已启用的整局采样流程调用。 返回 float；具体值及空输入行为见作用说明。
func _nearest_enemy_distance() -> float:
	if _player == null:
		return INF
	var nearest: float = INF
	for item: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = item as Node2D
		if enemy != null:
			nearest = minf(nearest, _player.global_position.distance_to(enemy.global_position))
	return nearest


## 作用：将当前血量除最大血量约束到零至一，缺玩家时返回一。
## 使用：由已启用的整局采样流程调用。 返回 float；具体值及空输入行为见作用说明。
func _hp_percent() -> float:
	if _player == null:
		return 1.0
	return clampf(float(_player.get("current_health")) / maxf(float(_player.get("max_health")), 1.0), 0.0, 1.0)


## 作用：遍历整棵场景树，统计脚本资源路径以 script_name 结尾的节点数。
## 使用：由已启用的整局采样流程调用。 入参：script_name: String。 返回 int；具体值及空输入行为见作用说明。
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


## 作用：遍历具有 get_status_snapshot 的节点，累计状态快照数组大小作为状态实例计数。
## 使用：由已启用的整局采样流程调用。 返回 int；具体值及空输入行为见作用说明。
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


## 作用：遍历场景树统计调试面板脚本节点和可见数量，返回存在、可见和开启标志。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：为每个尚未连接的 run_stats_tracker 监听 event_recorded，并记录实例 ID 避免重复连接。
## 使用：由已启用的整局采样流程调用。
func _connect_run_stats_tracker() -> void:
	for tracker: Node in get_tree().get_nodes_in_group(&"run_stats_tracker"):
		var instance_id: int = int(tracker.get_instance_id())
		if _connected_tracker_ids.has(instance_id):
			continue
		if tracker.has_signal("event_recorded"):
			tracker.connect("event_recorded", Callable(self, "_on_run_event_recorded"))
			_connected_tracker_ids[instance_id] = true


## 作用：统计运行事件，并把 DOT 伤害、元素反应及特定状态施加映射到逐帧状态 tick/反应计数。
## 使用：由已连接的信号或采样 Callable 触发。 入参：event_name: StringName, payload: Dictionary。
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


## 作用：过滤采样专用状态事件，累计运行事件次数后交给状态事件归因逻辑。
## 使用：由已连接的信号或采样 Callable 触发。 入参：event_name: StringName, payload: Dictionary。
func _on_profiler_status_event(event_name: StringName, payload: Dictionary) -> void:
	var event_key: String = String(event_name)
	if not _is_profiler_status_event(event_key):
		return
	_increment_dict(_run_event_counts, event_key, 1)
	_record_profiler_status_event(event_key, payload)


## 作用：判断事件名是否属于状态到期、tick、特效生成/刷新或反应触发的采样白名单。
## 使用：由已启用的整局采样流程调用。 入参：event_key: String。 返回 bool；具体值及空输入行为见作用说明。
func _is_profiler_status_event(event_key: String) -> bool:
	return [
		"status_tick_due",
		"status_tick_applied",
		"status_expired",
		"status_visual_spawn",
		"status_visual_update",
		"status_reaction_triggered"
	].has(event_key)


## 作用：累积采样状态事件次数、来源归因和逐帧指标，tick_applied 与反应触发额外计入诊断统计。
## 使用：由已启用的整局采样流程调用。 入参：event_key: String, _payload: Dictionary。
func _record_profiler_status_event(event_key: String, _payload: Dictionary) -> void:
	_increment_dict(_status_tick_observation, event_key, 1)
	_record_status_source_attribution(event_key, _payload)
	_add_frame_metric(event_key, "status", 1)
	match event_key:
		"status_tick_applied":
			_add_frame_metric("status_tick", "status", 1)
			_increment_dict(_status_tick_observation, "status_tick_events", 1)
		"status_reaction_triggered":
			_add_frame_metric("reaction", "status", 1)
			_increment_dict(_status_tick_observation, "status_reaction_events", 1)


## 作用：按状态、来源技能和来源 ID 更新全局及当前帧的状态事件归因计数。
## 使用：由已启用的整局采样流程调用。 入参：event_key: String, payload: Dictionary。
func _record_status_source_attribution(event_key: String, payload: Dictionary) -> void:
	var status_id: String = _attribution_value(payload.get("status_id", ""))
	var source_skill_id: String = _attribution_value(payload.get("source_skill_id", payload.get("source_id", "")))
	var source_id: String = _attribution_value(payload.get("source_id", source_skill_id))
	_increment_dict(_status_events_by_status_id, status_id, 1)
	_increment_dict(_status_events_by_source_skill_id, source_skill_id, 1)
	_increment_dict(_status_events_by_source_id, source_id, 1)
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	_increment_dict(_dict(_current_frame_bucket.get("status_events_by_status_id", {})), "%s|%s" % [status_id, event_key], 1)
	_increment_dict(_dict(_current_frame_bucket.get("status_events_by_source_skill_id", {})), "%s|%s" % [source_skill_id, event_key], 1)
	_increment_dict(_dict(_current_frame_bucket.get("status_events_by_source_id", {})), "%s|%s" % [source_id, event_key], 1)


## 作用：创建带帧索引、阶段、UI 状态和零初始化节点/状态计数的逐帧事件桶。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _new_frame_bucket() -> Dictionary:
	return {
		"frame_index": _frame_index,
		"elapsed_seconds": _elapsed,
		"profile_phase": _profile_phase_for_frame(),
		"ui_state": _ui_state_for_frame(),
		"created_total": 0,
		"destroyed_total": 0,
		"created_by_category": {},
		"destroyed_by_category": {},
		"created_by_key": {},
		"destroyed_by_key": {},
		"created_by_source_skill_id": {},
		"destroyed_by_source_skill_id": {},
		"created_by_source_id": {},
		"destroyed_by_source_id": {},
		"status_events_by_status_id": {},
		"status_events_by_source_skill_id": {},
		"status_events_by_source_id": {},
		"status_tick": 0,
		"status_tick_due": 0,
		"status_tick_applied": 0,
		"status_expired": 0,
		"status_visual_spawn": 0,
		"status_visual_update": 0,
		"status_reaction_triggered": 0,
		"reaction": 0
	}


## 作用：结束当前帧事件桶，记录活动帧和 50/100 毫秒慢帧以及前五帧上下文，分离弹窗慢帧后开启新桶。
## 使用：由已启用的整局采样流程调用。 入参：frame_ms: float。
func _finalize_frame_bucket(frame_ms: float) -> void:
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	_current_frame_bucket["frame_ms"] = frame_ms
	_current_frame_bucket["profile_phase"] = _profile_phase_for_frame()
	_current_frame_bucket["ui_state"] = _ui_state_for_frame()
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
		if String(spike.get("profile_phase", "")) == "ui_modal":
			_ui_modal_spike_frames.append(spike.duplicate(true))
		else:
			_runtime_spike_frames_over_50ms.append(spike.duplicate(true))
		if frame_ms >= 100.0:
			if String(spike.get("profile_phase", "")) != "ui_modal":
				_runtime_spike_frames_over_100ms.append(spike.duplicate(true))
			_spike_frames_over_100ms.append(spike.duplicate(true))
		_spike_frames_over_50ms.append(spike)
	_recent_frame_buckets.append(_current_frame_bucket.duplicate(true))
	while _recent_frame_buckets.size() > SPIKE_CONTEXT_FRAMES:
		_recent_frame_buckets.pop_front()
	_frame_index += 1
	_current_frame_bucket = _new_frame_bucket()


## 作用：按当前 UI 状态区分 ui_modal 与 runtime，供慢帧归因。
## 使用：由已启用的整局采样流程调用。 返回 String；具体值及空输入行为见作用说明。
func _profile_phase_for_frame() -> String:
	var ui_state: String = _ui_state_for_frame()
	if ["LEVEL_UP_MODAL", "RUN_REWARD_MODAL", "CURSE_CHOICE_MODAL"].has(ui_state):
		return "ui_modal"
	return "runtime"


## 作用：读取当前 UIManager.current_state，尚未找到 UI 时返回空字符串。
## 使用：由已启用的整局采样流程调用。 返回 String；具体值及空输入行为见作用说明。
func _ui_state_for_frame() -> String:
	if _ui == null:
		return ""
	return String(_ui.get("current_state"))


## 作用：从事件桶提取 AOE、状态、拾取与瞬态特效的创建、销毁、活动和当前存活数量。
## 使用：由已启用的整局采样流程调用。 入参：bucket: Dictionary。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：求事件桶内六种采样状态事件次数总和，用于判断帧是否有诊断活动。
## 使用：由已启用的整局采样流程调用。 入参：bucket: Dictionary。 返回 int；具体值及空输入行为见作用说明。
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


## 作用：按 kind 将节点创建或销毁记录加入当前帧，累计类别、键和来源维度计数。
## 使用：由已启用的整局采样流程调用。 入参：kind: String, record: Dictionary。
func _add_frame_node_event(kind: String, record: Dictionary) -> void:
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	var category: String = String(record.get("category", "other"))
	var key: String = String(record.get("key", "unknown"))
	if kind == "created":
		_current_frame_bucket["created_total"] = int(_current_frame_bucket.get("created_total", 0)) + 1
		_increment_dict(_dict(_current_frame_bucket.get("created_by_category", {})), category, 1)
		_increment_dict(_dict(_current_frame_bucket.get("created_by_key", {})), key, 1)
		_increment_dict(_dict(_current_frame_bucket.get("created_by_source_skill_id", {})), _attribution_value(record.get("source_skill_id", "")), 1)
		_increment_dict(_dict(_current_frame_bucket.get("created_by_source_id", {})), _attribution_value(record.get("source_id", "")), 1)
	else:
		_current_frame_bucket["destroyed_total"] = int(_current_frame_bucket.get("destroyed_total", 0)) + 1
		_increment_dict(_dict(_current_frame_bucket.get("destroyed_by_category", {})), category, 1)
		_increment_dict(_dict(_current_frame_bucket.get("destroyed_by_key", {})), key, 1)
		_increment_dict(_dict(_current_frame_bucket.get("destroyed_by_source_skill_id", {})), _attribution_value(record.get("source_skill_id", "")), 1)
		_increment_dict(_dict(_current_frame_bucket.get("destroyed_by_source_id", {})), _attribution_value(record.get("source_id", "")), 1)


## 作用：在当前帧累加指定 metric，并同步 category_metric 的整局事件计数。
## 使用：由已启用的整局采样流程调用。 入参：metric: String, category: String, amount: int。
func _add_frame_metric(metric: String, category: String, amount: int) -> void:
	if _current_frame_bucket.is_empty():
		_current_frame_bucket = _new_frame_bucket()
	_current_frame_bucket[metric] = int(_current_frame_bucket.get(metric, 0)) + amount
	var key: String = "%s_%s" % [category, metric]
	_increment_dict(_run_event_counts, key, amount)


## 作用：读取节点脚本、场景、类、名称及来源属性，生成节点生命周期归因记录。
## 使用：由已启用的整局采样流程调用。 入参：node: Node。 返回 Dictionary；具体值及空输入行为见作用说明。
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
	record.merge(_source_attribution_record(node), true)
	return record


## 作用：优先返回节点自身 scene_file_path，否则取 owner 场景路径，无场景返回空字符串。
## 使用：由已启用的整局采样流程调用。 入参：node: Node。 返回 String；具体值及空输入行为见作用说明。
func _node_scene_path(node: Node) -> String:
	if node.scene_file_path != "":
		return node.scene_file_path
	var owner_node: Node = node.owner
	if owner_node != null and owner_node.scene_file_path != "":
		return owner_node.scene_file_path
	return ""


## 作用：组合场景路径、脚本路径、原生类与节点名作为稳定归因键。
## 使用：由已启用的整局采样流程调用。 入参：node: Node, script_path: String, scene_path: String。 返回 String；具体值及空输入行为见作用说明。
func _node_attribution_key(node: Node, script_path: String, scene_path: String) -> String:
	var scene_key: String = scene_path if scene_path != "" else "no_scene"
	var script_key: String = script_path if script_path != "" else "no_script"
	return "%s|%s|%s|%s" % [scene_key, script_key, node.get_class(), String(node.name)]


## 作用：依据节点脚本、分组、名称与类型归类为 AOE、状态、拾取、弹字、投射物、敌人、特效、UI 或其他。
## 使用：由已启用的整局采样流程调用。 入参：node: Node, script_path: String, scene_path: String。 返回 String；具体值及空输入行为见作用说明。
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


## 作用：从节点元数据、属性、伤害包和技能实例提取来源 ID、技能 ID 与状态 ID，空值统一归为 unknown。
## 使用：由已启用的整局采样流程调用。 入参：node: Node。 返回 Dictionary；具体值及空输入行为见作用说明。
func _source_attribution_record(node: Node) -> Dictionary:
	var damage_packet: Dictionary = _dict(_node_property(node, "damage_packet"))
	var source_id: String = _node_source_string(node, "source_id")
	var source_skill_id: String = _node_source_string(node, "source_skill_id")
	var status_id: String = _node_source_string(node, "status_id")
	if source_id == "":
		source_id = String(damage_packet.get("source_id", ""))
	if source_skill_id == "":
		source_skill_id = String(damage_packet.get("source_skill_id", ""))
	if status_id == "":
		status_id = String(damage_packet.get("status_id", ""))
	if source_skill_id == "":
		var skill_instance: RefCounted = _node_property(node, "skill_instance") as RefCounted
		if skill_instance != null:
			source_skill_id = String(skill_instance.get("skill_id"))
	if source_id == "" and status_id != "":
		source_id = status_id
	return {
		"source_id": _attribution_value(source_id),
		"source_skill_id": _attribution_value(source_skill_id),
		"status_id": _attribution_value(status_id)
	}


## 作用：优先读取节点同名元数据，否则读取已登记属性，将非空值转为字符串。
## 使用：由已启用的整局采样流程调用。 入参：node: Node, key: String。 返回 String；具体值及空输入行为见作用说明。
func _node_source_string(node: Node, key: String) -> String:
	if node == null:
		return ""
	if node.has_meta(StringName(key)):
		return String(node.get_meta(StringName(key)))
	if node.has_meta(key):
		return String(node.get_meta(key))
	var property_value: Variant = _node_property(node, key)
	return String(property_value) if property_value != null else ""


## 作用：先检查 get_property_list 确认属性存在，再安全读取，缺属性或缺节点返回 null。
## 使用：由已启用的整局采样流程调用。 入参：node: Node, key: String。 返回 Variant；具体值及空输入行为见作用说明。
func _node_property(node: Node, key: String) -> Variant:
	if node == null:
		return null
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == key:
			return node.get(key)
	return null


## 作用：把值转字符串并去两端空白，空内容归为 unknown。
## 使用：由已启用的整局采样流程调用。 入参：value: Variant。 返回 String；具体值及空输入行为见作用说明。
func _attribution_value(value: Variant) -> String:
	var text: String = String(value).strip_edges()
	return text if text != "" else "unknown"


## 作用：按弹字脚本或节点名片段识别伤害数字节点，供瞬态寿命诊断。
## 使用：由已启用的整局采样流程调用。 入参：node: Node, script_path: String = ""。 返回 bool；具体值及空输入行为见作用说明。
func _is_damage_number_node(node: Node, script_path: String = "") -> bool:
	var node_name: String = String(node.name).to_lower()
	return script_path.ends_with("damage_number_popup.gd") \
		or node_name.contains("damagenumber") \
		or node_name.contains("damage_number") \
		or node_name.contains("playerdamagenumber")


## 作用：按节点归因键和类别更新存活增量，同时维护各类别最大存活数。
## 使用：由已启用的整局采样流程调用。 入参：record: Dictionary, delta: int。
func _record_live_delta(record: Dictionary, delta: int) -> void:
	var key: String = String(record.get("key", "unknown"))
	var category: String = String(record.get("category", "other"))
	_increment_dict(_live_by_key, key, delta)
	_increment_dict(_live_by_category, category, delta)
	_max_live_counts_by_category[category] = maxi(int(_max_live_counts_by_category.get(category, 0)), int(_live_by_category.get(category, 0)))


## 作用：按记录内来源技能和来源 ID 累加创建计数，amount 可为负数用于修正归因。
## 使用：由已启用的整局采样流程调用。 入参：record: Dictionary, amount: int。
func _record_node_source_created(record: Dictionary, amount: int) -> void:
	_increment_dict(_created_by_source_skill_id, _attribution_value(record.get("source_skill_id", "")), amount)
	_increment_dict(_created_by_source_id, _attribution_value(record.get("source_id", "")), amount)


## 作用：按记录内来源技能和来源 ID 累加销毁计数。
## 使用：由已启用的整局采样流程调用。 入参：record: Dictionary, amount: int。
func _record_node_source_destroyed(record: Dictionary, amount: int) -> void:
	_increment_dict(_destroyed_by_source_skill_id, _attribution_value(record.get("source_skill_id", "")), amount)
	_increment_dict(_destroyed_by_source_id, _attribution_value(record.get("source_id", "")), amount)


## 作用：在节点配置完成后的延迟调用中重读来源，撤销旧创建归因、应用新归因并更新记录缓存。
## 使用：由已启用的整局采样流程调用。 入参：instance_id: int。
func _refresh_node_record_source_attribution(instance_id: int) -> void:
	if not _node_records_by_instance_id.has(instance_id):
		return
	var object: Object = instance_from_id(instance_id)
	if not (object is Node):
		return
	var node: Node = object as Node
	if not is_instance_valid(node):
		return
	var old_record: Dictionary = _dict(_node_records_by_instance_id.get(instance_id, {}))
	if old_record.is_empty():
		return
	var source_record: Dictionary = _source_attribution_record(node)
	var new_record: Dictionary = old_record.duplicate(true)
	new_record["source_id"] = source_record.get("source_id", "unknown")
	new_record["source_skill_id"] = source_record.get("source_skill_id", "unknown")
	new_record["status_id"] = source_record.get("status_id", "unknown")
	if _source_record_key(old_record) == _source_record_key(new_record):
		return
	_record_node_source_created(old_record, -1)
	_record_node_source_created(new_record, 1)
	_adjust_current_frame_created_source(old_record, -1)
	_adjust_current_frame_created_source(new_record, 1)
	_node_records_by_instance_id[instance_id] = new_record


## 作用：按 amount 修正当前帧节点创建的来源技能与来源 ID 计数。
## 使用：由已启用的整局采样流程调用。 入参：record: Dictionary, amount: int。
func _adjust_current_frame_created_source(record: Dictionary, amount: int) -> void:
	if _current_frame_bucket.is_empty():
		return
	_increment_dict(_dict(_current_frame_bucket.get("created_by_source_skill_id", {})), _attribution_value(record.get("source_skill_id", "")), amount)
	_increment_dict(_dict(_current_frame_bucket.get("created_by_source_id", {})), _attribution_value(record.get("source_id", "")), amount)


## 作用：组合来源技能、来源 ID 和状态 ID，用于比较节点来源归因是否发生变化。
## 使用：由已启用的整局采样流程调用。 入参：record: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _source_record_key(record: Dictionary) -> String:
	return "%s|%s|%s" % [
		_attribution_value(record.get("source_skill_id", "")),
		_attribution_value(record.get("source_id", "")),
		_attribution_value(record.get("status_id", ""))
	]


## 作用：把计数字典转换为条目数组，按 count 降序返回前 limit 项。
## 使用：由已启用的整局采样流程调用。 入参：source: Dictionary, limit: int = 25。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _top_entries(source: Dictionary, limit: int = 25) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key_variant: Variant in source.keys():
		var key: String = String(key_variant)
		entries.append({"key": key, "count": int(source.get(key_variant, 0))})
	## 作用：匿名比较器按 count 计数 降序排列条目。
	## 使用：由 sort_custom 传入 a、b 两条字典；前项更大时返回 true，不改写条目。
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return entries.slice(0, mini(limit, entries.size()))


## 作用：按节点归因键计算创建减销毁的净数量，包含仅有销毁记录的键。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：按类别计算创建减销毁的净数量，包含仅有销毁记录的类别。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：结合弹字生命周期计数、当前选择器结果和伤害事件数，区分短寿命、关闭显示或无伤害等诊断情况。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：把 ObjectDB 总数增量与节点类别净增量对照，非 Node 的 Resource/RefCounted 增量标为未归因。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：按强制技能参数原顺序返回授予记录，尚未处理的技能补 pending 条目。
## 使用：由已启用的整局采样流程调用。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _forced_profile_skill_report() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_id: StringName in _forced_profile_skill_ids:
		var key: String = String(skill_id)
		var entry: Dictionary = _dict(_forced_profile_skill_results.get(key, {}))
		if entry.is_empty():
			entry = {
				"skill_id": key,
				"already_owned": false,
				"added": false,
				"owned_after": false,
				"primary_attack_id": "",
				"elapsed_seconds": _elapsed,
				"pending": true
			}
		result.append(entry)
	return result


## 作用：从 SkillManager 收集全部技能 ID、等级、类型和稀有度快照。
## 使用：由已启用的整局采样流程调用。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _skills_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _player == null:
		return result
	var manager: Node = _player.get_node_or_null("SkillManager")
	if manager == null or not manager.has_method("get_all_skills"):
		return result
	var skills_variant: Variant = manager.call("get_all_skills")
	if not (skills_variant is Array):
		return result
	for item: Variant in skills_variant:
		var skill: RefCounted = item as RefCounted
		if skill == null:
			continue
		result.append({
			"id": String(skill.get("skill_id")),
			"level": int(skill.get("current_level")),
			"type": String(skill.get("skill_type")),
			"rarity": String(skill.get("current_rarity"))
		})
	return result


## 作用：仅接受已开启采样的白名单热点 section 和正耗时，将微秒样本累计到窗口及整局统计。
## 使用：由根元数据中的热点 Callable 回调；section 须在 HOT_PATH_SECTIONS，duration_usec 是正数微秒耗时。
func _on_hot_path_event(section: Variant, duration_usec: Variant) -> void:
	if not _enabled:
		return
	var section_key: String = String(section)
	if not HOT_PATH_SECTIONS.has(section_key):
		return
	var elapsed_usec: int = maxi(int(duration_usec), 0)
	if elapsed_usec <= 0:
		return
	_record_hot_path_stat(_dict(_hot_path_window_sections.get(section_key, {})), elapsed_usec)
	_record_hot_path_stat(_dict(_hot_path_run_sections.get(section_key, {})), elapsed_usec)


## 作用：接受 AOE tick 字典事件，累计总体以及 area_id、source_id、source_skill_id 分组统计。
## 使用：由 AOE 采样 Callable 传入字典，读取 candidate_count、hit_count、status_apply_count 与来源字段；仅采样启用时累计。
func _on_area_effect_tick_event(payload_variant: Variant) -> void:
	if not _enabled or not (payload_variant is Dictionary):
		return
	var payload: Dictionary = payload_variant
	_record_area_effect_tick_stat(_area_effect_tick_stats, payload)
	_record_area_effect_tick_group(_dict(_area_effect_tick_stats.get("by_area_id", {})), String(payload.get("area_id", "unknown")), payload)
	_record_area_effect_tick_group(_dict(_area_effect_tick_stats.get("by_source_id", {})), String(payload.get("source_id", "unknown")), payload)
	_record_area_effect_tick_group(_dict(_area_effect_tick_stats.get("by_source_skill_id", {})), String(payload.get("source_skill_id", "unknown")), payload)


## 作用：创建 AOE tick 次数、候选、命中、状态施加总量/峰值与三个分组容器。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _new_area_effect_tick_stats() -> Dictionary:
	return {
		"tick_count": 0,
		"candidate_count": 0,
		"hit_count": 0,
		"status_apply_count": 0,
		"max_candidate_count": 0,
		"max_hit_count": 0,
		"max_status_apply_count": 0,
		"by_area_id": {},
		"by_source_id": {},
		"by_source_skill_id": {}
	}


## 作用：按分组键懒创建 AOE 统计桶，去除不需要的嵌套组再累积此次 tick。
## 使用：由已启用的整局采样流程调用。 入参：groups: Dictionary, key: String, payload: Dictionary。
func _record_area_effect_tick_group(groups: Dictionary, key: String, payload: Dictionary) -> void:
	var group_key: String = key if key.strip_edges() != "" else "unknown"
	var stat: Dictionary = _dict(groups.get(group_key, {}))
	if stat.is_empty():
		stat = _new_area_effect_tick_stats()
		stat.erase("by_area_id")
		stat.erase("by_source_id")
		stat.erase("by_source_skill_id")
		groups[group_key] = stat
	_record_area_effect_tick_stat(stat, payload)


## 作用：将 tick 事件的候选、命中和状态施加计数累加到 stat，并更新每次最大值。
## 使用：由已启用的整局采样流程调用。 入参：stat: Dictionary, payload: Dictionary。
func _record_area_effect_tick_stat(stat: Dictionary, payload: Dictionary) -> void:
	var candidate_count: int = int(payload.get("candidate_count", 0))
	var hit_count: int = int(payload.get("hit_count", 0))
	var status_apply_count: int = int(payload.get("status_apply_count", 0))
	stat["tick_count"] = int(stat.get("tick_count", 0)) + 1
	stat["candidate_count"] = int(stat.get("candidate_count", 0)) + candidate_count
	stat["hit_count"] = int(stat.get("hit_count", 0)) + hit_count
	stat["status_apply_count"] = int(stat.get("status_apply_count", 0)) + status_apply_count
	stat["max_candidate_count"] = maxi(int(stat.get("max_candidate_count", 0)), candidate_count)
	stat["max_hit_count"] = maxi(int(stat.get("max_hit_count", 0)), hit_count)
	stat["max_status_apply_count"] = maxi(int(stat.get("max_status_apply_count", 0)), status_apply_count)


## 作用：构建 AOE 总体与区域、来源、技能三个维度的报告字典。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _area_effect_tick_stats_report() -> Dictionary:
	var report: Dictionary = _area_effect_tick_stat_report(_area_effect_tick_stats)
	report["by_area_id"] = _area_effect_tick_group_report(_dict(_area_effect_tick_stats.get("by_area_id", {})))
	report["by_source_id"] = _area_effect_tick_group_report(_dict(_area_effect_tick_stats.get("by_source_id", {})))
	report["by_source_skill_id"] = _area_effect_tick_group_report(_dict(_area_effect_tick_stats.get("by_source_skill_id", {})))
	return report


## 作用：将每个 AOE 分组统计转换为包含总数、均值和峰值的报告。
## 使用：由已启用的整局采样流程调用。 入参：groups: Dictionary。 返回 Dictionary；具体值及空输入行为见作用说明。
func _area_effect_tick_group_report(groups: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in groups.keys():
		var key: String = String(key_variant)
		result[key] = _area_effect_tick_stat_report(_dict(groups.get(key_variant, {})))
	return result


## 作用：计算 AOE 每 tick 的候选、命中和状态施加均值，零 tick 时均值为零。
## 使用：由已启用的整局采样流程调用。 入参：stat: Dictionary。 返回 Dictionary；具体值及空输入行为见作用说明。
func _area_effect_tick_stat_report(stat: Dictionary) -> Dictionary:
	var tick_count: int = int(stat.get("tick_count", 0))
	var candidate_count: int = int(stat.get("candidate_count", 0))
	var hit_count: int = int(stat.get("hit_count", 0))
	var status_apply_count: int = int(stat.get("status_apply_count", 0))
	return {
		"tick_count": tick_count,
		"candidate_count": candidate_count,
		"hit_count": hit_count,
		"status_apply_count": status_apply_count,
		"avg_candidate_count": float(candidate_count) / float(tick_count) if tick_count > 0 else 0.0,
		"avg_hit_count": float(hit_count) / float(tick_count) if tick_count > 0 else 0.0,
		"avg_status_apply_count": float(status_apply_count) / float(tick_count) if tick_count > 0 else 0.0,
		"max_candidate_count": int(stat.get("max_candidate_count", 0)),
		"max_hit_count": int(stat.get("max_hit_count", 0)),
		"max_status_apply_count": int(stat.get("max_status_apply_count", 0))
	}


## 作用：重置热点窗口起始秒数、帧索引和统计桶，首次使用时同时创建整局桶。
## 使用：由已启用的整局采样流程调用。 入参：start_seconds: float。
func _reset_hot_path_window(start_seconds: float) -> void:
	_hot_path_window_start_seconds = start_seconds
	_hot_path_window_start_frame = _frame_index
	_hot_path_window_sections = _new_hot_path_sections()
	if _hot_path_run_sections.is_empty():
		_hot_path_run_sections = _new_hot_path_sections()


## 作用：为所有已登记热点 section 创建独立零值统计字典。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _new_hot_path_sections() -> Dictionary:
	var sections: Dictionary = {}
	for section: String in HOT_PATH_SECTIONS:
		sections[section] = _new_hot_path_stat()
	return sections


## 作用：创建热点累计微秒、峰值、调用次数与原始耗时数组的统计桶。
## 使用：由已启用的整局采样流程调用。 返回 Dictionary；具体值及空输入行为见作用说明。
func _new_hot_path_stat() -> Dictionary:
	return {
		"total_usec": 0,
		"max_usec": 0,
		"call_count": 0,
		"durations_usec": []
	}


## 作用：原位累计一次 elapsed_usec 样本的总时长、峰值和调用次数，并保存分位计算样本。
## 使用：由已启用的整局采样流程调用。 入参：stat: Dictionary, elapsed_usec: int。
func _record_hot_path_stat(stat: Dictionary, elapsed_usec: int) -> void:
	stat["total_usec"] = int(stat.get("total_usec", 0)) + elapsed_usec
	stat["max_usec"] = maxi(int(stat.get("max_usec", 0)), elapsed_usec)
	stat["call_count"] = int(stat.get("call_count", 0)) + 1
	var durations: Array = stat.get("durations_usec", [])
	durations.append(elapsed_usec)
	stat["durations_usec"] = durations


## 作用：将有调用的热点窗口转换为带时间和帧范围的报告并保存，随后重置；无调用仅推进窗口起点。
## 使用：由已启用的整局采样流程调用。 入参：reason: String。
func _snapshot_hot_path_window(reason: String) -> void:
	if _hot_path_window_sections.is_empty():
		_reset_hot_path_window(_elapsed)
		return
	var has_calls: bool = false
	for section: String in HOT_PATH_SECTIONS:
		if int(_dict(_hot_path_window_sections.get(section, {})).get("call_count", 0)) > 0:
			has_calls = true
			break
	if not has_calls:
		_hot_path_window_start_seconds = _elapsed
		_hot_path_window_start_frame = _frame_index
		return
	var frame_count: int = maxi(_frame_index - _hot_path_window_start_frame, 1)
	_hot_path_windows.append({
		"reason": reason,
		"start_seconds": _hot_path_window_start_seconds,
		"end_seconds": _elapsed,
		"duration_seconds": maxf(_elapsed - _hot_path_window_start_seconds, 0.0),
		"start_frame": _hot_path_window_start_frame,
		"end_frame": _frame_index,
		"frame_count": frame_count,
		"sections": _hot_path_report_sections(_hot_path_window_sections, frame_count)
	})
	_reset_hot_path_window(_elapsed)


## 作用：按 HOT_PATH_SECTIONS 顺序把统计字典转换成每区间报告。
## 使用：由已启用的整局采样流程调用。 入参：source: Dictionary, frame_count: int。 返回 Dictionary；具体值及空输入行为见作用说明。
func _hot_path_report_sections(source: Dictionary, frame_count: int) -> Dictionary:
	var result: Dictionary = {}
	for section: String in HOT_PATH_SECTIONS:
		result[section] = _hot_path_section_report(_dict(source.get(section, {})), frame_count)
	return result


## 作用：将微秒统计转为平均、最大、p95 和总毫秒数，同时计算调用数与每帧调用数。
## 使用：由已启用的整局采样流程调用。 入参：stat: Dictionary, frame_count: int。 返回 Dictionary；具体值及空输入行为见作用说明。
func _hot_path_section_report(stat: Dictionary, frame_count: int) -> Dictionary:
	var call_count: int = int(stat.get("call_count", 0))
	var total_usec: int = int(stat.get("total_usec", 0))
	return {
		"avg_ms": (float(total_usec) / float(call_count) / 1000.0) if call_count > 0 else 0.0,
		"max_ms": float(int(stat.get("max_usec", 0))) / 1000.0,
		"p95_ms": _percentile_usec(stat.get("durations_usec", []), 0.95),
		"call_count": call_count,
		"calls_per_frame": float(call_count) / float(maxi(frame_count, 1)),
		"total_ms": float(total_usec) / 1000.0
	}


## 作用：按 total_ms 降序返回前 limit 个热点报告条目，附上 section 名称。
## 使用：由已启用的整局采样流程调用。 入参：source: Dictionary, frame_count: int, limit: int = 10。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _top_hot_path_entries(source: Dictionary, frame_count: int, limit: int = 10) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for section: String in HOT_PATH_SECTIONS:
		var entry: Dictionary = _hot_path_section_report(_dict(source.get(section, {})), frame_count)
		entry["section"] = section
		entries.append(entry)
	## 作用：匿名比较器按 total_ms 热点总毫秒数 降序排列条目。
	## 使用：由 sort_custom 传入 a、b 两条字典；前项更大时返回 true，不改写条目。
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("total_ms", 0.0)) > float(b.get("total_ms", 0.0))
	)
	return entries.slice(0, mini(limit, entries.size()))


## 作用：覆盖写 latest_hot_path.json，包含采样窗口、整局热点排行、AOE 计数和最终技能快照。
## 使用：由已启用的整局采样流程调用。 入参：status: String。
func _write_hot_path_output(status: String) -> void:
	var frame_count: int = _frame_ms_values.size()
	var payload: Dictionary = {
		"status": status,
		"failure_reason": _failure_reason,
		"character": String(CHARACTER_ID),
		"map": String(MAP_ID),
		"elapsed_seconds": _elapsed,
		"sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
		"boss_seen": _boss_seen,
		"boss_start_health": _boss_start_health,
		"boss_damage_done": _boss_damage_done,
		"boss_damage_stop_amount": BOSS_DAMAGE_STOP_AMOUNT,
		"frame_count": frame_count,
		"sections": HOT_PATH_SECTIONS,
		"windows": _hot_path_windows,
		"summary": {
			"sections": _hot_path_report_sections(_hot_path_run_sections, frame_count),
			"top_10_hot_paths": _top_hot_path_entries(_hot_path_run_sections, frame_count, 10),
			"area_effect_tick_stats": _area_effect_tick_stats_report()
		},
		"area_effect_tick_stats": _area_effect_tick_stats_report(),
		"forced_profile_skills": _forced_profile_skill_report(),
		"final_skills": _skills_snapshot()
	}
	var file: FileAccess = FileAccess.open(HOT_PATH_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	print("[RealFullRunProfile] hot_path=%s" % ProjectSettings.globalize_path(HOT_PATH_PATH))


## 作用：复制并排序微秒样本，用向上取整的分位索引取得值并转为毫秒；空或非数组返回零。
## 使用：由已启用的整局采样流程调用。 入参：values_variant: Variant, percentile: float。 返回 float；具体值及空输入行为见作用说明。
func _percentile_usec(values_variant: Variant, percentile: float) -> float:
	if not (values_variant is Array):
		return 0.0
	var values: Array = values_variant
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(int(sorted[index])) / 1000.0


## 作用：结算最后事件桶并覆盖写 latest_attribution.json，汇总来源、净增节点、慢帧上下文及归因诊断。
## 使用：由已启用的整局采样流程调用。 入参：status: String。
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
		"created_by_source_skill_id": _created_by_source_skill_id,
		"destroyed_by_source_skill_id": _destroyed_by_source_skill_id,
		"created_by_source_id": _created_by_source_id,
		"destroyed_by_source_id": _destroyed_by_source_id,
		"status_events_by_status_id": _status_events_by_status_id,
		"status_events_by_source_skill_id": _status_events_by_source_skill_id,
		"status_events_by_source_id": _status_events_by_source_id,
		"live_by_category": _live_by_category,
		"max_live_counts_by_category": _max_live_counts_by_category,
		"top_created_by_key": _top_entries(_created_by_key, 40),
		"top_destroyed_by_key": _top_entries(_destroyed_by_key, 40),
		"top_net_nodes_by_key": _top_entries(_net_nodes_by_key(), 40),
		"top_created_by_source_skill_id": _top_entries(_created_by_source_skill_id, 40),
		"top_destroyed_by_source_skill_id": _top_entries(_destroyed_by_source_skill_id, 40),
		"top_created_by_source_id": _top_entries(_created_by_source_id, 40),
		"top_destroyed_by_source_id": _top_entries(_destroyed_by_source_id, 40),
		"frame_event_buckets": _frame_event_buckets,
		"spike_frames_over_50ms": _spike_frames_over_50ms,
		"spike_frames_over_100ms": _spike_frames_over_100ms,
		"ui_modal_spike_frames": _ui_modal_spike_frames,
		"runtime_spike_frames_over_50ms": _runtime_spike_frames_over_50ms,
		"runtime_spike_frames_over_100ms": _runtime_spike_frames_over_100ms,
		"status_tick_observation": _status_tick_observation,
		"run_event_counts": _run_event_counts,
		"damage_number_diagnosis": _damage_number_diagnosis(),
		"object_delta_attribution": _object_delta_attribution(),
		"forced_profile_skills": _forced_profile_skill_report(),
		"final_skills": _skills_snapshot()
	}
	var file: FileAccess = FileAccess.open(ATTRIBUTION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	print("[RealFullRunProfile] attribution=%s" % ProjectSettings.globalize_path(ATTRIBUTION_PATH))


## 作用：递归收集 root 中可见且启用的 Button，保留遍历顺序。
## 使用：由已启用的整局采样流程调用。 入参：root: Node。 返回 Array[Button]；具体值及空输入行为见作用说明。
func _collect_visible_enabled_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root == null:
		return buttons
	if root is Button and not (root as Button).disabled and _is_control_visible(root as Button):
		buttons.append(root as Button)
	for child: Node in root.get_children():
		buttons.append_array(_collect_visible_enabled_buttons(child))
	return buttons


## 作用：返回首个可见启用按钮，没有匹配时返回 null。
## 使用：由已启用的整局采样流程调用。 入参：root: Node。 返回 Button；具体值及空输入行为见作用说明。
func _first_visible_enabled_button(root: Node) -> Button:
	var buttons: Array[Button] = _collect_visible_enabled_buttons(root)
	return buttons[0] if not buttons.is_empty() else null


## 作用：按 needles 在按钮文本中的匹配数量，选出最高分的可见启用按钮。
## 使用：由已启用的整局采样流程调用。 入参：needles: Array[String]。 返回 Button；具体值及空输入行为见作用说明。
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


## 作用：合并按钮直接文本与后代 Label 文本，返回用空格连接的字符串。
## 使用：由已启用的整局采样流程调用。 入参：button: Button。 返回 String；具体值及空输入行为见作用说明。
func _button_text(button: Button) -> String:
	var parts: Array[String] = []
	if button.text.strip_edges() != "":
		parts.append(button.text)
	_collect_label_text(button, parts)
	return " ".join(parts)


## 作用：递归把非空 Label 文本追加到 parts，供按钮文本评分。
## 使用：由已启用的整局采样流程调用。 入参：root: Node, parts: Array[String]。
func _collect_label_text(root: Node, parts: Array[String]) -> void:
	for child: Node in root.get_children():
		if child is Label:
			var label_text: String = (child as Label).text.strip_edges()
			if label_text != "":
				parts.append(label_text)
		_collect_label_text(child, parts)


## 作用：检查 Control 非空且在场景树中可见。
## 使用：由已启用的整局采样流程调用。 入参：control: Control。 返回 bool；具体值及空输入行为见作用说明。
func _is_control_visible(control: Control) -> bool:
	return control != null and control.is_visible_in_tree()


## 作用：节点入树时累计创建/存活计数、逐帧事件和来源记录，延迟修正来源；弹字另外保留历史候选。
## 使用：由已连接的信号或采样 Callable 触发。 入参：_node: Node。
func _on_node_added(_node: Node) -> void:
	if _enabled:
		_node_created_total += 1
		_node_created_window += 1
		var record: Dictionary = _node_record(_node)
		var instance_id: int = int(_node.get_instance_id())
		_node_records_by_instance_id[instance_id] = record
		_increment_dict(_created_by_key, String(record.get("key", "unknown")), 1)
		_increment_dict(_created_by_category, String(record.get("category", "other")), 1)
		_record_node_source_created(record, 1)
		_record_live_delta(record, 1)
		_add_frame_node_event("created", record)
		call_deferred("_refresh_node_record_source_attribution", instance_id)
		if String(record.get("category", "")) == "damage_number":
			_damage_number_created_total += 1
			_damage_number_selector_candidates[str(instance_id)] = record


## 作用：节点出树时使用缓存归因记录累计销毁与存活减量，记录逐帧事件后移除实例缓存。
## 使用：由已连接的信号或采样 Callable 触发。 入参：_node: Node。
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
		_record_node_source_destroyed(record, 1)
		_record_live_delta(record, -1)
		_add_frame_node_event("destroyed", record)
		if String(record.get("category", "")) == "damage_number":
			_damage_number_destroyed_total += 1
		_node_records_by_instance_id.erase(instance_id)


## 作用：由平均帧毫秒换算平均 FPS，非正平均值返回零。
## 使用：由已启用的整局采样流程调用。 返回 float；具体值及空输入行为见作用说明。
func _average_fps() -> float:
	var avg_ms: float = _average(_frame_ms_values)
	return 1000.0 / avg_ms if avg_ms > 0.0 else 0.0


## 作用：计算 float 数组的算术均值，空数组返回零。
## 使用：由已启用的整局采样流程调用。 入参：values: Array[float]。 返回 float；具体值及空输入行为见作用说明。
func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


## 作用：复制排序帧时长数组，按 ceil(percentile*N)-1 取得分位值，空数组返回零。
## 使用：由已启用的整局采样流程调用。 入参：values: Array[float], percentile: float。 返回 float；具体值及空输入行为见作用说明。
func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]


## 作用：把调试面板 enabled 快照字段转为报告中的 on/off 文本。
## 使用：由已启用的整局采样流程调用。 入参：snapshot: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _debug_panel_summary(snapshot: Dictionary) -> String:
	return "on" if bool(snapshot.get("enabled", false)) else "off"


## 作用：将报告文字中的回车、换行和制表符替换为空格，保持单行日志。
## 使用：由已启用的整局采样流程调用。 入参：value: Variant。 返回 String；具体值及空输入行为见作用说明。
func _safe_text(value: Variant) -> String:
	return String(value).replace("\r", " ").replace("\n", " ").replace("\t", " ")


## 作用：释放移动与冲刺 Input 动作，避免结束流程遗留按键状态。
## 使用：由已启用的整局采样流程调用。
func _release_movement() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"dash"]:
		Input.action_release(action)


## 作用：幂等结束采样，恢复时间倍率为一，移除根节点采样回调和标志，释放输入后用 exit_code 退出。
## 使用：传入进程 exit_code；结束标记保证重复调用无副作用，清除 root 回调并退出场景树。
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
		if get_tree().root.has_meta(PROFILER_HOT_PATH_EVENT_META):
			get_tree().root.remove_meta(PROFILER_HOT_PATH_EVENT_META)
		if get_tree().root.has_meta(PROFILER_AOE_TICK_EVENT_META):
			get_tree().root.remove_meta(PROFILER_AOE_TICK_EVENT_META)
	_release_movement()
	get_tree().quit(exit_code)


## 作用：字典输入直接返回引用，其他值返回空字典，供统计桶原位更新。
## 使用：由已启用的整局采样流程调用。 入参：value: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## 作用：按 key 给 dictionary 原位累计 amount，缺失键从零开始。
## 使用：由已启用的整局采样流程调用。 入参：dictionary: Dictionary, key: Variant, amount: int。
func _increment_dict(dictionary: Dictionary, key: Variant, amount: int) -> void:
	dictionary[key] = int(dictionary.get(key, 0)) + amount
