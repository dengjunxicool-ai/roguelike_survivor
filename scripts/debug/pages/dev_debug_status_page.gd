## 文件用途：构建调试状态页，按目标选择批量施加或清除状态，接入单次攻击伤害追踪。
## 使用方式：以 DevDebugPanel 宿主构造本页控制器；持有 WeakRef，宿主负责控件与回调装配，不能独立挂载到场景。
extends RefCounted

const DevDebugDataSourceScript: Script = preload("res://scripts/debug/dev_debug_data_source.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/runtime/debug_combat_trace.gd")

var _host_ref: WeakRef

## 作用：保存宿主弱引用，复用宿主的目标查找、控件和伤害卡入口。
## 使用：创建页面控制器时传入 DevDebugPanel 宿主，保存弱引用。
func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


## 作用：建立状态、层数、时长、全敌人和玩家目标控件，绑定施加与清除按钮。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：page_root: VBoxContainer。
func _build_status_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var status_page: VBoxContainer = host._add_category_page(page_root, "status", "Status / Stacks")
	host._status_option = host._add_option_row(status_page, "Status")
	host._status_stack_spin = host._add_spin_row(status_page, "Stacks", 1.0, 99.0, 1.0, 1.0)
	host._status_duration_spin = host._add_spin_row(status_page, "Duration", 0.1, 120.0, 0.5, 6.0)
	var check_row: HBoxContainer = host._add_row(status_page)
	host._apply_to_all_enemies_check = CheckBox.new()
	host._apply_to_all_enemies_check.text = "All enemies"
	check_row.add_child(host._apply_to_all_enemies_check)
	host._target_player_check = CheckBox.new()
	host._target_player_check.text = "Target player"
	check_row.add_child(host._target_player_check)
	var status_row: HBoxContainer = host._add_row(status_page)
	host._add_button(status_row, "Apply Status", Callable(host, "_apply_status_from_panel"), 124)
	host._add_button(status_row, "Clear Status", Callable(host, "_clear_statuses"), 112)


## 作用：从 GameData 状态池填充能够查询到定义的选项。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _populate_status_options() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._status_option.clear()
	for status: Dictionary in GameData.get_status_pool():
		var id: String = String(status.get("id", ""))
		if id == "" or not host._is_status_option_available(id):
			continue
		host._add_option_item(host._status_option, host._display_name(status, id), id)


## 作用：判断状态 ID 是否解析到非空定义，避免生成无效选项。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：status_id: Variant。 返回 bool；具体值及空输入行为见作用说明。
func _is_status_option_available(status_id: Variant) -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return not host._get_status_definition_for_option(status_id).is_empty()


## 作用：经 DevDebugDataSource 查询状态配置，返回 GameData 的定义。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：status_id: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_status_definition_for_option(status_id: Variant) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return DevDebugDataSourceScript.get_status_definition_for_option(host, status_id)


## 作用：读取状态层数和时长，启动新追踪并重置伤害卡，对选中目标调用 apply_status，记录成功数。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _apply_status_from_panel() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var status_id: StringName = host._get_selected_id(host._status_option)
	var stacks: int = maxi(roundi(float(host._status_stack_spin.value)), 1)
	var duration: float = maxf(float(host._status_duration_spin.value), 0.1)
	var targets: Array[Node] = host._get_status_targets()
	if targets.is_empty():
		host._log_warn("No status target.")
		return

	var root: Node = host.get_tree().root if host.get_tree() != null else null
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	host._attack_damage_card_index = 0
	host._reset_attack_damage_scroll()
	host._last_attack_damage_text = "Damage Breakdown\nTrace #%d waiting for %s tick..." % [trace_id, String(status_id)]
	host._refresh_attack_damage_text()

	var status_params: Dictionary = {
		"duration": duration,
		"stacks": stacks,
		"stack": stacks,
		"max_stacks": stacks
	}
	if trace_id > 0:
		status_params["debug_attack_trace_id"] = trace_id

	var applied_count: int = 0
	for target: Node in targets:
		if target != null and target.has_method("apply_status"):
			if bool(target.call("apply_status", status_id, status_params)):
				applied_count += 1
	host._log("Applied %s x%d to %d target(s), trace #%d." % [String(status_id), stacks, applied_count, trace_id])


## 作用：按玩家优先、其次全敌人、最后最近敌人的顺序确定目标数组。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 Array[Node]；具体值及空输入行为见作用说明。
func _get_status_targets() -> Array[Node]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var result: Array[Node] = []
	if host._target_player_check != null and host._target_player_check.button_pressed:
		var player: Node = host._get_player()
		if player != null:
			result.append(player)
		return result
	if host._apply_to_all_enemies_check != null and host._apply_to_all_enemies_check.button_pressed:
		for enemy: Node in host.get_tree().get_nodes_in_group(&"enemies"):
			result.append(enemy)
		return result
	var nearest: Node = host._get_nearest_enemy()
	if nearest != null:
		result.append(nearest)
	return result


## 作用：对选定目标调用 clear_statuses，并在宿主日志中记录实际调用数。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _clear_statuses() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var cleared: int = 0
	for target: Node in host._get_status_targets():
		if target != null and target.has_method("clear_statuses"):
			target.call("clear_statuses")
			cleared += 1
	host._log("Cleared statuses on %d target(s)." % cleared)
