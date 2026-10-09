## 文件用途：构建调试开局页，选择角色地图、重启开发局并提升起始技能等级。
## 使用方式：以 DevDebugPanel 宿主构造本页控制器；持有 WeakRef，宿主负责控件与回调装配，不能独立挂载到场景。
extends RefCounted


var _host_ref: WeakRef

## 作用：保存宿主弱引用，供开局页操作宿主控件和游戏服务。
## 使用：创建页面控制器时传入 DevDebugPanel 宿主，保存弱引用。
func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


## 作用：添加角色、地图、重启与 Lv3 控件，将按钮和选择信号绑定到宿主入口。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：page_root: VBoxContainer。
func _build_run_setup_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var run_setup_page: VBoxContainer = host._add_category_page(page_root, "run_setup", "Run Setup")
	host._character_option = host._add_option_row(run_setup_page, "Character")
	host._map_option = host._add_option_row(run_setup_page, "Map")
	host._character_option.item_selected.connect(Callable(host, "_on_character_selected"))
	host._map_option.item_selected.connect(Callable(host, "_on_setup_option_selected"))

	var run_row: HBoxContainer = host._add_row(run_setup_page)
	host._add_button(run_row, "Restart Run", Callable(host, "_restart_debug_run"), 132)
	host._add_button(run_row, "Lv3", Callable(host, "_level_starting_skill_to").bind(3), 60)


## 作用：从 GameData 角色池填充带稳定 ID 元数据的下拉选项，跳过空 ID。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _populate_character_options() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._character_option.clear()
	for character: Dictionary in GameData.get_character_pool():
		var id: String = String(character.get("id", ""))
		if id == "":
			continue
		host._add_option_item(host._character_option, host._display_name(character, id), id)


## 作用：从 GameData 地图池填充地图下拉选项，跳过空 ID。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _populate_map_options() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._map_option.clear()
	for map_data: Dictionary in GameData.get_map_pool():
		var id: String = String(map_data.get("id", ""))
		if id == "":
			continue
		host._add_option_item(host._map_option, host._display_name(map_data, id), id)


## 作用：响应角色下拉选择，重新同步玩家及技能属性控件并刷新摘要；不直接换角色。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：_index: int。
func _on_character_selected(_index: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._sync_player_stat_controls()
	host._sync_skill_stat_controls()
	host._refresh_state()


## 作用：响应地图等开局选项选择，仅刷新宿主摘要。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：_index: int。
func _on_setup_option_selected(_index: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._refresh_state()


## 作用：把当前玩家角色和 UIManager 已选地图同步到下拉框，并刷新属性输入。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _sync_options_from_runtime() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player != null:
		host._select_option_by_id(host._character_option, String(player.get("selected_character_id")))

	var ui_manager: Node = host._get_ui_manager()
	if ui_manager != null:
		var selected_map: Variant = ui_manager.get("_selected_map_id")
		host._select_option_by_id(host._map_option, String(selected_map))
	host._sync_player_stat_controls()
	host._sync_skill_stat_controls()


## 作用：把面板角色和地图 ID 交给 UIManager.start_developer_debug_run，随后延迟刷新宿主状态。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _restart_debug_run() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var ui_manager: Node = host._get_ui_manager()
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		host._log_error("UIManager.start_developer_debug_run missing.")
		return
	ui_manager.call("start_developer_debug_run", {
		"character_id": host._get_selected_id(host._character_option),
		"map_id": host._get_selected_id(host._map_option)
	})
	host.call_deferred("_refresh_state")
	host._log("Restarted debug run.")


## 作用：反复调用玩家 _upgrade_skill 将起始技能提升到 target_level，升级拒绝时停止，再同步控件。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：target_level: int。
func _level_starting_skill_to(target_level: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	var skill: RefCounted = host._get_starting_skill(player)
	if player == null or skill == null:
		host._log_error("Starting skill missing.")
		return

	var skill_id: StringName = StringName(host._string_or(skill.get("skill_id"), ""))
	while int(skill.get("current_level")) < target_level:
		if not player.has_method("_upgrade_skill") or not bool(player.call("_upgrade_skill", skill_id, 1)):
			break
	host._sync_skill_stat_controls()
	host._log("Starting skill %s -> Lv.%d." % [String(skill_id), int(skill.get("current_level"))])
