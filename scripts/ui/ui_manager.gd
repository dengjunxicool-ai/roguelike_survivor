## 文件用途：编排页面状态、暂停、开局加载、局内事件与终局结算。
## 使用方式：挂载启动场景；页面发状态/命令请求，transition_to 统一验证、准备、显隐和暂停。

extends CanvasLayer
class_name UIManager


const STATE_BOOT: String = "BOOT"
const STATE_TITLE: String = "TITLE"
const STATE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const STATE_MAP_SELECT: String = "MAP_SELECT"
const STATE_RUNNING: String = "RUNNING"
const STATE_LEVEL_UP_MODAL: String = "LEVEL_UP_MODAL"
const STATE_RUN_REWARD_MODAL: String = "RUN_REWARD_MODAL"
const STATE_CURSE_CHOICE_MODAL: String = "CURSE_CHOICE_MODAL"
const STATE_PAUSE_MENU: String = "PAUSE_MENU"
const STATE_RESULT_DEFEAT: String = "RESULT_DEFEAT"
const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const STATE_META_UPGRADE: String = "META_UPGRADE"
const STATE_CODEX: String = "CODEX"
const STATE_SETTINGS: String = "SETTINGS"
const STATE_DEVELOPER_MODE: String = "DEVELOPER_MODE"

const PLAYER_GROUP: StringName = &"player"
const ENEMY_SPAWNER_GROUP: StringName = &"enemy_spawner"
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const RunProgressionServiceScript: Script = preload("res://scripts/game/run_progression_service.gd")
const RunSceneCoordinatorScript: Script = preload("res://scripts/game/run_scene_coordinator.gd")
const RunSceneUIBridgeScript: Script = preload("res://scripts/ui/run_scene_ui_bridge.gd")
const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")
const TitleScreenControllerScript: Script = preload("res://scripts/ui/screens/title_screen_controller.gd")
const CharacterLoadoutControllerScript: Script = preload("res://scripts/ui/screens/character_loadout_controller.gd")
const MapSelectControllerScript: Script = preload("res://scripts/ui/screens/map_select_controller.gd")
const MetaUpgradeControllerScript: Script = preload("res://scripts/ui/screens/meta_upgrade_controller.gd")
const CodexScreenControllerScript: Script = preload("res://scripts/ui/screens/codex_screen_controller.gd")
const SettingsScreenControllerScript: Script = preload("res://scripts/ui/screens/settings_screen_controller.gd")
const ResultScreenControllerScript: Script = preload("res://scripts/ui/screens/result_screen_controller.gd")
const RunHudControllerScript: Script = preload("res://scripts/ui/hud/run_hud_controller.gd")
const RunHudStateProviderScript: Script = preload("res://scripts/ui/hud/run_hud_state_provider.gd")
const RunChoiceModalControllerScript: Script = preload("res://scripts/ui/modals/run_choice_modal_controller.gd")
const ModalFlowControllerScript: Script = preload("res://scripts/ui/modals/modal_flow_controller.gd")
const DevDebugPanelScript: Script = preload("res://scripts/debug/dev_debug_panel.gd")
const UINodeFactoryScript: Script = preload("res://scripts/ui/ui_node_factory.gd")
const UIScreenFactoryScript: Script = preload("res://scripts/ui/ui_screen_factory.gd")
const UIResponsiveLayoutScript: Script = preload("res://scripts/ui/ui_responsive_layout.gd")
const UISettingsServiceScript: Script = preload("res://scripts/ui/ui_settings_service.gd")
const LocalizationServiceScript: Script = preload("res://scripts/ui/localization_service.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const UIScreenHostScript: Script = preload("res://scripts/ui/ui_screen_host.gd")
const UIScreenRegistryScript: Script = preload("res://scripts/ui/ui_screen_registry.gd")
const UIPausePolicyScript: Script = preload("res://scripts/ui/ui_pause_policy.gd")
const UIStateMachineScript: Script = preload("res://scripts/ui/ui_state_machine.gd")
const UIStateRegistryScript: Script = preload("res://scripts/ui/ui_state_registry.gd")
const UIStatePrepareRouterScript: Script = preload("res://scripts/ui/ui_state_prepare_router.gd")
const RunResultStateBuilderScript: Script = preload("res://scripts/ui/run_result_state_builder.gd")
const DEFAULT_MAP_ID: StringName = &"abandoned_dungeon"

var current_state: String = STATE_BOOT

var _screen_registry: RefCounted = UIScreenRegistryScript.new()
var _selected_character_id: StringName = &"mage"
var _selected_map_id: StringName = DEFAULT_MAP_ID
var _selected_map_name: String = "废弃地牢"
var _run_seconds: float = 0.0
var _run_duration: float = 600.0
var _wave_index: int = 0
var _wave_id: String = ""
var _wave_remaining_seconds: float = 0.0
var _wave_duration_seconds: float = 55.0
var _wave_spawned_count: int = 0
var _wave_total_count: int = 0
var _kill_count: int = 0
var _run_start_souls: int = 0
var _run_souls_earned: int = 0
var _result_reward_claimed: bool = false
var _result_progression_recorded: bool = false
var _last_progression_summary: Dictionary = {}
var _hud_refresh_cooldown: float = 0.0
var _announcement_timer: float = 0.0

var _level_up_options: HBoxContainer
var _reward_options: HBoxContainer
var _curse_options: VBoxContainer
var _title_controller: RefCounted
var _character_loadout_controller: RefCounted
var _map_select_controller: RefCounted
var _meta_upgrade_controller: RefCounted
var _codex_controller: RefCounted
var _settings_controller: RefCounted
var _result_controller: RefCounted
var _run_hud_controller: RefCounted
var _run_hud_state_provider: RefCounted = RunHudStateProviderScript.new()
var _run_choice_modal_controller: RefCounted
var _modal_flow_controller: RefCounted = ModalFlowControllerScript.new()
var _run_stats_tracker: Node
var _state_registry: RefCounted = UIStateRegistryScript.new()
var _state_machine: RefCounted = UIStateMachineScript.new()
var _state_prepare_router: RefCounted = UIStatePrepareRouterScript.new()
var _screen_host: RefCounted = UIScreenHostScript.new()
var _pause_policy: RefCounted = UIPausePolicyScript.new()
var _run_scene_ui_bridge: RefCounted = RunSceneUIBridgeScript.new()
var _run_scene_coordinator: RefCounted = RunSceneCoordinatorScript.new()
var _responsive_layout: RefCounted = UIResponsiveLayoutScript.new()
var _allow_direct_running_transition: bool = false
var _run_loading_overlay: Control
var _run_loading_status_label: Label
var _run_loading_dots_label: Label
var _run_loading_tween: Tween
var _run_loading_active: bool = false
var _run_loading_elapsed: float = 0.0


## 作用：组装状态机、页面宿主和界面，应用已存设置并进入启动状态。
## 使用：Godot 自动调用；节点保持 PROCESS_MODE_ALWAYS，使暂停菜单仍能接收输入。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	add_to_group(&"ui_manager")
	_state_machine.call("setup", current_state, _state_registry)
	_screen_host.call("setup", _screen_registry, _state_registry)
	_apply_startup_window_mode()
	get_viewport().size_changed.connect(Callable(self, "_update_responsive_layouts"))
	_build_screens()
	_ensure_run_loading_overlay()
	call_deferred("_update_responsive_layouts")
	transition_to(STATE_BOOT)
	call_deferred("_finish_boot")


## 作用：推进本节点的逐帧更新流程。
## 使用：由 Godot 自动调用；delta 为自上一帧经过的秒数。
func _process(delta: float) -> void:
	if _run_loading_active:
		_update_run_loading(delta)
	if current_state != STATE_RUNNING:
		return

	_update_announcement_timer(delta)
	_update_hud_refresh_timer(delta)


## 作用：更新公告计时器。
## 使用：本文件由 _process 调用；输入 delta（delta）。
func _update_announcement_timer(delta: float) -> void:
	_announcement_timer = maxf(_announcement_timer - delta, 0.0)
	if _announcement_timer <= 0.0:
		_set_hud_label("announcement", "")


## 作用：更新HUD刷新计时器。
## 使用：本文件由 _process 调用；输入 delta（delta）。
func _update_hud_refresh_timer(delta: float) -> void:
	_hud_refresh_cooldown = maxf(_hud_refresh_cooldown - delta, 0.0)
	if _hud_refresh_cooldown <= 0.0:
		_update_run_hud()
		_hud_refresh_cooldown = 0.25


## 作用：响应当前界面的输入事件。
## 使用：由 Godot 输入分发调用；event 为输入事件，是否消费由函数内分支决定；输入 event（事件）。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		if current_state == STATE_RUNNING:
			transition_to(STATE_PAUSE_MENU)
			get_viewport().set_input_as_handled()
			return
		if current_state == STATE_PAUSE_MENU:
			transition_to(STATE_RUNNING)
			get_viewport().set_input_as_handled()
			return
	if current_state == STATE_TITLE and _title_controller != null:
		_title_controller.call("handle_input", event)


## 作用：校验目标页面和允许转移，再统一准备内容、显隐页面与应用暂停。
## 使用：next_state 使用 STATE_* 常量；开发模式走独立开局入口，非法转移警告并返回。
func transition_to(next_state: String) -> void:
	if next_state == STATE_DEVELOPER_MODE:
		_start_developer_mode()
		return

	if not bool(_screen_registry.call("has_screen", next_state)):
		push_warning("Unknown UI state: %s" % next_state)
		return

	if not bool(_state_machine.call("can_transition", next_state)):
		push_warning("Blocked UI transition: %s -> %s" % [current_state, next_state])
		return

	if not bool(_state_machine.call("transition_to", next_state)):
		push_warning("Blocked UI transition: %s -> %s" % [current_state, next_state])
		return
	current_state = String(_state_machine.call("get_current_state"))
	_prepare_state(next_state)
	_apply_visible_hierarchy(next_state)
	_apply_pause_for_state(next_state)


## 作用：显示页面。
## 使用：供本模块调用者使用；输入 next_state（下一个状态）。
func show_screen(next_state: String) -> void:
	transition_to(next_state)


## 作用：启动开发者调试单局。
## 使用：本文件由 _start_developer_mode 调用；输入 setup（初始化）。
func start_developer_debug_run(setup: Dictionary = {}) -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		tree.root.set_meta("developer_mode_enabled", true)
		tree.root.set_meta("debug_control_mode", true)
		tree.root.set_meta("debug_manual_spawn_only", true)

	_selected_character_id = StringName(String(setup.get("character_id", _selected_character_id)))
	_selected_map_id = StringName(String(setup.get("map_id", _selected_map_id)))
	var previous_allow_direct: bool = _allow_direct_running_transition
	_allow_direct_running_transition = true
	_start_run(_selected_map_id)
	_allow_direct_running_transition = previous_allow_direct


## 作用：退出游戏。
## 使用：本文件由 _build_title 调用。
func _quit_game() -> void:
	get_tree().quit()


## 作用：应用启动窗口模式。
## 使用：本文件由 _ready 调用。
func _apply_startup_window_mode() -> void:
	UISettingsServiceScript.apply_saved_settings()


## 作用：完成启动。
## 使用：本文件由 _ready 调用。
func _finish_boot() -> void:
	if current_state == STATE_BOOT:
		transition_to(STATE_TITLE)
		_queue_responsive_layout_refresh()


## 作用：检查状态转移是否允许，返回布尔判断结果；具体处理委托给 _state_registry.can_transition。
## 使用：内部辅助入口；输入 from_state（来源状态）、to_state（转换状态）。
func _can_transition(from_state: String, to_state: String) -> bool:
	return bool(_state_registry.call("can_transition", from_state, to_state))


## 作用：准备状态；具体处理委托给 _state_prepare_router.prepare。
## 使用：本文件由 transition_to、_enter_running_state_with_direct 调用；输入 state（状态）。
func _prepare_state(state: String) -> void:
	_state_prepare_router.call("prepare", self, state, {
		"modal_flow_controller": _modal_flow_controller,
		"choice_modal": _run_choice_modal_controller
	})

## 作用：应用可见层级；具体处理委托给 _screen_host.apply_visible_hierarchy。
## 使用：本文件由 transition_to、_enter_running_state_with_direct 调用；输入 state（状态）。
func _apply_visible_hierarchy(state: String) -> void:
	_screen_host.call("apply_visible_hierarchy", state)
	_queue_responsive_layout_refresh()


## 作用：应用暂停对应状态；具体处理委托给 _pause_policy.apply。
## 使用：本文件由 transition_to、_enter_running_state_with_direct 调用；输入 state（状态）。
func _apply_pause_for_state(state: String) -> void:
	_pause_policy.call("apply", get_tree(), _state_registry, state)


## 作用：进入运行状态。
## 使用：内部辅助入口。
func _enter_running_state() -> void:
	_enter_running_state_with_direct(_allow_direct_running_transition)


## 作用：进入运行状态结合直接。
## 使用：本文件由 _enter_running_state、_start_run 调用；输入 allow_direct_transition（allow直接转移）。
func _enter_running_state_with_direct(allow_direct_transition: bool) -> void:
	if allow_direct_transition and not bool(_state_machine.call("can_transition", STATE_RUNNING)):
		_state_machine.call("force_transition_to", STATE_RUNNING)
		current_state = String(_state_machine.call("get_current_state"))
		_prepare_state(STATE_RUNNING)
		_apply_visible_hierarchy(STATE_RUNNING)
		_apply_pause_for_state(STATE_RUNNING)
		return
	transition_to(STATE_RUNNING)


## 作用：判断运行子节点状态，返回布尔判断结果；具体处理委托给 _state_registry.is_running_child_state。
## 使用：内部辅助入口；输入 state（状态）。
func _is_running_child_state(state: String) -> bool:
	return bool(_state_registry.call("is_running_child_state", state))


## 作用：判断全屏选择状态，返回布尔判断结果；具体处理委托给 _state_registry.is_fullscreen_choice_state。
## 使用：内部辅助入口；输入 state（状态）。
func _is_fullscreen_choice_state(state: String) -> bool:
	return bool(_state_registry.call("is_fullscreen_choice_state", state))


## 作用：设置页面可见性；具体处理委托给 _screen_host.set_screen_visible。
## 使用：内部辅助入口；输入 state（状态）、should_show（是否需要显示）。
func _set_screen_visible(state: String, should_show: bool) -> void:
	_screen_host.call("set_screen_visible", state, should_show)


## 作用：构建页面组。
## 使用：本文件由 _ready 调用。
func _build_screens() -> void:
	var build_order_variant: Variant = _state_registry.call("get_build_order")
	var build_order: Array = build_order_variant if build_order_variant is Array else []
	for state_variant: Variant in build_order:
		_build_screen_for_state(String(state_variant))
	_setup_run_choice_modals()


## 作用：构建页面对应状态。
## 使用：本文件由 _build_screens 调用；输入 state（状态）。
func _build_screen_for_state(state: String) -> void:
	if state == STATE_RUNNING:
		return
	if state == STATE_RESULT_DEFEAT:
		_build_result_screen(STATE_RESULT_DEFEAT, _tr("panel.defeat", "失败结算"))
		return
	if state == STATE_RESULT_VICTORY:
		_build_result_screen(STATE_RESULT_VICTORY, _tr("panel.victory", "胜利结算"))
		return
	var method_name: StringName = StringName(_state_registry.call("get_build_method", state))
	if method_name != &"" and has_method(method_name):
		call(method_name)


## 作用：构建启动并配置节点/样式所需的属性。
## 使用：内部辅助入口。
func _build_boot() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_BOOT, _tr("panel.boot", "BOOT"), Vector2(360, 220), 10)
	_add_label(body, _tr("panel.loading", "正在加载"), 1)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	body.add_child(bar)


## 作用：构建标题并配置节点/样式所需的属性。
## 使用：内部辅助入口。
func _build_title() -> void:
	_title_controller = TitleScreenControllerScript.new()
	_title_controller.state_requested.connect(Callable(self, "transition_to"))
	_title_controller.quit_requested.connect(Callable(self, "_quit_game"))
	var screen: Control = _title_controller.call("build") as Control
	add_child(screen)
	_screen_registry.call("register_screen", STATE_TITLE, screen)


## 作用：构建角色选择并配置节点/样式所需的属性。
## 使用：内部辅助入口。
func _build_character_select() -> void:
	_character_loadout_controller = CharacterLoadoutControllerScript.new()
	_character_loadout_controller.loadout_confirmed.connect(Callable(self, "_on_loadout_confirmed"))
	_character_loadout_controller.back_requested.connect(Callable(self, "transition_to").bind(STATE_TITLE))
	var screen: Control = _character_loadout_controller.call("build") as Control
	add_child(screen)
	_screen_registry.call("register_screen", STATE_CHARACTER_SELECT, screen)


## 作用：构建地图选择并配置节点/样式所需的属性。
## 使用：内部辅助入口。
func _build_map_select() -> void:
	_map_select_controller = MapSelectControllerScript.new()
	_map_select_controller.start_requested.connect(Callable(self, "_start_run"))
	_map_select_controller.back_requested.connect(Callable(self, "transition_to").bind(STATE_CHARACTER_SELECT))
	var screen: Control = _map_select_controller.call("build") as Control
	add_child(screen)
	_screen_registry.call("register_screen", STATE_MAP_SELECT, screen)




## 作用：构建局外升级并配置节点/样式所需的属性；具体处理委托给 _meta_upgrade_controller.build。
## 使用：内部辅助入口。
func _build_meta_upgrade() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_META_UPGRADE, _tr("panel.meta_upgrade", "局外升级"), Vector2(780, 620), 10)
	_meta_upgrade_controller = MetaUpgradeControllerScript.new()
	_meta_upgrade_controller.state_requested.connect(Callable(self, "transition_to"))
	_meta_upgrade_controller.call("build", body)


## 作用：构建图鉴并配置节点/样式所需的属性；具体处理委托给 _codex_controller.build。
## 使用：内部辅助入口。
func _build_codex() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_CODEX, _tr("panel.codex", "Codex图鉴"), Vector2(700, 520), 10)
	_codex_controller = CodexScreenControllerScript.new()
	_codex_controller.state_requested.connect(Callable(self, "transition_to"))
	_codex_controller.call("build", body)


## 作用：构建设置并配置节点/样式所需的属性；具体处理委托给 _settings_controller.build。
## 使用：内部辅助入口。
func _build_settings() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_SETTINGS, _tr("panel.settings", "设置"), Vector2(520, 420), 10)
	_settings_controller = SettingsScreenControllerScript.new()
	_settings_controller.state_requested.connect(Callable(self, "transition_to"))
	_settings_controller.call("build", body)


## 作用：构建单局HUD并配置节点/样式所需的属性。
## 使用：本文件由 _ensure_run_hud_built 调用。
func _build_run_hud() -> void:
	if bool(_screen_registry.call("has_screen", STATE_RUNNING)):
		return

	_run_hud_controller = RunHudControllerScript.new()
	_run_hud_controller.pause_requested.connect(Callable(self, "transition_to").bind(STATE_PAUSE_MENU))
	var screen: CanvasLayer = _run_hud_controller.call("build", get_tree()) as CanvasLayer
	add_child(screen)
	_run_hud_controller.call("update_layout")
	_screen_registry.call("register_screen", STATE_RUNNING, screen)


## 作用：检查 RUNNING 页面是否存在，缺失时调用 _build_run_hud 构建并登记 HUD。
## 使用：开局或需要 HUD 的流程调用；已构建时直接返回。
func _ensure_run_hud_built() -> void:
	if not bool(_screen_registry.call("has_screen", STATE_RUNNING)):
		_build_run_hud()



## 作用：构建升级弹窗。
## 使用：内部辅助入口。
func _build_level_up_modal() -> void:
	_level_up_options = _create_choice_modal_screen(STATE_LEVEL_UP_MODAL, _tr("panel.level_up", "技能选择"), 20)


## 作用：构建局内奖励弹窗。
## 使用：内部辅助入口。
func _build_run_reward_modal() -> void:
	_reward_options = _create_choice_modal_screen(STATE_RUN_REWARD_MODAL, _tr("panel.reward", "战利品选择"), 20)


## 作用：构建诅咒选择弹窗。
## 使用：内部辅助入口。
func _build_curse_choice_modal() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_CURSE_CHOICE_MODAL, _tr("panel.curse", "诅咒选择"), Vector2(720, 460), 20)
	_add_label(body, _tr("panel.curse_hint", "选择一项高风险高收益强化"), 1)
	_curse_options = _add_vbox(body)
	_add_state_button(body, _tr("panel.skip", "跳过"), STATE_RUNNING)


## 作用：初始化单局选择弹窗组。
## 使用：本文件由 _build_screens 调用。
func _setup_run_choice_modals() -> void:
	_run_choice_modal_controller = RunChoiceModalControllerScript.new()
	_run_choice_modal_controller.transition_requested.connect(Callable(self, "transition_to"))
	_run_choice_modal_controller.call(
		"setup",
		get_tree(),
		_level_up_options,
		_curse_options,
		_reward_options
	)
	_run_choice_modal_controller.call("prewarm_choice_card_pools")


## 作用：构建暂停菜单。
## 使用：内部辅助入口。
func _build_pause_menu() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_PAUSE_MENU, _tr("panel.pause", "暂停游戏"), Vector2(420, 360), 30)
	_add_state_button(body, _tr("panel.resume", "继续游戏"), STATE_RUNNING)
	_add_state_button(body, _tr("panel.give_up", "放弃战斗"), STATE_RESULT_DEFEAT)
	_add_state_button(body, _tr("panel.back_to_title", "返回主菜单"), STATE_TITLE)


## 作用：构建结果页面并配置节点/样式所需的属性；具体处理委托给 _result_controller.build。
## 使用：本文件由 _build_screen_for_state 调用；输入 state（状态）、title（标题）。
func _build_result_screen(state: String, title: String) -> void:
	var body: VBoxContainer = _create_panel_screen(state, title, Vector2(560, 460), 30)
	if _result_controller == null:
		_result_controller = ResultScreenControllerScript.new()
		_result_controller.state_requested.connect(Callable(self, "transition_to"))
		_result_controller.recommended_loadout_requested.connect(Callable(self, "_apply_recommended_loadout"))
	_result_controller.call("build", body, state)


## 作用：获取页面字典，供当前模块后续逻辑使用；具体处理委托给 _screen_registry.get_screens。
## 使用：本文件由 _create_panel_screen、_create_choice_modal_screen 调用；返回结果字典。
func _get_screen_dictionary() -> Dictionary:
	var screens_variant: Variant = _screen_registry.call("get_screens")
	if screens_variant is Dictionary:
		return screens_variant
	return {}


## 作用：创建面板页面。
## 使用：本文件由 _build_boot、_build_meta_upgrade、_build_codex 调用；输入 state（状态）、title（标题）、min_size（最小尺寸）、z_index_value（z索引值）；返回 VBoxContainer 对象/值。
func _create_panel_screen(state: String, title: String, min_size: Vector2, z_index_value: int) -> VBoxContainer:
	return UIScreenFactoryScript.create_panel_screen(
		self,
		_get_screen_dictionary(),
		_responsive_layout,
		state,
		title,
		min_size,
		z_index_value,
		get_viewport().get_visible_rect().size
	)


## 作用：创建选择弹窗页面并配置节点/样式所需的属性。
## 使用：本文件由 _build_level_up_modal、_build_run_reward_modal 调用；输入 state（状态）、title（标题）、z_index_value（z索引值）；返回 HBoxContainer 对象/值。
func _create_choice_modal_screen(state: String, title: String, z_index_value: int) -> HBoxContainer:
	var screen: Control = UIScreenFactoryScript.create_screen(self, _get_screen_dictionary(), state, z_index_value)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.027, 0.033, 0.92)
	screen.add_child(background)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_left = 48
	title_label.offset_top = 26
	title_label.offset_right = -48
	title_label.offset_bottom = 78
	screen.add_child(title_label)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	screen.add_child(margin)

	var center_column: VBoxContainer = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center_column)

	var options: HBoxContainer = HBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 28)
	center_column.add_child(options)
	return options


## 作用：更新响应式布局组。
## 使用：本文件由 _ready、_queue_responsive_layout_refresh、_update_responsive_layouts_next_frame 调用。
func _update_responsive_layouts() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_responsive_layout.call("update", viewport_size)
	_update_title_layout()
	_update_character_select_layout()
	_update_map_select_layout()
	if _run_hud_controller != null and _run_hud_controller.has_method("update_layout"):
		_run_hud_controller.call("update_layout")


## 作用：排队响应式布局刷新。
## 使用：本文件由 _finish_boot、_apply_visible_hierarchy 调用。
func _queue_responsive_layout_refresh() -> void:
	call_deferred("_update_responsive_layouts")
	call_deferred("_update_responsive_layouts_next_frame")


## 作用：更新响应式布局组下一个帧。
## 使用：本文件由 _queue_responsive_layout_refresh 调用；包含等待操作，需完成时使用 await 调用。
func _update_responsive_layouts_next_frame() -> void:
	await get_tree().process_frame
	_update_responsive_layouts()


## 作用：更新地图选择布局；具体处理委托给 _map_select_controller.update_layout。
## 使用：本文件由 _update_responsive_layouts 调用。
func _update_map_select_layout() -> void:
	if _map_select_controller != null:
		_map_select_controller.call("update_layout", get_viewport().get_visible_rect().size)



## 作用：添加标签。
## 使用：本文件由 _build_boot、_build_curse_choice_modal 调用；输入 parent（父节点）、text（文本）、alignment（alignment）、node_name（节点名称）；返回 Label 对象/值。
func _add_label(parent: Node, text: String, alignment: int = 0, node_name: String = "") -> Label:
	return UINodeFactoryScript.add_label(parent, text, alignment, node_name)


## 作用：添加按钮。
## 使用：本文件由 _add_state_button 调用；输入 parent（父节点）、text（文本）；返回 Button 对象/值。
func _add_button(parent: Node, text: String) -> Button:
	return UINodeFactoryScript.add_button(parent, text)


## 作用：添加状态切换按钮。
## 使用：本文件由 _build_curse_choice_modal、_build_pause_menu 调用；输入 parent（父节点）、text（文本）、state（状态）；返回 Button 对象/值。
func _add_state_button(parent: Node, text: String, state: String) -> Button:
	var button: Button = _add_button(parent, text)
	button.pressed.connect(Callable(self, "transition_to").bind(state))
	return button


## 作用：添加滚动区。
## 使用：内部辅助入口；输入 parent（父节点）；返回 ScrollContainer 对象/值。
func _add_scroll(parent: Node) -> ScrollContainer:
	return UINodeFactoryScript.add_scroll(parent)


## 作用：添加纵向容器。
## 使用：本文件由 _build_curse_choice_modal 调用；输入 parent（父节点）；返回 VBoxContainer 对象/值。
func _add_vbox(parent: Node) -> VBoxContainer:
	return UINodeFactoryScript.add_vbox(parent)


## 作用：添加横向容器。
## 使用：内部辅助入口；输入 parent（父节点）；返回 HBoxContainer 对象/值。
func _add_hbox(parent: Node) -> HBoxContainer:
	return UINodeFactoryScript.add_hbox(parent)


## 作用：添加带标签进度。
## 使用：内部辅助入口；输入 parent（父节点）、label_text（标签文本）、value（值）、max_value（上限值）；返回 ProgressBar 对象/值。
func _add_labeled_progress(parent: Node, label_text: String, value: float, max_value: float) -> ProgressBar:
	return UINodeFactoryScript.add_labeled_progress(parent, label_text, value, max_value)


## 作用：更新标题布局；具体处理委托给 _title_controller.update_layout。
## 使用：本文件由 _update_responsive_layouts 调用。
func _update_title_layout() -> void:
	if _title_controller != null:
		_title_controller.call("update_layout", get_viewport().get_visible_rect().size)


## 作用：重置标题页面；具体处理委托给 _title_controller.reset。
## 使用：内部辅助入口。
func _reset_title_screen() -> void:
	if _title_controller != null:
		_title_controller.call("reset")


## 作用：刷新角色选择页面；具体处理委托给 _character_loadout_controller.refresh。
## 使用：内部辅助入口。
func _refresh_character_select_screen() -> void:
	if _character_loadout_controller != null:
		_character_loadout_controller.call("refresh", _selected_character_id)


## 作用：更新角色选择布局；具体处理委托给 _character_loadout_controller.update_layout。
## 使用：本文件由 _update_responsive_layouts 调用。
func _update_character_select_layout() -> void:
	if _character_loadout_controller != null:
		_character_loadout_controller.call("update_layout", get_viewport().get_visible_rect().size)


## 作用：获取技能展示名称，供当前模块后续逻辑使用。
## 使用：内部辅助入口；输入 skill_id（技能ID）；返回 String 文本/标识。
func _get_skill_display_name(skill_id: StringName) -> String:
	var skill: Dictionary = GameData.get_skill(skill_id)
	return String(skill.get("display_name", skill_id))


## 作用：刷新地图选择页面；具体处理委托给 _map_select_controller.refresh。
## 使用：内部辅助入口。
func _refresh_map_select_screen() -> void:
	if _map_select_controller != null:
		_map_select_controller.call("refresh", _selected_character_id)


## 作用：刷新局外升级页面；具体处理委托给 _meta_upgrade_controller.refresh。
## 使用：内部辅助入口。
func _refresh_meta_upgrade_screen() -> void:
	if _meta_upgrade_controller != null:
		_meta_upgrade_controller.call("refresh")




## 作用：响应开局配置已确认并衔接对应的事件处理流程。
## 使用：本文件由 _build_character_select 调用；输入 character_id（角色ID）。
func _on_loadout_confirmed(character_id: StringName) -> void:
	_selected_character_id = character_id
	transition_to(STATE_MAP_SELECT)


## 作用：绘制加载遮罩后构建合法 loadout，重置局内场景与统计并进入运行态。
## 使用：map_id 为选中地图；协程需等待初始化帧，重复加载被拒绝，失败关闭遮罩。
func _start_run(map_id: Variant) -> void:
	if _run_loading_active:
		return
	var allow_direct_transition: bool = _allow_direct_running_transition
	var resolved_map_id: StringName = _run_scene_coordinator.call("resolve_map_id", map_id)
	var loading_map_data: Dictionary = GameData.get_map(resolved_map_id)
	var loading_map_name: String = String(loading_map_data.get("display_name", resolved_map_id)) if not loading_map_data.is_empty() else String(resolved_map_id)
	_show_run_loading_overlay(loading_map_name)
	await _wait_for_run_loading_overlay_painted()
	var loadout: RefCounted = CharacterLoadoutServiceScript.build_loadout(_selected_character_id)
	if loadout == null:
		_hide_run_loading_overlay(true)
		CharacterLoadoutServiceScript.warn_if_invalid(_selected_character_id, "[UIManager]")
		return
	var run_setup: Dictionary = _run_scene_coordinator.call("start_run", {
		"tree": get_tree(),
		"scene_parent": get_parent(),
		"map_id": map_id,
		"run_loadout": loadout,
		"choice_modal": _run_choice_modal_controller,
		"debug": bool(get_tree().root.get_meta("developer_mode_enabled", false)),
		"stat_event_callable": Callable(self, "_on_run_stat_event")
	})
	if run_setup.is_empty():
		_hide_run_loading_overlay(true)
		return
	_selected_map_id = StringName(run_setup.get("map_id", DEFAULT_MAP_ID))
	_selected_map_name = String(run_setup.get("map_name", _selected_map_id))
	_set_run_loading_status("场景初始化中")
	_run_stats_tracker = run_setup.get("run_stats_tracker", null) as Node
	_run_seconds = 0.0
	_kill_count = 0
	_run_start_souls = SaveManager.get_soul_stones()
	_run_souls_earned = 0
	_result_reward_claimed = false
	_result_progression_recorded = false
	_last_progression_summary.clear()
	if _result_controller != null:
		_result_controller.call("reset_for_new_run")
	_announcement_timer = 0.0
	_run_scene_ui_bridge.call("reset")
	_wave_index = 0
	_wave_id = ""
	_wave_remaining_seconds = 0.0
	_wave_duration_seconds = 55.0
	_wave_spawned_count = 0
	_wave_total_count = 0
	_ensure_run_hud_built()
	await get_tree().process_frame
	await get_tree().process_frame
	_enter_running_state_with_direct(allow_direct_transition)
	_hide_run_loading_overlay(false)
	if bool(get_tree().root.get_meta("developer_mode_enabled", false)):
		call_deferred("_open_developer_debug_panel")


## 作用：显示单局加载叠层。
## 使用：本文件由 _start_run 调用；输入 map_name（地图名称）。
func _show_run_loading_overlay(map_name: String) -> void:
	_ensure_run_loading_overlay()
	_run_loading_active = true
	_run_loading_elapsed = 0.0
	_run_loading_overlay.visible = true
	_run_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_run_loading_overlay.modulate = Color(1, 1, 1, 1)
	_set_run_loading_status("正在进入 %s" % map_name)
	if _run_loading_tween != null and _run_loading_tween.is_running():
		_run_loading_tween.kill()


## 作用：等待下一处理帧和可渲染模式的帧绘制完成。
## 使用：开局耗时初始化前 await，确保遮罩已经显示；headless 只等处理帧。
func _wait_for_run_loading_overlay_painted() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name().to_lower() == "headless":
		return
	await RenderingServer.frame_post_draw


## 作用：隐藏单局加载叠层。
## 使用：本文件由 _start_run 调用；输入 immediate（immediate）。
func _hide_run_loading_overlay(immediate: bool) -> void:
	if _run_loading_overlay == null:
		_run_loading_active = false
		return
	_run_loading_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _run_loading_tween != null and _run_loading_tween.is_running():
		_run_loading_tween.kill()
	if immediate:
		_run_loading_overlay.visible = false
		_run_loading_overlay.modulate = Color(1, 1, 1, 0)
		_run_loading_active = false
		return
	_run_loading_tween = create_tween()
	_run_loading_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_run_loading_tween.tween_property(_run_loading_overlay, "modulate:a", 0.0, 0.18)
	_run_loading_tween.tween_callback(Callable(self, "_finish_hide_run_loading_overlay"))


## 作用：完成隐藏单局加载叠层。
## 使用：本文件由 _hide_run_loading_overlay 调用。
func _finish_hide_run_loading_overlay() -> void:
	if _run_loading_overlay != null:
		_run_loading_overlay.visible = false
	_run_loading_active = false


## 作用：更新单局加载。
## 使用：本文件由 _process 调用；输入 delta（delta）。
func _update_run_loading(delta: float) -> void:
	_run_loading_elapsed += delta
	if _run_loading_dots_label == null:
		return
	var dot_count: int = int(floor(_run_loading_elapsed * 3.0)) % 4
	_run_loading_dots_label.text = ".".repeat(dot_count)


## 作用：设置单局加载状态效果。
## 使用：本文件由 _start_run、_show_run_loading_overlay 调用；输入 text（文本）。
func _set_run_loading_status(text: String) -> void:
	if _run_loading_status_label != null:
		_run_loading_status_label.text = text


## 作用：确保单局加载叠层。
## 使用：本文件由 _ready、_show_run_loading_overlay 调用。
func _ensure_run_loading_overlay() -> void:
	if _run_loading_overlay != null and is_instance_valid(_run_loading_overlay):
		return
	_run_loading_overlay = Control.new()
	_run_loading_overlay.name = "RunLoadingOverlay"
	_run_loading_overlay.visible = false
	_run_loading_overlay.z_index = 1000
	_run_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_run_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_run_loading_overlay)

	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.025, 0.027, 0.033, 0.98)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_run_loading_overlay.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_run_loading_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 220)
	panel.add_theme_stylebox_override("panel", _create_run_loading_panel_style())
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title: Label = Label.new()
	title.text = "战斗载入"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	content.add_child(title)

	var status_row: HBoxContainer = HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 0)
	content.add_child(status_row)

	_run_loading_status_label = Label.new()
	_run_loading_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_loading_status_label.add_theme_font_size_override("font_size", 18)
	_run_loading_status_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	status_row.add_child(_run_loading_status_label)

	_run_loading_dots_label = Label.new()
	_run_loading_dots_label.custom_minimum_size = Vector2(34, 0)
	_run_loading_dots_label.add_theme_font_size_override("font_size", 18)
	_run_loading_dots_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	status_row.add_child(_run_loading_dots_label)

	var hint: Label = Label.new()
	hint.text = "正在准备角色、地图和怪物波次"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 1.0))
	content.add_child(hint)


## 作用：创建单局加载面板样式并配置节点/样式所需的属性。
## 使用：本文件由 _ensure_run_loading_overlay 调用；返回 StyleBoxFlat 对象/值。
func _create_run_loading_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.095, 0.105, 0.125, 0.96)
	style.border_color = Color(0.34, 0.43, 0.60, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 18
	return style


## 作用：启动开发者模式。
## 使用：本文件由 transition_to 调用。
func _start_developer_mode() -> void:
	start_developer_debug_run({
		"character_id": &"mage",
		"map_id": DEFAULT_MAP_ID
	})


## 作用：打开开发者调试面板。
## 使用：本文件由 _start_run 调用。
func _open_developer_debug_panel() -> void:
	var panel: Node = get_tree().root.find_child("DevDebugPanel", true, false)
	if panel == null:
		var parent: Node = get_tree().current_scene
		if parent == null:
			parent = get_parent()
		panel = DevDebugPanelScript.new() as Node
		panel.name = "DevDebugPanel"
		parent.add_child(panel)
	if panel != null and panel.has_method("open_developer_mode"):
		panel.call("open_developer_mode")


## 作用：清除开发模式标记并释放单局场景、统计和信号桥接状态。
## 使用：离开运行场景时调用；由 RunSceneCoordinator 处理各运行对象的清理。
func _teardown_run_scene() -> void:
	if get_tree() != null and get_tree().root != null:
		get_tree().root.set_meta("developer_mode_enabled", false)
		get_tree().root.set_meta("debug_control_mode", false)
		get_tree().root.set_meta("debug_manual_spawn_only", false)
	_run_scene_coordinator.call("teardown", get_tree())
	_run_stats_tracker = null
	_run_scene_ui_bridge.call("reset")


## 作用：补接敌人信号、刷新统计快照并向 HUD controller 提供展示状态。
## 使用：运行态刷新计时器触发；附带 UI 热点性能采样。
func _update_run_hud() -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_run_scene_ui_bridge.call("connect_enemy_death_signals", get_tree(), self)
	_update_run_stats_snapshots()
	if _run_hud_controller != null:
		_run_hud_controller.call("update", get_tree(), _get_run_hud_state())
	HotPathProfilerScript.end(self, &"ui_update", hot_path_start)


## 作用：获取单局HUD状态，供当前模块后续逻辑使用。
## 使用：本文件由 _update_run_hud 调用；返回字典包含 tree/run_seconds/run_duration/wave_index/wave_id/wave_remaining_seconds/wave_duration_seconds/wave_spawned_count 等字段。
func _get_run_hud_state() -> Dictionary:
	var state_variant: Variant = _run_hud_state_provider.call("build", {
		"tree": get_tree(),
		"run_seconds": _run_seconds,
		"run_duration": _run_duration,
		"wave_index": _wave_index,
		"wave_id": _wave_id,
		"wave_remaining_seconds": _wave_remaining_seconds,
		"wave_duration_seconds": _wave_duration_seconds,
		"wave_spawned_count": _wave_spawned_count,
		"wave_total_count": _wave_total_count,
		"kill_count": _kill_count,
		"run_stats_tracker": _run_stats_tracker
	})
	if state_variant is Dictionary:
		var state: Dictionary = state_variant
		return state
	return {}

## 作用：响应敌人死亡并衔接对应的事件处理流程；具体处理委托给 _run_stats_tracker.record_enemy_killed。
## 使用：内部辅助入口；输入 _enemy（敌人）。
func _on_enemy_died(_enemy: Node) -> void:
	_kill_count += 1
	if _run_stats_tracker != null and _run_stats_tracker.has_method("record_enemy_killed"):
		_run_stats_tracker.call("record_enemy_killed", _enemy)


## 作用：设置HUD标签；具体处理委托给 _run_hud_controller.set_label。
## 使用：本文件由 _update_announcement_timer 调用；输入 key（键）、text（文本）。
func _set_hud_label(key: String, text: String) -> void:
	if _run_hud_controller != null:
		_run_hud_controller.call("set_label", key, text)


## 作用：显示公告；具体处理委托给 _run_hud_controller.show_announcement。
## 使用：本文件由 _on_timeline_event_started、_on_wave_changed、_on_wave_cleared 调用；输入 text（文本）、duration（持续时间）。
func _show_announcement(text: String, duration: float = 3.0) -> void:
	if _run_hud_controller != null:
		_run_hud_controller.call("show_announcement", text)
	_announcement_timer = duration


## 作用：连接运行时来源组；具体处理委托给 _run_scene_ui_bridge.connect_runtime_sources。
## 使用：内部辅助入口。
func _connect_runtime_sources() -> void:
	_run_scene_ui_bridge.call("connect_runtime_sources", get_tree(), self)


## 作用：响应局内时间变化并衔接对应的事件处理流程；具体处理委托给 _run_stats_tracker.set_run_time。
## 使用：内部辅助入口；输入 elapsed_time（elapsed时间）、duration（持续时间）。
func _on_run_time_changed(elapsed_time: float, duration: float) -> void:
	_run_seconds = elapsed_time
	_run_duration = duration
	if _run_stats_tracker != null and _run_stats_tracker.has_method("set_run_time"):
		_run_stats_tracker.call("set_run_time", elapsed_time)


## 作用：记录待处理等级并在运行态打开技能选择弹窗。
## 使用：玩家升级信号回调；非运行态先保留升级待办。
func _on_player_leveled_up(new_level: int) -> void:
	if _run_choice_modal_controller != null:
		_run_choice_modal_controller.call("add_pending_level", new_level)
	if current_state == STATE_RUNNING:
		transition_to(STATE_LEVEL_UP_MODAL)


## 作用：显示待处理升级按条件运行。
## 使用：内部辅助入口。
func _show_pending_level_up_if_running() -> void:
	_show_pending_modal_if_running()


## 作用：显示待处理奖励按条件运行。
## 使用：本文件由 _on_timeline_event_started 调用。
func _show_pending_reward_if_running() -> void:
	_show_pending_modal_if_running()


## 作用：仅在运行态查询下个奖励或升级弹窗并请求状态切换。
## 使用：通常由延迟回调调用，避免弹窗叠加和战斗事件中同步抢占界面。
func _show_pending_modal_if_running() -> void:
	if current_state != STATE_RUNNING:
		return
	var pending_state: String = String(_modal_flow_controller.call("get_pending_state", _run_choice_modal_controller))
	if pending_state != "":
		transition_to(pending_state)


## 作用：正式局首次收到玩家死亡时进入失败结算。
## 使用：信号回调；已进入任一终局或调试局时直接返回，避免覆盖已确定结果。
func _on_player_died() -> void:
	if current_state == STATE_RESULT_DEFEAT or current_state == STATE_RESULT_VICTORY:
		return
	if _is_current_run_debug():
		return

	transition_to(STATE_RESULT_DEFEAT)


## 作用：判断当前单局调试，返回布尔判断结果；具体处理委托给 _run_scene_coordinator.get_run_scene_parent。
## 使用：本文件由 _on_player_died 调用。
func _is_current_run_debug() -> bool:
	var run_scene: Node = _run_scene_coordinator.call("get_run_scene_parent", get_tree()) as Node
	return run_scene != null and bool(run_scene.get_meta("debug", false))


## 作用：响应玩家升级应用结果并衔接对应的事件处理流程；具体处理委托给 _run_stats_tracker.record_upgrade_applied。
## 使用：内部辅助入口；输入 upgrade_id（升级ID）。
func _on_player_upgrade_applied(upgrade_id: StringName) -> void:
	if _run_stats_tracker != null and _run_stats_tracker.has_method("record_upgrade_applied"):
		_run_stats_tracker.call("record_upgrade_applied", upgrade_id)


## 作用：响应单局属性事件并衔接对应的事件处理流程；具体处理委托给 relic_manager.handle_combat_event。
## 使用：本文件由 _start_run 调用；输入 event_name（事件名称）、payload（payload）。
func _on_run_stat_event(event_name: StringName, payload: Dictionary) -> void:
	var player: Node = get_tree().get_first_node_in_group(PLAYER_GROUP)
	var relic_manager: Node = player.get_node_or_null("RelicManager") if player != null else null
	if relic_manager != null and relic_manager.has_method("handle_combat_event"):
		relic_manager.call("handle_combat_event", event_name, payload)


## 作用：展示时间线公告并按精英或最终祝福事件排队奖励。
## 使用：最终祝福先收集全场经验；延迟打开待办弹窗以保持事件顺序。
func _on_timeline_event_started(_event_id: String, announcement: String) -> void:
	if announcement != "":
		_show_announcement(announcement, 4.0)
	if _run_choice_modal_controller != null:
		if _event_id.begins_with("elite:"):
			_run_choice_modal_controller.call("queue_reward", "elite")
			call_deferred("_show_pending_reward_if_running")
		elif _event_id.begins_with("final_blessing:"):
			_collect_all_experience_gems()
			_run_choice_modal_controller.call("queue_reward", "boss_blessing")
			call_deferred("_show_pending_reward_if_running")


## 作用：收集全部经验经验晶体。
## 使用：本文件由 _on_timeline_event_started 调用。
func _collect_all_experience_gems() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return
	for gem: Node in get_tree().get_nodes_in_group(&"experience_crystal"):
		if gem != null and gem.has_method("collect_to_player"):
			gem.call("collect_to_player", player)
	if _run_stats_tracker != null and _run_stats_tracker.has_method("record_map_event"):
		_run_stats_tracker.call("record_map_event", "pre_boss_full_screen_exp_magnet")


## 作用：响应波次变化并衔接对应的事件处理流程。
## 使用：内部辅助入口；输入 wave_id（波次ID）。
func _on_wave_changed(wave_id: String) -> void:
	if wave_id != "":
		_show_announcement("波次开始：%s" % wave_id, 2.0)


## 作用：响应波次计时器变化并衔接对应的事件处理流程。
## 使用：内部辅助入口；输入 wave_index（波次索引）、wave_id（波次ID）、remaining_time（剩余时间）、duration（持续时间）、spawned_count（已生成数量）、total_count（总量数量）。
func _on_wave_timer_changed(wave_index: int, wave_id: String, remaining_time: float, duration: float, spawned_count: int, total_count: int) -> void:
	_wave_index = wave_index
	_wave_id = wave_id
	_wave_remaining_seconds = remaining_time
	_wave_duration_seconds = duration
	_wave_spawned_count = spawned_count
	_wave_total_count = total_count


## 作用：响应波次通关并衔接对应的事件处理流程。
## 使用：内部辅助入口；输入 wave_id（波次ID）、cleared_early（通关early）。
func _on_wave_cleared(wave_id: String, cleared_early: bool) -> void:
	if wave_id == "":
		return
	if cleared_early:
		_show_announcement("本波敌人已清理", 2.0)
	else:
		_show_announcement("波次结束", 2.0)


## 作用：首次收到 Boss 击败信号时进入胜利结算。
## 使用：任一终局已锁定时忽略迟到信号；_elapsed_time 由信号传入但本函数不使用。
func _on_boss_defeated(_elapsed_time: float) -> void:
	if current_state == STATE_RESULT_DEFEAT or current_state == STATE_RESULT_VICTORY:
		return
	transition_to(STATE_RESULT_VICTORY)


## 作用：刷新结果页面；具体处理委托给 _result_controller.refresh。
## 使用：内部辅助入口；输入 state（状态）。
func _refresh_result_screen(state: String) -> void:
	_run_souls_earned = maxi(SaveManager.get_soul_stones() - _run_start_souls, 0)
	_record_result_progression_once(state)
	if _result_controller != null:
		_result_controller.call("refresh", state, _get_result_state())


## 作用：将当前局结果持久化一次并缓存成长摘要。
## 使用：结果页面刷新调用；重开局重置标志，重复刷新不会累计奖励或计数。
func _record_result_progression_once(state: String) -> void:
	if _result_progression_recorded:
		return
	_last_progression_summary = RunProgressionServiceScript.record_run_result(state, _get_result_state())
	_result_progression_recorded = true


## 作用：获取结果状态，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_result_screen、_record_result_progression_once 调用；返回字典包含 tree/player_group/selected_character_id/selected_map_id/selected_map_name/run_seconds/kill_count/run_souls_earned 等字段。
func _get_result_state() -> Dictionary:
	return RunResultStateBuilderScript.build_result_state({
		"tree": get_tree(),
		"player_group": PLAYER_GROUP,
		"selected_character_id": _selected_character_id,
		"selected_map_id": _selected_map_id,
		"selected_map_name": _selected_map_name,
		"run_seconds": _run_seconds,
		"kill_count": _kill_count,
		"run_souls_earned": _run_souls_earned,
		"run_stats_tracker": _run_stats_tracker,
		"progression_summary": _last_progression_summary
	})


## 作用：更新局内统计快照组。
## 使用：本文件由 _update_run_hud 调用。
func _update_run_stats_snapshots() -> void:
	if _run_stats_tracker == null:
		return
	var alive_normal: int = 0
	for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
		if String(enemy.get_meta("enemy_rank", "normal")) == "normal" and String(enemy.get_meta("spawn_source_type", "")) != "boss_minion":
			alive_normal += 1
		if String(enemy.get_meta("enemy_rank", "")) == "boss" and _run_stats_tracker.has_method("update_boss_snapshot"):
			_run_stats_tracker.call("update_boss_snapshot", enemy)
	if _run_stats_tracker.has_method("update_wave_pressure"):
		_run_stats_tracker.call("update_wave_pressure", alive_normal, _wave_total_count, 0.25)


## 作用：保存结算推荐角色和地图并进入地图选择页。
## 使用：推荐信号回调；只修改下一局选择，开局仍由 _start_run 完成。
func _apply_recommended_loadout(character_id: StringName, map_id: StringName) -> void:
	_selected_character_id = character_id
	_selected_map_id = map_id
	var map_data: Dictionary = GameData.get_map(_selected_map_id)
	_selected_map_name = String(map_data.get("display_name", _selected_map_id)) if not map_data.is_empty() else String(_selected_map_id)
	if _map_select_controller != null and _map_select_controller.has_method("set_selected_map"):
		_map_select_controller.call("set_selected_map", _selected_map_id)
	transition_to(STATE_MAP_SELECT)


## 作用：本地化。
## 使用：本文件由 _build_screen_for_state、_build_boot、_build_meta_upgrade 调用；输入 key（键）、fallback（回退）；返回 String 文本/标识。
func _tr(key: String, fallback: String) -> String:
	return LocalizationServiceScript.translate(key, {}, fallback)
