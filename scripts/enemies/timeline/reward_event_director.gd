## 文件用途：按时间与触发条件发布局内奖励事件。
## 使用方式：setup 绑定 spawner；process_reward_events 扫描，start_reward_event 发布事件信号。

extends RefCounted
class_name RewardEventDirector


var _owner: Node
var _treasure_service: RefCounted = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd").new()
var _treasure_roll_rng := RandomNumberGenerator.new()
var _treasure_position_rng := RandomNumberGenerator.new()
var _treasure_seeded := false
var _treasure_reserved := 0
var _treasure_draws := 0


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node) -> void:
	_owner = owner
	_treasure_service.call("cancel_all",&"run_reset",true)
	_treasure_seeded=false
	_treasure_reserved=0
	_treasure_draws=0
	_treasure_service.call("setup",owner,owner.get("enemy_scene"),null,owner.get("target_group"),_treasure_position_rng)
	_treasure_service.call("set_visible_spawn_rules",true,64.0,120.0,1.5)
	_treasure_service.call("set_context",int(owner.get("_run_generation")),String(owner.get("_current_wave_id")))
	if not _treasure_service.is_connected("spawn_created",Callable(self,"_on_treasure_created")):
		_treasure_service.connect("spawn_created",Callable(self,"_on_treasure_created"))

func get_treasure_snapshot() -> Dictionary:
	return {"reserved":_treasure_reserved,"draws":_treasure_draws,"pending":_treasure_service.call("get_pending_count"),"delivery":_treasure_service.get("statistics").duplicate(true)}

func cancel_pending_for_transition() -> void:
	_treasure_service.call("set_context",int(_owner.get("_run_generation")),"")

func _on_treasure_created(request: Dictionary, _enemy: Node2D) -> void:
	_owner.emit_signal(&"timeline_event_started",String(request.source_id),"宝石史莱姆出现")

func _process_treasure_events(rewards: Dictionary) -> void:
	var wave_id := String(_owner.get("_current_wave_id"))
	_treasure_service.call("set_context",int(_owner.get("_run_generation")),wave_id)
	if String(_owner.call("_get_wave_progress_snapshot").get("transition_kind",""))!="active": return
	if not _treasure_seeded:
		var normal_rng: RandomNumberGenerator = _owner.get("_rng")
		_treasure_roll_rng.seed=int(normal_rng.seed)^0x74726561
		_treasure_position_rng.seed=int(normal_rng.seed)^0x67656d73
		_treasure_seeded=true
	for event: Dictionary in _get_array(rewards.get("treasure_events",[])):
		if String(event.get("wave_id",""))!=wave_id or float(_owner.get("_wave_elapsed_time"))<float(event.get("wave_time",5.0)): continue
		var key := "treasure:"+wave_id
		var triggered: Dictionary = _owner.get("_triggered_reward_events")
		if triggered.has(key): continue
		triggered[key]=true
		_treasure_draws+=1
		var roll := _treasure_roll_rng.randf()
		if roll>=float(event.get("chance",0.35)) or _treasure_reserved>=mini(2,int(event.get("max_per_run",2))): continue
		_treasure_reserved+=1
		var request: Dictionary = preload("res://scripts/enemies/spawning/enemy_spawn_request.gd").create(event.get("enemy_id","gem_slime"),{
			"source_type":"treasure_event","source_id":key,"wave_bound":true,
			"treasure_lifetime":float(event.get("lifetime",12.0)),"visible_spawn":true,
			"avoid_map_hazards":true})
		_treasure_service.call("spawn",request)


## 作用：更新奖励事件组。
## 使用：供本模块调用者使用。
func process_reward_events() -> void:
	if _owner == null:
		return

	var elapsed_time: float = float(_owner.get("_elapsed_time"))
	var triggered: Dictionary = _owner.get("_triggered_reward_events")
	if String(_owner.call("_get_wave_progress_snapshot").get("transition_kind",""))=="boss_prepare" and not triggered.has("builtin_final_blessing"):
		triggered["builtin_final_blessing"] = true
		_owner.set("_triggered_reward_events", triggered)
		_owner.emit_signal(&"timeline_event_started", "final_blessing:builtin", "Boss 前祝福")

	var rewards: Dictionary = _owner.call("_get_config_dictionary", "rewards")
	_process_treasure_events(rewards)
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
