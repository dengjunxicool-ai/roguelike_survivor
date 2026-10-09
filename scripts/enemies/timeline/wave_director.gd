## 文件用途：管理离散波次的启动、预算投放、结束与过渡经验收集。
## 使用方式：setup 绑定 spawner；每帧 process_discrete_wave，批次间隔适配预算而不裁剪总数量。

extends RefCounted
class_name WaveDirector


var _owner: Node


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node) -> void:
	_owner = owner


## 作用：推进波次计时、事件、生成和过渡，并判断提前清场或超时结束。
## 使用：spawner 每物理帧调用，delta 为秒；过渡期间持续收集经验，避免漏掉延迟生成晶体。
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

	if int(_owner.get("_wave_spawned_count")) >= int(_owner.get("_wave_total_count")) and int(_owner.call("_get_alive_enemy_count")) <= 0:
		finish_wave(true)


## 作用：按波次剩余预算投放一个批次并更新冷却。
## 使用：警示中的敌人也计入占场；实际生成数回写预算进度，不裁剪总预算。
func process_wave_spawn(delta: float, wave: Dictionary) -> void:
	if _owner == null:
		return
	if int(_owner.get("_wave_spawned_count")) >= int(_owner.get("_wave_total_count")):
		return

	var cooldown: float = maxf(float(_owner.get("_normal_spawn_cooldown")) - delta, 0.0)
	_owner.set("_normal_spawn_cooldown", cooldown)
	# Pending warnings count as enemies so an empty field cannot flood every tick.
	if cooldown > 0.0 and int(_owner.call("_get_alive_enemy_count")) > 0:
		return

	var remaining_budget: int = maxi(int(_owner.get("_wave_total_count")) - int(_owner.get("_wave_spawned_count")), 0)
	var batch_limit: int = mini(int(_owner.get("_max_spawn_batch_size")), remaining_budget)
	var spawned: int = int(_owner.call(
		"_spawn_batch_from_source",
		wave,
		_owner.call("_get_wave_enemy_multipliers", wave),
		&"wave",
		batch_limit
	))
	_owner.set("_wave_spawned_count", int(_owner.get("_wave_spawned_count")) + spawned)
	_owner.set("_normal_spawn_cooldown", _get_batch_interval(wave))


## 作用：计算能在波次期限内投完预算的批次间隔。
## 使用：使用波次时长、警示时长和批次数；间隔至少 0.05 秒；返回计算或读取的数值。
func _get_batch_interval(wave: Dictionary) -> float:
	var interval: float = maxf(float(wave.get("spawn_batch_interval_seconds", _owner.get("_spawn_batch_interval"))), 0.05)
	var batches: int = ceili(float(_owner.get("_wave_total_count")) / float(_owner.get("_max_spawn_batch_size")))
	var duration: float = float(wave.get("duration_seconds", 0.0))
	var warning_duration: float = float(_owner.get("_spawn_warning_duration"))
	# Density modifiers increase the wave budget; speed delivery up instead of truncating it.
	if batches > 1 and duration > warning_duration + 0.1:
		interval = minf(interval, (duration - warning_duration - 0.1) / float(batches - 1))
	return maxf(interval, 0.05)


## 作用：载入指定波次、重置计时和生成计数并发出波次信号。
## 使用：wave_index 从 0 开始；无对应波次则进入普通阶段结束流程。
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
	_owner.set("_normal_spawn_cooldown", 0.0)
	_owner.set("_wave_total_count", int(_owner.call("_get_wave_total_count", wave)))
	_owner.set("_wave_transition_timer", 0.0)
	_owner.emit_signal(&"wave_changed", wave_id)
	_owner.emit_signal(&"wave_timer_changed", wave_index + 1, wave_id, wave_duration, wave_duration, 0, int(_owner.get("_wave_total_count")))
	_owner.emit_signal(
		&"timeline_event_started",
		"wave:%s" % wave_id,
		String(wave.get("announcement", "第 %s 波来袭" % wave_id))
	)


## 作用：发布波次结束、收集经验并开始下一波的过渡计时。
## 使用：cleared_early 区分提前清场与超时；超时不等同于杀死遗留敌人。
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


## 作用：收集波次经验晶体组；具体处理委托给 _owner._collect_all_experience_crystals。
## 使用：本文件由 process_discrete_wave、finish_wave 调用。
func _collect_wave_experience_crystals() -> void:
	if _owner == null:
		return
	_owner.call("_collect_all_experience_crystals")
	_owner.call_deferred("_collect_all_experience_crystals")
