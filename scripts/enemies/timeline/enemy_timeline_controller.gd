## 文件用途：驱动普通波次、奖励、Boss 和定期远处敌人清理。
## 使用方式：setup 注入 owner；spawner 每次 process 统一推进时间线。

extends RefCounted
class_name EnemyTimelineController


const DESPAWN_SCAN_INTERVAL: float = 0.5

var _owner: Node
var _despawn_cooldown: float = 0.0


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node) -> void:
	_owner = owner


## 作用：更新。
## 使用：供本模块调用者使用；输入 delta（delta）。
func process(delta: float) -> void:
	if _owner == null:
		return
	if bool(_owner.call("_is_debug_control_mode")):
		return

	_owner.set("_elapsed_time",float(_owner.get("_elapsed_time"))+delta)

	_process_despawn_scan(delta)
	_owner.call("_process_reward_events")
	_owner.call("_process_boss_event")
	if bool(_owner.get("_boss_active")):
		_owner.call("_process_boss_minion_spawn", delta)
	elif not bool(_owner.get("_normal_phase_complete")):
		_owner.call("_process_discrete_wave", delta)

	_owner.emit_signal(&"run_time_changed", float(_owner.get("_elapsed_time")), float(_owner.get("_run_duration")))
	var tracker := RunStatsTracker.get_active(_owner.get_tree())
	if tracker!=null:
		tracker.record_wave_snapshot(_owner.call("_get_wave_progress_snapshot"))


## 作用：更新回收扫描；具体处理委托给 _owner._despawn_far_enemies。
## 使用：本文件由 process 调用；输入 delta（delta）。
func _process_despawn_scan(delta: float) -> void:
	_despawn_cooldown = maxf(_despawn_cooldown - delta, 0.0)
	if _despawn_cooldown > 0.0:
		return
	_despawn_cooldown = DESPAWN_SCAN_INTERVAL
	_owner.call("_despawn_far_enemies")
