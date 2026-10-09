## 文件用途：累计连续移动时间激活属性，并在停步或受击打断后提供短时惩罚。
## 使用方式：接收玩家移动、停止和受击事件；process 推进惩罚倒计时，get_modifiers 按当前阶段返回快照。
extends CharacterTrait
class_name MovingBonusTrait


const CharacterEventScript: Script = preload("res://scripts/characters/events/character_event.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")

var _moving_time: float = 0.0
var _stopped_time: float = 0.0
var _movement_penalty_remaining: float = 0.0


## 作用：调用基类 setup 后清零移动、停止和惩罚计时。
## 使用：trait_config 为当前角色特性配置；trait_context 为角色和场景树上下文。
func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	super.setup(trait_config, trait_context)
	_moving_time = 0.0
	_stopped_time = 0.0
	_movement_penalty_remaining = 0.0


## 作用：每帧扣减移动打断惩罚的剩余秒数并截断到零。
## 使用：delta 为本帧经过的秒数。
func process(delta: float) -> void:
	_movement_penalty_remaining = maxf(_movement_penalty_remaining - delta, 0.0)


## 作用：按玩家移动、停止或受伤事件更新连续移动节奏与打断状态。
## 使用：event 读取 payload/type。
func handle_event(event: RefCounted) -> void:
	var payload: Dictionary = _get_dictionary(event.get("payload"))
	match StringName(event.get("type")):
		CharacterEventScript.PLAYER_MOVED:
			_on_player_moved(float(payload.get("delta", 0.0)))
		CharacterEventScript.PLAYER_STOPPED:
			_on_player_stopped(float(payload.get("delta", 0.0)))
		CharacterEventScript.PLAYER_DAMAGED:
			_break_moving_bonus()


## 作用：移动已满足门槛时返回激活属性，否则惩罚窗口内返回惩罚属性，其余为空。
## 使用：接收玩家移动、停止和受击事件；process 推进惩罚倒计时，get_modifiers 按当前阶段返回快照；无适用数据时返回空字典。
func get_modifiers(_query: RefCounted) -> Dictionary:
	var params: Dictionary = _get_params()
	var required_time: float = maxf(float(params.get("moving_seconds_required", 2.5)), 0.0)
	if _moving_time >= required_time:
		return _get_modifier_values(params.get("active_modifiers", []))
	if _movement_penalty_remaining > 0.0:
		return _get_modifier_values(params.get("penalty_modifiers", []))
	return {}


## 作用：返回当前特性运行状态，包括 moving_time、stopped_time、movement_penalty_remaining，供运行时与调试查询。
## 使用：接收玩家移动、停止和受击事件；process 推进惩罚倒计时，get_modifiers 按当前阶段返回快照。
func get_debug_state() -> Dictionary:
	return {
		"moving_time": _moving_time,
		"stopped_time": _stopped_time,
		"movement_penalty_remaining": _movement_penalty_remaining
	}


## 作用：累积连续移动时长，达到激活门槛后记录猎手节奏持续时间。
## 使用：delta 为本帧经过的秒数。
func _on_player_moved(delta: float) -> void:
	var params: Dictionary = _get_params()
	var required_time: float = maxf(float(params.get("moving_seconds_required", 2.5)), 0.0)
	_stopped_time = 0.0
	_moving_time = minf(_moving_time + delta, required_time)
	if _moving_time >= required_time:
		var tree: SceneTree = null
		if context != null:
			tree = context.get("tree") as SceneTree
		var tracker: Node = RunStatsTrackerScript.get_active(tree)
		if tracker != null and tracker.has_method("record_hunter_rhythm"):
			tracker.call("record_hunter_rhythm", delta)


## 作用：累计停步时间，超过容许停步窗口后打断移动增益。
## 使用：delta 为本帧经过的秒数。
func _on_player_stopped(delta: float) -> void:
	var params: Dictionary = _get_params()
	var break_seconds: float = maxf(float(params.get("stop_break_seconds", 0.0)), 0.0)
	if break_seconds > 0.0:
		_stopped_time += delta
		if _stopped_time < break_seconds:
			return
	_break_moving_bonus()


## 作用：在已激活时启动惩罚倒计时，并清空移动与停止累计时间。
## 使用：由本文件 handle_event/_on_player_stopped 调用。
func _break_moving_bonus() -> void:
	var params: Dictionary = _get_params()
	var required_time: float = maxf(float(params.get("moving_seconds_required", 2.5)), 0.0)
	if _moving_time >= required_time:
		_movement_penalty_remaining = maxf(float(params.get("penalty_duration", 3.0)), 0.0)
	_moving_time = 0.0
	_stopped_time = 0.0
