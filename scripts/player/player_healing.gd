## 文件用途：统一生命恢复入口，以实际恢复量记录治疗，供玩家与兼容受治疗节点使用。
extends RefCounted

const RunStatsTrackerScript = preload("res://scripts/game/run_stats_tracker.gd")

## 使用：优先调用玩家 heal；普通可治疗节点采用相同血量边界和信号语义。
static func apply(target: Node, amount: int) -> int:
	if not is_instance_valid(target) or amount <= 0:
		return 0
	if target.has_method("heal"):
		return int(target.call("heal", amount))
	return restore(target, amount)

## 使用：由 Player.heal 调用；上限增长不进入本函数，满血与非正数不计治疗。
static func restore(target: Node, amount: int) -> int:
	if not is_instance_valid(target) or amount <= 0:
		return 0
	var before: int = int(target.get("current_health"))
	var max_health: int = int(target.get("max_health"))
	var restored: int = mini(amount, maxi(max_health - before, 0))
	if restored <= 0:
		return 0
	target.set("current_health", before + restored)
	if target.is_in_group(&"player"):
		var tracker: Node = RunStatsTrackerScript.get_active(target.get_tree())
		if tracker != null:
			tracker.record_healing(restored)
	if target.has_signal("health_changed"):
		target.emit_signal("health_changed", before + restored, max_health)
	return restored
