extends RefCounted

const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/runtime/debug_combat_trace.gd")
const StatusShortNameFormatterScript: Script = preload("res://scripts/ui/status_short_name_formatter.gd")

var _host_ref: WeakRef

func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


func _build_runtime_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var runtime_page: VBoxContainer = host._add_category_page(page_root, "runtime", "Runtime")
	var runtime_row: HBoxContainer = host._add_row(runtime_page)
	host._add_button(runtime_row, "Pause Game", Callable(host, "_toggle_tree_pause"), 112)
	host._add_button(runtime_row, "Auto On/Off", Callable(host, "_toggle_auto_combat"), 112)
	var attack_row: HBoxContainer = host._add_row(runtime_page)
	host._add_button(attack_row, "Manual Attack", Callable(host, "_manual_cast_player_skills"), 120)
	host._add_button(attack_row, "Attack On/Off", Callable(host, "_toggle_player_attack_disabled"), 120)
	var attack_trace_row: HBoxContainer = host._add_row(runtime_page)
	host._add_button(attack_trace_row, "Attack Once", Callable(host, "_attack_once_player_skills"), 112)
	host._add_button(attack_trace_row, "Clear Attack Trace", Callable(host, "_clear_attack_trace"), 156)
	var attack_trace_nav_row: HBoxContainer = host._add_row(runtime_page)
	host._add_button(attack_trace_nav_row, "Prev Card", Callable(host, "_show_previous_attack_damage_card"), 112)
	host._add_button(attack_trace_nav_row, "Next Card", Callable(host, "_show_next_attack_damage_card"), 112)
	var copy_record_button: Button = host._add_button(attack_trace_nav_row, "Copy Record", Callable(host, "_copy_current_attack_damage_record"), 124)
	copy_record_button.name = "CopyDamageRecordButton"
	host._attack_damage_scroll = ScrollContainer.new()
	host._attack_damage_scroll.name = "AttackDamageCardScroll"
	host._attack_damage_scroll.custom_minimum_size = Vector2(440, 360)
	host._attack_damage_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._attack_damage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host._attack_damage_label = Label.new()
	host._attack_damage_label.name = "AttackDamageBreakdownLabel"
	host._attack_damage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._attack_damage_label.add_theme_font_size_override("font_size", 12)
	host._attack_damage_label.text = host._last_attack_damage_text
	host._attack_damage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._attack_damage_scroll.add_child(host._attack_damage_label)
	runtime_page.add_child(host._attack_damage_scroll)


func _toggle_tree_pause() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host.get_tree().paused = not host.get_tree().paused
	host._log("Game paused=%s." % str(host.get_tree().paused))


func _toggle_auto_combat() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var enabled: bool = not host._is_debug_control_mode()
	host._set_debug_control_mode(enabled)
	if enabled:
		host.get_tree().paused = false
	host._log("Auto combat paused by debug_control_mode=%s." % str(enabled))


func _toggle_player_attack_disabled() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var disabled: bool = not host._is_player_attack_disabled()
	host._set_player_attack_disabled(disabled)
	host._log("Player auto attack disabled=%s." % str(disabled))


func _manual_cast_player_skills() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var cast_count: int = host._cast_player_skills_once()
	if cast_count < 0:
		return
	host._log("Manual attack cast %d skill(s)." % cast_count)


func _attack_once_player_skills() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var root: Node = host.get_tree().root if host.get_tree() != null else null
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	host._attack_damage_card_index = 0
	host._reset_attack_damage_scroll()
	host._last_attack_damage_text = "Damage Breakdown\nTrace #%d waiting for hit..." % trace_id
	host._refresh_attack_damage_text()

	var cast_count: int = host._cast_player_skills_once(trace_id)
	if cast_count < 0:
		return
	if cast_count > 0:
		host._log("Attack once trace #%d cast %d skill(s)." % [trace_id, cast_count])
		return
	host._log("Attack once trace #%d had no runtime skill cast." % trace_id)


func _clear_attack_trace() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var root: Node = host.get_tree().root if host.get_tree() != null else null
	var cleared: int = DebugCombatTraceScript.clear(root)
	host._attack_damage_card_index = 0
	host._reset_attack_damage_scroll()
	host._last_attack_damage_text = "Damage Breakdown: cleared."
	host._refresh_attack_damage_text()
	host._log("Cleared attack trace and %d explosion site overlay(s)." % cleared)


func _show_previous_attack_damage_card() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var record_count: int = host._get_attack_damage_record_count()
	if record_count <= 0:
		host._attack_damage_card_index = 0
	else:
		host._attack_damage_card_index = posmod(host._attack_damage_card_index - 1, record_count)
	host._reset_attack_damage_scroll()
	host._refresh_attack_damage_text()


func _show_next_attack_damage_card() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var record_count: int = host._get_attack_damage_record_count()
	if record_count <= 0:
		host._attack_damage_card_index = 0
	else:
		host._attack_damage_card_index = posmod(host._attack_damage_card_index + 1, record_count)
	host._reset_attack_damage_scroll()
	host._refresh_attack_damage_text()


func _copy_current_attack_damage_record() -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var record_text: String = host._get_current_attack_damage_record_text()
	if record_text == "":
		host._last_copied_attack_damage_record_text = ""
		host._log("No damage record to copy.")
		return false

	DisplayServer.clipboard_set(record_text)
	host._last_copied_attack_damage_record_text = record_text
	host._log("Copied damage record card %d/%d." % [host._attack_damage_card_index + 1, host._get_attack_damage_record_count()])
	return true


func _cast_player_skills_once(trace_id: int = 0) -> int:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		host._log_error("Player missing.")
		return -1

	var executor: Node = player.get_node_or_null("SkillExecutor")
	if executor == null or not executor.has_method("debug_cast_all_skills"):
		host._log_error("SkillExecutor debug_cast_all_skills missing.")
		return -1

	var was_debug_control: bool = host._is_debug_control_mode()
	host._set_debug_control_mode(false)
	var cast_count: int = int(executor.call("debug_cast_all_skills", trace_id))
	host._set_debug_control_mode(was_debug_control)
	return cast_count


func _build_player_stats(parent: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._player_attributes_label = Label.new()
	host._player_attributes_label.name = "CalculatedPlayerAttributesLabel"
	host._player_attributes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._player_attributes_label.add_theme_font_size_override("font_size", 12)
	parent.add_child(host._player_attributes_label)

	var calculated_row: HBoxContainer = host._add_row(parent)
	host._add_button(calculated_row, "Refresh Calculated", Callable(host, "_refresh_state"), 168)

	host._player_stat_spins.clear()
	for config: Dictionary in host._get_player_stat_configs():
		var property: String = String(config.get("property", ""))
		if property == "":
			continue
		host._player_stat_spins[property] = host._add_spin_row(
			parent,
			String(config.get("label", property)),
			float(config.get("min", 0.0)),
			float(config.get("max", 1000.0)),
			float(config.get("step", 1.0)),
			float(config.get("value", 0.0))
		)
	var row: HBoxContainer = host._add_row(parent)
	host._add_button(row, "Apply Player Stats", Callable(host, "_apply_player_stats_from_panel"), 168)
	host._add_button(row, "Sync Player Stats", Callable(host, "_sync_player_stat_controls"), 156)


func _build_skill_stats(parent: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._skill_stat_spins.clear()
	host._skill_stat_active.clear()
	for config: Dictionary in host._get_skill_stat_configs():
		var stat_name: String = String(config.get("stat", ""))
		if stat_name == "":
			continue
		host._skill_stat_spins[stat_name] = host._add_spin_row(
			parent,
			String(config.get("label", stat_name)),
			float(config.get("min", 0.0)),
			float(config.get("max", 10000.0)),
			float(config.get("step", 1.0)),
			float(config.get("value", 0.0))
		)
	var row: HBoxContainer = host._add_row(parent)
	host._add_button(row, "Apply Attack Stats", Callable(host, "_apply_skill_stats_from_panel"), 168)
	host._add_button(row, "Sync Attack Stats", Callable(host, "_sync_skill_stat_controls"), 156)


func _sync_player_stat_controls() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		return
	for config: Dictionary in host._get_player_stat_configs():
		var property: String = String(config.get("property", ""))
		var spin: SpinBox = host._player_stat_spins.get(property, null) as SpinBox
		if spin == null:
			continue
		var value: Variant = player.get(property)
		if value != null:
			spin.value = float(value)


func _sync_skill_stat_controls() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	var skill: RefCounted = host._get_starting_skill(player)
	host._skill_stat_active.clear()
	if player == null or skill == null:
		return

	var skill_manager: Node = host._get_skill_manager(player)
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	for config: Dictionary in host._get_skill_stat_configs():
		var stat_name: String = String(config.get("stat", ""))
		var spin: SpinBox = host._skill_stat_spins.get(stat_name, null) as SpinBox
		if spin == null:
			continue
		var value: Variant = SkillStatServiceScript.get_effective_stat(skill, stat_name, null, skill_manager, relic_manager, player)
		if value == null:
			host._skill_stat_active[stat_name] = false
			if bool(config.get("allow_new", false)):
				spin.editable = true
				spin.modulate = Color.WHITE
				spin.value = float(config.get("value", spin.value))
			else:
				spin.editable = false
				spin.modulate = Color(1.0, 1.0, 1.0, 0.45)
			continue
		host._skill_stat_active[stat_name] = true
		spin.editable = true
		spin.modulate = Color.WHITE
		spin.value = float(value)


func _apply_player_stats_from_panel() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		host._log_error("Player missing.")
		return

	for config: Dictionary in host._get_player_stat_configs():
		var property: String = String(config.get("property", ""))
		var spin: SpinBox = host._player_stat_spins.get(property, null) as SpinBox
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
	host._log("Applied player stats.")


func _apply_skill_stats_from_panel() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	var skill: RefCounted = host._get_starting_skill(player)
	if player == null or skill == null:
		host._log_error("Primary attack missing.")
		return

	var runtime_modifiers: Dictionary = {}
	var runtime_variant: Variant = skill.get("runtime_modifiers")
	if runtime_variant is Dictionary:
		runtime_modifiers = (runtime_variant as Dictionary).duplicate(true)

	var applied: int = 0
	for config: Dictionary in host._get_skill_stat_configs():
		var stat_name: String = String(config.get("stat", ""))
		var spin: SpinBox = host._skill_stat_spins.get(stat_name, null) as SpinBox
		if stat_name == "" or spin == null:
			continue
		if not bool(host._skill_stat_active.get(stat_name, false)) and not bool(config.get("allow_new", false)):
			continue
		runtime_modifiers["%s_override" % stat_name] = roundi(float(spin.value)) if bool(config.get("int", false)) else float(spin.value)
		applied += 1
	skill.set("runtime_modifiers", runtime_modifiers)

	var skill_manager: Node = host._get_skill_manager(player)
	if skill_manager != null and skill_manager.has_signal(&"skill_changed"):
		skill_manager.emit_signal(&"skill_changed")
	host._log("Applied %d primary attack stat override(s)." % applied)


func _get_player_stat_configs() -> Array[Dictionary]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
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


func _refresh_attack_damage_text() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._last_attack_damage_text = host._build_attack_damage_text()
	if host._attack_damage_label != null:
		host._attack_damage_label.text = host._last_attack_damage_text


func _reset_attack_damage_scroll() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._attack_damage_scroll == null:
		return
	host._attack_damage_scroll.scroll_horizontal = 0
	host._attack_damage_scroll.scroll_vertical = 0


func _get_attack_damage_record_count() -> int:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return host._get_attack_damage_records().size()


func _get_current_attack_damage_record_text() -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var records: Array[Dictionary] = host._get_attack_damage_records()
	if records.is_empty():
		return ""

	host._attack_damage_card_index = clampi(host._attack_damage_card_index, 0, records.size() - 1)
	return host._format_record_dump(records[host._attack_damage_card_index])


func _get_attack_damage_records() -> Array[Dictionary]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var root: Node = host.get_tree().root if host.get_tree() != null else null
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var root: Node = host.get_tree().root if host.get_tree() != null else null
	var trace_id: int = DebugCombatTraceScript.current_attack_trace_id(root)
	var records: Array = DebugCombatTraceScript.get_records(root)
	var display_records: Array[Dictionary] = host._get_attack_damage_records()
	var damage_records: Array[Dictionary] = display_records
	var explosion_count: int = host._count_explosion_records(records)
	var has_explosion_record: bool = explosion_count > 0

	if trace_id <= 0:
		return "Damage Breakdown: no attack trace."
	if display_records.is_empty():
		return "Damage Breakdown\nTrace #%d waiting for hit... Explosions=%d" % [trace_id, explosion_count]
	host._attack_damage_card_index = clampi(host._attack_damage_card_index, 0, display_records.size() - 1)

	var target_summary: Dictionary = host._group_damage_records_by_target(damage_records)
	var target_groups: Dictionary = host._get_dictionary(target_summary.get("groups", {}))
	var target_order: Array[String] = host._to_string_array(target_summary.get("order", []))

	var lines: Array[String] = ["Damage Breakdown"]
	lines.append("Card %d/%d" % [host._attack_damage_card_index + 1, display_records.size()])
	for target_index: int in range(target_order.size()):
		var target_name: String = target_order[target_index]
		var target_records: Array = host._get_array(target_groups.get(target_name, []))
		if target_index > 0:
			lines.append("")
		lines.append("敌人：%s" % target_name)
		lines.append("trace: %d" % target_records.size())
		lines.append("构成：%s" % host._build_damage_component_summary(target_records, has_explosion_record))
	lines.append("")
	lines.append(host._format_record_dump(display_records[host._attack_damage_card_index]))
	return "\n".join(lines)


func _count_explosion_records(records: Array) -> int:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var explosion_count: int = 0
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "explosion":
			explosion_count += 1
	return explosion_count


func _group_damage_records_by_target(records: Array[Dictionary]) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var target_groups: Dictionary = {}
	var target_order: Array[String] = []
	for record: Dictionary in records:
		var target_name: String = String(record.get("target", "target"))
		if not target_groups.has(target_name):
			target_groups[target_name] = []
			target_order.append(target_name)
		var target_records: Array = host._get_array(target_groups.get(target_name, []))
		target_records.append(record)
		target_groups[target_name] = target_records
	return {
		"groups": target_groups,
		"order": target_order
	}


func _build_damage_component_summary(records: Array, includes_explosion: bool = false) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var seen: Dictionary = {}
	if includes_explosion:
		seen["爆炸伤害"] = true
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		seen[host._damage_component_label(record)] = true

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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var source_type: String = String(record.get("source_type", ""))
	var damage_origin: String = String(record.get("damage_origin", ""))
	var source_skill_id: String = String(record.get("source_skill_id", ""))
	var special_label: String = host._legacy_skill_damage_component_label(source_skill_id)
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var lines: Array[String] = ["record："]
	host._append_dictionary_dump(lines, record, 1)
	return "\n".join(lines)


func _append_dictionary_dump(lines: Array[String], dictionary: Dictionary, indent_level: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var keys: Array[String] = []
	for key_variant: Variant in dictionary.keys():
		keys.append(String(key_variant))
	keys.sort()
	for key: String in keys:
		host._append_record_value_line(lines, key, dictionary.get(key), indent_level)


func _append_array_dump(lines: Array[String], items: Array, indent_level: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for index in range(items.size()):
		host._append_record_value_line(lines, "- %d" % index, items[index], indent_level)


func _append_record_value_line(lines: Array[String], key: String, value: Variant, indent_level: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var prefix: String = host._record_indent(indent_level)
	if value is Dictionary:
		lines.append("%s%s:" % [prefix, key])
		host._append_dictionary_dump(lines, value as Dictionary, indent_level + 1)
		return
	if value is Array:
		var items: Array = value
		if items.is_empty():
			lines.append("%s%s: []" % [prefix, key])
			return
		lines.append("%s%s:" % [prefix, key])
		host._append_array_dump(lines, items, indent_level + 1)
		return
	lines.append("%s%s: %s" % [prefix, key, host._format_record_value(value)])


func _record_indent(indent_level: int) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var text: String = ""
	for _index in range(maxi(indent_level, 0)):
		text += "  "
	return text


func _format_record_value(value: Variant) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if value is String or value is StringName:
		return String(value)
	return str(value)


func _build_player_attributes_text() -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		return "Calculated Player Attributes: none"

	var lines: Array[String] = host._build_player_core_attribute_lines(player)
	lines.append_array(host._build_starting_skill_attribute_lines(player))
	lines.append_array(host._build_trait_attribute_lines(player))
	var status_snapshot: Array = host._get_status_snapshot(player)
	lines.append("Status %s" % host._format_statuses(status_snapshot))
	return "\n".join(lines)


func _build_player_core_attribute_lines(player: Node) -> Array[String]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var effective_move_speed: float = host._get_player_effective_move_speed(player)
	return [
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
			host._get_player_effective_pickup_radius(player),
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


func _build_starting_skill_attribute_lines(player: Node) -> Array[String]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var lines: Array[String] = []
	var skill: RefCounted = host._get_starting_skill(player)
	if skill != null:
		var skill_manager: Node = host._get_skill_manager(player)
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
	return lines


func _build_trait_attribute_lines(player: Node) -> Array[String]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var lines: Array[String] = []
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
	return lines


func _build_state_text() -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		var selected_fields: Array[String] = host._build_selected_setup_fields(&"")
		if selected_fields.is_empty():
			return "Player: none"
		selected_fields.push_front("Player=none")
		return host._format_summary_fields(selected_fields)

	var current_character_id: StringName = StringName(String(player.get("selected_character_id")))
	var selected_character_id: StringName = host._get_selected_id(host._character_option)
	var display_character_id: StringName = selected_character_id if selected_character_id != &"" else current_character_id
	var fields: Array[String] = [
		"Character=%s" % String(display_character_id),
		"HP=%d/%d" % [int(player.get("current_health")), int(player.get("max_health"))],
		"Level=%d" % int(player.get("level")),
		"MoveSpeed=%.1f" % host._get_player_effective_move_speed(player),
		"Paused=%s" % str(host.get_tree().paused),
		"AutoPaused=%s" % str(host._is_debug_control_mode()),
		"AttackDisabled=%s" % str(host._is_player_attack_disabled()),
		"EnemyMode=%s" % host._format_enemy_state_override(),
		"Enemies=%d" % host.get_tree().get_nodes_in_group(&"enemy").size()
	]

	fields.append_array(host._build_selected_setup_fields(current_character_id))

	var skill: RefCounted = host._get_starting_skill(player)
	if skill != null:
		fields.append_array(host._build_skill_fields(player, skill))

	fields.append_array(host._build_nearest_enemy_fields())
	fields.append("PlayerStatus=%s" % host._format_statuses(host._get_status_snapshot(player)))
	return host._format_summary_fields(fields)


func _build_nearest_enemy_fields() -> Array[String]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var fields: Array[String] = []
	var enemy: Node = host._get_nearest_enemy()
	if enemy == null:
		return fields
	fields.append("Nearest=%s" % String(enemy.get("enemy_id")))
	if enemy.has_method("get_runtime_state"):
		fields.append("EnemyState=%s" % String(enemy.call("get_runtime_state")))
	fields.append("EnemyHP=%d/%d" % [int(enemy.get("current_health")), int(enemy.get("max_health"))])
	fields.append("EnemyArmor=%d" % int(enemy.get("armor")))
	fields.append("EnemyRange=%.1f" % host._get_enemy_attack_range(enemy))
	fields.append("EnemyStatus=%s" % host._format_statuses(host._get_status_snapshot(enemy)))
	return fields


func _build_selected_setup_fields(current_character_id: StringName) -> Array[String]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var fields: Array[String] = []
	var selected_character_id: StringName = host._get_selected_id(host._character_option)
	var selected_map_id: StringName = host._get_selected_id(host._map_option)
	if selected_character_id != &"" and selected_character_id != current_character_id:
		var character_key: String = "RunCharacter" if current_character_id != &"" else "SelectedCharacter"
		var character_value: StringName = current_character_id if current_character_id != &"" else selected_character_id
		fields.append("%s=%s" % [character_key, String(character_value)])
	if selected_map_id != &"":
		fields.append("SelectedMap=%s" % String(selected_map_id))
	return fields


func _build_skill_fields(player: Node, skill: RefCounted) -> Array[String]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var skill_manager: Node = host._get_skill_manager(player)
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	var parts: Array[String] = [
		"Skill=%s" % host._string_or(skill.get("skill_id"), ""),
		"SkillLevel=%d" % int(skill.get("current_level"))
	]
	for stat_name: String in ["damage", "cooldown", "projectile_speed", "area_radius", "range", "projectile_count"]:
		var value: Variant = SkillStatServiceScript.get_effective_stat(skill, stat_name, null, skill_manager, relic_manager, player)
		if value != null:
			var label: String = "ProjectileSpeed" if stat_name == "projectile_speed" else stat_name
			parts.append("%s=%s" % [label, str(value)])
	return parts


func _get_player_effective_move_speed(player: Node) -> float:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if player == null:
		return 0.0
	if player.has_method("_get_effective_move_speed"):
		return float(player.call("_get_effective_move_speed"))
	return float(player.get("move_speed"))


func _get_player_effective_pickup_radius(player: Node) -> float:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if player == null:
		return 0.0
	if player.has_method("get_effective_pickup_radius"):
		return float(player.call("get_effective_pickup_radius"))
	return float(player.get("pickup_radius"))


func _format_summary_fields(fields: Array[String]) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
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
				host._debug_status_short_name(status_id),
				stacks,
				tick_damage,
				duration_remaining
			])
	return "statuses:%s" % ",".join(parts)


func _debug_status_short_name(status_id: String) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return StatusShortNameFormatterScript.short_name(status_id, -1)


func _get_status_snapshot(target: Node) -> Array:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if target != null and target.has_method("get_status_snapshot"):
		return target.call("get_status_snapshot")
	var manager: Node = target.get_node_or_null("StatusEffectManager") if target != null else null
	if manager != null and manager.has_method("get_status_snapshot"):
		return manager.call("get_status_snapshot")
	return []
