extends RefCounted
class_name EnemyTimelineController


var _owner: Node


func setup(owner: Node) -> void:
	_owner = owner


func process(delta: float) -> void:
	if _owner == null:
		return
	if bool(_owner.call("_is_debug_control_mode")):
		return

	_owner.set("_elapsed_time", minf(float(_owner.get("_elapsed_time")) + delta, float(_owner.get("_hard_time_limit"))))

	_owner.call("_despawn_far_enemies")
	_owner.call("_process_reward_events")
	_owner.call("_process_boss_event")
	if bool(_owner.get("_boss_active")):
		_owner.call("_process_boss_minion_spawn", delta)
	elif not bool(_owner.get("_normal_phase_complete")):
		_owner.call("_process_discrete_wave", delta)

	_owner.emit_signal(&"run_time_changed", float(_owner.get("_elapsed_time")), float(_owner.get("_run_duration")))
