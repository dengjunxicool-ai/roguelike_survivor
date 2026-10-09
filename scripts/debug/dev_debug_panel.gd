## 文件用途：调试工具宿主与左侧面板，装配开局、运行时、技能卡、敌人、特效、状态及工具页，保留各页公开转发入口。
## 使用方式：在调试构建或 developer_mode_enabled 开启时运行；F12 切换工具栏，open_developer_mode 启用手控和手动刷怪，各按钮经本宿主转发给 pages 控制器。
extends CanvasLayer
class_name DevDebugPanel
const DevDebugDataSourceScript: Script = preload("res://scripts/debug/dev_debug_data_source.gd")


const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const EnemyAttackRangeOverlayScript: Script = preload("res://scripts/debug/enemy_attack_range_overlay.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/runtime/debug_combat_trace.gd")
const DevDebugEffectsPageScript: Script = preload("res://scripts/debug/pages/dev_debug_effects_page.gd")
const SkillEffectSummaryBuilderScript: Script = preload("res://scripts/skills/skill_effect_summary_builder.gd")
const StatusShortNameFormatterScript: Script = preload("res://scripts/ui/status_short_name_formatter.gd")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

@export var enabled_in_debug_builds: bool = true
@export var update_interval: float = 0.2

var _panel: PanelContainer
var _state_label: Label
var _log_label: Label
var _player_attributes_label: Label
var _character_option: OptionButton
var _map_option: OptionButton
var _enemy_option: OptionButton
var _enemy_state_option: OptionButton
var _effects_page: VBoxContainer
var _effect_option: OptionButton
var _fire_skill_option: OptionButton
var _status_option: OptionButton
var _spawn_count_spin: SpinBox
var _enemy_health_spin: SpinBox
var _enemy_armor_spin: SpinBox
var _enemy_resistance_spin: SpinBox
var _status_stack_spin: SpinBox
var _status_duration_spin: SpinBox
var _apply_to_all_enemies_check: CheckBox
var _target_player_check: CheckBox
var _player_stat_spins: Dictionary = {}
var _skill_stat_spins: Dictionary = {}
var _skill_stat_active: Dictionary = {}
var _category_pages: Dictionary = {}
var _category_buttons: Dictionary = {}
var _active_category_id: String = ""
var _update_timer: float = 0.0
var _last_log: String = "Ready."
var _hidden_ui_manager: CanvasLayer
var _hidden_ui_was_visible: bool = true
var _tree_was_paused: bool = false
var _enemy_range_overlays: Dictionary = {}
var _upgrade_pool: RefCounted = UpgradePoolScript.new()
var _god_skill_buttons: Dictionary = {}
var _god_skill_cards_scroll: ScrollContainer
var _god_skill_cards: VBoxContainer
var _selected_god_id: StringName = &"fire"
var _selected_god_skill_id: StringName = &""
var _god_skill_options: Array[Dictionary] = []
var _god_skill_definitions: Array[Dictionary] = []
var _debug_fire_skill_options: Array[Dictionary] = []
var _fire_skill_chain_log_label: Label
var _attack_damage_scroll: ScrollContainer
var _attack_damage_label: Label
var _last_attack_damage_text: String = "Damage Breakdown: no attack trace."
var _last_copied_attack_damage_record_text: String = ""
var _attack_damage_card_index: int = 0


const DevDebugRunSetupPageScript: Script = preload("res://scripts/debug/pages/dev_debug_run_setup_page.gd")
var _run_setup_controller: RefCounted = DevDebugRunSetupPageScript.new(self)
const DevDebugRuntimePageScript: Script = preload("res://scripts/debug/pages/dev_debug_runtime_page.gd")
var _runtime_controller: RefCounted = DevDebugRuntimePageScript.new(self)
const DevDebugSkillCardsPageScript: Script = preload("res://scripts/debug/pages/dev_debug_skill_cards_page.gd")
var _skill_cards_controller: RefCounted = DevDebugSkillCardsPageScript.new(self)
const DevDebugEnemySpawnPageScript: Script = preload("res://scripts/debug/pages/dev_debug_enemy_spawn_page.gd")
var _enemy_spawn_controller: RefCounted = DevDebugEnemySpawnPageScript.new(self)
const DevDebugStatusPageScript: Script = preload("res://scripts/debug/pages/dev_debug_status_page.gd")
var _status_controller: RefCounted = DevDebugStatusPageScript.new(self)
const DevDebugUtilityPageScript: Script = preload("res://scripts/debug/pages/dev_debug_utility_page.gd")
var _utility_controller: RefCounted = DevDebugUtilityPageScript.new(self)




## 作用：依据调试构建与开发模式开关建立面板、加载配置选项并同步运行时，默认隐藏且由 F12 开启。
## 使用：由 Godot 在节点入树并完成子节点就绪后调用。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 500
	visible = false
	var force_enabled: bool = _is_developer_mode_enabled()
	if not enabled_in_debug_builds or (not OS.is_debug_build() and not force_enabled):
		visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return

	_build_panel()
	_populate_options()
	_sync_options_from_runtime()
	set_process(true)
	set_process_unhandled_input(true)
	_set_left_toolbar_visible(force_enabled)
	_log("DevDebugPanel ready. F12 toggles the left toolbar.")


## 作用：重新填充并同步选项，启用手动刷怪与调试手控，展开面板并刷新摘要。
## 使用：游戏开发模式入口调用此无参方法；会展开工具栏、暂停自动战斗并改为手动调试刷怪。
func open_developer_mode() -> void:
	_populate_options()
	_sync_options_from_runtime()
	_set_debug_manual_spawn_only(true)
	_set_left_toolbar_visible(true)
	_set_debug_control_mode(true)
	_refresh_state()
	_log("Developer mode opened.")


## 作用：仅在左侧工具栏可见时按 update_interval 定时刷新状态摘要。
## 使用：由 Godot 每处理帧调用，delta 参数以秒为单位。 入参：delta: float。
func _process(delta: float) -> void:
	if not _is_left_toolbar_visible():
		return
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = update_interval
	_refresh_state()


## 作用：在调试/开发模式中响应非重复按键，将 F1 至 F12 分派为施放、升级、刷怪、状态、清理和面板开关。
## 使用：由 Godot 传入 InputEvent；只处理按下且非 echo 的键盘事件，调试构建或开发模式才响应快捷键。
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() and not _is_developer_mode_enabled():
		return
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F1:
			_manual_cast_player_skills()
		KEY_F2:
			_level_starting_skill_to(2)
		KEY_F3:
			_level_starting_skill_to(3)
		KEY_F4:
			_spawn_configured_enemies()
		KEY_F5:
			_apply_status_from_panel()
		KEY_F6:
			_print_state()
		KEY_F7:
			_set_nearest_enemy_stats()
		KEY_F9:
			_clear_enemies()
		KEY_F10:
			_clear_statuses()
		KEY_F11:
			_toggle_auto_combat()
		KEY_F12:
			_set_left_toolbar_visible(not _is_left_toolbar_visible())


## 作用：重建分类索引与面板壳，按顺序装配七个调试页面、日志区，默认打开开局页。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _build_panel() -> void:
	_category_pages.clear()
	_category_buttons.clear()
	_active_category_id = ""

	var root: VBoxContainer = _build_panel_shell()

	_add_category_navigation(root)
	var page_root: VBoxContainer = _build_page_root(root)

	_build_run_setup_page(page_root)

	_build_runtime_page(page_root)

	_build_skill_cards_page(page_root)

	_build_enemy_spawn_page(page_root)

	_build_effects_page(page_root)

	_build_status_page(page_root)

	_build_utility_page(page_root)

	_log_label = Label.new()
	_log_label.name = "LogLabel"
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_log_label)
	_open_category("run_setup")
	_refresh_state()


## 作用：创建固定偏移的 PanelContainer、内边距和标题/状态标签，返回页面根 VBoxContainer。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 VBoxContainer；具体值及空输入行为见作用说明。
func _build_panel_shell() -> VBoxContainer:
	_panel = PanelContainer.new()
	_panel.name = "DevDebugPanelRoot"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 12
	_panel.offset_top = 56
	_panel.offset_right = 492
	_panel.offset_bottom = 2036
	_panel.visible = false
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "DEV DEBUG TOOL"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_state_label)

	return root


## 作用：为开局、运行时、技能、敌人、特效、状态和工具七类建立两列导航按钮。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：root: VBoxContainer。
func _add_category_navigation(root: VBoxContainer) -> void:
	var category_grid: GridContainer = GridContainer.new()
	category_grid.columns = 2
	category_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_grid.add_theme_constant_override("h_separation", 6)
	category_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(category_grid)
	_add_category_button(category_grid, "run_setup", "Run Setup")
	_add_category_button(category_grid, "runtime", "Runtime")
	_add_category_button(category_grid, "skill_cards", "Skill Cards")
	_add_category_button(category_grid, "enemy_spawn", "Enemy Spawn")
	_add_category_button(category_grid, "effects", "Effects")
	_add_category_button(category_grid, "status", "Status / Stacks")
	_add_category_button(category_grid, "utility", "Utility")


## 作用：在根布局添加滚动容器和可伸展页面根，返回供各分类挂载的 VBoxContainer。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：root: VBoxContainer。 返回 VBoxContainer；具体值及空输入行为见作用说明。
func _build_page_root(root: VBoxContainer) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var page_root: VBoxContainer = VBoxContainer.new()
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", 7)
	scroll.add_child(page_root)

	return page_root


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _build_run_setup_page：添加角色、地图、重启与 Lv3 控件，将按钮和选择信号绑定到宿主入口。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_run_setup_page(page_root: VBoxContainer) -> void:
	_run_setup_controller._build_run_setup_page(page_root)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_runtime_page：创建暂停、自动攻击和追踪按钮以及可滚动伤害卡，所有回调绑定宿主入口。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_runtime_page(page_root: VBoxContainer) -> void:
	_runtime_controller._build_runtime_page(page_root)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _build_skill_cards_page：建立神系切换区、清技能按钮、滚动技能卡列表和技能链诊断日志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_skill_cards_page(page_root: VBoxContainer) -> void:
	_skill_cards_controller._build_skill_cards_page(page_root)


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _build_enemy_spawn_page：添加敌人类型、数量、血量、护甲、抗性和强制状态控件，并绑定宿主操作。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_enemy_spawn_page(page_root: VBoxContainer) -> void:
	_enemy_spawn_controller._build_enemy_spawn_page(page_root)


## 作用：创建并挂载 DevDebugEffectsPage，注入玩家/敌人查询回调、绑定日志信号后构建控件并缓存下拉框。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_effects_page(page_root: VBoxContainer) -> void:
	var effects_category: VBoxContainer = _add_category_page(page_root, "effects", "Effects")
	_effects_page = DevDebugEffectsPageScript.new() as VBoxContainer
	_effects_page.name = "DevDebugEffectsPage"
	effects_category.add_child(_effects_page)
	_effects_page.call("setup", Callable(self, "_get_player"), Callable(self, "_get_nearest_enemy"))
	if not _effects_page.is_connected("log_requested", Callable(self, "_on_effects_page_log_requested")):
		_effects_page.connect("log_requested", Callable(self, "_on_effects_page_log_requested"))
	_effects_page.call("build")
	_effect_option = _effects_page.call("get_effect_option") as OptionButton


## 作用：转发到状态页 dev_debug_status_page.gd 的 _build_status_page：建立状态、层数、时长、全敌人和玩家目标控件，绑定施加与清除按钮。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_status_page(page_root: VBoxContainer) -> void:
	_status_controller._build_status_page(page_root)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _build_utility_page：构建状态打印和范围圈开关按钮，并绑定到宿主操作。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：page_root: VBoxContainer。
func _build_utility_page(page_root: VBoxContainer) -> void:
	_utility_controller._build_utility_page(page_root)


## 作用：重新填充角色、地图、敌人、特效、技能和状态选项，并同步玩家与技能属性输入。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_options() -> void:
	_populate_character_options()
	_populate_map_options()
	_populate_enemy_options()
	_populate_enemy_state_options()
	_populate_effect_options()
	_populate_god_skill_buttons()
	_refresh_god_skill_cards()
	_populate_status_options()
	_sync_player_stat_controls()
	_sync_skill_stat_controls()


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _populate_character_options：从 GameData 角色池填充带稳定 ID 元数据的下拉选项，跳过空 ID。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_character_options() -> void:
	_run_setup_controller._populate_character_options()


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _populate_map_options：从 GameData 地图池填充地图下拉选项，跳过空 ID。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_map_options() -> void:
	_run_setup_controller._populate_map_options()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _populate_enemy_options：将 GameData 敌人池分成普通、精英和 Boss 选项，添加不可选组标题并选择首个可用项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_enemy_options() -> void:
	_enemy_spawn_controller._populate_enemy_options()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _get_enemy_option_group：读取 enemy_rank 作为选项分组标识，缺省为 normal。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enemy: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _get_enemy_option_group(enemy: Dictionary) -> String:
	return _enemy_spawn_controller._get_enemy_option_group(enemy)


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _add_enemy_group_options：为非空敌人组添加禁用标题和带稳定 ID 的选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：group_label: String, enemies: Array[Dictionary]。
func _add_enemy_group_options(group_label: String, enemies: Array[Dictionary]) -> void:
	_enemy_spawn_controller._add_enemy_group_options(group_label, enemies)


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _populate_enemy_state_options：填充 Auto、Idle、Chase、Attack、Hurt、Death 强制状态选项并同步可用性。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_enemy_state_options() -> void:
	_enemy_spawn_controller._populate_enemy_state_options()


## 作用：已有特效页时调用其 populate_options，重建火龙卷与火星飞弹选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_effect_options() -> void:
	if _effects_page != null:
		_effects_page.call("populate_options")


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _populate_god_skill_buttons：从神系定义重新创建切换按钮并绑定 ID，校正选择后同步按下状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_god_skill_buttons() -> void:
	_skill_cards_controller._populate_god_skill_buttons()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _refresh_god_skill_cards：清理旧卡片并加载当前神系定义和调试学习选项，校正技能选择后建立卡片或空列表提示。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _refresh_god_skill_cards() -> void:
	_skill_cards_controller._refresh_god_skill_cards()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _refresh_god_skill_section：依次刷新神系按钮和技能卡，供打开技能分类时更新。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _refresh_god_skill_section() -> void:
	_skill_cards_controller._refresh_god_skill_section()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _select_god_skill_cards：设置所选 god_id，同步按钮并重新加载此神系卡片。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：god_id: StringName。
func _select_god_skill_cards(god_id: StringName) -> void:
	_skill_cards_controller._select_god_skill_cards(god_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _update_god_skill_button_states：遍历神系按钮，用无信号方式同步其是否为当前所选神系。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _update_god_skill_button_states() -> void:
	_skill_cards_controller._update_god_skill_button_states()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _sync_selected_god_skill_id：保持当前技能在定义池中的选择，缺失时选首项，空池时清空选择。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _sync_selected_god_skill_id() -> void:
	_skill_cards_controller._sync_selected_god_skill_id()


## 作用：通过 DevDebugDataSource 取得 GameData 神系池，供切换按钮使用。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _get_god_definitions() -> Array[Dictionary]:
	return DevDebugDataSourceScript.get_god_definitions()


## 作用：通过 DevDebugDataSource 筛选 god_id 主神系或融合神系的可提供学习技能定义。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：god_id: StringName。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	return DevDebugDataSourceScript.get_god_skill_definitions(god_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _populate_fire_skill_options：重建火系学习选项下拉框，空池添加禁用提示，否则用学习技能 ID 绑定条目。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_fire_skill_options() -> void:
	_skill_cards_controller._populate_fire_skill_options()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _build_debug_fire_skill_options：复用通用神系调试选项生成器，默认 god_id 为 fire。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：god_id: StringName = &"fire"。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _build_debug_fire_skill_options(god_id: StringName = &"fire") -> Array[Dictionary]:
	return _skill_cards_controller._build_debug_fire_skill_options(god_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _build_debug_god_skill_options：向 UpgradePool 生成指定神系调试学习选项，转字典并按学习技能 ID 去重。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：god_id: StringName。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _build_debug_god_skill_options(god_id: StringName) -> Array[Dictionary]:
	return _skill_cards_controller._build_debug_god_skill_options(god_id)


## 作用：转发到状态页 dev_debug_status_page.gd 的 _populate_status_options：从 GameData 状态池填充能够查询到定义的选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _populate_status_options() -> void:
	_status_controller._populate_status_options()


## 作用：转发到状态页 dev_debug_status_page.gd 的 _is_status_option_available：判断状态 ID 是否解析到非空定义，避免生成无效选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：status_id: Variant。 返回 bool；具体值及空输入行为见作用说明。
func _is_status_option_available(status_id: Variant) -> bool:
	return _status_controller._is_status_option_available(status_id)


## 作用：转发到状态页 dev_debug_status_page.gd 的 _get_status_definition_for_option：经 DevDebugDataSource 查询状态配置，返回 GameData 的定义。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：status_id: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_status_definition_for_option(status_id: Variant) -> Dictionary:
	return _status_controller._get_status_definition_for_option(status_id)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_player_stats：构建计算后属性展示区和玩家属性 SpinBox，添加应用、同步按钮。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer。
func _build_player_stats(parent: VBoxContainer) -> void:
	_runtime_controller._build_player_stats(parent)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_skill_stats：按起始技能属性配置创建 SpinBox 并初始化活动属性索引，添加应用、同步按钮。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer。
func _build_skill_stats(parent: VBoxContainer) -> void:
	_runtime_controller._build_skill_stats(parent)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _sync_player_stat_controls：把玩家当前属性值同步到对应输入控件，玩家或控件缺失时跳过。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _sync_player_stat_controls() -> void:
	_runtime_controller._sync_player_stat_controls()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _sync_skill_stat_controls：从 SkillStatService 同步起始技能有效属性，按 allow_new 决定缺失属性是否可编辑并调整透明度。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _sync_skill_stat_controls() -> void:
	_runtime_controller._sync_skill_stat_controls()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _apply_player_stats_from_panel：把输入框数值写回玩家，整数项取整并约束血量；发送血量、经验信号和刷新协同。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _apply_player_stats_from_panel() -> void:
	_runtime_controller._apply_player_stats_from_panel()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _apply_skill_stats_from_panel：将可编辑技能值写入 runtime_modifiers 的属性 override，保留其余修改并发出 skill_changed。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _apply_skill_stats_from_panel() -> void:
	_runtime_controller._apply_skill_stats_from_panel()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_player_stat_configs：返回玩家属性编辑项定义，包含字段名、标签、范围、步长和整数标记。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _get_player_stat_configs() -> Array[Dictionary]:
	return _runtime_controller._get_player_stat_configs()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_skill_stat_configs：返回起始技能属性编辑项定义，包含范围、取整与允许新增属性标记。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _get_skill_stat_configs() -> Array[Dictionary]:
	return _runtime_controller._get_skill_stat_configs()


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _on_character_selected：响应角色下拉选择，重新同步玩家及技能属性控件并刷新摘要；不直接换角色。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：_index: int。
func _on_character_selected(_index: int) -> void:
	_run_setup_controller._on_character_selected(_index)


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _on_setup_option_selected：响应地图等开局选项选择，仅刷新宿主摘要。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：_index: int。
func _on_setup_option_selected(_index: int) -> void:
	_run_setup_controller._on_setup_option_selected(_index)


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _sync_options_from_runtime：把当前玩家角色和 UIManager 已选地图同步到下拉框，并刷新属性输入。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _sync_options_from_runtime() -> void:
	_run_setup_controller._sync_options_from_runtime()


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _restart_debug_run：把面板角色和地图 ID 交给 UIManager.start_developer_debug_run，随后延迟刷新宿主状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _restart_debug_run() -> void:
	_run_setup_controller._restart_debug_run()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _toggle_tree_pause：反转 SceneTree.paused 并记录暂停状态，调试宿主继续常驻处理。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _toggle_tree_pause() -> void:
	_runtime_controller._toggle_tree_pause()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _toggle_auto_combat：反转 debug_control_mode；启用调试手控时解除树暂停，控制自动战斗编排。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _toggle_auto_combat() -> void:
	_runtime_controller._toggle_auto_combat()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _toggle_player_attack_disabled：反转玩家自动攻击禁用标志并记录结果。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _toggle_player_attack_disabled() -> void:
	_runtime_controller._toggle_player_attack_disabled()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _apply_enemy_state_override：校验当前下拉状态，将强制状态写入宿主；Hurt/Death 仅在最近敌人为精英或 Boss 时允许。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _apply_enemy_state_override() -> void:
	_enemy_spawn_controller._apply_enemy_state_override()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _clear_enemy_state_override：清空强制状态元数据并把下拉选项恢复到 Auto。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _clear_enemy_state_override() -> void:
	_enemy_spawn_controller._clear_enemy_state_override()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _spawn_configured_enemies：以玩家为圆心按输入数量生成所选敌人，应用面板属性，随后同步范围圈。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _spawn_configured_enemies() -> void:
	_enemy_spawn_controller._spawn_configured_enemies()


## 作用：转发到特效页 dev_debug_effects_page.gd 的 spawn_fire_tornado_effect：实例化火龙卷场景，加入玩家场景父节点并放到目标方向 96 像素处；缺少父节点时释放实例。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _spawn_fire_tornado_effect() -> void:
	if _effects_page != null:
		_effects_page.call("spawn_fire_tornado_effect")


## 作用：转发到特效页 dev_debug_effects_page.gd 的 start_continuous_effect：用 continuous=true 转交当前选中特效；持续开关由火星飞弹预览消费。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _start_continuous_effect_fire() -> void:
	if _effects_page != null:
		_effects_page.call("start_continuous_effect")


## 作用：转发到特效页 dev_debug_effects_page.gd 的 fire_single_effect：用 continuous=false 转交当前选中特效，预览一次发射。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _fire_single_effect() -> void:
	if _effects_page != null:
		_effects_page.call("fire_single_effect")


## 作用：转发到特效页 dev_debug_effects_page.gd 的 trigger_selected_effect：按特效 ID 分派火龙卷或火星飞弹预览，空选项发出警告日志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：continuous: bool。
func _trigger_selected_effect(continuous: bool) -> void:
	if _effects_page != null:
		_effects_page.call("trigger_selected_effect", continuous)


## 作用：转发到特效页 dev_debug_effects_page.gd 的 spawn_mars_spark_missile_effect：创建火星飞弹预览，配置起点和目标点以及 continuous 开关，加入场景并输出模式日志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：continuous: bool。
func _spawn_mars_spark_missile_effect(continuous: bool) -> void:
	if _effects_page != null:
		_effects_page.call("spawn_mars_spark_missile_effect", continuous)


## 作用：转发到特效页 dev_debug_effects_page.gd 的 resolve_fire_tornado_spawn_position：返回玩家朝最近敌人方向 96 像素的世界坐标；无敌人使用右方向，无玩家返回零向量。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node2D。 返回 Vector2；具体值及空输入行为见作用说明。
func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_fire_tornado_spawn_position", player)
	return result if result is Vector2 else Vector2.ZERO


## 作用：转发到特效页 dev_debug_effects_page.gd 的 resolve_mars_spark_missile_spawn_position：返回玩家朝敌人方向 32 像素的飞弹起点；方向退化时用右方向。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node2D。 返回 Vector2；具体值及空输入行为见作用说明。
func _resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_mars_spark_missile_spawn_position", player)
	return result if result is Vector2 else Vector2.ZERO


## 作用：转发到特效页 dev_debug_effects_page.gd 的 resolve_mars_spark_missile_target_position：优先返回最近敌人世界坐标；无目标时沿发射方向向前延伸 360 像素。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node2D, origin: Vector2。 返回 Vector2；具体值及空输入行为见作用说明。
func _resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_mars_spark_missile_target_position", player, origin)
	return result if result is Vector2 else Vector2.ZERO


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _spawn_all_enemy_types：遍历敌人配置池，各生成一个原始配置实体，环形摆放并标记 debug_spawn_all_types。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _spawn_all_enemy_types() -> void:
	_enemy_spawn_controller._spawn_all_enemy_types()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _spawn_debug_enemy：实例化敌人场景，赋予 ID、位置和 debug_spawned 标记后挂到 spawn_parent；按开关覆写属性。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enemy_id: StringName, position: Vector2, spawn_parent: Node, apply_panel_stats: bool。 返回 Node2D；具体值及空输入行为见作用说明。
func _spawn_debug_enemy(enemy_id: StringName, position: Vector2, spawn_parent: Node, apply_panel_stats: bool) -> Node2D:
	return _enemy_spawn_controller._spawn_debug_enemy(enemy_id, position, spawn_parent, apply_panel_stats)


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _spawn_enemies：把 count 写入数量输入框后复用配置生成流程；数量至少为一。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：count: int。
func _spawn_enemies(count: int) -> void:
	_enemy_spawn_controller._spawn_enemies(count)


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _set_nearest_enemy_stats：取得距玩家最近的敌人，应用面板属性并打印结果。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _set_nearest_enemy_stats() -> void:
	_enemy_spawn_controller._set_nearest_enemy_stats()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _apply_enemy_panel_stats：以正数血量和护甲覆写敌人，按百分比统一各系抗性；发送 health_changed 刷新显示。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enemy: Node。
func _apply_enemy_panel_stats(enemy: Node) -> void:
	_enemy_spawn_controller._apply_enemy_panel_stats(enemy)


## 作用：转发到状态页 dev_debug_status_page.gd 的 _apply_status_from_panel：读取状态层数和时长，启动新追踪并重置伤害卡，对选中目标调用 apply_status，记录成功数。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _apply_status_from_panel() -> void:
	_status_controller._apply_status_from_panel()


## 作用：转发到状态页 dev_debug_status_page.gd 的 _get_status_targets：按玩家优先、其次全敌人、最后最近敌人的顺序确定目标数组。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Array[Node]；具体值及空输入行为见作用说明。
func _get_status_targets() -> Array[Node]:
	return _status_controller._get_status_targets()


## 作用：转发到状态页 dev_debug_status_page.gd 的 _clear_statuses：对选定目标调用 clear_statuses，并在宿主日志中记录实际调用数。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _clear_statuses() -> void:
	_status_controller._clear_statuses()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _clear_enemies：对 enemies 组全部实体 queue_free，清空范围圈索引并记录清理数量。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _clear_enemies() -> void:
	_enemy_spawn_controller._clear_enemies()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _clear_player_skills：在调试构建或开发模式下清空玩家所有技能槽，刷新协同和宿主摘要。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _clear_player_skills() -> void:
	_skill_cards_controller._clear_player_skills()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _manual_cast_player_skills：调用单次全技能调试施放入口，成功时记录施放技能数。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _manual_cast_player_skills() -> void:
	_runtime_controller._manual_cast_player_skills()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _attack_once_player_skills：新建攻击 trace、重置伤害卡索引和滚动位置，施放全部技能并显示等待命中的提示。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _attack_once_player_skills() -> void:
	_runtime_controller._attack_once_player_skills()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _clear_attack_trace：清空攻击记录和爆炸位置覆盖层，重置当前卡片索引、滚动位置及提示。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _clear_attack_trace() -> void:
	_runtime_controller._clear_attack_trace()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _show_previous_attack_damage_card：循环选择上一条伤害卡，重置滚动并刷新显示；空记录恢复索引零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _show_previous_attack_damage_card() -> void:
	_runtime_controller._show_previous_attack_damage_card()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _show_next_attack_damage_card：循环选择下一条伤害卡，重置滚动并刷新显示；空记录恢复索引零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _show_next_attack_damage_card() -> void:
	_runtime_controller._show_next_attack_damage_card()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _copy_current_attack_damage_record：格式化当前记录并写入系统剪贴板，同时缓存已复制文本；无记录返回 false。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _copy_current_attack_damage_record() -> bool:
	return _runtime_controller._copy_current_attack_damage_record()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _cast_player_skills_once：临时解除 debug_control_mode 调用 SkillExecutor.debug_cast_all_skills，再恢复旧标志；返回施放数，缺入口返回 -1。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：trace_id: int = 0。 返回 int；具体值及空输入行为见作用说明。
func _cast_player_skills_once(trace_id: int = 0) -> int:
	return _runtime_controller._cast_player_skills_once(trace_id)


## 作用：转发到开局页 dev_debug_run_setup_page.gd 的 _level_starting_skill_to：反复调用玩家 _upgrade_skill 将起始技能提升到 target_level，升级拒绝时停止，再同步控件。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：target_level: int。
func _level_starting_skill_to(target_level: int) -> void:
	_run_setup_controller._level_starting_skill_to(target_level)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _toggle_range_overlay：反转范围显示状态，统一更新玩家和敌人覆盖层并记录日志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _toggle_range_overlay() -> void:
	_utility_controller._toggle_range_overlay()


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _set_all_range_overlays_visible：设置玩家 PlayerDebugOverlay 与所有敌人范围圈可见性，保存根节点显示标志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：should_show: bool。
func _set_all_range_overlays_visible(should_show: bool) -> void:
	_utility_controller._set_all_range_overlays_visible(should_show)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _sync_enemy_attack_range_overlays：剔除失效覆盖层后遍历有效 enemies 组实体，保证范围层存在并设置可见性、请求重绘。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：should_show: bool。
func _sync_enemy_attack_range_overlays(should_show: bool) -> void:
	_utility_controller._sync_enemy_attack_range_overlays(should_show)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _ensure_enemy_attack_range_overlay：复用敌人已有覆盖层或新建 EnemyAttackRangeOverlay 子节点，setup 后缓存到实例 ID 索引。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enemy: Node2D。 返回 CanvasItem；具体值及空输入行为见作用说明。
func _ensure_enemy_attack_range_overlay(enemy: Node2D) -> CanvasItem:
	return _utility_controller._ensure_enemy_attack_range_overlay(enemy)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _prune_enemy_attack_range_overlays：遍历范围圈缓存，移除已释放或待删除的条目。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _prune_enemy_attack_range_overlays() -> void:
	_utility_controller._prune_enemy_attack_range_overlays()


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _get_valid_enemy_range_overlay：按实例 ID 查找有效 CanvasItem 覆盖层，失效或待删除时返回 null。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：key: int。 返回 CanvasItem；具体值及空输入行为见作用说明。
func _get_valid_enemy_range_overlay(key: int) -> CanvasItem:
	return _utility_controller._get_valid_enemy_range_overlay(key)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _are_range_overlays_visible：优先读取根节点 debug_range_overlays_visible；不存在时查询玩家覆盖层可见性。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _are_range_overlays_visible() -> bool:
	return _utility_controller._are_range_overlays_visible()


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _set_range_overlays_visible：把范围显示开关保存到根节点 debug_range_overlays_visible 元数据。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：visible: bool。
func _set_range_overlays_visible(visible: bool) -> void:
	_utility_controller._set_range_overlays_visible(visible)


## 作用：转发到工具页 dev_debug_utility_page.gd 的 _print_state：构建状态摘要并输出到控制台，更新宿主最近日志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _print_state() -> void:
	_utility_controller._print_state()


## 作用：更新敌人状态选项可用性和范围圈，再同步状态摘要、玩家属性、伤害卡及最近日志标签。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _refresh_state() -> void:
	if _state_label == null:
		return
	_refresh_enemy_state_option_availability()
	_sync_enemy_attack_range_overlays(_are_range_overlays_visible())
	_state_label.text = _build_state_text()
	if _player_attributes_label != null:
		_player_attributes_label.text = _build_player_attributes_text()
	_refresh_attack_damage_text()
	if _log_label != null:
		_log_label.text = "Log: %s" % _last_log


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _add_god_skill_card：根据技能定义建立带序号元数据的按钮卡片，点击绑定指定技能 ID。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer, skill: Dictionary, skill_index: int。
func _add_god_skill_card(parent: VBoxContainer, skill: Dictionary, skill_index: int) -> void:
	_skill_cards_controller._add_god_skill_card(parent, skill, skill_index)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _format_god_skill_card_text：组合名称、描述、特效描述和效果摘要作为技能卡多行文本。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _format_god_skill_card_text(skill: Dictionary) -> String:
	return _skill_cards_controller._format_god_skill_card_text(skill)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _get_god_skill_effect_description：优先读取 effect_description，否则用 SkillEffectSummaryBuilder 推导摘要，无内容返回占位文本。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _get_god_skill_effect_description(skill: Dictionary) -> String:
	return _skill_cards_controller._get_god_skill_effect_description(skill)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _on_god_skill_card_pressed：更新当前选中技能后异步执行该技能的授予与施放链。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 直接调用时须 await 等待异步流程完成。
func _on_god_skill_card_pressed(skill_id: StringName) -> void:
	await _skill_cards_controller._on_god_skill_card_pressed(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _select_god_skill_card：保存所选技能 ID，并在宿主日志中显示选择。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。
func _select_god_skill_card(skill_id: StringName) -> void:
	_skill_cards_controller._select_god_skill_card(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 debug_select_god_skill_cards：切换神系后返回卡片数、按钮数、实例数量和选中按钮状态，供自动验证查询。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：god_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func debug_select_god_skill_cards(god_id: StringName) -> Dictionary:
	return _skill_cards_controller.debug_select_god_skill_cards(god_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _build_god_skill_button_summary：遍历神系按钮，收集按钮 ID、入树数量和指定神系按下状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：selected_god_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _build_god_skill_button_summary(selected_god_id: StringName) -> Dictionary:
	return _skill_cards_controller._build_god_skill_button_summary(selected_god_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 debug_run_god_skill_chain：异步执行指定神系技能卡调试链并返回结果字典。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。 直接调用时须 await 等待异步流程完成。
func debug_run_god_skill_chain(skill_id: StringName) -> Dictionary:
	return await _skill_cards_controller.debug_run_god_skill_chain(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _run_god_skill_card：解析调试学习选项、授予技能后施放一次，合并结果并更新日志；不主动生成靶子。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。 直接调用时须 await 等待异步流程完成。
func _run_god_skill_card(skill_id: StringName) -> Dictionary:
	return await _skill_cards_controller._run_god_skill_card(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _mark_god_skill_chain_no_target：在 result 中标记未生成目标且允许无目标静默施放，避免把此模式误判为强制命中。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：result: Dictionary。
func _mark_god_skill_chain_no_target(result: Dictionary) -> void:
	_skill_cards_controller._mark_god_skill_chain_no_target(result)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _apply_god_skill_cast_result：把 cast_result 合并进 result，补齐技能、选项、授予状态并恢复无目标标记。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary。
func _apply_god_skill_cast_result(result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary) -> void:
	_skill_cards_controller._apply_god_skill_cast_result(result, cast_result, selected_skill_id, option)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 debug_run_fire_skill_chain：先切换 fire 神系，再异步复用通用神系技能调试链。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。 直接调用时须 await 等待异步流程完成。
func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	return await _skill_cards_controller.debug_run_fire_skill_chain(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _run_selected_fire_skill_chain：读取火系下拉选择，执行技能链并按完整诊断条件打印健康或需检查状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 直接调用时须 await 等待异步流程完成。
func _run_selected_fire_skill_chain() -> void:
	await _skill_cards_controller._run_selected_fire_skill_chain()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _grant_selected_fire_skill：授予当前火系选项，将技能和选项标识、授予结果写到诊断日志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _grant_selected_fire_skill() -> void:
	_skill_cards_controller._grant_selected_fire_skill()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _cast_selected_fire_skill：确保选中的火系技能已授予后异步施放，记录伤害、特效和施放次数。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 直接调用时须 await 等待异步流程完成。
func _cast_selected_fire_skill() -> void:
	await _skill_cards_controller._cast_selected_fire_skill()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _spawn_fire_skill_debug_target：在玩家右侧 150 像素生成所选敌人或小史莱姆靶子，标记用途并强制敌人为 idle。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Node2D；具体值及空输入行为见作用说明。
func _spawn_fire_skill_debug_target() -> Node2D:
	return _skill_cards_controller._spawn_fire_skill_debug_target()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _grant_fire_skill_option：已有技能直接成功，否则先应用学习升级，失败再 add_skill；新增成功后刷新技能配置与协同。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: Dictionary。 返回 bool；具体值及空输入行为见作用说明。
func _grant_fire_skill_option(option: Dictionary) -> bool:
	return _skill_cards_controller._grant_fire_skill_option(option)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _cast_fire_skill_once：清理旧 trace、施放指定技能并按帧等待，统计本技能和全部伤害记录、GPU 粒子及伤害弹字增量。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName, max_damage_wait_frames: int = 120。 返回 Dictionary；具体值及空输入行为见作用说明。 直接调用时须 await 等待异步流程完成。
func _cast_fire_skill_once(skill_id: StringName, max_damage_wait_frames: int = 120) -> Dictionary:
	return await _skill_cards_controller._cast_fire_skill_once(skill_id, max_damage_wait_frames)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _cast_player_skill_once：调用 SkillExecutor.debug_cast_skill 施放一个技能并携带 trace_id，缺玩家或入口返回 -1。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName, trace_id: int = 0。 返回 int；具体值及空输入行为见作用说明。
func _cast_player_skill_once(skill_id: StringName, trace_id: int = 0) -> int:
	return _skill_cards_controller._cast_player_skill_once(skill_id, trace_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _wait_for_fire_skill_damage_record：逐物理帧查找 trace_id 与技能匹配的 damage 记录，首次出现即结束或达到帧数上限。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName, trace_id: int, max_physics_frames: int。 直接调用时须 await 等待异步流程完成。
func _wait_for_fire_skill_damage_record(skill_id: StringName, trace_id: int, max_physics_frames: int) -> void:
	await _skill_cards_controller._wait_for_fire_skill_damage_record(skill_id, trace_id, max_physics_frames)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _prepare_fire_skill_debug_target：把有效靶子血量设为 240 并移到玩家右侧，发出 health_changed 刷新血条。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：target: Node2D。
func _prepare_fire_skill_debug_target(target: Node2D) -> void:
	_skill_cards_controller._prepare_fire_skill_debug_target(target)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _build_fire_skill_chain_result：创建包含技能 ID、选项、授予、目标、追踪和可视统计默认值的结果字典。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _build_fire_skill_chain_result(skill_id: StringName) -> Dictionary:
	return _skill_cards_controller._build_fire_skill_chain_result(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _get_selected_fire_skill_option：由火系下拉框的选中 ID 查询对应学习选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_selected_fire_skill_option() -> Dictionary:
	return _skill_cards_controller._get_selected_fire_skill_option()


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _get_fire_skill_option：按学习技能 ID 查询火系调试选项；缓存为空时重建，命中后返回深拷贝。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_fire_skill_option(skill_id: StringName) -> Dictionary:
	return _skill_cards_controller._get_fire_skill_option(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _get_god_skill_option：按学习技能 ID 查询当前神系调试选项；缓存为空时重建，命中后返回深拷贝。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_god_skill_option(skill_id: StringName) -> Dictionary:
	return _skill_cards_controller._get_god_skill_option(skill_id)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _get_option_learn_skill_id：优先读取 payload.learn_skill_id，否则解析 level_up_upgrade: 前缀并由学习仓库解析升级定义。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: Dictionary。 返回 StringName；具体值及空输入行为见作用说明。
func _get_option_learn_skill_id(option: Dictionary) -> StringName:
	return _skill_cards_controller._get_option_learn_skill_id(option)


## 作用：统计 type=damage 且可选 trace_id、source_skill_id 匹配的追踪条目，忽略非字典记录。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：records: Array, skill_id: StringName, trace_id: int = 0。 返回 int；具体值及空输入行为见作用说明。
func _count_damage_records(records: Array, skill_id: StringName, trace_id: int = 0) -> int:
	var count: int = 0
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if trace_id > 0 and int(record.get("trace_id", 0)) != trace_id:
			continue
		if String(record.get("type", "")) != "damage":
			continue
		if skill_id != &"" and StringName(String(record.get("source_skill_id", ""))) != skill_id:
			continue
		count += 1
	return count


## 作用：递归统计指定节点子树中的 GPUParticles2D 数量，空根返回零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：node: Node。 返回 int；具体值及空输入行为见作用说明。
func _count_particle_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1 if node is GPUParticles2D else 0
	for child: Node in node.get_children():
		count += _count_particle_nodes(child)
	return count


## 作用：递归统计指定子树中名称含 DamageNumber 的 Label 节点，空根返回零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：node: Node。 返回 int；具体值及空输入行为见作用说明。
func _count_damage_popup_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 0
	if node is Label and String(node.name).find("DamageNumber") >= 0:
		count += 1
	for child: Node in node.get_children():
		count += _count_damage_popup_nodes(child)
	return count


## 作用：按 physics 选择等待 process_frame 或 physics_frame，等待非负 count 帧用于调试同步。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：count: int, physics: bool。 直接调用时须 await 等待异步流程完成。
func _wait_debug_frames(count: int, physics: bool) -> void:
	for _frame_index: int in range(maxi(count, 0)):
		if physics:
			await get_tree().physics_frame
		else:
			await get_tree().process_frame


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _update_fire_skill_chain_log：将选项生成、授予、目标、施放、伤害、粒子和弹字统计同步到技能链日志 Label。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：result: Dictionary。
func _update_fire_skill_chain_log(result: Dictionary) -> void:
	_skill_cards_controller._update_fire_skill_chain_log(result)


## 作用：转发到技能卡页 dev_debug_skill_cards_page.gd 的 _is_fire_skill_chain_result_healthy：检查选项、授予和施放均成功，且至少有伤害记录、粒子与弹字，返回诊断健康标志。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：result: Dictionary。 返回 bool；具体值及空输入行为见作用说明。
func _is_fire_skill_chain_result_healthy(result: Dictionary) -> bool:
	return _skill_cards_controller._is_fire_skill_chain_result_healthy(result)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _refresh_attack_damage_text：重新构建伤害卡文本，保存宿主缓存并同步显示 Label。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _refresh_attack_damage_text() -> void:
	_runtime_controller._refresh_attack_damage_text()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _reset_attack_damage_scroll：将伤害卡 ScrollContainer 的横向与纵向滚动位置重置为零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _reset_attack_damage_scroll() -> void:
	_runtime_controller._reset_attack_damage_scroll()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_attack_damage_record_count：统计当前可显示的 damage 类型追踪记录数量。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 int；具体值及空输入行为见作用说明。
func _get_attack_damage_record_count() -> int:
	return _runtime_controller._get_attack_damage_record_count()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_current_attack_damage_record_text：将当前卡片索引约束到记录范围后格式化记录；无记录返回空字符串。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 String；具体值及空输入行为见作用说明。
func _get_current_attack_damage_record_text() -> String:
	return _runtime_controller._get_current_attack_damage_record_text()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_attack_damage_records：从 DebugCombatTrace 的深拷贝记录中过滤 damage 条目，供伤害卡显示。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _get_attack_damage_records() -> Array[Dictionary]:
	return _runtime_controller._get_attack_damage_records()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_attack_damage_text：组合 trace、卡片编号、目标分组和伤害构成摘要，附上当前记录完整文本。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 String；具体值及空输入行为见作用说明。
func _build_attack_damage_text() -> String:
	return _runtime_controller._build_attack_damage_text()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _count_explosion_records：统计记录数组内 type=explosion 的字典数量，忽略非字典条目。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：records: Array。 返回 int；具体值及空输入行为见作用说明。
func _count_explosion_records(records: Array) -> int:
	return _runtime_controller._count_explosion_records(records)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _group_damage_records_by_target：按 target 名称分组 damage 记录并保留目标首次出现顺序。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：records: Array[Dictionary]。 返回 Dictionary；具体值及空输入行为见作用说明。
func _group_damage_records_by_target(records: Array[Dictionary]) -> Dictionary:
	return _runtime_controller._group_damage_records_by_target(records)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_damage_component_summary：去重伤害类别标签，优先按爆炸、主攻击、区域、反应和持续伤害排序，再拼接摘要。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：records: Array, includes_explosion: bool = false。 返回 String；具体值及空输入行为见作用说明。
func _build_damage_component_summary(records: Array, includes_explosion: bool = false) -> String:
	return _runtime_controller._build_damage_component_summary(records, includes_explosion)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _damage_component_label：结合特殊技能标识、source_type 和 damage_origin 判断一条记录的中文伤害类别。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：record: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _damage_component_label(record: Dictionary) -> String:
	return _runtime_controller._damage_component_label(record)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _legacy_skill_damage_component_label：将已登记的特殊来源技能片段映射为中文组件名称，未匹配时返回空字符串。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：source_skill_id: String。 返回 String；具体值及空输入行为见作用说明。
func _legacy_skill_damage_component_label(source_skill_id: String) -> String:
	return _runtime_controller._legacy_skill_damage_component_label(source_skill_id)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _format_record_dump：将记录格式化为带 record 标题和递归缩进内容的多行文本。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：record: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _format_record_dump(record: Dictionary) -> String:
	return _runtime_controller._format_record_dump(record)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _append_dictionary_dump：按排序后的字典键向 lines 追加递归记录文本，确保输出顺序稳定。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：lines: Array[String], dictionary: Dictionary, indent_level: int。
func _append_dictionary_dump(lines: Array[String], dictionary: Dictionary, indent_level: int) -> void:
	_runtime_controller._append_dictionary_dump(lines, dictionary, indent_level)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _append_array_dump：按数组顺序向 lines 追加带索引的递归记录条目。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：lines: Array[String], items: Array, indent_level: int。
func _append_array_dump(lines: Array[String], items: Array, indent_level: int) -> void:
	_runtime_controller._append_array_dump(lines, items, indent_level)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _append_record_value_line：按 value 类型递归展开字典或数组，标量直接格式化后追加到 lines。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：lines: Array[String], key: String, value: Variant, indent_level: int。
func _append_record_value_line(lines: Array[String], key: String, value: Variant, indent_level: int) -> void:
	_runtime_controller._append_record_value_line(lines, key, value, indent_level)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _record_indent：按非负层数生成每层两个空格的记录缩进字符串。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：indent_level: int。 返回 String；具体值及空输入行为见作用说明。
func _record_indent(indent_level: int) -> String:
	return _runtime_controller._record_indent(indent_level)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _format_record_value：String 与 StringName 直接取字符串，其他 Variant 通过 str 格式化。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：value: Variant。 返回 String；具体值及空输入行为见作用说明。
func _format_record_value(value: Variant) -> String:
	return _runtime_controller._format_record_value(value)


## 作用：将提供 to_dictionary 的升级对象或字典转为深拷贝字典，非法输入返回空字典。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option_variant: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
func _upgrade_option_to_dictionary(option_variant: Variant) -> Dictionary:
	var option: RefCounted = option_variant as RefCounted
	if option != null and option.has_method("to_dictionary"):
		var dictionary_variant: Variant = option.call("to_dictionary")
		if dictionary_variant is Dictionary:
			var option_dictionary: Dictionary = dictionary_variant
			return option_dictionary.duplicate(true)
	if option_variant is Dictionary:
		var dictionary: Dictionary = option_variant
		return dictionary.duplicate(true)
	return {}


## 作用：对节点所有直属子节点调用 queue_free，空节点不处理。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：node: Node。
func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		child.queue_free()


## 作用：对 Dictionary 返回深拷贝，其他类型返回空字典，防止调试视图改写原数据。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：value: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 作用：Array 输入原样返回供读取，其他类型返回空数组。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：value: Variant。 返回 Array；具体值及空输入行为见作用说明。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：null 使用 default_value，其他 Variant 通过 str 转为字符串。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：value: Variant, default_value: String = ""。 返回 String；具体值及空输入行为见作用说明。
func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)


## 作用：仅当 Variant 类型为整数或浮点数时返回 true。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：value: Variant。 返回 bool；具体值及空输入行为见作用说明。
func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


## 作用：把数组各项通过空值安全字符串转换收集为 Array[String]，非数组返回空数组。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：value: Variant。 返回 Array[String]；具体值及空输入行为见作用说明。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(_string_or(item, ""))
	return result


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_player_attributes_text：组合玩家基础有效属性、起始技能、特性和状态快照形成完整计算后属性文本。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 String；具体值及空输入行为见作用说明。
func _build_player_attributes_text() -> String:
	return _runtime_controller._build_player_attributes_text()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_player_core_attribute_lines：按玩家字段生成血量、成长、移动、暴击、抗伤、收益和各修正项的展示行。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 Array[String]；具体值及空输入行为见作用说明。
func _build_player_core_attribute_lines(player: Node) -> Array[String]:
	return _runtime_controller._build_player_core_attribute_lines(player)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_starting_skill_attribute_lines：合并角色及技能修正，展示起始技能最终攻速、冷却、暴击概率和弹速。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 Array[String]；具体值及空输入行为见作用说明。
func _build_starting_skill_attribute_lines(player: Node) -> Array[String]:
	return _runtime_controller._build_starting_skill_attribute_lines(player)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_trait_attribute_lines：从 CharacterRuntime.trait_runtime_state 读取特性计数、移动计时和护盾字段形成展示行。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 Array[String]；具体值及空输入行为见作用说明。
func _build_trait_attribute_lines(player: Node) -> Array[String]:
	return _runtime_controller._build_trait_attribute_lines(player)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_state_text：生成角色、暂停标志、敌人、主技能和玩家状态摘要；无玩家时显示开局选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 String；具体值及空输入行为见作用说明。
func _build_state_text() -> String:
	return _runtime_controller._build_state_text()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_nearest_enemy_fields：取得最近敌人 ID、状态、血量、护甲、攻击范围和状态快照的摘要字段。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Array[String]；具体值及空输入行为见作用说明。
func _build_nearest_enemy_fields() -> Array[String]:
	return _runtime_controller._build_nearest_enemy_fields()


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_selected_setup_fields：比较所选角色与当前局角色，生成角色差异及当前所选地图字段。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：current_character_id: StringName。 返回 Array[String]；具体值及空输入行为见作用说明。
func _build_selected_setup_fields(current_character_id: StringName) -> Array[String]:
	return _runtime_controller._build_selected_setup_fields(current_character_id)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _build_skill_fields：从技能实例及 SkillStatService 生成技能 ID、等级和有效攻击数值字段。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node, skill: RefCounted。 返回 Array[String]；具体值及空输入行为见作用说明。
func _build_skill_fields(player: Node, skill: RefCounted) -> Array[String]:
	return _runtime_controller._build_skill_fields(player, skill)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_player_effective_move_speed：优先调用玩家有效移动速度方法，缺少时读 move_speed；无玩家返回零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 float；具体值及空输入行为见作用说明。
func _get_player_effective_move_speed(player: Node) -> float:
	return _runtime_controller._get_player_effective_move_speed(player)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_player_effective_pickup_radius：优先调用玩家有效拾取半径方法，缺少时读 pickup_radius；无玩家返回零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 float；具体值及空输入行为见作用说明。
func _get_player_effective_pickup_radius(player: Node) -> float:
	return _runtime_controller._get_player_effective_pickup_radius(player)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _format_summary_fields：把摘要字段按每行三个分组，使用双空格间隔并换行返回。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：fields: Array[String]。 返回 String；具体值及空输入行为见作用说明。
func _format_summary_fields(fields: Array[String]) -> String:
	return _runtime_controller._format_summary_fields(fields)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _format_statuses：将状态快照格式化为短名称、层数、总 tick 伤害及剩余时长，空数组显示 statuses:none。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：statuses: Array。 返回 String；具体值及空输入行为见作用说明。
func _format_statuses(statuses: Array) -> String:
	return _runtime_controller._format_statuses(statuses)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _debug_status_short_name：委托 StatusShortNameFormatter.short_name 获取调试显示用状态短名称。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：status_id: String。 返回 String；具体值及空输入行为见作用说明。
func _debug_status_short_name(status_id: String) -> String:
	return _runtime_controller._debug_status_short_name(status_id)


## 作用：转发到运行时页 dev_debug_runtime_page.gd 的 _get_status_snapshot：优先向 target 查询状态快照，否则查询其 StatusEffectManager，均不可用返回空数组。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：target: Node。 返回 Array；具体值及空输入行为见作用说明。
func _get_status_snapshot(target: Node) -> Array:
	return _runtime_controller._get_status_snapshot(target)


## 作用：依次读取起始技能有效 range、area_radius、orbit_radius，以其 75% 约束到 56 至 180 像素；无数值用 120。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node2D。 返回 float；具体值及空输入行为见作用说明。
func _get_debug_spawn_radius(player: Node2D) -> float:
	var skill: RefCounted = _get_starting_skill(player)
	if skill == null:
		return 120.0
	var skill_manager: Node = _get_skill_manager(player)
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	for stat_name: String in ["range", "area_radius", "orbit_radius"]:
		var value: Variant = SkillStatServiceScript.get_effective_stat(skill, stat_name, null, skill_manager, relic_manager, player)
		if value != null:
			return clampf(float(value) * 0.75, 56.0, 180.0)
	return 120.0


## 作用：读取敌人 attack_range 转为浮点，空敌人或空属性返回零。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enemy: Node。 返回 float；具体值及空输入行为见作用说明。
func _get_enemy_attack_range(enemy: Node) -> float:
	if enemy == null:
		return 0.0
	var value: Variant = enemy.get("attack_range")
	return 0.0 if value == null else float(value)


## 作用：遍历有效 enemies 组 Node2D，按距当前玩家的平方距离返回最近实体，无玩家或无敌人返回 null。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Node；具体值及空输入行为见作用说明。
func _get_nearest_enemy() -> Node:
	var player: Node2D = _get_player() as Node2D
	if player == null:
		return null

	var nearest: Node2D = null
	var nearest_distance_squared: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance_squared: float = player.global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = enemy
			nearest_distance_squared = distance_squared
	return nearest


## 作用：根据角色起始技能 ID 从 SkillManager 查询技能实例，缺管理器或 ID 返回 null。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 RefCounted；具体值及空输入行为见作用说明。
func _get_starting_skill(player: Node) -> RefCounted:
	var skill_manager: Node = _get_skill_manager(player)
	var skill_id: StringName = _get_starting_skill_id(player)
	if skill_manager == null or skill_id == &"":
		return null
	return skill_manager.call("get_skill", skill_id) as RefCounted


## 作用：合并技能定义 events 与 runtime_events 中的字典深拷贝，保持先定义后运行事件顺序。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：skill: RefCounted。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _get_skill_events(skill: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if skill == null:
		return events

	var definition: RefCounted = skill.get("definition") as RefCounted
	if definition != null:
		var definition_events_variant: Variant = definition.get("events")
		if definition_events_variant is Array:
			for event_variant: Variant in definition_events_variant:
				if event_variant is Dictionary:
					events.append((event_variant as Dictionary).duplicate(true))

	var runtime_events_variant: Variant = skill.get("runtime_events")
	if runtime_events_variant is Array:
		for event_variant: Variant in runtime_events_variant:
			if event_variant is Dictionary:
				events.append((event_variant as Dictionary).duplicate(true))
	return events


## 作用：优先从角色配置读 starting_skill_id，缺失时在已拥有技能中检查 fireball 备用标识，否则返回空 ID。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 StringName；具体值及空输入行为见作用说明。
func _get_starting_skill_id(player: Node) -> StringName:
	if player == null:
		return &""
	var character_id: StringName = StringName(String(player.get("selected_character_id")))
	var character: Dictionary = GameData.get_character(character_id)
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id != &"":
		return starting_skill_id
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		for skill_variant: Variant in skill_manager.call("get_all_skills"):
			var skill: RefCounted = skill_variant as RefCounted
			if skill == null:
				continue
			if _string_or(skill.get("skill_id"), "") == "fireball":
				return &"fireball"
	return &""


## 作用：从 player 组取得首个玩家节点，供各页查询当前局实体。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Node；具体值及空输入行为见作用说明。
func _get_player() -> Node:
	return get_tree().get_first_node_in_group(&"player")


## 作用：返回玩家 SkillManager 子节点，空玩家返回 null。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：player: Node。 返回 Node；具体值及空输入行为见作用说明。
func _get_skill_manager(player: Node) -> Node:
	return player.get_node_or_null("SkillManager") if player != null else null


## 作用：优先查询 ui_manager 组，缺少时从根节点递归查找 UIManager。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 Node；具体值及空输入行为见作用说明。
func _get_ui_manager() -> Node:
	var ui_manager: Node = get_tree().get_first_node_in_group(&"ui_manager")
	if ui_manager != null:
		return ui_manager
	return get_tree().root.find_child("UIManager", true, false)


## 作用：转交左侧工具栏可见性设置，统一维护面板及覆盖层状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：should_show: bool。
func _set_debug_visible(should_show: bool) -> void:
	_set_left_toolbar_visible(should_show)


## 作用：同步 CanvasLayer 和面板可见性；打开时刷新摘要，关闭时隐藏全部范围覆盖层。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：should_show: bool。
func _set_left_toolbar_visible(should_show: bool) -> void:
	if _is_left_toolbar_visible() == should_show:
		if _panel != null:
			_panel.visible = should_show
		return

	visible = should_show
	if _panel != null:
		_panel.visible = should_show

	if should_show:
		_refresh_state()
	else:
		_set_all_range_overlays_visible(false)


## 作用：仅当宿主与已构建面板均可见时返回 true。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _is_left_toolbar_visible() -> bool:
	return visible and _panel != null and _panel.visible


## 作用：把调试手控标志写到根节点，启用时保证玩家手动攻击 nonce 元数据存在。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enabled: bool。
func _set_debug_control_mode(enabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_control_mode", enabled)
	if enabled:
		tree.root.set_meta("debug_player_attack_nonce", int(tree.root.get_meta("debug_player_attack_nonce", 0)))


## 作用：写入根节点 debug_manual_spawn_only，控制生成器是否只接受手动调试刷怪。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enabled: bool。
func _set_debug_manual_spawn_only(enabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_manual_spawn_only", enabled)


## 作用：读取有效根节点 debug_control_mode 开关，无树或根时返回 false。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


## 作用：写入根节点 debug_player_attack_disabled，供玩家自动攻击入口查询。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：disabled: bool。
func _set_player_attack_disabled(disabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_player_attack_disabled", disabled)


## 作用：查询根节点玩家自动攻击禁用标志，无树或根时返回 false。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _is_player_attack_disabled() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_player_attack_disabled", false))


## 作用：规范化敌人状态并验证白名单，根节点仅保存合法强制状态，无效输入写为空。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：state: String。
func _set_enemy_state_override(state: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var normalized_state: String = _normalize_enemy_forced_state(state)
	tree.root.set_meta("debug_enemy_forced_state", normalized_state if _is_valid_enemy_forced_state(normalized_state) else "")


## 作用：读取并规范化根节点强制状态，非法状态或无根返回空字符串。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 String；具体值及空输入行为见作用说明。
func _get_enemy_state_override() -> String:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return ""
	var state: String = _normalize_enemy_forced_state(String(tree.root.get_meta("debug_enemy_forced_state", "")))
	return state if _is_valid_enemy_forced_state(state) else ""


## 作用：把空强制状态显示为 auto，其他状态直接返回供摘要使用。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 String；具体值及空输入行为见作用说明。
func _format_enemy_state_override() -> String:
	var state: String = _get_enemy_state_override()
	return "auto" if state == "" else state


## 作用：仅接受 idle、chase、attack、hurt、dead 五个敌人强制状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：state: String。 返回 bool；具体值及空输入行为见作用说明。
func _is_valid_enemy_forced_state(state: String) -> bool:
	return state == "idle" or state == "chase" or state == "attack" or state == "hurt" or state == "dead"


## 作用：将 death 别名规范为 dead，其他状态保持原字符串。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：state: String。 返回 String；具体值及空输入行为见作用说明。
func _normalize_enemy_forced_state(state: String) -> String:
	return "dead" if state == "death" else state


## 作用：判断强制状态是否为 hurt 或 dead，供限制精英/Boss 状态选项。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：state: String。 返回 bool；具体值及空输入行为见作用说明。
func _is_elite_only_enemy_state(state: String) -> bool:
	return state == "hurt" or state == "dead"


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _refresh_enemy_state_option_availability：按最近敌人分类启用或禁用 Hurt/Death 选项，不满足条件时撤销已有精英状态覆写。
## 使用：由面板按钮、快捷键或调试流程调用此入口。
func _refresh_enemy_state_option_availability() -> void:
	_enemy_spawn_controller._refresh_enemy_state_option_availability()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _can_apply_elite_enemy_state_to_nearest：判断最近敌人是否存在且支持精英专属状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _can_apply_elite_enemy_state_to_nearest() -> bool:
	return _enemy_spawn_controller._can_apply_elite_enemy_state_to_nearest()


## 作用：转发到敌人页 dev_debug_enemy_spawn_page.gd 的 _is_elite_state_debug_enemy：根据 enemy_rank 元数据判断敌人是否为 elite 或 boss。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：enemy: Node。 返回 bool；具体值及空输入行为见作用说明。
func _is_elite_state_debug_enemy(enemy: Node) -> bool:
	return _enemy_spawn_controller._is_elite_state_debug_enemy(enemy)


## 作用：读取根节点 developer_mode_enabled，无有效树或根返回 false。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 返回 bool；具体值及空输入行为见作用说明。
func _is_developer_mode_enabled() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("developer_mode_enabled", false))


## 作用：隐藏主 UI 时保存原可见状态与引用，恢复时还原原状态并清空缓存。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：should_show: bool。
func _set_main_flow_ui_visible(should_show: bool) -> void:
	var ui_manager: CanvasLayer = _get_ui_manager() as CanvasLayer
	if not should_show:
		if ui_manager == null:
			return
		_hidden_ui_manager = ui_manager
		_hidden_ui_was_visible = ui_manager.visible
		ui_manager.visible = false
		return

	if _hidden_ui_manager != null and is_instance_valid(_hidden_ui_manager):
		_hidden_ui_manager.visible = _hidden_ui_was_visible
	_hidden_ui_manager = null


## 作用：创建带皮肤的切换按钮，绑定 _open_category(category_id) 并登记分类按钮索引，返回 Button。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: Container, category_id: String, text: String。 返回 Button；具体值及空输入行为见作用说明。
func _add_category_button(parent: Container, category_id: String, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(214, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	button.pressed.connect(Callable(self, "_open_category").bind(category_id))
	parent.add_child(button)
	_category_buttons[category_id] = button
	return button


## 作用：新建分类 VBoxContainer、登记页面索引并添加标题，初始隐藏后返回页面引用。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer, category_id: String, title_text: String。 返回 VBoxContainer；具体值及空输入行为见作用说明。
func _add_category_page(parent: VBoxContainer, category_id: String, title_text: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "CategoryPage_%s" % category_id
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 7)
	parent.add_child(page)
	_category_pages[category_id] = page
	_add_section(page, title_text)
	page.visible = false
	return page


## 作用：只展示已有指定分类，打开技能页时刷新卡片，同步导航按钮按下状态并刷新摘要。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：category_id: String。
func _open_category(category_id: String) -> void:
	if not _category_pages.has(category_id):
		return
	_active_category_id = category_id
	if category_id == "skill_cards":
		_refresh_god_skill_section()
	for page_id_variant: Variant in _category_pages.keys():
		var page_id: String = String(page_id_variant)
		var page: CanvasItem = _category_pages[page_id] as CanvasItem
		if page != null:
			page.visible = page_id == category_id
	for button_id_variant: Variant in _category_buttons.keys():
		var button_id: String = String(button_id_variant)
		var button: Button = _category_buttons[button_id] as Button
		if button != null:
			button.set_pressed_no_signal(button_id == category_id)
	_refresh_state()


## 作用：向父 VBoxContainer 添加指定文字与主题字号、颜色的分节标签。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer, text: String。
func _add_section(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62, 1.0))
	parent.add_child(label)


## 作用：创建带间隔的 HBoxContainer，挂入父布局并返回，供各页构造同一行控件。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer。 返回 HBoxContainer；具体值及空输入行为见作用说明。
func _add_row(parent: VBoxContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


## 作用：创建固定标签宽度与可伸展 OptionButton 的一行布局，返回下拉控件。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer, label_text: String。 返回 OptionButton；具体值及空输入行为见作用说明。
func _add_option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var row: HBoxContainer = _add_row(parent)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(104, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(300, 30)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	return option


## 作用：创建标签与 SpinBox，配置范围、步长和初始值后挂入父布局，返回数值控件。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float。 返回 SpinBox；具体值及空输入行为见作用说明。
func _add_spin_row(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var row: HBoxContainer = _add_row(parent)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(104, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(120, 30)
	row.add_child(spin)
	return spin


## 作用：创建皮肤按钮，设定文字与最小宽度、绑定 Callable 后挂到 parent，返回 Button。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：parent: HBoxContainer, text: String, callable: Callable, width: float = 92.0。 返回 Button；具体值及空输入行为见作用说明。
func _add_button(parent: HBoxContainer, text: String, callable: Callable, width: float = 92.0) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 30)
	UIButtonSkin.apply(button)
	button.pressed.connect(callable)
	parent.add_child(button)
	return button


## 作用：添加选项文字并在该项元数据中保存 StringName(id)，供稳定 ID 查询。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: OptionButton, text: String, id: String。
func _add_option_item(option: OptionButton, text: String, id: String) -> void:
	var index: int = option.item_count
	option.add_item(text)
	option.set_item_metadata(index, StringName(id))


## 作用：创建不可选择的下拉分组标题，元数据为空 ID，空控件不处理。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: OptionButton, text: String。
func _add_disabled_option_header(option: OptionButton, text: String) -> void:
	if option == null:
		return
	var index: int = option.item_count
	option.add_item(text)
	option.set_item_metadata(index, StringName(""))
	option.set_item_disabled(index, true)


## 作用：查找首个启用且有 ID 的选项并选中，无匹配不改变选择。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: OptionButton。
func _select_first_enabled_option(option: OptionButton) -> void:
	var index: int = _find_first_enabled_option_index(option)
	if index >= 0:
		option.select(index)


## 作用：返回首个未禁用且元数据 ID 非空的条目索引，无控件或无匹配返回 -1。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: OptionButton。 返回 int；具体值及空输入行为见作用说明。
func _find_first_enabled_option_index(option: OptionButton) -> int:
	if option == null:
		return -1
	for index in range(option.item_count):
		if option.is_item_disabled(index):
			continue
		if String(option.get_item_metadata(index)) == "":
			continue
		return index
	return -1


## 作用：遍历下拉元数据寻找匹配 ID 并选中首个匹配项，空控件不处理。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: OptionButton, id: String。
func _select_option_by_id(option: OptionButton, id: String) -> void:
	if option == null:
		return
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == id:
			option.select(index)
			return


## 作用：读取合法选中项 ID，当前项禁用时改选首个可用项，无可用项返回空 StringName。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：option: OptionButton。 返回 StringName；具体值及空输入行为见作用说明。
func _get_selected_id(option: OptionButton) -> StringName:
	if option == null or option.item_count <= 0:
		return &""
	var selected_index: int = clampi(option.selected, 0, option.item_count - 1)
	if option.is_item_disabled(selected_index):
		selected_index = _find_first_enabled_option_index(option)
		if selected_index < 0:
			return &""
		option.select(selected_index)
	return StringName(String(option.get_item_metadata(selected_index)))


## 作用：从定义字典取 display_name 转字符串，字段缺失时使用 fallback。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：data: Dictionary, fallback: String。 返回 String；具体值及空输入行为见作用说明。
func _display_name(data: Dictionary, fallback: String) -> String:
	return String(data.get("display_name", fallback))


## 作用：根据特效页日志等级转发普通、警告或错误显示入口。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：level: StringName, message: String。
func _on_effects_page_log_requested(level: StringName, message: String) -> void:
	match level:
		&"error":
			_log_error(message)
		&"warning":
			_log_warn(message)
		_:
			_log(message)


## 作用：保存最近日志，打印青色调试前缀并刷新状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：message: String。
func _log(message: String) -> void:
	_last_log = message
	print_rich("[color=cyan][DevDebug][/color] %s" % message)
	_refresh_state()


## 作用：保存最近警告，打印黄色调试前缀并刷新状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：message: String。
func _log_warn(message: String) -> void:
	_last_log = message
	print_rich("[color=yellow][DevDebug][/color] %s" % message)
	_refresh_state()


## 作用：保存最近错误，打印红色调试前缀并刷新状态。
## 使用：由面板按钮、快捷键或调试流程调用此入口。 入参：message: String。
func _log_error(message: String) -> void:
	_last_log = message
	print_rich("[color=red][DevDebug][/color] %s" % message)
	_refresh_state()
