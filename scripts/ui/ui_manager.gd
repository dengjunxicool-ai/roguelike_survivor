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
const HotPathProfilerScript: Script = preload("res://scripts/debug/hot_path_profiler.gd")
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


func _process(delta: float) -> void:
	if _run_loading_active:
		_update_run_loading(delta)
	if current_state != STATE_RUNNING:
		return

	_update_announcement_timer(delta)
	_update_hud_refresh_timer(delta)


func _update_announcement_timer(delta: float) -> void:
	_announcement_timer = maxf(_announcement_timer - delta, 0.0)
	if _announcement_timer <= 0.0:
		_set_hud_label("announcement", "")


func _update_hud_refresh_timer(delta: float) -> void:
	_hud_refresh_cooldown = maxf(_hud_refresh_cooldown - delta, 0.0)
	if _hud_refresh_cooldown <= 0.0:
		_update_run_hud()
		_hud_refresh_cooldown = 0.25


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


func show_screen(next_state: String) -> void:
	transition_to(next_state)


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


func _quit_game() -> void:
	get_tree().quit()


func _apply_startup_window_mode() -> void:
	UISettingsServiceScript.apply_saved_settings()


func _finish_boot() -> void:
	if current_state == STATE_BOOT:
		transition_to(STATE_TITLE)
		_queue_responsive_layout_refresh()


func _can_transition(from_state: String, to_state: String) -> bool:
	return bool(_state_registry.call("can_transition", from_state, to_state))


func _prepare_state(state: String) -> void:
	_state_prepare_router.call("prepare", self, state, {
		"modal_flow_controller": _modal_flow_controller,
		"choice_modal": _run_choice_modal_controller
	})

func _apply_visible_hierarchy(state: String) -> void:
	_screen_host.call("apply_visible_hierarchy", state)
	_queue_responsive_layout_refresh()


func _apply_pause_for_state(state: String) -> void:
	_pause_policy.call("apply", get_tree(), _state_registry, state)


func _enter_running_state() -> void:
	_enter_running_state_with_direct(_allow_direct_running_transition)


func _enter_running_state_with_direct(allow_direct_transition: bool) -> void:
	if allow_direct_transition and not bool(_state_machine.call("can_transition", STATE_RUNNING)):
		_state_machine.call("force_transition_to", STATE_RUNNING)
		current_state = String(_state_machine.call("get_current_state"))
		_prepare_state(STATE_RUNNING)
		_apply_visible_hierarchy(STATE_RUNNING)
		_apply_pause_for_state(STATE_RUNNING)
		return
	transition_to(STATE_RUNNING)


func _is_running_child_state(state: String) -> bool:
	return bool(_state_registry.call("is_running_child_state", state))


func _is_fullscreen_choice_state(state: String) -> bool:
	return bool(_state_registry.call("is_fullscreen_choice_state", state))


func _set_screen_visible(state: String, should_show: bool) -> void:
	_screen_host.call("set_screen_visible", state, should_show)


func _build_screens() -> void:
	var build_order_variant: Variant = _state_registry.call("get_build_order")
	var build_order: Array = build_order_variant if build_order_variant is Array else []
	for state_variant: Variant in build_order:
		_build_screen_for_state(String(state_variant))
	_setup_run_choice_modals()


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


func _build_boot() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_BOOT, _tr("panel.boot", "BOOT"), Vector2(360, 220), 10)
	_add_label(body, _tr("panel.loading", "正在加载"), 1)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	body.add_child(bar)


func _build_title() -> void:
	_title_controller = TitleScreenControllerScript.new()
	_title_controller.state_requested.connect(Callable(self, "transition_to"))
	_title_controller.quit_requested.connect(Callable(self, "_quit_game"))
	var screen: Control = _title_controller.call("build") as Control
	add_child(screen)
	_screen_registry.call("register_screen", STATE_TITLE, screen)


func _build_character_select() -> void:
	_character_loadout_controller = CharacterLoadoutControllerScript.new()
	_character_loadout_controller.loadout_confirmed.connect(Callable(self, "_on_loadout_confirmed"))
	_character_loadout_controller.back_requested.connect(Callable(self, "transition_to").bind(STATE_TITLE))
	var screen: Control = _character_loadout_controller.call("build") as Control
	add_child(screen)
	_screen_registry.call("register_screen", STATE_CHARACTER_SELECT, screen)


func _build_map_select() -> void:
	_map_select_controller = MapSelectControllerScript.new()
	_map_select_controller.start_requested.connect(Callable(self, "_start_run"))
	_map_select_controller.back_requested.connect(Callable(self, "transition_to").bind(STATE_CHARACTER_SELECT))
	var screen: Control = _map_select_controller.call("build") as Control
	add_child(screen)
	_screen_registry.call("register_screen", STATE_MAP_SELECT, screen)




func _build_meta_upgrade() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_META_UPGRADE, _tr("panel.meta_upgrade", "局外升级"), Vector2(780, 620), 10)
	_meta_upgrade_controller = MetaUpgradeControllerScript.new()
	_meta_upgrade_controller.state_requested.connect(Callable(self, "transition_to"))
	_meta_upgrade_controller.call("build", body)


func _build_codex() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_CODEX, _tr("panel.codex", "Codex图鉴"), Vector2(700, 520), 10)
	_codex_controller = CodexScreenControllerScript.new()
	_codex_controller.state_requested.connect(Callable(self, "transition_to"))
	_codex_controller.call("build", body)


func _build_settings() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_SETTINGS, _tr("panel.settings", "设置"), Vector2(520, 420), 10)
	_settings_controller = SettingsScreenControllerScript.new()
	_settings_controller.state_requested.connect(Callable(self, "transition_to"))
	_settings_controller.call("build", body)


func _build_run_hud() -> void:
	if bool(_screen_registry.call("has_screen", STATE_RUNNING)):
		return

	_run_hud_controller = RunHudControllerScript.new()
	_run_hud_controller.pause_requested.connect(Callable(self, "transition_to").bind(STATE_PAUSE_MENU))
	var screen: CanvasLayer = _run_hud_controller.call("build", get_tree()) as CanvasLayer
	add_child(screen)
	_run_hud_controller.call("update_layout")
	_screen_registry.call("register_screen", STATE_RUNNING, screen)


func _ensure_run_hud_built() -> void:
	if not bool(_screen_registry.call("has_screen", STATE_RUNNING)):
		_build_run_hud()



func _build_level_up_modal() -> void:
	_level_up_options = _create_choice_modal_screen(STATE_LEVEL_UP_MODAL, _tr("panel.level_up", "技能选择"), 20)


func _build_run_reward_modal() -> void:
	_reward_options = _create_choice_modal_screen(STATE_RUN_REWARD_MODAL, _tr("panel.reward", "战利品选择"), 20)


func _build_curse_choice_modal() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_CURSE_CHOICE_MODAL, _tr("panel.curse", "诅咒选择"), Vector2(720, 460), 20)
	_add_label(body, _tr("panel.curse_hint", "选择一项高风险高收益强化"), 1)
	_curse_options = _add_vbox(body)
	_add_state_button(body, _tr("panel.skip", "跳过"), STATE_RUNNING)


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


func _build_pause_menu() -> void:
	var body: VBoxContainer = _create_panel_screen(STATE_PAUSE_MENU, _tr("panel.pause", "暂停游戏"), Vector2(420, 360), 30)
	_add_state_button(body, _tr("panel.resume", "继续游戏"), STATE_RUNNING)
	_add_state_button(body, _tr("panel.give_up", "放弃战斗"), STATE_RESULT_DEFEAT)
	_add_state_button(body, _tr("panel.back_to_title", "返回主菜单"), STATE_TITLE)


func _build_result_screen(state: String, title: String) -> void:
	var body: VBoxContainer = _create_panel_screen(state, title, Vector2(560, 460), 30)
	if _result_controller == null:
		_result_controller = ResultScreenControllerScript.new()
		_result_controller.state_requested.connect(Callable(self, "transition_to"))
		_result_controller.recommended_loadout_requested.connect(Callable(self, "_apply_recommended_loadout"))
	_result_controller.call("build", body, state)


func _get_screen_dictionary() -> Dictionary:
	var screens_variant: Variant = _screen_registry.call("get_screens")
	if screens_variant is Dictionary:
		return screens_variant
	return {}


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


func _update_responsive_layouts() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_responsive_layout.call("update", viewport_size)
	_update_title_layout()
	_update_character_select_layout()
	_update_map_select_layout()
	if _run_hud_controller != null and _run_hud_controller.has_method("update_layout"):
		_run_hud_controller.call("update_layout")


func _queue_responsive_layout_refresh() -> void:
	call_deferred("_update_responsive_layouts")
	call_deferred("_update_responsive_layouts_next_frame")


func _update_responsive_layouts_next_frame() -> void:
	await get_tree().process_frame
	_update_responsive_layouts()


func _update_map_select_layout() -> void:
	if _map_select_controller != null:
		_map_select_controller.call("update_layout", get_viewport().get_visible_rect().size)



func _add_label(parent: Node, text: String, alignment: int = 0, node_name: String = "") -> Label:
	return UINodeFactoryScript.add_label(parent, text, alignment, node_name)


func _add_button(parent: Node, text: String) -> Button:
	return UINodeFactoryScript.add_button(parent, text)


func _add_state_button(parent: Node, text: String, state: String) -> Button:
	var button: Button = _add_button(parent, text)
	button.pressed.connect(Callable(self, "transition_to").bind(state))
	return button


func _add_scroll(parent: Node) -> ScrollContainer:
	return UINodeFactoryScript.add_scroll(parent)


func _add_vbox(parent: Node) -> VBoxContainer:
	return UINodeFactoryScript.add_vbox(parent)


func _add_hbox(parent: Node) -> HBoxContainer:
	return UINodeFactoryScript.add_hbox(parent)


func _add_labeled_progress(parent: Node, label_text: String, value: float, max_value: float) -> ProgressBar:
	return UINodeFactoryScript.add_labeled_progress(parent, label_text, value, max_value)


func _update_title_layout() -> void:
	if _title_controller != null:
		_title_controller.call("update_layout", get_viewport().get_visible_rect().size)


func _reset_title_screen() -> void:
	if _title_controller != null:
		_title_controller.call("reset")


func _refresh_character_select_screen() -> void:
	if _character_loadout_controller != null:
		_character_loadout_controller.call("refresh", _selected_character_id)


func _update_character_select_layout() -> void:
	if _character_loadout_controller != null:
		_character_loadout_controller.call("update_layout", get_viewport().get_visible_rect().size)


func _get_skill_display_name(skill_id: StringName) -> String:
	var skill: Dictionary = GameData.get_skill(skill_id)
	return String(skill.get("display_name", skill_id))


func _refresh_map_select_screen() -> void:
	if _map_select_controller != null:
		_map_select_controller.call("refresh", _selected_character_id)


func _refresh_meta_upgrade_screen() -> void:
	if _meta_upgrade_controller != null:
		_meta_upgrade_controller.call("refresh")




func _on_loadout_confirmed(character_id: StringName) -> void:
	_selected_character_id = character_id
	transition_to(STATE_MAP_SELECT)


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


func _wait_for_run_loading_overlay_painted() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name().to_lower() == "headless":
		return
	await RenderingServer.frame_post_draw


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


func _finish_hide_run_loading_overlay() -> void:
	if _run_loading_overlay != null:
		_run_loading_overlay.visible = false
	_run_loading_active = false


func _update_run_loading(delta: float) -> void:
	_run_loading_elapsed += delta
	if _run_loading_dots_label == null:
		return
	var dot_count: int = int(floor(_run_loading_elapsed * 3.0)) % 4
	_run_loading_dots_label.text = ".".repeat(dot_count)


func _set_run_loading_status(text: String) -> void:
	if _run_loading_status_label != null:
		_run_loading_status_label.text = text


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


func _create_run_loading_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.095, 0.105, 0.125, 0.96)
	style.border_color = Color(0.34, 0.43, 0.60, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 18
	return style


func _start_developer_mode() -> void:
	start_developer_debug_run({
		"character_id": &"mage",
		"map_id": DEFAULT_MAP_ID
	})


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


func _teardown_run_scene() -> void:
	if get_tree() != null and get_tree().root != null:
		get_tree().root.set_meta("developer_mode_enabled", false)
		get_tree().root.set_meta("debug_control_mode", false)
		get_tree().root.set_meta("debug_manual_spawn_only", false)
	_run_scene_coordinator.call("teardown", get_tree())
	_run_stats_tracker = null
	_run_scene_ui_bridge.call("reset")


func _update_run_hud() -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_run_scene_ui_bridge.call("connect_enemy_death_signals", get_tree(), self)
	_update_run_stats_snapshots()
	if _run_hud_controller != null:
		_run_hud_controller.call("update", get_tree(), _get_run_hud_state())
	HotPathProfilerScript.end(self, &"ui_update", hot_path_start)


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

func _on_enemy_died(_enemy: Node) -> void:
	_kill_count += 1
	if _run_stats_tracker != null and _run_stats_tracker.has_method("record_enemy_killed"):
		_run_stats_tracker.call("record_enemy_killed", _enemy)


func _set_hud_label(key: String, text: String) -> void:
	if _run_hud_controller != null:
		_run_hud_controller.call("set_label", key, text)


func _show_announcement(text: String, duration: float = 3.0) -> void:
	if _run_hud_controller != null:
		_run_hud_controller.call("show_announcement", text)
	_announcement_timer = duration


func _connect_runtime_sources() -> void:
	_run_scene_ui_bridge.call("connect_runtime_sources", get_tree(), self)


func _on_run_time_changed(elapsed_time: float, duration: float) -> void:
	_run_seconds = elapsed_time
	_run_duration = duration
	if _run_stats_tracker != null and _run_stats_tracker.has_method("set_run_time"):
		_run_stats_tracker.call("set_run_time", elapsed_time)


func _on_player_leveled_up(new_level: int) -> void:
	if _run_choice_modal_controller != null:
		_run_choice_modal_controller.call("add_pending_level", new_level)
	if current_state == STATE_RUNNING:
		transition_to(STATE_LEVEL_UP_MODAL)


func _show_pending_level_up_if_running() -> void:
	_show_pending_modal_if_running()


func _show_pending_reward_if_running() -> void:
	_show_pending_modal_if_running()


func _show_pending_modal_if_running() -> void:
	if current_state != STATE_RUNNING:
		return
	var pending_state: String = String(_modal_flow_controller.call("get_pending_state", _run_choice_modal_controller))
	if pending_state != "":
		transition_to(pending_state)


func _on_player_died() -> void:
	if current_state == STATE_RESULT_DEFEAT or current_state == STATE_RESULT_VICTORY:
		return
	if _is_current_run_debug():
		return

	transition_to(STATE_RESULT_DEFEAT)


func _is_current_run_debug() -> bool:
	var run_scene: Node = _run_scene_coordinator.call("get_run_scene_parent", get_tree()) as Node
	return run_scene != null and bool(run_scene.get_meta("debug", false))


func _on_player_upgrade_applied(upgrade_id: StringName) -> void:
	if _run_stats_tracker != null and _run_stats_tracker.has_method("record_upgrade_applied"):
		_run_stats_tracker.call("record_upgrade_applied", upgrade_id)


func _on_run_stat_event(event_name: StringName, payload: Dictionary) -> void:
	var player: Node = get_tree().get_first_node_in_group(PLAYER_GROUP)
	var relic_manager: Node = player.get_node_or_null("RelicManager") if player != null else null
	if relic_manager != null and relic_manager.has_method("handle_combat_event"):
		relic_manager.call("handle_combat_event", event_name, payload)


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


func _collect_all_experience_gems() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return
	for gem: Node in get_tree().get_nodes_in_group(&"experience_crystal"):
		if gem != null and gem.has_method("collect_to_player"):
			gem.call("collect_to_player", player)
	if _run_stats_tracker != null and _run_stats_tracker.has_method("record_map_event"):
		_run_stats_tracker.call("record_map_event", "pre_boss_full_screen_exp_magnet")


func _on_wave_changed(wave_id: String) -> void:
	if wave_id != "":
		_show_announcement("波次开始：%s" % wave_id, 2.0)


func _on_wave_timer_changed(wave_index: int, wave_id: String, remaining_time: float, duration: float, spawned_count: int, total_count: int) -> void:
	_wave_index = wave_index
	_wave_id = wave_id
	_wave_remaining_seconds = remaining_time
	_wave_duration_seconds = duration
	_wave_spawned_count = spawned_count
	_wave_total_count = total_count


func _on_wave_cleared(wave_id: String, cleared_early: bool) -> void:
	if wave_id == "":
		return
	if cleared_early:
		_show_announcement("本波敌人已清理", 2.0)
	else:
		_show_announcement("波次结束", 2.0)


func _on_boss_defeated(_elapsed_time: float) -> void:
	transition_to(STATE_RESULT_VICTORY)


func _refresh_result_screen(state: String) -> void:
	_run_souls_earned = maxi(SaveManager.get_soul_stones() - _run_start_souls, 0)
	_record_result_progression_once(state)
	if _result_controller != null:
		_result_controller.call("refresh", state, _get_result_state())


func _record_result_progression_once(state: String) -> void:
	if _result_progression_recorded:
		return
	_last_progression_summary = RunProgressionServiceScript.record_run_result(state, _get_result_state())
	_result_progression_recorded = true


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


func _update_run_stats_snapshots() -> void:
	if _run_stats_tracker == null:
		return
	var alive_normal: int = 0
	for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
		if String(enemy.get_meta("enemy_type", "normal")) == "normal":
			alive_normal += 1
		if String(enemy.get_meta("enemy_type", "")) == "boss" and _run_stats_tracker.has_method("update_boss_snapshot"):
			_run_stats_tracker.call("update_boss_snapshot", enemy)
	if _run_stats_tracker.has_method("update_wave_pressure"):
		_run_stats_tracker.call("update_wave_pressure", alive_normal, _wave_total_count, 0.25)


func _apply_recommended_loadout(character_id: StringName, map_id: StringName) -> void:
	_selected_character_id = character_id
	_selected_map_id = map_id
	var map_data: Dictionary = GameData.get_map(_selected_map_id)
	_selected_map_name = String(map_data.get("display_name", _selected_map_id)) if not map_data.is_empty() else String(_selected_map_id)
	if _map_select_controller != null and _map_select_controller.has_method("set_selected_map"):
		_map_select_controller.call("set_selected_map", _selected_map_id)
	transition_to(STATE_MAP_SELECT)


func _tr(key: String, fallback: String) -> String:
	return LocalizationServiceScript.translate(key, {}, fallback)
