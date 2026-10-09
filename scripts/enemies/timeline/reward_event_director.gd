## 文件用途：按时间与触发条件发布局内奖励事件。
## 使用方式：setup 绑定 spawner；process_reward_events 扫描，start_reward_event 发布事件信号。

extends RefCounted
class_name RewardEventDirector


var _owner: Node


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node) -> void:
	_owner = owner


## 作用：更新奖励事件组。
## 使用：供本模块调用者使用。
func process_reward_events() -> void:
	if _owner == null:
		return

	var elapsed_time: float = float(_owner.get("_elapsed_time"))
	var triggered: Dictionary = _owner.get("_triggered_reward_events")
	if elapsed_time >= 220.0 and not triggered.has("builtin_final_blessing"):
		triggered["builtin_final_blessing"] = true
		_owner.set("_triggered_reward_events", triggered)
		_owner.emit_signal(&"timeline_event_started", "final_blessing:builtin", "Boss 前祝福")

	var rewards: Dictionary = _owner.call("_get_config_dictionary", "rewards")
	var reward_events: Array = _get_array(rewards.get("wave_clear_rewards", []))
	for event_index in range(reward_events.size()):
		var event_variant: Variant = reward_events[event_index]
		if not (event_variant is Dictionary):
			continue

		var event: Dictionary = event_variant
		triggered = _owner.get("_triggered_reward_events")
		if triggered.has(event_index):
			continue
		if elapsed_time < float(event.get("time", 0.0)):
			continue

		triggered[event_index] = true
		_owner.set("_triggered_reward_events", triggered)
		start_reward_event(event_index, event)


## 作用：启动奖励事件。
## 使用：本文件由 process_reward_events 调用；输入 event_index（事件索引）、event（事件）。
func start_reward_event(event_index: int, event: Dictionary) -> void:
	if _owner == null:
		return

	match String(event.get("type", "")):
		"force_level_up":
			var tree: SceneTree = _owner.get_tree()
			var target_group: StringName = StringName(String(_owner.get("target_group")))
			var player: Node = tree.get_first_node_in_group(target_group) if tree != null else null
			if player != null and player.has_signal(&"leveled_up"):
				player.emit_signal(&"leveled_up", int(player.get("level")) + 1)

	_owner.emit_signal(
		&"timeline_event_started",
		"reward:%d:%s" % [event_index, String(event.get("type", ""))],
		String(event.get("announcement", ""))
	)


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 process_reward_events 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
