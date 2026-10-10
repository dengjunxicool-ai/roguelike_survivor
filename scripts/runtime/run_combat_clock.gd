## 局内有效运行时间；继承场景暂停，重开通过 reset 清零。
extends Node
class_name RunCombatClock
var _seconds: float = 0.0
func _physics_process(delta: float) -> void:
	if get_tree() != null and not get_tree().paused:
		tick(delta)
func tick(delta: float) -> void:
	_seconds += maxf(delta, 0.0)
func now_seconds() -> float:
	return _seconds
func reset() -> void:
	_seconds = 0.0
