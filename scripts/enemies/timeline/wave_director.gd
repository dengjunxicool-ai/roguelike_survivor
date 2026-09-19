extends RefCounted
class_name WaveDirector


var _owner: Node


func setup(owner: Node) -> void:
	_owner = owner


func process_discrete_wave(delta: float) -> void:
	if _owner == null:
		return

	if int(_owner.get("_current_wave_index")) < 0:
		start_wave(0)
		return

	var transition_timer: float = float(_owner.get("_wave_transition_timer"))
	if transition_timer > 0.0:
		_collect_wave_experience_crystals()
		transition_timer = maxf(transition_timer - delta, 0.0)
		_owner.set("_wave_transition_timer", transition_timer)
		if transition_timer <= 0.0:
			_collect_wave_experience_crystals()
			start_wave(int(_owner.get("_current_wave_index")) + 1)
		return

	var wave: Dictionary = _owner.call("_get_wave_at_index", int(_owner.get("_current_wave_index")))
	if wave.is_empty():
		_owner.call("_finish_normal_phase")
		return

	var wave_duration: float = float(_owner.get("_wave_duration"))
	var wave_elapsed_time: float = minf(float(_owner.get("_wave_elapsed_time")) + delta, wave_duration)
	_owner.set("_wave_elapsed_time", wave_elapsed_time)
	_owner.call("_process_wave_events", wave)
	process_wave_spawn(delta, wave)

	var remaining: float = maxf(wave_duration - wave_elapsed_time, 0.0)
	_owner.emit_signal(
		&"wave_timer_changed",
		int(_owner.get("_current_wave_index")) + 1,
		String(_owner.get("_current_wave_id")),
		remaining,
		wave_duration,
		int(_owner.get("_wave_spawned_count")),
		int(_owner.get("_wave_total_count"))
	)

	if wave_elapsed_time >= wave_duration:
		finish_wave(false)
		return

	if int(_owner.get("_wave_spawned_count")) >= int(_owner.get("_wave_total_count")) and int(_owner.call("_get_alive_normal_enemy_count")) <= 0:
		finish_wave(true)


func process_wave_spawn(delta: float, wave: Dictionary) -> void:
	if _owner == null:
		return
	if int(_owner.get("_wave_spawned_count")) >= int(_owner.get("_wave_total_count")):
		return

	var cooldown: float = maxf(float(_owner.get("_normal_spawn_cooldown")) - delta, 0.0)
	_owner.set("_normal_spawn_cooldown", cooldown)
	if cooldown > 0.0:
		return

	var max_alive: int = mini(int(wave.get("max_alive", _owner.get("_max_normal_enemies_alive"))), int(_owner.get("_max_normal_enemies_alive")))
	var alive_count: int = int(_owner.call("_get_alive_normal_enemy_count"))
	if alive_count >= max_alive:
		_owner.set("_normal_spawn_cooldown", float(_owner.get("_spawn_batch_interval")))
		return

	var remaining_budget: int = maxi(int(_owner.get("_wave_total_count")) - int(_owner.get("_wave_spawned_count")), 0)
	var available_slots: int = maxi(max_alive - alive_count, 0)
	var batch_limit: int = mini(int(_owner.get("_max_spawn_batch_size")), mini(remaining_budget, available_slots))
	var spawned: int = int(_owner.call(
		"_spawn_batch_from_source",
		wave,
		_owner.call("_get_wave_enemy_multipliers", wave),
		&"normal",
		batch_limit
	))
	_owner.set("_wave_spawned_count", int(_owner.get("_wave_spawned_count")) + spawned)
	_owner.set("_normal_spawn_cooldown", float(_owner.get("_spawn_batch_interval")))


func start_wave(wave_index: int) -> void:
	if _owner == null:
		return

	var wave: Dictionary = _owner.call("_get_wave_at_index", wave_index)
	if wave.is_empty():
		_owner.call("_finish_normal_phase")
		return

	var wave_id: String = String(wave.get("id", "wave_%02d" % (wave_index + 1)))
	var wave_duration: float = float(wave.get("duration_seconds", _owner.get("_wave_duration")))
	_owner.set("_current_wave_index", wave_index)
	_owner.set("_current_wave_id", wave_id)
	_owner.set("_wave_duration", wave_duration)
	_owner.set("_wave_elapsed_time", 0.0)
	_owner.set("_wave_spawned_count", 0)
	_owner.set("_wave_total_count", int(_owner.call("_get_wave_total_count", wave)))
	_owner.set("_wave_transition_timer", 0.0)
	_owner.emit_signal(&"wave_changed", wave_id)
	_owner.emit_signal(&"wave_timer_changed", wave_index + 1, wave_id, wave_duration, wave_duration, 0, int(_owner.get("_wave_total_count")))
	_owner.emit_signal(
		&"timeline_event_started",
		"wave:%s" % wave_id,
		String(wave.get("announcement", "第 %s 波来袭" % wave_id))
	)


func finish_wave(cleared_early: bool) -> void:
	if _owner == null:
		return

	var finished_wave_id: String = String(_owner.get("_current_wave_id"))
	_collect_wave_experience_crystals()
	_owner.emit_signal(&"wave_cleared", finished_wave_id, cleared_early)
	if (_owner.call("_get_wave_at_index", int(_owner.get("_current_wave_index")) + 1) as Dictionary).is_empty():
		_owner.call("_finish_normal_phase")
		return

	var transition_timer: float = maxf(float(_owner.get("_wave_transition_notice_seconds")), 0.0)
	_owner.set("_wave_transition_timer", transition_timer)
	_owner.emit_signal(&"timeline_event_started", "wave_transition:%s" % finished_wave_id, "短暂喘息，准备下一波")
	if transition_timer <= 0.0:
		_collect_wave_experience_crystals()
		start_wave(int(_owner.get("_current_wave_index")) + 1)


func _collect_wave_experience_crystals() -> void:
	if _owner == null:
		return
	_owner.call("_collect_all_experience_crystals")
	_owner.call_deferred("_collect_all_experience_crystals")
