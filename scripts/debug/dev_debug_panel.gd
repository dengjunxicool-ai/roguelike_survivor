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


func open_developer_mode() -> void:
	_populate_options()
	_sync_options_from_runtime()
	_set_debug_manual_spawn_only(true)
	_set_left_toolbar_visible(true)
	_set_debug_control_mode(true)
	_refresh_state()
	_log("Developer mode opened.")


func _process(delta: float) -> void:
	if not _is_left_toolbar_visible():
		return
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = update_interval
	_refresh_state()


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


func _build_run_setup_page(page_root: VBoxContainer) -> void:
	_run_setup_controller._build_run_setup_page(page_root)


func _build_runtime_page(page_root: VBoxContainer) -> void:
	_runtime_controller._build_runtime_page(page_root)


func _build_skill_cards_page(page_root: VBoxContainer) -> void:
	_skill_cards_controller._build_skill_cards_page(page_root)


func _build_enemy_spawn_page(page_root: VBoxContainer) -> void:
	_enemy_spawn_controller._build_enemy_spawn_page(page_root)


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


func _build_status_page(page_root: VBoxContainer) -> void:
	_status_controller._build_status_page(page_root)


func _build_utility_page(page_root: VBoxContainer) -> void:
	_utility_controller._build_utility_page(page_root)


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


func _populate_character_options() -> void:
	_run_setup_controller._populate_character_options()


func _populate_map_options() -> void:
	_run_setup_controller._populate_map_options()


func _populate_enemy_options() -> void:
	_enemy_spawn_controller._populate_enemy_options()


func _get_enemy_option_group(enemy: Dictionary) -> String:
	return _enemy_spawn_controller._get_enemy_option_group(enemy)


func _add_enemy_group_options(group_label: String, enemies: Array[Dictionary]) -> void:
	_enemy_spawn_controller._add_enemy_group_options(group_label, enemies)


func _populate_enemy_state_options() -> void:
	_enemy_spawn_controller._populate_enemy_state_options()


func _populate_effect_options() -> void:
	if _effects_page != null:
		_effects_page.call("populate_options")


func _populate_god_skill_buttons() -> void:
	_skill_cards_controller._populate_god_skill_buttons()


func _refresh_god_skill_cards() -> void:
	_skill_cards_controller._refresh_god_skill_cards()


func _refresh_god_skill_section() -> void:
	_skill_cards_controller._refresh_god_skill_section()


func _select_god_skill_cards(god_id: StringName) -> void:
	_skill_cards_controller._select_god_skill_cards(god_id)


func _update_god_skill_button_states() -> void:
	_skill_cards_controller._update_god_skill_button_states()


func _sync_selected_god_skill_id() -> void:
	_skill_cards_controller._sync_selected_god_skill_id()


func _get_god_definitions() -> Array[Dictionary]:
	return DevDebugDataSourceScript.get_god_definitions()


func _get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	return DevDebugDataSourceScript.get_god_skill_definitions(god_id)


func _populate_fire_skill_options() -> void:
	_skill_cards_controller._populate_fire_skill_options()


func _build_debug_fire_skill_options(god_id: StringName = &"fire") -> Array[Dictionary]:
	return _skill_cards_controller._build_debug_fire_skill_options(god_id)


func _build_debug_god_skill_options(god_id: StringName) -> Array[Dictionary]:
	return _skill_cards_controller._build_debug_god_skill_options(god_id)


func _populate_status_options() -> void:
	_status_controller._populate_status_options()


func _is_status_option_available(status_id: Variant) -> bool:
	return _status_controller._is_status_option_available(status_id)


func _get_status_definition_for_option(status_id: Variant) -> Dictionary:
	return _status_controller._get_status_definition_for_option(status_id)


func _build_player_stats(parent: VBoxContainer) -> void:
	_runtime_controller._build_player_stats(parent)


func _build_skill_stats(parent: VBoxContainer) -> void:
	_runtime_controller._build_skill_stats(parent)


func _sync_player_stat_controls() -> void:
	_runtime_controller._sync_player_stat_controls()


func _sync_skill_stat_controls() -> void:
	_runtime_controller._sync_skill_stat_controls()


func _apply_player_stats_from_panel() -> void:
	_runtime_controller._apply_player_stats_from_panel()


func _apply_skill_stats_from_panel() -> void:
	_runtime_controller._apply_skill_stats_from_panel()


func _get_player_stat_configs() -> Array[Dictionary]:
	return _runtime_controller._get_player_stat_configs()


func _get_skill_stat_configs() -> Array[Dictionary]:
	return _runtime_controller._get_skill_stat_configs()


func _on_character_selected(_index: int) -> void:
	_run_setup_controller._on_character_selected(_index)


func _on_setup_option_selected(_index: int) -> void:
	_run_setup_controller._on_setup_option_selected(_index)


func _sync_options_from_runtime() -> void:
	_run_setup_controller._sync_options_from_runtime()


func _restart_debug_run() -> void:
	_run_setup_controller._restart_debug_run()


func _toggle_tree_pause() -> void:
	_runtime_controller._toggle_tree_pause()


func _toggle_auto_combat() -> void:
	_runtime_controller._toggle_auto_combat()


func _toggle_player_attack_disabled() -> void:
	_runtime_controller._toggle_player_attack_disabled()


func _apply_enemy_state_override() -> void:
	_enemy_spawn_controller._apply_enemy_state_override()


func _clear_enemy_state_override() -> void:
	_enemy_spawn_controller._clear_enemy_state_override()


func _spawn_configured_enemies() -> void:
	_enemy_spawn_controller._spawn_configured_enemies()


func _spawn_fire_tornado_effect() -> void:
	if _effects_page != null:
		_effects_page.call("spawn_fire_tornado_effect")


func _start_continuous_effect_fire() -> void:
	if _effects_page != null:
		_effects_page.call("start_continuous_effect")


func _fire_single_effect() -> void:
	if _effects_page != null:
		_effects_page.call("fire_single_effect")


func _trigger_selected_effect(continuous: bool) -> void:
	if _effects_page != null:
		_effects_page.call("trigger_selected_effect", continuous)


func _spawn_mars_spark_missile_effect(continuous: bool) -> void:
	if _effects_page != null:
		_effects_page.call("spawn_mars_spark_missile_effect", continuous)


func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_fire_tornado_spawn_position", player)
	return result if result is Vector2 else Vector2.ZERO


func _resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_mars_spark_missile_spawn_position", player)
	return result if result is Vector2 else Vector2.ZERO


func _resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_mars_spark_missile_target_position", player, origin)
	return result if result is Vector2 else Vector2.ZERO


func _spawn_all_enemy_types() -> void:
	_enemy_spawn_controller._spawn_all_enemy_types()


func _spawn_debug_enemy(enemy_id: StringName, position: Vector2, spawn_parent: Node, apply_panel_stats: bool) -> Node2D:
	return _enemy_spawn_controller._spawn_debug_enemy(enemy_id, position, spawn_parent, apply_panel_stats)


func _spawn_enemies(count: int) -> void:
	_enemy_spawn_controller._spawn_enemies(count)


func _set_nearest_enemy_stats() -> void:
	_enemy_spawn_controller._set_nearest_enemy_stats()


func _apply_enemy_panel_stats(enemy: Node) -> void:
	_enemy_spawn_controller._apply_enemy_panel_stats(enemy)


func _apply_status_from_panel() -> void:
	_status_controller._apply_status_from_panel()


func _get_status_targets() -> Array[Node]:
	return _status_controller._get_status_targets()


func _clear_statuses() -> void:
	_status_controller._clear_statuses()


func _clear_enemies() -> void:
	_enemy_spawn_controller._clear_enemies()


func _clear_player_skills() -> void:
	_skill_cards_controller._clear_player_skills()


func _manual_cast_player_skills() -> void:
	_runtime_controller._manual_cast_player_skills()


func _attack_once_player_skills() -> void:
	_runtime_controller._attack_once_player_skills()


func _clear_attack_trace() -> void:
	_runtime_controller._clear_attack_trace()


func _show_previous_attack_damage_card() -> void:
	_runtime_controller._show_previous_attack_damage_card()


func _show_next_attack_damage_card() -> void:
	_runtime_controller._show_next_attack_damage_card()


func _copy_current_attack_damage_record() -> bool:
	return _runtime_controller._copy_current_attack_damage_record()


func _cast_player_skills_once(trace_id: int = 0) -> int:
	return _runtime_controller._cast_player_skills_once(trace_id)


func _level_starting_skill_to(target_level: int) -> void:
	_run_setup_controller._level_starting_skill_to(target_level)


func _toggle_range_overlay() -> void:
	_utility_controller._toggle_range_overlay()


func _set_all_range_overlays_visible(should_show: bool) -> void:
	_utility_controller._set_all_range_overlays_visible(should_show)


func _sync_enemy_attack_range_overlays(should_show: bool) -> void:
	_utility_controller._sync_enemy_attack_range_overlays(should_show)


func _ensure_enemy_attack_range_overlay(enemy: Node2D) -> CanvasItem:
	return _utility_controller._ensure_enemy_attack_range_overlay(enemy)


func _prune_enemy_attack_range_overlays() -> void:
	_utility_controller._prune_enemy_attack_range_overlays()


func _get_valid_enemy_range_overlay(key: int) -> CanvasItem:
	return _utility_controller._get_valid_enemy_range_overlay(key)


func _are_range_overlays_visible() -> bool:
	return _utility_controller._are_range_overlays_visible()


func _set_range_overlays_visible(visible: bool) -> void:
	_utility_controller._set_range_overlays_visible(visible)


func _print_state() -> void:
	_utility_controller._print_state()


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


func _add_god_skill_card(parent: VBoxContainer, skill: Dictionary, skill_index: int) -> void:
	_skill_cards_controller._add_god_skill_card(parent, skill, skill_index)


func _format_god_skill_card_text(skill: Dictionary) -> String:
	return _skill_cards_controller._format_god_skill_card_text(skill)


func _get_god_skill_effect_description(skill: Dictionary) -> String:
	return _skill_cards_controller._get_god_skill_effect_description(skill)


func _on_god_skill_card_pressed(skill_id: StringName) -> void:
	await _skill_cards_controller._on_god_skill_card_pressed(skill_id)


func _select_god_skill_card(skill_id: StringName) -> void:
	_skill_cards_controller._select_god_skill_card(skill_id)


func debug_select_god_skill_cards(god_id: StringName) -> Dictionary:
	return _skill_cards_controller.debug_select_god_skill_cards(god_id)


func _build_god_skill_button_summary(selected_god_id: StringName) -> Dictionary:
	return _skill_cards_controller._build_god_skill_button_summary(selected_god_id)


func debug_run_god_skill_chain(skill_id: StringName) -> Dictionary:
	return await _skill_cards_controller.debug_run_god_skill_chain(skill_id)


func _run_god_skill_card(skill_id: StringName) -> Dictionary:
	return await _skill_cards_controller._run_god_skill_card(skill_id)


func _mark_god_skill_chain_no_target(result: Dictionary) -> void:
	_skill_cards_controller._mark_god_skill_chain_no_target(result)


func _apply_god_skill_cast_result(result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary) -> void:
	_skill_cards_controller._apply_god_skill_cast_result(result, cast_result, selected_skill_id, option)


func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	return await _skill_cards_controller.debug_run_fire_skill_chain(skill_id)


func _run_selected_fire_skill_chain() -> void:
	await _skill_cards_controller._run_selected_fire_skill_chain()


func _grant_selected_fire_skill() -> void:
	_skill_cards_controller._grant_selected_fire_skill()


func _cast_selected_fire_skill() -> void:
	await _skill_cards_controller._cast_selected_fire_skill()


func _spawn_fire_skill_debug_target() -> Node2D:
	return _skill_cards_controller._spawn_fire_skill_debug_target()


func _grant_fire_skill_option(option: Dictionary) -> bool:
	return _skill_cards_controller._grant_fire_skill_option(option)


func _cast_fire_skill_once(skill_id: StringName, max_damage_wait_frames: int = 120) -> Dictionary:
	return await _skill_cards_controller._cast_fire_skill_once(skill_id, max_damage_wait_frames)


func _cast_player_skill_once(skill_id: StringName, trace_id: int = 0) -> int:
	return _skill_cards_controller._cast_player_skill_once(skill_id, trace_id)


func _wait_for_fire_skill_damage_record(skill_id: StringName, trace_id: int, max_physics_frames: int) -> void:
	await _skill_cards_controller._wait_for_fire_skill_damage_record(skill_id, trace_id, max_physics_frames)


func _prepare_fire_skill_debug_target(target: Node2D) -> void:
	_skill_cards_controller._prepare_fire_skill_debug_target(target)


func _build_fire_skill_chain_result(skill_id: StringName) -> Dictionary:
	return _skill_cards_controller._build_fire_skill_chain_result(skill_id)


func _get_selected_fire_skill_option() -> Dictionary:
	return _skill_cards_controller._get_selected_fire_skill_option()


func _get_fire_skill_option(skill_id: StringName) -> Dictionary:
	return _skill_cards_controller._get_fire_skill_option(skill_id)


func _get_god_skill_option(skill_id: StringName) -> Dictionary:
	return _skill_cards_controller._get_god_skill_option(skill_id)


func _get_option_learn_skill_id(option: Dictionary) -> StringName:
	return _skill_cards_controller._get_option_learn_skill_id(option)


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


func _count_particle_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1 if node is GPUParticles2D else 0
	for child: Node in node.get_children():
		count += _count_particle_nodes(child)
	return count


func _count_damage_popup_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 0
	if node is Label and String(node.name).find("DamageNumber") >= 0:
		count += 1
	for child: Node in node.get_children():
		count += _count_damage_popup_nodes(child)
	return count


func _wait_debug_frames(count: int, physics: bool) -> void:
	for _frame_index: int in range(maxi(count, 0)):
		if physics:
			await get_tree().physics_frame
		else:
			await get_tree().process_frame


func _update_fire_skill_chain_log(result: Dictionary) -> void:
	_skill_cards_controller._update_fire_skill_chain_log(result)


func _is_fire_skill_chain_result_healthy(result: Dictionary) -> bool:
	return _skill_cards_controller._is_fire_skill_chain_result_healthy(result)


func _refresh_attack_damage_text() -> void:
	_runtime_controller._refresh_attack_damage_text()


func _reset_attack_damage_scroll() -> void:
	_runtime_controller._reset_attack_damage_scroll()


func _get_attack_damage_record_count() -> int:
	return _runtime_controller._get_attack_damage_record_count()


func _get_current_attack_damage_record_text() -> String:
	return _runtime_controller._get_current_attack_damage_record_text()


func _get_attack_damage_records() -> Array[Dictionary]:
	return _runtime_controller._get_attack_damage_records()


func _build_attack_damage_text() -> String:
	return _runtime_controller._build_attack_damage_text()


func _count_explosion_records(records: Array) -> int:
	return _runtime_controller._count_explosion_records(records)


func _group_damage_records_by_target(records: Array[Dictionary]) -> Dictionary:
	return _runtime_controller._group_damage_records_by_target(records)


func _build_damage_component_summary(records: Array, includes_explosion: bool = false) -> String:
	return _runtime_controller._build_damage_component_summary(records, includes_explosion)


func _damage_component_label(record: Dictionary) -> String:
	return _runtime_controller._damage_component_label(record)


func _legacy_skill_damage_component_label(source_skill_id: String) -> String:
	return _runtime_controller._legacy_skill_damage_component_label(source_skill_id)


func _format_record_dump(record: Dictionary) -> String:
	return _runtime_controller._format_record_dump(record)


func _append_dictionary_dump(lines: Array[String], dictionary: Dictionary, indent_level: int) -> void:
	_runtime_controller._append_dictionary_dump(lines, dictionary, indent_level)


func _append_array_dump(lines: Array[String], items: Array, indent_level: int) -> void:
	_runtime_controller._append_array_dump(lines, items, indent_level)


func _append_record_value_line(lines: Array[String], key: String, value: Variant, indent_level: int) -> void:
	_runtime_controller._append_record_value_line(lines, key, value, indent_level)


func _record_indent(indent_level: int) -> String:
	return _runtime_controller._record_indent(indent_level)


func _format_record_value(value: Variant) -> String:
	return _runtime_controller._format_record_value(value)


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


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		child.queue_free()


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)


func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(_string_or(item, ""))
	return result


func _build_player_attributes_text() -> String:
	return _runtime_controller._build_player_attributes_text()


func _build_player_core_attribute_lines(player: Node) -> Array[String]:
	return _runtime_controller._build_player_core_attribute_lines(player)


func _build_starting_skill_attribute_lines(player: Node) -> Array[String]:
	return _runtime_controller._build_starting_skill_attribute_lines(player)


func _build_trait_attribute_lines(player: Node) -> Array[String]:
	return _runtime_controller._build_trait_attribute_lines(player)


func _build_state_text() -> String:
	return _runtime_controller._build_state_text()


func _build_nearest_enemy_fields() -> Array[String]:
	return _runtime_controller._build_nearest_enemy_fields()


func _build_selected_setup_fields(current_character_id: StringName) -> Array[String]:
	return _runtime_controller._build_selected_setup_fields(current_character_id)


func _build_skill_fields(player: Node, skill: RefCounted) -> Array[String]:
	return _runtime_controller._build_skill_fields(player, skill)


func _get_player_effective_move_speed(player: Node) -> float:
	return _runtime_controller._get_player_effective_move_speed(player)


func _get_player_effective_pickup_radius(player: Node) -> float:
	return _runtime_controller._get_player_effective_pickup_radius(player)


func _format_summary_fields(fields: Array[String]) -> String:
	return _runtime_controller._format_summary_fields(fields)


func _format_statuses(statuses: Array) -> String:
	return _runtime_controller._format_statuses(statuses)


func _debug_status_short_name(status_id: String) -> String:
	return _runtime_controller._debug_status_short_name(status_id)


func _get_status_snapshot(target: Node) -> Array:
	return _runtime_controller._get_status_snapshot(target)


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


func _get_enemy_attack_range(enemy: Node) -> float:
	if enemy == null:
		return 0.0
	var value: Variant = enemy.get("attack_range")
	return 0.0 if value == null else float(value)


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


func _get_starting_skill(player: Node) -> RefCounted:
	var skill_manager: Node = _get_skill_manager(player)
	var skill_id: StringName = _get_starting_skill_id(player)
	if skill_manager == null or skill_id == &"":
		return null
	return skill_manager.call("get_skill", skill_id) as RefCounted


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


func _get_player() -> Node:
	return get_tree().get_first_node_in_group(&"player")


func _get_skill_manager(player: Node) -> Node:
	return player.get_node_or_null("SkillManager") if player != null else null


func _get_ui_manager() -> Node:
	var ui_manager: Node = get_tree().get_first_node_in_group(&"ui_manager")
	if ui_manager != null:
		return ui_manager
	return get_tree().root.find_child("UIManager", true, false)


func _set_debug_visible(should_show: bool) -> void:
	_set_left_toolbar_visible(should_show)


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


func _is_left_toolbar_visible() -> bool:
	return visible and _panel != null and _panel.visible


func _set_debug_control_mode(enabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_control_mode", enabled)
	if enabled:
		tree.root.set_meta("debug_player_attack_nonce", int(tree.root.get_meta("debug_player_attack_nonce", 0)))


func _set_debug_manual_spawn_only(enabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_manual_spawn_only", enabled)


func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


func _set_player_attack_disabled(disabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_player_attack_disabled", disabled)


func _is_player_attack_disabled() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_player_attack_disabled", false))


func _set_enemy_state_override(state: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var normalized_state: String = _normalize_enemy_forced_state(state)
	tree.root.set_meta("debug_enemy_forced_state", normalized_state if _is_valid_enemy_forced_state(normalized_state) else "")


func _get_enemy_state_override() -> String:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return ""
	var state: String = _normalize_enemy_forced_state(String(tree.root.get_meta("debug_enemy_forced_state", "")))
	return state if _is_valid_enemy_forced_state(state) else ""


func _format_enemy_state_override() -> String:
	var state: String = _get_enemy_state_override()
	return "auto" if state == "" else state


func _is_valid_enemy_forced_state(state: String) -> bool:
	return state == "idle" or state == "chase" or state == "attack" or state == "hurt" or state == "dead"


func _normalize_enemy_forced_state(state: String) -> String:
	return "dead" if state == "death" else state


func _is_elite_only_enemy_state(state: String) -> bool:
	return state == "hurt" or state == "dead"


func _refresh_enemy_state_option_availability() -> void:
	_enemy_spawn_controller._refresh_enemy_state_option_availability()


func _can_apply_elite_enemy_state_to_nearest() -> bool:
	return _enemy_spawn_controller._can_apply_elite_enemy_state_to_nearest()


func _is_elite_state_debug_enemy(enemy: Node) -> bool:
	return _enemy_spawn_controller._is_elite_state_debug_enemy(enemy)


func _is_developer_mode_enabled() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("developer_mode_enabled", false))


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


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62, 1.0))
	parent.add_child(label)


func _add_row(parent: VBoxContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


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


func _add_button(parent: HBoxContainer, text: String, callable: Callable, width: float = 92.0) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 30)
	UIButtonSkin.apply(button)
	button.pressed.connect(callable)
	parent.add_child(button)
	return button


func _add_option_item(option: OptionButton, text: String, id: String) -> void:
	var index: int = option.item_count
	option.add_item(text)
	option.set_item_metadata(index, StringName(id))


func _add_disabled_option_header(option: OptionButton, text: String) -> void:
	if option == null:
		return
	var index: int = option.item_count
	option.add_item(text)
	option.set_item_metadata(index, StringName(""))
	option.set_item_disabled(index, true)


func _select_first_enabled_option(option: OptionButton) -> void:
	var index: int = _find_first_enabled_option_index(option)
	if index >= 0:
		option.select(index)


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


func _select_option_by_id(option: OptionButton, id: String) -> void:
	if option == null:
		return
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == id:
			option.select(index)
			return


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


func _display_name(data: Dictionary, fallback: String) -> String:
	return String(data.get("display_name", fallback))


func _on_effects_page_log_requested(level: StringName, message: String) -> void:
	match level:
		&"error":
			_log_error(message)
		&"warning":
			_log_warn(message)
		_:
			_log(message)


func _log(message: String) -> void:
	_last_log = message
	print_rich("[color=cyan][DevDebug][/color] %s" % message)
	_refresh_state()


func _log_warn(message: String) -> void:
	_last_log = message
	print_rich("[color=yellow][DevDebug][/color] %s" % message)
	_refresh_state()


func _log_error(message: String) -> void:
	_last_log = message
	print_rich("[color=red][DevDebug][/color] %s" % message)
	_refresh_state()
