extends CanvasLayer
class_name DevDebugPanel
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const EnemyAttackRangeOverlayScript: Script = preload("res://scripts/debug/enemy_attack_range_overlay.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const SkillEffectSummaryBuilderScript: Script = preload("res://scripts/skills/skill_effect_summary_builder.gd")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const FIRE_TORNADO_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/fire_tornado_effect.tscn")
const MARS_SPARK_MISSILE_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/mars_spark_missile_effect.tscn")
const GODS_DATA_PATH: String = DataPathsScript.GODS_PATH
const SKILLS_DATA_PATH: String = DataPathsScript.SKILLS_PATH

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

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var page_root: VBoxContainer = VBoxContainer.new()
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", 7)
	scroll.add_child(page_root)

	var run_setup_page: VBoxContainer = _add_category_page(page_root, "run_setup", "Run Setup")
	_character_option = _add_option_row(run_setup_page, "Character")
	_map_option = _add_option_row(run_setup_page, "Map")
	_character_option.item_selected.connect(Callable(self, "_on_character_selected"))
	_map_option.item_selected.connect(Callable(self, "_on_setup_option_selected"))

	var run_row: HBoxContainer = _add_row(run_setup_page)
	_add_button(run_row, "Restart Run", Callable(self, "_restart_debug_run"), 132)
	_add_button(run_row, "Lv3", Callable(self, "_level_starting_skill_to").bind(3), 60)

	var runtime_page: VBoxContainer = _add_category_page(page_root, "runtime", "Runtime")
	var runtime_row: HBoxContainer = _add_row(runtime_page)
	_add_button(runtime_row, "Pause Game", Callable(self, "_toggle_tree_pause"), 112)
	_add_button(runtime_row, "Auto On/Off", Callable(self, "_toggle_auto_combat"), 112)
	var attack_row: HBoxContainer = _add_row(runtime_page)
	_add_button(attack_row, "Manual Attack", Callable(self, "_manual_cast_player_skills"), 120)
	_add_button(attack_row, "Attack On/Off", Callable(self, "_toggle_player_attack_disabled"), 120)
	var attack_trace_row: HBoxContainer = _add_row(runtime_page)
	_add_button(attack_trace_row, "Attack Once", Callable(self, "_attack_once_player_skills"), 112)
	_add_button(attack_trace_row, "Clear Attack Trace", Callable(self, "_clear_attack_trace"), 156)
	var attack_trace_nav_row: HBoxContainer = _add_row(runtime_page)
	_add_button(attack_trace_nav_row, "Prev Card", Callable(self, "_show_previous_attack_damage_card"), 112)
	_add_button(attack_trace_nav_row, "Next Card", Callable(self, "_show_next_attack_damage_card"), 112)
	var copy_record_button: Button = _add_button(attack_trace_nav_row, "Copy Record", Callable(self, "_copy_current_attack_damage_record"), 124)
	copy_record_button.name = "CopyDamageRecordButton"
	_attack_damage_scroll = ScrollContainer.new()
	_attack_damage_scroll.name = "AttackDamageCardScroll"
	_attack_damage_scroll.custom_minimum_size = Vector2(440, 360)
	_attack_damage_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_damage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attack_damage_label = Label.new()
	_attack_damage_label.name = "AttackDamageBreakdownLabel"
	_attack_damage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attack_damage_label.add_theme_font_size_override("font_size", 12)
	_attack_damage_label.text = _last_attack_damage_text
	_attack_damage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_damage_scroll.add_child(_attack_damage_label)
	runtime_page.add_child(_attack_damage_scroll)

	var skill_cards_page: VBoxContainer = _add_category_page(page_root, "skill_cards", "Skill Cards")
	var god_skill_button_row: HBoxContainer = _add_row(skill_cards_page)
	god_skill_button_row.name = "GodSkillButtons"
	var skill_tools_row: HBoxContainer = _add_row(skill_cards_page)
	var clear_skills_button: Button = _add_button(skill_tools_row, "Clear Skills", Callable(self, "_clear_player_skills"), 124)
	clear_skills_button.name = "ClearSkillsButton"

	_god_skill_cards_scroll = ScrollContainer.new()
	_god_skill_cards_scroll.name = "GodSkillCardsScroll"
	_god_skill_cards_scroll.custom_minimum_size = Vector2(440, 560)
	_god_skill_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_god_skill_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_cards_page.add_child(_god_skill_cards_scroll)

	_god_skill_cards = VBoxContainer.new()
	_god_skill_cards.name = "GodSkillCards"
	_god_skill_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_god_skill_cards.add_theme_constant_override("separation", 6)
	_god_skill_cards_scroll.add_child(_god_skill_cards)

	_fire_skill_chain_log_label = Label.new()
	_fire_skill_chain_log_label.name = "GodSkillChainLogLabel"
	_fire_skill_chain_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fire_skill_chain_log_label.add_theme_font_size_override("font_size", 12)
	_fire_skill_chain_log_label.text = "God skill chain: idle."
	skill_cards_page.add_child(_fire_skill_chain_log_label)

	var enemy_spawn_page: VBoxContainer = _add_category_page(page_root, "enemy_spawn", "Enemy Spawn")
	_enemy_option = _add_option_row(enemy_spawn_page, "Enemy")
	_spawn_count_spin = _add_spin_row(enemy_spawn_page, "Count", 1.0, 200.0, 1.0, 8.0)
	_enemy_health_spin = _add_spin_row(enemy_spawn_page, "HP 0=default", 0.0, 100000.0, 10.0, 0.0)
	_enemy_armor_spin = _add_spin_row(enemy_spawn_page, "Armor 0=default", 0.0, 1000.0, 1.0, 0.0)
	_enemy_resistance_spin = _add_spin_row(enemy_spawn_page, "All Resist %", -75.0, 90.0, 5.0, 0.0)
	var enemy_row: HBoxContainer = _add_row(enemy_spawn_page)
	_add_button(enemy_row, "Spawn", Callable(self, "_spawn_configured_enemies"), 92)
	_add_button(enemy_row, "Set Nearest", Callable(self, "_set_nearest_enemy_stats"), 116)
	_add_button(enemy_row, "Clear Enemies", Callable(self, "_clear_enemies"), 124)
	var enemy_batch_row: HBoxContainer = _add_row(enemy_spawn_page)
	_add_button(enemy_batch_row, "Spawn All Types", Callable(self, "_spawn_all_enemy_types"), 148)
	_enemy_state_option = _add_option_row(enemy_spawn_page, "Enemy State")
	var enemy_state_row: HBoxContainer = _add_row(enemy_spawn_page)
	_add_button(enemy_state_row, "Set Enemy State", Callable(self, "_apply_enemy_state_override"), 140)
	_add_button(enemy_state_row, "Clear Enemy State", Callable(self, "_clear_enemy_state_override"), 148)

	var effects_page: VBoxContainer = _add_category_page(page_root, "effects", "Effects")
	_effect_option = _add_option_row(effects_page, "Effect")
	var effects_row: HBoxContainer = _add_row(effects_page)
	_add_button(effects_row, "持续发射", Callable(self, "_start_continuous_effect_fire"), 116)
	_add_button(effects_row, "单次发射", Callable(self, "_fire_single_effect"), 116)

	var status_page: VBoxContainer = _add_category_page(page_root, "status", "Status / Stacks")
	_status_option = _add_option_row(status_page, "Status")
	_status_stack_spin = _add_spin_row(status_page, "Stacks", 1.0, 99.0, 1.0, 1.0)
	_status_duration_spin = _add_spin_row(status_page, "Duration", 0.1, 120.0, 0.5, 6.0)
	var check_row: HBoxContainer = _add_row(status_page)
	_apply_to_all_enemies_check = CheckBox.new()
	_apply_to_all_enemies_check.text = "All enemies"
	check_row.add_child(_apply_to_all_enemies_check)
	_target_player_check = CheckBox.new()
	_target_player_check.text = "Target player"
	check_row.add_child(_target_player_check)
	var status_row: HBoxContainer = _add_row(status_page)
	_add_button(status_row, "Apply Status", Callable(self, "_apply_status_from_panel"), 124)
	_add_button(status_row, "Clear Status", Callable(self, "_clear_statuses"), 112)

	var utility_page: VBoxContainer = _add_category_page(page_root, "utility", "Utility")
	var util_row: HBoxContainer = _add_row(utility_page)
	_add_button(util_row, "Print", Callable(self, "_print_state"), 72)
	_add_button(util_row, "Ranges", Callable(self, "_toggle_range_overlay"), 84)

	_log_label = Label.new()
	_log_label.name = "LogLabel"
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_log_label)
	_open_category("run_setup")
	_refresh_state()


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
	_character_option.clear()
	for character: Dictionary in GameData.get_character_pool():
		var id: String = String(character.get("id", ""))
		if id == "":
			continue
		_add_option_item(_character_option, _display_name(character, id), id)


func _populate_map_options() -> void:
	_map_option.clear()
	for map_data: Dictionary in GameData.get_map_pool():
		var id: String = String(map_data.get("id", ""))
		if id == "":
			continue
		_add_option_item(_map_option, _display_name(map_data, id), id)


func _populate_enemy_options() -> void:
	_enemy_option.clear()
	var normal_enemies: Array[Dictionary] = []
	var elite_enemies: Array[Dictionary] = []
	var boss_enemies: Array[Dictionary] = []
	for enemy: Dictionary in GameData.get_enemy_pool():
		var id: String = String(enemy.get("id", ""))
		if id == "":
			continue
		match _get_enemy_option_group(enemy):
			"boss":
				boss_enemies.append(enemy)
			"elite":
				elite_enemies.append(enemy)
			_:
				normal_enemies.append(enemy)
	_add_enemy_group_options("普通", normal_enemies)
	_add_enemy_group_options("精英", elite_enemies)
	_add_enemy_group_options("BOSS", boss_enemies)
	_select_first_enabled_option(_enemy_option)


func _get_enemy_option_group(enemy: Dictionary) -> String:
	var enemy_type: String = String(enemy.get("type", enemy.get("rank", "normal"))).to_lower()
	var enemy_rank: String = String(enemy.get("rank", enemy_type)).to_lower()
	if enemy_type == "boss" or enemy_rank == "boss":
		return "boss"
	if enemy_type == "elite" or enemy_rank == "elite":
		return "elite"
	return "normal"


func _add_enemy_group_options(group_label: String, enemies: Array[Dictionary]) -> void:
	if enemies.is_empty():
		return
	_add_disabled_option_header(_enemy_option, "-- %s --" % group_label)
	for enemy: Dictionary in enemies:
		var id: String = String(enemy.get("id", ""))
		if id != "":
			_add_option_item(_enemy_option, _display_name(enemy, id), id)


func _populate_enemy_state_options() -> void:
	if _enemy_state_option == null:
		return
	_enemy_state_option.clear()
	_add_option_item(_enemy_state_option, "Auto", "")
	_add_option_item(_enemy_state_option, "Idle", "idle")
	_add_option_item(_enemy_state_option, "Chase", "chase")
	_add_option_item(_enemy_state_option, "Attack", "attack")
	_add_option_item(_enemy_state_option, "Hurt", "hurt")
	_add_option_item(_enemy_state_option, "Death", "dead")
	_select_option_by_id(_enemy_state_option, _get_enemy_state_override())
	_refresh_enemy_state_option_availability()


func _populate_effect_options() -> void:
	if _effect_option == null:
		return
	_effect_option.clear()
	_add_option_item(_effect_option, "Fire Tornado", "fire_tornado")
	_add_option_item(_effect_option, "火星飞弹", "mars_spark_missile")
	_select_first_enabled_option(_effect_option)


func _populate_god_skill_buttons() -> void:
	var button_row: HBoxContainer = find_child("GodSkillButtons", true, false) as HBoxContainer
	if button_row == null:
		return
	_clear_children(button_row)
	_god_skill_buttons.clear()

	var gods: Array[Dictionary] = _get_god_definitions()
	for god: Dictionary in gods:
		var god_id: String = _string_or(god.get("id", ""), "")
		if god_id == "":
			continue
		var button: Button = _add_button(
			button_row,
			_string_or(god.get("display_name", god_id), god_id),
			Callable(self, "_select_god_skill_cards").bind(StringName(god_id)),
			68
		)
		button.name = "GodSkillButton_%s" % god_id
		button.toggle_mode = true
		_god_skill_buttons[StringName(god_id)] = button
	if not _god_skill_buttons.has(_selected_god_id) and not gods.is_empty():
		_selected_god_id = StringName(_string_or(gods[0].get("id", "fire"), "fire"))
	_update_god_skill_button_states()


func _refresh_god_skill_cards() -> void:
	if _god_skill_cards == null:
		return
	_clear_children(_god_skill_cards)
	_god_skill_definitions = _get_god_skill_definitions(_selected_god_id)
	_god_skill_options = _build_debug_god_skill_options(_selected_god_id)
	_sync_selected_god_skill_id()
	if _god_skill_definitions.is_empty():
		var empty_label: Label = Label.new()
		empty_label.name = "GodSkillCardsEmpty"
		empty_label.text = "No skill cards for this god yet."
		empty_label.add_theme_font_size_override("font_size", 12)
		_god_skill_cards.add_child(empty_label)
		_update_god_skill_button_states()
		_refresh_state()
		return

	for index in range(_god_skill_definitions.size()):
		_add_god_skill_card(_god_skill_cards, _god_skill_definitions[index], index)
	_update_god_skill_button_states()
	_refresh_state()


func _refresh_god_skill_section() -> void:
	_populate_god_skill_buttons()
	_refresh_god_skill_cards()


func _select_god_skill_cards(god_id: StringName) -> void:
	_selected_god_id = god_id
	_update_god_skill_button_states()
	_refresh_god_skill_cards()


func _update_god_skill_button_states() -> void:
	for god_id_variant: Variant in _god_skill_buttons.keys():
		var god_id: StringName = StringName(_string_or(god_id_variant, ""))
		var button: Button = _god_skill_buttons[god_id_variant] as Button
		if button != null:
			button.set_pressed_no_signal(god_id == _selected_god_id)


func _sync_selected_god_skill_id() -> void:
	if _god_skill_definitions.is_empty():
		_selected_god_skill_id = &""
		return
	for skill: Dictionary in _god_skill_definitions:
		if StringName(_string_or(skill.get("id", ""), "")) == _selected_god_skill_id:
			return
	_selected_god_skill_id = StringName(_string_or(_god_skill_definitions[0].get("id", ""), ""))


func _load_json_document(path: String) -> Dictionary:
	return JsonDataLoaderScript.load_dictionary(path, "DevDebugPanel", JsonDataLoaderScript.REPORT_SILENT)


func _get_god_definitions() -> Array[Dictionary]:
	var document: Dictionary = _load_json_document(GODS_DATA_PATH)
	var gods: Array[Dictionary] = []
	var god_variants: Variant = document.get("gods", [])
	if god_variants is Array:
		for god_variant: Variant in god_variants:
			if god_variant is Dictionary:
				var god: Dictionary = god_variant
				if String(god.get("id", "")) != "":
					gods.append(god.duplicate(true))
	if not gods.is_empty():
		return gods
	return [
		{"id": "fire", "display_name": "Fire"},
		{"id": "thunder", "display_name": "Thunder"},
		{"id": "frost", "display_name": "Frost"},
		{"id": "curse", "display_name": "Curse"},
		{"id": "holy", "display_name": "Holy"},
		{"id": "chaos", "display_name": "Chaos"}
	]


func _get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var document: Dictionary = _load_json_document(SKILLS_DATA_PATH)
	var definitions: Array[Dictionary] = []
	var skills_variant: Variant = document.get("skills", [])
	if not (skills_variant is Array):
		return definitions
	for skill_variant: Variant in skills_variant:
		if not (skill_variant is Dictionary):
			continue
		var skill: Dictionary = skill_variant
		if not _is_god_skill_definition(skill, god_id):
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		definitions.append(skill.duplicate(true))
	return definitions


func _is_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	if StringName(_string_or(skill.get("god_id", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("school", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("fusion_school", ""), "")) == god_id:
		return true
	var tags: Array = _get_array(skill.get("tags", []))
	return tags.has(_string_or(god_id, "")) or tags.has(god_id)


func _populate_fire_skill_options() -> void:
	if _fire_skill_option == null:
		return
	_fire_skill_option.clear()
	_debug_fire_skill_options = _build_debug_fire_skill_options()
	if _debug_fire_skill_options.is_empty():
		_add_disabled_option_header(_fire_skill_option, "No fire skill options")
		_update_fire_skill_chain_log({"option_generated": false, "error": "No fire skill options."})
		return
	for option: Dictionary in _debug_fire_skill_options:
		var skill_id: StringName = _get_option_learn_skill_id(option)
		if skill_id == &"":
			continue
		var label: String = "%s [%s]" % [
			String(option.get("display_name", skill_id)),
			String(skill_id)
		]
		_add_option_item(_fire_skill_option, label, String(skill_id))
	_select_first_enabled_option(_fire_skill_option)


func _build_debug_fire_skill_options(god_id: StringName = &"fire") -> Array[Dictionary]:
	return _build_debug_god_skill_options(god_id)


func _build_debug_god_skill_options(god_id: StringName) -> Array[Dictionary]:
	var player: Node = _get_player()
	if player == null:
		return []
	if not _upgrade_pool.has_method("generate_debug_fire_skill_options"):
		return []

	var options: Array[Dictionary] = []
	var seen: Dictionary = {}
	for option_variant: Variant in _upgrade_pool.call("generate_debug_fire_skill_options", player, god_id):
		var option: Dictionary = _upgrade_option_to_dictionary(option_variant)
		var skill_id: StringName = _get_option_learn_skill_id(option)
		if skill_id == &"" or seen.has(skill_id):
			continue
		seen[skill_id] = true
		options.append(option)
	return options


func _populate_status_options() -> void:
	_status_option.clear()
	for status: Dictionary in GameData.get_status_pool():
		var id: String = String(status.get("id", ""))
		if id == "" or not _is_status_option_available(id):
			continue
		_add_option_item(_status_option, _display_name(status, id), id)


func _is_status_option_available(status_id: Variant) -> bool:
	return not _get_status_definition_for_option(status_id).is_empty()


func _get_status_definition_for_option(status_id: Variant) -> Dictionary:
	var id: StringName = StringName(String(status_id))
	if id == &"":
		return {}

	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_status_definition"):
		var data: Variant = data_manager.call("get_status_definition", id)
		if data is Dictionary and not (data as Dictionary).is_empty():
			return (data as Dictionary).duplicate(true)

	for status: Dictionary in GameData.get_status_pool():
		if StringName(String(status.get("id", ""))) == id:
			return status.duplicate(true)
	return {}


func _build_player_stats(parent: VBoxContainer) -> void:
	_player_attributes_label = Label.new()
	_player_attributes_label.name = "CalculatedPlayerAttributesLabel"
	_player_attributes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_player_attributes_label.add_theme_font_size_override("font_size", 12)
	parent.add_child(_player_attributes_label)

	var calculated_row: HBoxContainer = _add_row(parent)
	_add_button(calculated_row, "Refresh Calculated", Callable(self, "_refresh_state"), 168)

	_player_stat_spins.clear()
	for config: Dictionary in _get_player_stat_configs():
		var property: String = String(config.get("property", ""))
		if property == "":
			continue
		_player_stat_spins[property] = _add_spin_row(
			parent,
			String(config.get("label", property)),
			float(config.get("min", 0.0)),
			float(config.get("max", 1000.0)),
			float(config.get("step", 1.0)),
			float(config.get("value", 0.0))
		)
	var row: HBoxContainer = _add_row(parent)
	_add_button(row, "Apply Player Stats", Callable(self, "_apply_player_stats_from_panel"), 168)
	_add_button(row, "Sync Player Stats", Callable(self, "_sync_player_stat_controls"), 156)


func _build_skill_stats(parent: VBoxContainer) -> void:
	_skill_stat_spins.clear()
	_skill_stat_active.clear()
	for config: Dictionary in _get_skill_stat_configs():
		var stat_name: String = String(config.get("stat", ""))
		if stat_name == "":
			continue
		_skill_stat_spins[stat_name] = _add_spin_row(
			parent,
			String(config.get("label", stat_name)),
			float(config.get("min", 0.0)),
			float(config.get("max", 10000.0)),
			float(config.get("step", 1.0)),
			float(config.get("value", 0.0))
		)
	var row: HBoxContainer = _add_row(parent)
	_add_button(row, "Apply Attack Stats", Callable(self, "_apply_skill_stats_from_panel"), 168)
	_add_button(row, "Sync Attack Stats", Callable(self, "_sync_skill_stat_controls"), 156)


func _sync_player_stat_controls() -> void:
	var player: Node = _get_player()
	if player == null:
		return
	for config: Dictionary in _get_player_stat_configs():
		var property: String = String(config.get("property", ""))
		var spin: SpinBox = _player_stat_spins.get(property, null) as SpinBox
		if spin == null:
			continue
		var value: Variant = player.get(property)
		if value != null:
			spin.value = float(value)


func _sync_skill_stat_controls() -> void:
	var player: Node = _get_player()
	var skill: RefCounted = _get_starting_skill(player)
	_skill_stat_active.clear()
	if player == null or skill == null:
		return

	var skill_manager: Node = _get_skill_manager(player)
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	for config: Dictionary in _get_skill_stat_configs():
		var stat_name: String = String(config.get("stat", ""))
		var spin: SpinBox = _skill_stat_spins.get(stat_name, null) as SpinBox
		if spin == null:
			continue
		var value: Variant = SkillStatServiceScript.get_effective_stat(skill, stat_name, null, skill_manager, relic_manager, player)
		if value == null:
			_skill_stat_active[stat_name] = false
			if bool(config.get("allow_new", false)):
				spin.editable = true
				spin.modulate = Color.WHITE
				spin.value = float(config.get("value", spin.value))
			else:
				spin.editable = false
				spin.modulate = Color(1.0, 1.0, 1.0, 0.45)
			continue
		_skill_stat_active[stat_name] = true
		spin.editable = true
		spin.modulate = Color.WHITE
		spin.value = float(value)


func _apply_player_stats_from_panel() -> void:
	var player: Node = _get_player()
	if player == null:
		_log_error("Player missing.")
		return

	for config: Dictionary in _get_player_stat_configs():
		var property: String = String(config.get("property", ""))
		var spin: SpinBox = _player_stat_spins.get(property, null) as SpinBox
		if property == "" or spin == null:
			continue
		if bool(config.get("int", false)):
			player.set(property, roundi(float(spin.value)))
		else:
			player.set(property, float(spin.value))

	var max_health: int = maxi(int(player.get("max_health")), 1)
	var current_health: int = clampi(int(player.get("current_health")), 0, max_health)
	player.set("max_health", max_health)
	player.set("current_health", current_health)
	if player.has_signal(&"health_changed"):
		player.emit_signal(&"health_changed", current_health, max_health)
	if player.has_signal(&"experience_changed"):
		player.emit_signal(&"experience_changed", int(player.get("current_experience")), int(player.get("experience_to_next_level")), int(player.get("level")))
	if player.has_method("_refresh_synergies"):
		player.call("_refresh_synergies")
	_log("Applied player stats.")


func _apply_skill_stats_from_panel() -> void:
	var player: Node = _get_player()
	var skill: RefCounted = _get_starting_skill(player)
	if player == null or skill == null:
		_log_error("Primary attack missing.")
		return

	var runtime_modifiers: Dictionary = {}
	var runtime_variant: Variant = skill.get("runtime_modifiers")
	if runtime_variant is Dictionary:
		runtime_modifiers = (runtime_variant as Dictionary).duplicate(true)

	var applied: int = 0
	for config: Dictionary in _get_skill_stat_configs():
		var stat_name: String = String(config.get("stat", ""))
		var spin: SpinBox = _skill_stat_spins.get(stat_name, null) as SpinBox
		if stat_name == "" or spin == null:
			continue
		if not bool(_skill_stat_active.get(stat_name, false)) and not bool(config.get("allow_new", false)):
			continue
		runtime_modifiers["%s_override" % stat_name] = roundi(float(spin.value)) if bool(config.get("int", false)) else float(spin.value)
		applied += 1
	skill.set("runtime_modifiers", runtime_modifiers)

	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager != null and skill_manager.has_signal(&"skill_changed"):
		skill_manager.emit_signal(&"skill_changed")
	_log("Applied %d primary attack stat override(s)." % applied)


func _get_player_stat_configs() -> Array[Dictionary]:
	return [
		{"property": "max_health", "label": "Max HP", "min": 1.0, "max": 100000.0, "step": 10.0, "int": true},
		{"property": "current_health", "label": "Current HP", "min": 0.0, "max": 100000.0, "step": 10.0, "int": true},
		{"property": "level", "label": "Level", "min": 1.0, "max": 100.0, "step": 1.0, "int": true},
		{"property": "current_experience", "label": "Current EXP", "min": 0.0, "max": 1000000.0, "step": 10.0, "int": true},
		{"property": "experience_to_next_level", "label": "EXP To Next", "min": 1.0, "max": 1000000.0, "step": 10.0, "int": true},
		{"property": "move_speed", "label": "Move Speed", "min": 0.0, "max": 3000.0, "step": 5.0},
		{"property": "damage_multiplier", "label": "Damage Mult", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "attack_speed_multiplier", "label": "Attack Speed", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "crit_chance", "label": "Crit Chance", "min": 0.0, "max": 1.0, "step": 0.01},
		{"property": "crit_damage", "label": "Crit Damage", "min": 1.0, "max": 50.0, "step": 0.05},
		{"property": "armor", "label": "Armor", "min": 0.0, "max": 10000.0, "step": 1.0, "int": true},
		{"property": "pickup_radius", "label": "Pickup Radius", "min": 0.0, "max": 3000.0, "step": 5.0},
		{"property": "damage_taken_multiplier", "label": "Taken Mult", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "skill_area_multiplier", "label": "Area Mult", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "experience_gain_multiplier", "label": "EXP Gain", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "coin_gain_multiplier", "label": "Coin Gain", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "soul_gain_multiplier", "label": "Soul Gain", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "status_duration_multiplier", "label": "Status Duration", "min": 0.01, "max": 100.0, "step": 0.05},
		{"property": "fire_damage_multiplier_add", "label": "Fire Damage Add", "min": -10.0, "max": 100.0, "step": 0.05},
		{"property": "poison_damage_multiplier_add", "label": "Poison Damage Add", "min": -10.0, "max": 100.0, "step": 0.05},
		{"property": "rare_weight_add", "label": "Rare Weight Add", "min": -100.0, "max": 100.0, "step": 0.1},
		{"property": "epic_weight_add", "label": "Epic Weight Add", "min": -100.0, "max": 100.0, "step": 0.1},
		{"property": "legendary_weight_add", "label": "Legend Weight Add", "min": -100.0, "max": 100.0, "step": 0.1},
		{"property": "level_up_rerolls", "label": "Rerolls", "min": 0.0, "max": 999.0, "step": 1.0, "int": true},
		{"property": "enemy_spawn_count_multiplier_add", "label": "Spawn Count Add", "min": -0.95, "max": 100.0, "step": 0.05},
		{"property": "boss_hp_multiplier_add", "label": "Boss HP Add", "min": -0.95, "max": 100.0, "step": 0.05},
		{"property": "on_hit_slow_chance_add", "label": "Slow Chance Add", "min": 0.0, "max": 1.0, "step": 0.01},
		{"property": "slow_percent", "label": "Slow Percent", "min": 0.0, "max": 0.95, "step": 0.01},
		{"property": "slow_duration", "label": "Slow Duration", "min": 0.0, "max": 120.0, "step": 0.5},
		{"property": "aura_radius", "label": "Aura Radius", "min": 0.0, "max": 3000.0, "step": 5.0},
		{"property": "thorns_damage", "label": "Thorns Damage", "min": 0.0, "max": 100000.0, "step": 1.0, "int": true},
		{"property": "thorns_area_radius", "label": "Thorns Radius", "min": 0.0, "max": 3000.0, "step": 5.0},
		{"property": "revive_count_add", "label": "Revive Count", "min": 0.0, "max": 99.0, "step": 1.0, "int": true},
		{"property": "revive_hp_percent", "label": "Revive HP %", "min": 0.0, "max": 1.0, "step": 0.01}
	]


func _get_skill_stat_configs() -> Array[Dictionary]:
	return [
		{"stat": "damage", "label": "Damage", "min": 0.0, "max": 100000.0, "step": 1.0, "int": true},
		{"stat": "cooldown", "label": "Cooldown", "min": 0.01, "max": 120.0, "step": 0.05},
		{"stat": "range", "label": "Flight Range", "min": 0.0, "max": 10000.0, "step": 10.0, "allow_new": true},
		{"stat": "projectile_speed", "label": "Projectile Speed", "min": 0.0, "max": 10000.0, "step": 10.0, "allow_new": true},
		{"stat": "projectile_count", "label": "Projectile Count", "min": 0.0, "max": 999.0, "step": 1.0, "int": true},
		{"stat": "pierce", "label": "Pierce", "min": 0.0, "max": 999.0, "step": 1.0, "int": true},
		{"stat": "area_radius", "label": "Area Radius", "min": 0.0, "max": 10000.0, "step": 5.0},
		{"stat": "duration", "label": "Duration", "min": 0.0, "max": 120.0, "step": 0.1},
		{"stat": "tick_interval", "label": "Tick Interval", "min": 0.01, "max": 30.0, "step": 0.05},
		{"stat": "orbit_radius", "label": "Orbit Radius", "min": 0.0, "max": 5000.0, "step": 5.0},
		{"stat": "orbit_object_count", "label": "Orbit Count", "min": 0.0, "max": 999.0, "step": 1.0, "int": true},
		{"stat": "rotation_speed", "label": "Rotation Speed", "min": 0.0, "max": 5000.0, "step": 5.0},
		{"stat": "explosion_damage", "label": "Explosion Damage", "min": 0.0, "max": 100000.0, "step": 1.0, "int": true, "allow_new": true},
		{"stat": "explosion_radius", "label": "Explosion Radius", "min": 0.0, "max": 10000.0, "step": 5.0, "allow_new": true}
	]


func _on_character_selected(_index: int) -> void:
	_sync_player_stat_controls()
	_sync_skill_stat_controls()
	_refresh_state()


func _on_setup_option_selected(_index: int) -> void:
	_refresh_state()


func _sync_options_from_runtime() -> void:
	var player: Node = _get_player()
	if player != null:
		_select_option_by_id(_character_option, String(player.get("selected_character_id")))

	var ui_manager: Node = _get_ui_manager()
	if ui_manager != null:
		var selected_map: Variant = ui_manager.get("_selected_map_id")
		_select_option_by_id(_map_option, String(selected_map))
	_sync_player_stat_controls()
	_sync_skill_stat_controls()


func _restart_debug_run() -> void:
	var ui_manager: Node = _get_ui_manager()
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		_log_error("UIManager.start_developer_debug_run missing.")
		return
	ui_manager.call("start_developer_debug_run", {
		"character_id": _get_selected_id(_character_option),
		"map_id": _get_selected_id(_map_option)
	})
	call_deferred("_refresh_state")
	_log("Restarted debug run.")


func _toggle_tree_pause() -> void:
	get_tree().paused = not get_tree().paused
	_log("Game paused=%s." % str(get_tree().paused))


func _toggle_auto_combat() -> void:
	var enabled: bool = not _is_debug_control_mode()
	_set_debug_control_mode(enabled)
	if enabled:
		get_tree().paused = false
	_log("Auto combat paused by debug_control_mode=%s." % str(enabled))


func _toggle_player_attack_disabled() -> void:
	var disabled: bool = not _is_player_attack_disabled()
	_set_player_attack_disabled(disabled)
	_log("Player auto attack disabled=%s." % str(disabled))


func _apply_enemy_state_override() -> void:
	var state: String = String(_get_selected_id(_enemy_state_option))
	state = _normalize_enemy_forced_state(state)
	if not _is_valid_enemy_forced_state(state) and state != "":
		_log_warn("Unsupported enemy state: %s." % state)
		return
	if _is_elite_only_enemy_state(state) and not _can_apply_elite_enemy_state_to_nearest():
		_select_option_by_id(_enemy_state_option, "")
		_log_warn("Hurt/Death enemy states are only enabled for elite enemies.")
		return
	_set_enemy_state_override(state)
	_log("Enemy forced state=%s." % ("auto" if state == "" else state))


func _clear_enemy_state_override() -> void:
	_set_enemy_state_override("")
	_select_option_by_id(_enemy_state_option, "")
	_log("Enemy forced state=auto.")


func _spawn_configured_enemies() -> void:
	var player: Node2D = _get_player() as Node2D
	if player == null or player.get_parent() == null:
		_log_error("Player missing.")
		return

	var enemy_id: StringName = _get_selected_id(_enemy_option)
	var count: int = maxi(roundi(float(_spawn_count_spin.value)), 1)
	var spawn_parent: Node = player.get_parent()
	var radius: float = _get_debug_spawn_radius(player)
	var spawned: int = 0
	for spawn_index in range(count):
		var angle: float = TAU * float(spawn_index) / float(maxi(count, 1))
		var position: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * (radius + 12.0 * float(spawn_index % 4))
		var enemy: Node2D = _spawn_debug_enemy(enemy_id, position, spawn_parent, true)
		if enemy == null:
			continue
		spawned += 1
	_sync_enemy_attack_range_overlays(_are_range_overlays_visible())
	_log("Spawned %d x %s." % [spawned, String(enemy_id)])


func _spawn_fire_tornado_effect() -> void:
	var player: Node2D = _get_player() as Node2D
	if player == null:
		_log_warn("Cannot spawn Fire Tornado: player not found.")
		return
	if FIRE_TORNADO_EFFECT_SCENE == null:
		_log_error("Cannot spawn Fire Tornado: scene failed to load.")
		return

	var effect: Node2D = FIRE_TORNADO_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		_log_error("Cannot spawn Fire Tornado: scene root is not Node2D.")
		return

	var parent: Node = player.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		effect.queue_free()
		_log_error("Cannot spawn Fire Tornado: no scene parent available.")
		return

	parent.add_child(effect)
	effect.global_position = _resolve_fire_tornado_spawn_position(player)
	_log("Spawned Fire Tornado VFX.")


func _start_continuous_effect_fire() -> void:
	_trigger_selected_effect(true)


func _fire_single_effect() -> void:
	_trigger_selected_effect(false)


func _trigger_selected_effect(continuous: bool) -> void:
	var effect_id: StringName = _get_selected_id(_effect_option)
	match effect_id:
		&"fire_tornado":
			_spawn_fire_tornado_effect()
		&"mars_spark_missile":
			_spawn_mars_spark_missile_effect(continuous)
		_:
			_log_warn("No effect selected.")


func _spawn_mars_spark_missile_effect(continuous: bool) -> void:
	var player: Node2D = _get_player() as Node2D
	if player == null:
		_log_warn("Cannot spawn Mars Spark Missile: player not found.")
		return
	if MARS_SPARK_MISSILE_EFFECT_SCENE == null:
		_log_error("Cannot spawn Mars Spark Missile: scene failed to load.")
		return

	var effect: Variant = MARS_SPARK_MISSILE_EFFECT_SCENE.instantiate()
	if not (effect is Node2D):
		_log_error("Cannot spawn Mars Spark Missile: scene root is not MarsSparkMissileEffect.")
		return

	var parent: Node = player.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		effect.queue_free()
		_log_error("Cannot spawn Mars Spark Missile: no scene parent available.")
		return

	parent.add_child(effect)
	var origin: Vector2 = _resolve_mars_spark_missile_spawn_position(player)
	var target: Vector2 = _resolve_mars_spark_missile_target_position(player, origin)
	effect.configure(origin, target, false)
	effect.set_continuous(continuous)
	_log("Spawned %s Mars Spark Missile VFX." % ("continuous" if continuous else "single"))


func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _get_nearest_enemy() as Node2D
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		var to_enemy: Vector2 = nearest_enemy.global_position - player.global_position
		if to_enemy.length_squared() > 0.0001:
			direction = to_enemy.normalized()
	return player.global_position + direction * 96.0


func _resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _get_nearest_enemy() as Node2D
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		direction = player.global_position.direction_to(nearest_enemy.global_position)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return player.global_position + direction.normalized() * 32.0


func _resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	var nearest_enemy: Node2D = _get_nearest_enemy() as Node2D
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		return nearest_enemy.global_position
	var direction: Vector2 = Vector2.RIGHT
	if player != null:
		direction = player.global_position.direction_to(origin)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return origin + direction.normalized() * 360.0


func _spawn_all_enemy_types() -> void:
	var player: Node2D = _get_player() as Node2D
	if player == null or player.get_parent() == null:
		_log_error("Player missing.")
		return

	var enemy_pool: Array[Dictionary] = GameData.get_enemy_pool()
	if enemy_pool.is_empty():
		_log_warn("Enemy pool is empty.")
		return

	var spawn_parent: Node = player.get_parent()
	var count: int = enemy_pool.size()
	var base_radius: float = maxf(_get_debug_spawn_radius(player), 150.0)
	var spawned: int = 0
	for index in range(count):
		var enemy_data: Dictionary = enemy_pool[index]
		var enemy_id: StringName = StringName(String(enemy_data.get("id", "")))
		if enemy_id == &"":
			continue
		var angle: float = TAU * float(index) / float(maxi(count, 1))
		var ring_offset: float = 34.0 * float(index / 12)
		var position: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * (base_radius + ring_offset)
		var enemy: Node2D = _spawn_debug_enemy(enemy_id, position, spawn_parent, false)
		if enemy == null:
			continue
		enemy.set_meta("debug_spawn_all_types", true)
		spawned += 1

	_sync_enemy_attack_range_overlays(_are_range_overlays_visible())
	_log("Spawned %d enemy type(s)." % spawned)


func _spawn_debug_enemy(enemy_id: StringName, position: Vector2, spawn_parent: Node, apply_panel_stats: bool) -> Node2D:
	var enemy: Node2D = ENEMY_SCENE.instantiate() as Node2D
	if enemy == null:
		return null
	enemy.set("enemy_id", enemy_id)
	enemy.global_position = position
	enemy.set_meta("debug_spawned", true)
	spawn_parent.add_child(enemy)
	if apply_panel_stats:
		_apply_enemy_panel_stats(enemy)
	return enemy


func _spawn_enemies(count: int) -> void:
	if _spawn_count_spin != null:
		_spawn_count_spin.value = maxi(count, 1)
	_spawn_configured_enemies()


func _set_nearest_enemy_stats() -> void:
	var enemy: Node = _get_nearest_enemy()
	if enemy == null:
		_log_warn("No enemy found.")
		return
	_apply_enemy_panel_stats(enemy)
	_log("Applied enemy stats to %s." % enemy.name)


func _apply_enemy_panel_stats(enemy: Node) -> void:
	var hp: int = roundi(float(_enemy_health_spin.value))
	if hp > 0:
		enemy.set("max_health", hp)
		enemy.set("current_health", hp)
	if enemy.get("armor") != null:
		var armor: int = roundi(float(_enemy_armor_spin.value))
		if armor > 0:
			enemy.set("armor", armor)
	if enemy.get("resistances") != null:
		var resistance: float = clampf(float(_enemy_resistance_spin.value) * 0.01, -0.75, 0.90)
		enemy.set("resistances", {
			"physical": resistance,
			"fire": resistance,
			"ice": resistance,
			"lightning": resistance,
			"poison": resistance,
			"acid": resistance,
			"holy": resistance,
			"arcane": resistance,
			"magic": resistance
		})
	if enemy.has_signal(&"health_changed"):
		enemy.emit_signal(&"health_changed", int(enemy.get("current_health")), int(enemy.get("max_health")))


func _apply_status_from_panel() -> void:
	var status_id: StringName = _get_selected_id(_status_option)
	var stacks: int = maxi(roundi(float(_status_stack_spin.value)), 1)
	var duration: float = maxf(float(_status_duration_spin.value), 0.1)
	var targets: Array[Node] = _get_status_targets()
	if targets.is_empty():
		_log_warn("No status target.")
		return

	var root: Node = get_tree().root if get_tree() != null else null
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	_attack_damage_card_index = 0
	_reset_attack_damage_scroll()
	_last_attack_damage_text = "Damage Breakdown\nTrace #%d waiting for %s tick..." % [trace_id, String(status_id)]
	_refresh_attack_damage_text()

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
	_log("Applied %s x%d to %d target(s), trace #%d." % [String(status_id), stacks, applied_count, trace_id])


func _get_status_targets() -> Array[Node]:
	var result: Array[Node] = []
	if _target_player_check != null and _target_player_check.button_pressed:
		var player: Node = _get_player()
		if player != null:
			result.append(player)
		return result
	if _apply_to_all_enemies_check != null and _apply_to_all_enemies_check.button_pressed:
		for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
			result.append(enemy)
		return result
	var nearest: Node = _get_nearest_enemy()
	if nearest != null:
		result.append(nearest)
	return result


func _clear_statuses() -> void:
	var cleared: int = 0
	for target: Node in _get_status_targets():
		if target != null and target.has_method("clear_statuses"):
			target.call("clear_statuses")
			cleared += 1
	_log("Cleared statuses on %d target(s)." % cleared)


func _clear_enemies() -> void:
	var cleared: int = 0
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		enemy.queue_free()
		cleared += 1
	_enemy_range_overlays.clear()
	_log("Cleared %d enemies." % cleared)


func _clear_player_skills() -> void:
	if not OS.is_debug_build() and not _is_developer_mode_enabled():
		_log_warn("Clear Skills is only available in debug mode.")
		return
	var player: Node = _get_player()
	if player == null:
		_log_error("Player missing.")
		return
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null or not skill_manager.has_method("clear_skills"):
		_log_error("SkillManager.clear_skills missing.")
		return
	skill_manager.call("clear_skills")
	if player.has_method("_refresh_synergies"):
		player.call("_refresh_synergies")
	_refresh_state()
	_log("Cleared current skill slots.")


func _manual_cast_player_skills() -> void:
	var cast_count: int = _cast_player_skills_once()
	if cast_count < 0:
		return
	_log("Manual attack cast %d skill(s)." % cast_count)


func _attack_once_player_skills() -> void:
	var root: Node = get_tree().root if get_tree() != null else null
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	_attack_damage_card_index = 0
	_reset_attack_damage_scroll()
	_last_attack_damage_text = "Damage Breakdown\nTrace #%d waiting for hit..." % trace_id
	_refresh_attack_damage_text()

	var cast_count: int = _cast_player_skills_once(trace_id)
	if cast_count < 0:
		return
	if cast_count > 0:
		_log("Attack once trace #%d cast %d skill(s)." % [trace_id, cast_count])
		return
	_log("Attack once trace #%d had no runtime skill cast." % trace_id)


func _clear_attack_trace() -> void:
	var root: Node = get_tree().root if get_tree() != null else null
	var cleared: int = DebugCombatTraceScript.clear(root)
	_attack_damage_card_index = 0
	_reset_attack_damage_scroll()
	_last_attack_damage_text = "Damage Breakdown: cleared."
	_refresh_attack_damage_text()
	_log("Cleared attack trace and %d explosion site overlay(s)." % cleared)


func _show_previous_attack_damage_card() -> void:
	var record_count: int = _get_attack_damage_record_count()
	if record_count <= 0:
		_attack_damage_card_index = 0
	else:
		_attack_damage_card_index = posmod(_attack_damage_card_index - 1, record_count)
	_reset_attack_damage_scroll()
	_refresh_attack_damage_text()


func _show_next_attack_damage_card() -> void:
	var record_count: int = _get_attack_damage_record_count()
	if record_count <= 0:
		_attack_damage_card_index = 0
	else:
		_attack_damage_card_index = posmod(_attack_damage_card_index + 1, record_count)
	_reset_attack_damage_scroll()
	_refresh_attack_damage_text()


func _copy_current_attack_damage_record() -> bool:
	var record_text: String = _get_current_attack_damage_record_text()
	if record_text == "":
		_last_copied_attack_damage_record_text = ""
		_log("No damage record to copy.")
		return false

	DisplayServer.clipboard_set(record_text)
	_last_copied_attack_damage_record_text = record_text
	_log("Copied damage record card %d/%d." % [_attack_damage_card_index + 1, _get_attack_damage_record_count()])
	return true


func _cast_player_skills_once(trace_id: int = 0) -> int:
	var player: Node = _get_player()
	if player == null:
		_log_error("Player missing.")
		return -1

	var executor: Node = player.get_node_or_null("SkillExecutor")
	if executor == null or not executor.has_method("debug_cast_all_skills"):
		_log_error("SkillExecutor debug_cast_all_skills missing.")
		return -1

	var was_debug_control: bool = _is_debug_control_mode()
	_set_debug_control_mode(false)
	var cast_count: int = int(executor.call("debug_cast_all_skills", trace_id))
	_set_debug_control_mode(was_debug_control)
	return cast_count


func _level_starting_skill_to(target_level: int) -> void:
	var player: Node = _get_player()
	var skill: RefCounted = _get_starting_skill(player)
	if player == null or skill == null:
		_log_error("Starting skill missing.")
		return

	var skill_id: StringName = StringName(_string_or(skill.get("skill_id"), ""))
	while int(skill.get("current_level")) < target_level:
		if not player.has_method("_upgrade_skill") or not bool(player.call("_upgrade_skill", skill_id, 1)):
			break
	_sync_skill_stat_controls()
	_log("Starting skill %s -> Lv.%d." % [String(skill_id), int(skill.get("current_level"))])


func _toggle_range_overlay() -> void:
	var next_visible: bool = not _are_range_overlays_visible()
	_set_all_range_overlays_visible(next_visible)
	_log("Range overlay visible=%s." % str(next_visible))


func _set_all_range_overlays_visible(should_show: bool) -> void:
	var player: Node = _get_player()
	var overlay: CanvasItem = null
	if player != null:
		overlay = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
	if overlay != null:
		overlay.visible = should_show
	_sync_enemy_attack_range_overlays(should_show)
	_set_range_overlays_visible(should_show)


func _sync_enemy_attack_range_overlays(should_show: bool) -> void:
	_prune_enemy_attack_range_overlays()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var overlay: CanvasItem = _ensure_enemy_attack_range_overlay(enemy)
		if overlay != null:
			overlay.visible = should_show
			overlay.queue_redraw()


func _ensure_enemy_attack_range_overlay(enemy: Node2D) -> CanvasItem:
	var key: int = enemy.get_instance_id()
	var existing: CanvasItem = _get_valid_enemy_range_overlay(key)
	if existing != null:
		return existing

	var overlay: Node2D = enemy.get_node_or_null("EnemyAttackRangeOverlay") as Node2D
	if overlay == null:
		overlay = EnemyAttackRangeOverlayScript.new() as Node2D
		overlay.name = "EnemyAttackRangeOverlay"
		enemy.add_child(overlay)
	if overlay.has_method("setup"):
		overlay.call("setup", enemy)
	_enemy_range_overlays[key] = overlay
	return overlay as CanvasItem


func _prune_enemy_attack_range_overlays() -> void:
	for key: Variant in _enemy_range_overlays.keys():
		if _get_valid_enemy_range_overlay(int(key)) == null:
			_enemy_range_overlays.erase(key)


func _get_valid_enemy_range_overlay(key: int) -> CanvasItem:
	var value: Variant = _enemy_range_overlays.get(key, null)
	if value == null or not is_instance_valid(value):
		return null
	var overlay: CanvasItem = value as CanvasItem
	if overlay == null or overlay.is_queued_for_deletion():
		return null
	return overlay


func _are_range_overlays_visible() -> bool:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.has_meta("debug_range_overlays_visible"):
		return bool(tree.root.get_meta("debug_range_overlays_visible", false))
	var player: Node = _get_player()
	var overlay: CanvasItem = null
	if player != null:
		overlay = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
	return overlay != null and overlay.visible


func _set_range_overlays_visible(visible: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_range_overlays_visible", visible)


func _print_state() -> void:
	var text: String = _build_state_text()
	print_rich("[color=cyan][DevDebug][/color]\n%s" % text)
	_log("Printed state.")


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
	var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
	var button: Button = Button.new()
	button.name = "GodSkillCard_%s" % _string_or(skill_id, "")
	button.set_meta("skill_index", skill_index)
	button.text = _format_god_skill_card_text(skill)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 118)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = _string_or(skill.get("description", ""), "")
	UIButtonSkin.apply(button)
	button.pressed.connect(Callable(self, "_on_god_skill_card_pressed").bind(skill_id))
	parent.add_child(button)


func _format_god_skill_card_text(skill: Dictionary) -> String:
	var title: String = _string_or(skill.get("display_name", skill.get("id", "")), "")
	var description: String = _string_or(skill.get("description", ""), "")
	var vfx_description: String = _string_or(skill.get("vfx_description", ""), "")
	var effect_description: String = _get_god_skill_effect_description(skill)
	return "%s\n描述：%s\n特效：%s\n效果：%s" % [
		title,
		description,
		vfx_description,
		effect_description
	]


func _get_god_skill_effect_description(skill: Dictionary) -> String:
	var effect_description: String = _string_or(skill.get("effect_description", ""), "")
	if effect_description != "":
		return effect_description
	var summary: String = String(SkillEffectSummaryBuilderScript.build_for_skill(skill))
	if summary != "":
		return summary
	return "No effect summary."


func _on_god_skill_card_pressed(skill_id: StringName) -> void:
	_select_god_skill_card(skill_id)
	await _run_god_skill_card(skill_id)


func _select_god_skill_card(skill_id: StringName) -> void:
	_selected_god_skill_id = skill_id
	_log("God skill card selected: %s." % _string_or(skill_id, ""))


func debug_select_god_skill_cards(god_id: StringName) -> Dictionary:
	_select_god_skill_cards(god_id)
	var button_summary: Dictionary = _build_god_skill_button_summary(god_id)
	return {
		"god_id": god_id,
		"card_count": _god_skill_definitions.size(),
		"button_count": _god_skill_buttons.size(),
		"button_ids": button_summary.get("button_ids", []),
		"button_tree_count": int(button_summary.get("button_tree_count", 0)),
		"selected_button_pressed": bool(button_summary.get("selected_button_pressed", false))
	}


func _build_god_skill_button_summary(selected_god_id: StringName) -> Dictionary:
	var button_ids: Array[String] = []
	var button_tree_count: int = 0
	var selected_button_pressed: bool = false
	for button_id_variant: Variant in _god_skill_buttons.keys():
		var button_id: StringName = StringName(_string_or(button_id_variant, ""))
		var button: Button = _god_skill_buttons[button_id_variant] as Button
		button_ids.append(_string_or(button_id, ""))
		if button != null and button.is_inside_tree():
			button_tree_count += 1
		if button_id == selected_god_id and button != null:
			selected_button_pressed = button.button_pressed
	return {
		"button_ids": button_ids,
		"button_tree_count": button_tree_count,
		"selected_button_pressed": selected_button_pressed
	}


func debug_run_god_skill_chain(skill_id: StringName) -> Dictionary:
	return await _run_god_skill_card(skill_id)


func _run_god_skill_card(skill_id: StringName) -> Dictionary:
	_select_god_skill_card(skill_id)
	if skill_id == &"":
		return {"skill_id": skill_id, "option_generated": false, "granted": false, "error": "Missing skill id."}
	var option: Dictionary = _get_god_skill_option(skill_id)
	if option.is_empty():
		var fallback: Dictionary = _build_fire_skill_chain_result(skill_id)
		fallback["option_generated"] = false
		fallback["error"] = "No god skill debug option for %s." % _string_or(skill_id, "")
		_update_fire_skill_chain_log(fallback)
		return fallback
	var selected_skill_id: StringName = _get_option_learn_skill_id(option)
	var result: Dictionary = _build_fire_skill_chain_result(selected_skill_id)
	result["option_generated"] = true
	result["option_id"] = _string_or(option.get("id", ""), "")
	result["granted"] = _grant_fire_skill_option(option)
	if not bool(result.get("granted", false)):
		result["error"] = "Could not grant %s." % _string_or(selected_skill_id, "")
		_update_fire_skill_chain_log(result)
		return result
	_mark_god_skill_chain_no_target(result)
	var cast_result: Dictionary = await _cast_fire_skill_once(selected_skill_id, 0)
	_apply_god_skill_cast_result(result, cast_result, selected_skill_id, option)
	_update_fire_skill_chain_log(result)
	return result


func _mark_god_skill_chain_no_target(result: Dictionary) -> void:
	result["target_spawned"] = false
	result["silent_no_target_allowed"] = true


func _apply_god_skill_cast_result(result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary) -> void:
	for key_variant: Variant in cast_result.keys():
		result[key_variant] = cast_result[key_variant]
	result["skill_id"] = selected_skill_id
	result["option_id"] = _string_or(option.get("id", ""), "")
	result["option_generated"] = true
	result["granted"] = true
	_mark_god_skill_chain_no_target(result)


func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	_select_god_skill_cards(&"fire")
	return await debug_run_god_skill_chain(skill_id)


func _run_selected_fire_skill_chain() -> void:
	var result: Dictionary = await debug_run_fire_skill_chain(_get_selected_id(_fire_skill_option))
	_log("Fire skill chain %s: %s." % [
		String(result.get("skill_id", "")),
		"ok" if _is_fire_skill_chain_result_healthy(result) else "needs attention"
	])


func _grant_selected_fire_skill() -> void:
	var option: Dictionary = _get_selected_fire_skill_option()
	if option.is_empty():
		_log_warn("No fire skill option selected.")
		return
	var granted: bool = _grant_fire_skill_option(option)
	_update_fire_skill_chain_log({
		"skill_id": _get_option_learn_skill_id(option),
		"option_id": _string_or(option.get("id", ""), ""),
		"option_generated": true,
		"granted": granted
	})
	_log("Grant fire skill %s: %s." % [_string_or(_get_option_learn_skill_id(option), ""), str(granted)])


func _cast_selected_fire_skill() -> void:
	var option: Dictionary = _get_selected_fire_skill_option()
	if option.is_empty():
		_log_warn("No fire skill option selected.")
		return
	var skill_id: StringName = _get_option_learn_skill_id(option)
	var granted: bool = _grant_fire_skill_option(option)
	if not granted:
		_update_fire_skill_chain_log({"skill_id": skill_id, "option_generated": true, "granted": false})
		_log_warn("Cannot cast %s: grant failed." % _string_or(skill_id, ""))
		return
	var cast_result: Dictionary = await _cast_fire_skill_once(skill_id)
	cast_result["option_generated"] = true
	cast_result["granted"] = true
	_update_fire_skill_chain_log(cast_result)
	_log("Cast fire skill %s; cast_count=%d damage_records=%d." % [
		_string_or(skill_id, ""),
		int(cast_result.get("cast_count", 0)),
		int(cast_result.get("damage_record_count", 0))
	])


func _spawn_fire_skill_debug_target() -> Node2D:
	var player: Node2D = _get_player() as Node2D
	if player == null or player.get_parent() == null:
		_log_error("Player missing.")
		return null
	var enemy_id: StringName = _get_selected_id(_enemy_option)
	if enemy_id == &"":
		enemy_id = &"small_slime"
	var target_position: Vector2 = player.global_position + Vector2(150.0, 0.0)
	var enemy: Node2D = _spawn_debug_enemy(enemy_id, target_position, player.get_parent(), false)
	if enemy != null:
		enemy.set_meta("debug_fire_skill_target", true)
		_set_enemy_state_override("idle")
		_log("Spawned fire skill target: %s." % String(enemy_id))
	return enemy


func _grant_fire_skill_option(option: Dictionary) -> bool:
	var player: Node = _get_player()
	if player == null:
		return false
	var skill_id: StringName = _get_option_learn_skill_id(option)
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager != null and skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
		return true

	var option_id: StringName = StringName(_string_or(option.get("id", ""), ""))
	if option_id != &"" and player.has_method("apply_upgrade"):
		player.call("apply_upgrade", option_id)
		if skill_manager != null and skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
			return true

	if skill_manager != null and skill_manager.has_method("add_skill"):
		var added: bool = bool(skill_manager.call("add_skill", skill_id))
		if added:
			if player.has_method("_refresh_skill_configs"):
				player.call("_refresh_skill_configs")
			if player.has_method("_refresh_synergies"):
				player.call("_refresh_synergies")
			return true
	return false


func _cast_fire_skill_once(skill_id: StringName, max_damage_wait_frames: int = 120) -> Dictionary:
	var result: Dictionary = _build_fire_skill_chain_result(skill_id)
	var player: Node = _get_player()
	if player == null:
		result["error"] = "Player missing."
		return result

	var root: Node = get_tree().root if get_tree() != null else null
	var particle_count_before: int = _count_particle_nodes(root)
	var damage_popup_count_before: int = _count_damage_popup_nodes(root)
	DebugCombatTraceScript.clear(root)
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	_attack_damage_card_index = 0
	_reset_attack_damage_scroll()

	var cast_count: int = _cast_player_skill_once(skill_id, trace_id)
	result["trace_id"] = trace_id
	result["cast_count"] = maxi(cast_count, 0)
	await _wait_debug_frames(2, false)
	var immediate_particle_delta: int = maxi(_count_particle_nodes(root) - particle_count_before, 0)
	if max_damage_wait_frames > 0:
		await _wait_for_fire_skill_damage_record(skill_id, trace_id, max_damage_wait_frames)
	await _wait_debug_frames(6, false)

	var records: Array = DebugCombatTraceScript.get_records(root)
	var selected_damage_count: int = _count_damage_records(records, skill_id, trace_id)
	var all_damage_count: int = _count_damage_records(records, &"", trace_id)
	var final_particle_delta: int = maxi(_count_particle_nodes(root) - particle_count_before, 0)
	var damage_popup_delta: int = maxi(_count_damage_popup_nodes(root) - damage_popup_count_before, 0)
	result["damage_record_count"] = selected_damage_count
	result["selected_damage_record_count"] = selected_damage_count
	result["all_damage_record_count"] = all_damage_count
	result["particle_count"] = maxi(immediate_particle_delta, final_particle_delta)
	result["damage_popup_count"] = damage_popup_delta
	_refresh_attack_damage_text()
	return result


func _cast_player_skill_once(skill_id: StringName, trace_id: int = 0) -> int:
	var player: Node = _get_player()
	if player == null:
		_log_error("Player missing.")
		return -1

	var executor: Node = player.get_node_or_null("SkillExecutor")
	if executor == null:
		_log_error("SkillExecutor missing.")
		return -1
	if executor.has_method("debug_cast_skill"):
		return int(executor.call("debug_cast_skill", skill_id, trace_id))
	_log_error("SkillExecutor debug_cast_skill missing.")
	return -1


func _wait_for_fire_skill_damage_record(skill_id: StringName, trace_id: int, max_physics_frames: int) -> void:
	var root: Node = get_tree().root if get_tree() != null else null
	for _frame_index: int in range(maxi(max_physics_frames, 0)):
		await get_tree().physics_frame
		var records: Array = DebugCombatTraceScript.get_records(root)
		for record_variant: Variant in records:
			if not (record_variant is Dictionary):
				continue
			var record: Dictionary = record_variant
			if int(record.get("trace_id", 0)) != trace_id:
				continue
			if String(record.get("type", "")) != "damage":
				continue
			if skill_id == &"" or StringName(String(record.get("source_skill_id", ""))) == skill_id:
				return


func _prepare_fire_skill_debug_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set("max_health", 240)
	target.set("current_health", 240)
	var player: Node2D = _get_player() as Node2D
	if player != null:
		target.global_position = player.global_position + Vector2(150.0, 0.0)
	if target.has_signal(&"health_changed"):
		target.emit_signal(&"health_changed", 240, 240)


func _build_fire_skill_chain_result(skill_id: StringName) -> Dictionary:
	return {
		"skill_id": skill_id,
		"option_id": "",
		"option_generated": false,
		"granted": false,
		"target_spawned": false,
		"trace_id": 0,
		"cast_count": 0,
		"damage_record_count": 0,
		"selected_damage_record_count": 0,
		"particle_count": 0,
		"damage_popup_count": 0
	}


func _get_selected_fire_skill_option() -> Dictionary:
	return _get_fire_skill_option(_get_selected_id(_fire_skill_option))


func _get_fire_skill_option(skill_id: StringName) -> Dictionary:
	if _debug_fire_skill_options.is_empty():
		_debug_fire_skill_options = _build_debug_fire_skill_options()
	for option: Dictionary in _debug_fire_skill_options:
		if _get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}


func _get_god_skill_option(skill_id: StringName) -> Dictionary:
	if _god_skill_options.is_empty():
		_god_skill_options = _build_debug_god_skill_options(_selected_god_id)
	for option: Dictionary in _god_skill_options:
		if _get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}


func _get_option_learn_skill_id(option: Dictionary) -> StringName:
	var payload: Dictionary = _get_dictionary(option.get("payload", {}))
	if payload.has("learn_skill_id"):
		return StringName(_string_or(payload.get("learn_skill_id", ""), ""))
	var option_id: String = _string_or(option.get("id", ""), "")
	if option_id.begins_with("level_up_upgrade:"):
		var upgrade_id: StringName = StringName(option_id.substr("level_up_upgrade:".length()))
		var upgrade: Dictionary = GameData.get_upgrade(upgrade_id)
		return StringName(_string_or(upgrade.get("learn_skill_id", ""), ""))
	return &""


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
	if _fire_skill_chain_log_label == null:
		return
	var lines: Array[String] = [
		"Fire skill chain: %s" % String(result.get("skill_id", "")),
		"option=%s granted=%s target=%s" % [str(result.get("option_generated", false)), str(result.get("granted", false)), str(result.get("target_spawned", false))],
		"cast=%d damage=%d particles=%d popups=%d" % [
			int(result.get("cast_count", 0)),
			int(result.get("damage_record_count", 0)),
			int(result.get("particle_count", 0)),
			int(result.get("damage_popup_count", 0))
		]
	]
	if result.has("error"):
		lines.append("error=%s" % String(result.get("error", "")))
	_fire_skill_chain_log_label.text = "\n".join(lines)


func _is_fire_skill_chain_result_healthy(result: Dictionary) -> bool:
	return bool(result.get("option_generated", false)) \
		and bool(result.get("granted", false)) \
		and int(result.get("cast_count", 0)) >= 1 \
		and int(result.get("damage_record_count", 0)) >= 1 \
		and int(result.get("particle_count", 0)) >= 1 \
		and int(result.get("damage_popup_count", 0)) >= 1


func _refresh_attack_damage_text() -> void:
	_last_attack_damage_text = _build_attack_damage_text()
	if _attack_damage_label != null:
		_attack_damage_label.text = _last_attack_damage_text


func _reset_attack_damage_scroll() -> void:
	if _attack_damage_scroll == null:
		return
	_attack_damage_scroll.scroll_horizontal = 0
	_attack_damage_scroll.scroll_vertical = 0


func _get_attack_damage_record_count() -> int:
	return _get_attack_damage_records().size()


func _get_current_attack_damage_record_text() -> String:
	var records: Array[Dictionary] = _get_attack_damage_records()
	if records.is_empty():
		return ""

	_attack_damage_card_index = clampi(_attack_damage_card_index, 0, records.size() - 1)
	return _format_record_dump(records[_attack_damage_card_index])


func _get_attack_damage_records() -> Array[Dictionary]:
	var root: Node = get_tree().root if get_tree() != null else null
	var records: Array = DebugCombatTraceScript.get_records(root)
	var damage_records: Array[Dictionary] = []
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		damage_records.append(record)
	return damage_records


func _build_attack_damage_text() -> String:
	var root: Node = get_tree().root if get_tree() != null else null
	var trace_id: int = DebugCombatTraceScript.current_attack_trace_id(root)
	var records: Array = DebugCombatTraceScript.get_records(root)
	var display_records: Array[Dictionary] = _get_attack_damage_records()
	var damage_records: Array[Dictionary] = display_records
	var explosion_count: int = _count_explosion_records(records)
	var has_explosion_record: bool = explosion_count > 0

	if trace_id <= 0:
		return "Damage Breakdown: no attack trace."
	if display_records.is_empty():
		return "Damage Breakdown\nTrace #%d waiting for hit... Explosions=%d" % [trace_id, explosion_count]
	_attack_damage_card_index = clampi(_attack_damage_card_index, 0, display_records.size() - 1)

	var target_summary: Dictionary = _group_damage_records_by_target(damage_records)
	var target_groups: Dictionary = _get_dictionary(target_summary.get("groups", {}))
	var target_order: Array[String] = _to_string_array(target_summary.get("order", []))

	var lines: Array[String] = ["Damage Breakdown"]
	lines.append("Card %d/%d" % [_attack_damage_card_index + 1, display_records.size()])
	for target_index: int in range(target_order.size()):
		var target_name: String = target_order[target_index]
		var target_records: Array = _get_array(target_groups.get(target_name, []))
		if target_index > 0:
			lines.append("")
		lines.append("敌人：%s" % target_name)
		lines.append("trace: %d" % target_records.size())
		lines.append("构成：%s" % _build_damage_component_summary(target_records, has_explosion_record))
	lines.append("")
	lines.append(_format_record_dump(display_records[_attack_damage_card_index]))
	return "\n".join(lines)


func _count_explosion_records(records: Array) -> int:
	var explosion_count: int = 0
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "explosion":
			explosion_count += 1
	return explosion_count


func _group_damage_records_by_target(records: Array[Dictionary]) -> Dictionary:
	var target_groups: Dictionary = {}
	var target_order: Array[String] = []
	for record: Dictionary in records:
		var target_name: String = String(record.get("target", "target"))
		if not target_groups.has(target_name):
			target_groups[target_name] = []
			target_order.append(target_name)
		var target_records: Array = _get_array(target_groups.get(target_name, []))
		target_records.append(record)
		target_groups[target_name] = target_records
	return {
		"groups": target_groups,
		"order": target_order
	}


func _build_damage_component_summary(records: Array, includes_explosion: bool = false) -> String:
	var seen: Dictionary = {}
	if includes_explosion:
		seen["爆炸伤害"] = true
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		seen[_damage_component_label(record)] = true

	var ordered_labels: Array[String] = []
	for label: String in ["爆炸伤害", "主攻击伤害", "区域伤害", "反应伤害", "持续伤害"]:
		if bool(seen.get(label, false)):
			ordered_labels.append(label)
			seen.erase(label)

	var remaining_labels: Array[String] = []
	for label_variant: Variant in seen.keys():
		remaining_labels.append(String(label_variant))
	remaining_labels.sort()
	ordered_labels.append_array(remaining_labels)
	return "+".join(ordered_labels) if not ordered_labels.is_empty() else "未知伤害"


func _damage_component_label(record: Dictionary) -> String:
	var source_type: String = String(record.get("source_type", ""))
	var damage_origin: String = String(record.get("damage_origin", ""))
	var source_skill_id: String = String(record.get("source_skill_id", ""))
	var special_label: String = _legacy_skill_damage_component_label(source_skill_id)
	if special_label != "":
		return special_label
	if source_type == "explosion" or source_skill_id.find("explosion") >= 0:
		return "爆炸伤害"
	if damage_origin == "primary_attack" or source_type == "projectile" or source_type == "skill":
		return "主攻击伤害"
	if source_type == "area":
		return "区域伤害"
	if damage_origin == "reaction":
		return "反应伤害"
	if source_type == "dot":
		return "持续伤害"
	return "%s伤害" % source_type if not source_type.is_empty() else "未知伤害"


func _legacy_skill_damage_component_label(source_skill_id: String) -> String:
	if source_skill_id.find("fireball_burning_death_explosion") >= 0:
		return "爆裂小爆炸"
	if source_skill_id.find("soulburn_burst") >= 0:
		return "灼魂爆发"
	if source_skill_id.find("flame_core_burst") >= 0:
		return "聚核爆发"
	if source_skill_id.find("frost_lock_bonus_hit") >= 0:
		return "极寒直击"
	if source_skill_id.find("frost_core_crack") >= 0:
		return "极寒裂核"
	if source_skill_id.find("shatter") >= 0:
		return "碎冰伤害"
	if source_skill_id.find("lightning_overload") >= 0:
		return "过载伤害"
	if source_skill_id.find("lightning_shock_consume_reaction") >= 0:
		return "感电伤害"
	if source_skill_id.find("lightning_magnetic_storm") >= 0:
		return "磁暴伤害"
	if source_skill_id.find("arcane_seal_burst") >= 0:
		return "爆印伤害"
	if source_skill_id.find("throwing_knife_execution_burst") >= 0:
		return "处决伤害"
	if source_skill_id.find("throwing_knife_rupture") >= 0:
		return "割裂伤害"
	if source_skill_id.find("hunter_bow_eagle_shot") >= 0:
		return "鹰眼射击"
	if source_skill_id.find("hunter_arrow_hit_explosion") >= 0:
		return "箭矢爆炸"
	if source_skill_id.find("hunter_burst_mark_death_explosion") >= 0:
		return "爆裂小爆炸"
	if source_skill_id.find("trap_pincer_reaction") >= 0:
		return "夹击反应"
	if source_skill_id.find("boss_core_trap_bonus") >= 0:
		return "猎杀夹伤害"
	if source_skill_id.find("decoy_trap_explosion") >= 0:
		return "诱饵爆炸"
	if source_skill_id.find("holy_counter_on_marked_break_hit") >= 0:
		return "圣裁反击"
	if source_skill_id.find("holy_judgement_beam") >= 0:
		return "裁决光束"
	if source_skill_id.find("warhammer_judgement_shock") >= 0:
		return "裁决震荡"
	if source_skill_id.find("warhammer_boss_poise_judgement_bonus") >= 0:
		return "强化裁决"
	if source_skill_id.find("warhammer_execution_shockwave") >= 0:
		return "斩杀震波"
	if source_skill_id.find("cross_relic_echo") >= 0:
		return "信仰回响"
	if source_skill_id.find("cross_relic_faith_judgement") >= 0:
		return "信仰裁决"
	if source_skill_id.find("cross_relic_purify_impurity") >= 0:
		return "净化反应"
	if source_skill_id.find("cross_relic_purify_small_pulse") >= 0:
		return "小圣光脉冲"
	if source_skill_id.find("toxic_core_boss_pulse") >= 0:
		return "剧毒脉冲"
	if source_skill_id.find("poison_death_explosion") >= 0:
		return "毒爆"
	if source_skill_id.find("fire_oil_flammable_burst") >= 0:
		return "易燃爆发"
	if source_skill_id.find("fire_oil_secondary_deflagration") >= 0:
		return "二次爆燃"
	if source_skill_id.find("fire_oil_deflagration") >= 0:
		return "爆燃"
	if source_skill_id.find("acid_burst") >= 0:
		return "酸爆"
	return ""


func _format_record_dump(record: Dictionary) -> String:
	var lines: Array[String] = ["record："]
	_append_dictionary_dump(lines, record, 1)
	return "\n".join(lines)


func _append_dictionary_dump(lines: Array[String], dictionary: Dictionary, indent_level: int) -> void:
	var keys: Array[String] = []
	for key_variant: Variant in dictionary.keys():
		keys.append(String(key_variant))
	keys.sort()
	for key: String in keys:
		_append_record_value_line(lines, key, dictionary.get(key), indent_level)


func _append_array_dump(lines: Array[String], items: Array, indent_level: int) -> void:
	for index in range(items.size()):
		_append_record_value_line(lines, "- %d" % index, items[index], indent_level)


func _append_record_value_line(lines: Array[String], key: String, value: Variant, indent_level: int) -> void:
	var prefix: String = _record_indent(indent_level)
	if value is Dictionary:
		lines.append("%s%s:" % [prefix, key])
		_append_dictionary_dump(lines, value as Dictionary, indent_level + 1)
		return
	if value is Array:
		var items: Array = value
		if items.is_empty():
			lines.append("%s%s: []" % [prefix, key])
			return
		lines.append("%s%s:" % [prefix, key])
		_append_array_dump(lines, items, indent_level + 1)
		return
	lines.append("%s%s: %s" % [prefix, key, _format_record_value(value)])


func _record_indent(indent_level: int) -> String:
	var text: String = ""
	for _index in range(maxi(indent_level, 0)):
		text += "  "
	return text


func _format_record_value(value: Variant) -> String:
	if value is String or value is StringName:
		return String(value)
	return str(value)


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
	var player: Node = _get_player()
	if player == null:
		return "Calculated Player Attributes: none"

	var effective_move_speed: float = float(player.get("move_speed"))
	if player.has_method("_get_effective_move_speed"):
		effective_move_speed = float(player.call("_get_effective_move_speed"))

	var lines: Array[String] = [
		"Calculated Player Attributes",
		"HP %d/%d  Lv.%d  EXP %d/%d" % [
			int(player.get("current_health")),
			int(player.get("max_health")),
			int(player.get("level")),
			int(player.get("current_experience")),
			int(player.get("experience_to_next_level"))
		],
		"MoveSpeed %.1f effective / %.1f base  Pickup %.1f / %.1f base" % [
			effective_move_speed,
			float(player.get("move_speed")),
			_get_player_effective_pickup_radius(player),
			float(player.get("pickup_radius"))
		],
		"Damage x%.3f  AttackSpeed x%.3f  Crit %.1f%% / x%.2f  Armor %d" % [
			float(player.get("damage_multiplier")),
			float(player.get("attack_speed_multiplier")),
			float(player.get("crit_chance")) * 100.0,
			float(player.get("crit_damage")),
			int(player.get("armor"))
		],
		"Taken x%.3f  Area x%.3f  StatusDuration x%.3f" % [
			float(player.get("damage_taken_multiplier")),
			float(player.get("skill_area_multiplier")),
			float(player.get("status_duration_multiplier"))
		],
		"Gain EXP x%.3f  Coin x%.3f  Soul x%.3f" % [
			float(player.get("experience_gain_multiplier")),
			float(player.get("coin_gain_multiplier")),
			float(player.get("soul_gain_multiplier"))
		],
		"ElementAdd fire %.3f  poison %.3f" % [
			float(player.get("fire_damage_multiplier_add")),
			float(player.get("poison_damage_multiplier_add"))
		],
		"Slow chance +%.1f%%  slow %.1f%% / %.1fs  Aura %s %.1f" % [
			float(player.get("on_hit_slow_chance_add")) * 100.0,
			float(player.get("slow_percent")) * 100.0,
			float(player.get("slow_duration")),
			str(bool(player.get("aura_slow_enabled"))),
			float(player.get("aura_radius"))
		],
		"Thorns %d / radius %.1f  Revive +%d / %.1f%% HP" % [
			int(player.get("thorns_damage")),
			float(player.get("thorns_area_radius")),
			int(player.get("revive_count_add")),
			float(player.get("revive_hp_percent")) * 100.0
		],
		"RewardWeight rare +%.2f  epic +%.2f  legendary +%.2f  Rerolls %d" % [
			float(player.get("rare_weight_add")),
			float(player.get("epic_weight_add")),
			float(player.get("legendary_weight_add")),
			int(player.get("level_up_rerolls"))
		],
		"RunModifier spawn_count +%.3f  boss_hp +%.3f" % [
			float(player.get("enemy_spawn_count_multiplier_add")),
			float(player.get("boss_hp_multiplier_add"))
		]
	]

	var skill: RefCounted = _get_starting_skill(player)
	if skill != null:
		var skill_manager: Node = _get_skill_manager(player)
		var relic_manager: Node = player.get_node_or_null("RelicManager")
		var skill_modifiers: Dictionary = SkillStatServiceScript.get_combined_modifiers(skill, skill_manager, relic_manager)
		var primary_attack_speed: float = maxf(float(player.get("attack_speed_multiplier")), 0.05)
		primary_attack_speed *= maxf(float(skill_modifiers.get("attack_speed_multiplier", 1.0)), 0.05)
		primary_attack_speed += float(skill_modifiers.get("attack_speed_multiplier_add", 0.0))
		primary_attack_speed = maxf(primary_attack_speed, 0.1)
		var primary_crit_chance: float = clampf(float(player.get("crit_chance")) + float(skill_modifiers.get("crit_chance_add", 0.0)), 0.0, 1.0)
		var effective_cooldown: Variant = SkillStatServiceScript.get_effective_stat(skill, "cooldown", null, skill_manager, relic_manager, player)
		var projectile_speed: Variant = SkillStatServiceScript.get_effective_stat(skill, "projectile_speed", null, skill_manager, relic_manager, player)
		if effective_cooldown != null:
			lines.append("Primary AttackSpeed x%.3f  Cooldown %.3fs  Crit %.1f%%" % [
				primary_attack_speed,
				float(effective_cooldown),
				primary_crit_chance * 100.0
			])
		if projectile_speed != null:
			lines.append("ProjectileSpeed %.1f" % float(projectile_speed))

	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	if runtime != null:
		var trait_state: Variant = runtime.get("trait_runtime_state")
		if trait_state is Dictionary:
			var state: Dictionary = trait_state
			lines.append("Trait %s type=%s stacks=%d casts=%d moving=%.1f stopped=%.1f shield=%d/%.1fs" % [
				String(state.get("trait_id", "")),
				String(state.get("trait_type", "")),
				int(state.get("stack_count", 0)),
				int(state.get("cast_count", 0)),
				float(state.get("moving_time", 0.0)),
				float(state.get("stopped_time", 0.0)),
				int(state.get("shield_points", 0)),
				float(state.get("shield_remaining_seconds", 0.0))
			])

	var status_snapshot: Array = _get_status_snapshot(player)
	lines.append("Status %s" % _format_statuses(status_snapshot))
	return "\n".join(lines)


func _build_state_text() -> String:
	var player: Node = _get_player()
	if player == null:
		var selected_fields: Array[String] = _build_selected_setup_fields(&"")
		if selected_fields.is_empty():
			return "Player: none"
		selected_fields.push_front("Player=none")
		return _format_summary_fields(selected_fields)

	var current_character_id: StringName = StringName(String(player.get("selected_character_id")))
	var selected_character_id: StringName = _get_selected_id(_character_option)
	var display_character_id: StringName = selected_character_id if selected_character_id != &"" else current_character_id
	var fields: Array[String] = [
		"Character=%s" % String(display_character_id),
		"HP=%d/%d" % [int(player.get("current_health")), int(player.get("max_health"))],
		"Level=%d" % int(player.get("level")),
		"MoveSpeed=%.1f" % _get_player_effective_move_speed(player),
		"Paused=%s" % str(get_tree().paused),
		"AutoPaused=%s" % str(_is_debug_control_mode()),
		"AttackDisabled=%s" % str(_is_player_attack_disabled()),
		"EnemyMode=%s" % _format_enemy_state_override(),
		"Enemies=%d" % get_tree().get_nodes_in_group(&"enemy").size()
	]

	fields.append_array(_build_selected_setup_fields(current_character_id))

	var skill: RefCounted = _get_starting_skill(player)
	if skill != null:
		fields.append_array(_build_skill_fields(player, skill))

	var enemy: Node = _get_nearest_enemy()
	if enemy != null:
		fields.append("Nearest=%s" % String(enemy.get("enemy_id")))
		if enemy.has_method("get_runtime_state"):
			fields.append("EnemyState=%s" % String(enemy.call("get_runtime_state")))
		fields.append("EnemyHP=%d/%d" % [int(enemy.get("current_health")), int(enemy.get("max_health"))])
		fields.append("EnemyArmor=%d" % int(enemy.get("armor")))
		fields.append("EnemyRange=%.1f" % _get_enemy_attack_range(enemy))
		fields.append("EnemyStatus=%s" % _format_statuses(_get_status_snapshot(enemy)))
	fields.append("PlayerStatus=%s" % _format_statuses(_get_status_snapshot(player)))
	return _format_summary_fields(fields)


func _build_selected_setup_fields(current_character_id: StringName) -> Array[String]:
	var fields: Array[String] = []
	var selected_character_id: StringName = _get_selected_id(_character_option)
	var selected_map_id: StringName = _get_selected_id(_map_option)
	if selected_character_id != &"" and selected_character_id != current_character_id:
		var character_key: String = "RunCharacter" if current_character_id != &"" else "SelectedCharacter"
		var character_value: StringName = current_character_id if current_character_id != &"" else selected_character_id
		fields.append("%s=%s" % [character_key, String(character_value)])
	if selected_map_id != &"":
		fields.append("SelectedMap=%s" % String(selected_map_id))
	return fields


func _build_skill_fields(player: Node, skill: RefCounted) -> Array[String]:
	var skill_manager: Node = _get_skill_manager(player)
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	var parts: Array[String] = [
		"Skill=%s" % _string_or(skill.get("skill_id"), ""),
		"SkillLevel=%d" % int(skill.get("current_level"))
	]
	for stat_name: String in ["damage", "cooldown", "projectile_speed", "area_radius", "range", "projectile_count"]:
		var value: Variant = SkillStatServiceScript.get_effective_stat(skill, stat_name, null, skill_manager, relic_manager, player)
		if value != null:
			var label: String = "ProjectileSpeed" if stat_name == "projectile_speed" else stat_name
			parts.append("%s=%s" % [label, str(value)])
	return parts


func _get_player_effective_move_speed(player: Node) -> float:
	if player == null:
		return 0.0
	if player.has_method("_get_effective_move_speed"):
		return float(player.call("_get_effective_move_speed"))
	return float(player.get("move_speed"))


func _get_player_effective_pickup_radius(player: Node) -> float:
	if player == null:
		return 0.0
	if player.has_method("get_effective_pickup_radius"):
		return float(player.call("get_effective_pickup_radius"))
	return float(player.get("pickup_radius"))


func _format_summary_fields(fields: Array[String]) -> String:
	var lines: Array[String] = []
	var row: Array[String] = []
	for field: String in fields:
		row.append(field)
		if row.size() >= 3:
			lines.append("  ".join(row))
			row.clear()
	if not row.is_empty():
		lines.append("  ".join(row))
	return "\n".join(lines)


func _format_statuses(statuses: Array) -> String:
	if statuses.is_empty():
		return "statuses:none"
	var parts: Array[String] = []
	for status_variant: Variant in statuses:
		if status_variant is Dictionary:
			var status: Dictionary = status_variant
			var status_id: String = String(status.get("id", ""))
			var stacks: int = int(status.get("stacks", 0))
			var tick_damage: float = float(status.get("tick_damage_total", 0.0))
			if tick_damage <= 0.0:
				tick_damage = float(status.get("tick_damage", 0.0)) * float(maxi(stacks, 1))
			var duration_remaining: float = maxf(float(status.get("duration_remaining", 0.0)), 0.0)
			parts.append("%s(%d, %.1f, %.1fs)" % [
				_debug_status_short_name(status_id),
				stacks,
				tick_damage,
				duration_remaining
			])
	return "statuses:%s" % ",".join(parts)


func _debug_status_short_name(status_id: String) -> String:
	match status_id:
		"soul_ember":
			return "Embr"
		"flame_core":
			return "Core"
		"frost_lock":
			return "Lock"
		"frostbite":
			return "Fbt"
		"voltage":
			return "Volt"
		"arcane_seal":
			return "Seal"
		"eagle_mark":
			return "Egl"
		"burst_mark":
			return "Bst"
		"prey_mark":
			return "Prey"
		"holy_mark":
			return "Hol"
		"judgment":
			return "Jdg"
		"impurity":
			return "Imp"
		"toxin_seed":
			return "Seed"
		"toxic_core":
			return "TCore"
		"flammable_mark":
			return "Fla"
		"oil_stack":
			return "Oil"
		"acid_mark":
			return "Acid"
		"acid_residue":
			return "ARes"
		_:
			return status_id


func _get_status_snapshot(target: Node) -> Array:
	if target != null and target.has_method("get_status_snapshot"):
		return target.call("get_status_snapshot")
	var manager: Node = target.get_node_or_null("StatusEffectManager") if target != null else null
	if manager != null and manager.has_method("get_status_snapshot"):
		return manager.call("get_status_snapshot")
	return []


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
	if _enemy_state_option == null:
		return

	var allow_elite_states: bool = _can_apply_elite_enemy_state_to_nearest()
	for index in range(_enemy_state_option.item_count):
		var state: String = _normalize_enemy_forced_state(String(_enemy_state_option.get_item_metadata(index)))
		_enemy_state_option.set_item_disabled(index, _is_elite_only_enemy_state(state) and not allow_elite_states)

	var current_state: String = _get_enemy_state_override()
	if _is_elite_only_enemy_state(current_state) and not allow_elite_states:
		_set_enemy_state_override("")
		_select_option_by_id(_enemy_state_option, "")


func _can_apply_elite_enemy_state_to_nearest() -> bool:
	var enemy: Node = _get_nearest_enemy()
	return enemy != null and _is_elite_state_debug_enemy(enemy)


func _is_elite_state_debug_enemy(enemy: Node) -> bool:
	if enemy == null:
		return false
	var rank: String = String(enemy.get_meta("enemy_rank", enemy.get_meta("enemy_type", "normal")))
	return rank == "elite" or rank == "boss"


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
