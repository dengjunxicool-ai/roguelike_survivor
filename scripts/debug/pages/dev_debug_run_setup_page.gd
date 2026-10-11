## 文件用途：构建调试开局页，选择角色地图、编辑技能构筑、开始战斗或重启手动调试局。
## 使用方式：以 DevDebugPanel 宿主构造本页控制器；持有 WeakRef，宿主负责控件与回调装配，不能独立挂载到场景。
extends RefCounted


var _host_ref: WeakRef
const Build := preload("res://scripts/game/developer_skill_build.gd")
const TYPE_LABELS := {"attack": "攻击", "dash": "冲刺", "cast": "施法", "summon": "召唤", "power": "能力", "passive": "被动", "core": "核心", "fusion": "融合"}
const RARITY_LABELS: Array[String] = ["普通", "稀有", "史诗", "传说"]
var _build_entries: Array[Dictionary] = []
var _school_option: OptionButton
var _build_skill_option: OptionButton
var _build_list: VBoxContainer
var _build_summary: Label
var _start_build_button: Button

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
	_build_skill_build_controls(run_setup_page)


## 作用：构建神系筛选、技能选择、可编辑构筑和开始游戏入口。
func _build_skill_build_controls(page: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._add_section(page, "技能构筑")
	_school_option = host._add_option_row(page, "神系筛选")
	_school_option.add_item("全部")
	_school_option.set_item_metadata(0, "")
	for god: Dictionary in GameData.get_god_pool():
		host._add_option_item(_school_option, host._display_name(god, String(god.id)), String(god.id))
	_school_option.item_selected.connect(_on_build_school_selected)
	_build_skill_option = host._add_option_row(page, "添加技能")
	_build_skill_option.name = "BuildSkillOption"
	_build_skill_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var tools: HBoxContainer = host._add_row(page)
	host._add_button(tools, "添加所选技能", _add_selected_build_skill, 132).name = "AddBuildSkillButton"
	host._add_button(tools, "清空构筑", _clear_build, 108).name = "ClearSkillBuildButton"
	_build_summary = Label.new()
	_build_summary.name = "SkillBuildSummary"
	_build_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_build_summary)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_build_list = VBoxContainer.new()
	_build_list.name = "SkillBuildList"
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_build_list)
	var start_row: HBoxContainer = host._add_row(page)
	_start_build_button = host._add_button(start_row, "使用构筑开始游戏", _start_skill_build_run, 220)
	_start_build_button.name = "StartSkillBuildButton"
	_refresh_build_picker()
	_refresh_build_list()


func _on_build_school_selected(_index: int) -> void:
	_refresh_build_picker()


func _refresh_build_picker() -> void:
	if _build_skill_option == null: return
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var previous_id: String = host._get_selected_id(_build_skill_option)
	var school: String = host._get_selected_id(_school_option)
	var character: Dictionary = GameData.get_character(host._get_selected_id(host._character_option))
	_build_skill_option.clear()
	for data: Dictionary in GameData.get_all_skill_pool():
		if not Build.is_selectable(data, character): continue
		if school != "" and host._string_or(data.get("school")) != school and host._string_or(data.get("fusion_school")) != school: continue
		var selected := false
		for entry: Dictionary in _build_entries:
			if String(entry.skill_id) == String(data.id): selected = true
		if selected: continue
		host._add_option_item(_build_skill_option, "%s [%s]" % [host._display_name(data, String(data.id)), TYPE_LABELS.get(String(data.get("skill_type", "")), "技能")], String(data.id))
	host._select_option_by_id(_build_skill_option, previous_id)
	if _build_skill_option.item_count == 0:
		host._add_disabled_option_header(_build_skill_option, "没有可添加的技能")


func _add_selected_build_skill() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var id: String = host._get_selected_id(_build_skill_option)
	if id == "": return
	var candidate: Array[Dictionary] = _build_entries.duplicate(true)
	candidate.append({"skill_id": id, "level": 1, "rarity": "normal"})
	var check: Dictionary = Build.validate(host._get_selected_id(host._character_option), candidate)
	if not bool(check.valid):
		host._log_warn("\n".join(check.errors))
		return
	_build_entries = candidate
	_refresh_build_picker()
	_refresh_build_list()


func _refresh_build_list() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._clear_children(_build_list)
	for entry: Dictionary in _build_entries:
		var data: Dictionary = GameData.get_skill(entry.skill_id)
		var card := VBoxContainer.new()
		card.name = "BuildEntry_%s" % entry.skill_id
		_build_list.add_child(card)
		var label := Label.new()
		label.text = host._display_name(data, String(entry.skill_id))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		var row: HBoxContainer = host._add_row(card)
		var level := SpinBox.new()
		level.name = "BuildLevel"
		level.min_value = 1
		level.max_value = int(data.get("max_level", 1))
		level.step = 1
		level.value = int(entry.level)
		level.prefix = "Lv."
		level.custom_minimum_size = Vector2(100, 30)
		row.add_child(level)
		level.value_changed.connect(_set_build_level.bind(String(entry.skill_id)))
		var rarity := OptionButton.new()
		rarity.name = "BuildRarity"
		for text: String in RARITY_LABELS: rarity.add_item(text)
		rarity.select(Build.RARITIES.find(String(entry.rarity)))
		rarity.custom_minimum_size = Vector2(112, 30)
		row.add_child(rarity)
		rarity.item_selected.connect(_set_build_rarity.bind(String(entry.skill_id)))
		host._add_button(row, "移除", _remove_build_skill.bind(String(entry.skill_id)), 72)
	_update_build_summary()


func _set_build_level(value: float, id: String) -> void:
	for entry: Dictionary in _build_entries:
		if String(entry.skill_id) == id: entry.level = int(value)
	_update_build_summary()


func _set_build_rarity(index: int, id: String) -> void:
	for entry: Dictionary in _build_entries:
		if String(entry.skill_id) == id: entry.rarity = Build.RARITIES[index]


func _remove_build_skill(id: String) -> void:
	for index: int in range(_build_entries.size() - 1, -1, -1):
		if String(_build_entries[index].skill_id) == id: _build_entries.remove_at(index)
	_refresh_build_picker()
	_refresh_build_list()


func _clear_build() -> void:
	_build_entries.clear()
	_refresh_build_picker()
	_refresh_build_list()


func _update_build_summary() -> void:
	if _build_summary == null: return
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var character: Dictionary = GameData.get_character(host._get_selected_id(host._character_option))
	var check: Dictionary = Build.validate(character.get("id", ""), _build_entries)
	var counts: Dictionary = check.counts
	var default_attack: Dictionary = GameData.get_skill(character.get("starting_skill_id", ""))
	_build_summary.text = "攻击 %d/1 · 冲刺 %d/1 · 主动 %d/5\n被动 %d/3 · 核心 %d/1 · 融合 %d/1" % [maxi(int(counts.get("attack", 0)), 1), counts.get("dash", 0), counts.get("ordinary", 0), counts.get("passive", 0), counts.get("core", 0), counts.get("fusion", 0)]
	if int(counts.get("attack", 0)) == 0:
		_build_summary.text += "\n默认攻击：" + host._display_name(default_attack, "")
	_build_summary.text += "\n跳过学习前置条件；开始后自动战斗、正常刷怪。"
	if not bool(check.valid): _build_summary.text += "\n" + "\n".join(check.errors)
	_start_build_button.disabled = not bool(check.valid)


func _start_skill_build_run() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var ui: Node = host._get_ui_manager()
	if ui == null: return
	_start_build_button.disabled = true
	var succeeded: bool = await ui.call("start_developer_debug_run", {
		"character_id": host._get_selected_id(host._character_option),
		"map_id": host._get_selected_id(host._map_option),
		"skill_build": _build_entries.duplicate(true),
		"play_build": true
	})
	if not succeeded: host._log_error(String(ui.get("last_developer_run_error")))
	_update_build_summary()


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
	_refresh_build_picker()
	_update_build_summary()


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
	_refresh_build_picker()
	_update_build_summary()


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
