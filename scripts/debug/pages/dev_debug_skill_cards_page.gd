extends RefCounted

const LearnRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/runtime/debug_combat_trace.gd")
const SkillEffectSummaryBuilderScript: Script = preload("res://scripts/skills/skill_effect_summary_builder.gd")

var _host_ref: WeakRef

func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


func _build_skill_cards_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var skill_cards_page: VBoxContainer = host._add_category_page(page_root, "skill_cards", "Skill Cards")
	var god_skill_button_row: HBoxContainer = host._add_row(skill_cards_page)
	god_skill_button_row.name = "GodSkillButtons"
	var skill_tools_row: HBoxContainer = host._add_row(skill_cards_page)
	var clear_skills_button: Button = host._add_button(skill_tools_row, "Clear Skills", Callable(host, "_clear_player_skills"), 124)
	clear_skills_button.name = "ClearSkillsButton"

	host._god_skill_cards_scroll = ScrollContainer.new()
	host._god_skill_cards_scroll.name = "GodSkillCardsScroll"
	host._god_skill_cards_scroll.custom_minimum_size = Vector2(440, 560)
	host._god_skill_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._god_skill_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_cards_page.add_child(host._god_skill_cards_scroll)

	host._god_skill_cards = VBoxContainer.new()
	host._god_skill_cards.name = "GodSkillCards"
	host._god_skill_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._god_skill_cards.add_theme_constant_override("separation", 6)
	host._god_skill_cards_scroll.add_child(host._god_skill_cards)

	host._fire_skill_chain_log_label = Label.new()
	host._fire_skill_chain_log_label.name = "GodSkillChainLogLabel"
	host._fire_skill_chain_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._fire_skill_chain_log_label.add_theme_font_size_override("font_size", 12)
	host._fire_skill_chain_log_label.text = "God skill chain: idle."
	skill_cards_page.add_child(host._fire_skill_chain_log_label)


func _populate_god_skill_buttons() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var button_row: HBoxContainer = host.find_child("GodSkillButtons", true, false) as HBoxContainer
	if button_row == null:
		return
	host._clear_children(button_row)
	host._god_skill_buttons.clear()

	var gods: Array[Dictionary] = host._get_god_definitions()
	for god: Dictionary in gods:
		var god_id: String = host._string_or(god.get("id", ""), "")
		if god_id == "":
			continue
		var button: Button = host._add_button(
			button_row,
			host._string_or(god.get("display_name", god_id), god_id),
			Callable(host, "_select_god_skill_cards").bind(StringName(god_id)),
			68
		)
		button.name = "GodSkillButton_%s" % god_id
		button.toggle_mode = true
		host._god_skill_buttons[StringName(god_id)] = button
	if not host._god_skill_buttons.has(host._selected_god_id) and not gods.is_empty():
		host._selected_god_id = StringName(host._string_or(gods[0].get("id", "fire"), "fire"))
	host._update_god_skill_button_states()


func _refresh_god_skill_cards() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._god_skill_cards == null:
		return
	host._clear_children(host._god_skill_cards)
	host._god_skill_definitions = host._get_god_skill_definitions(host._selected_god_id)
	host._god_skill_options = host._build_debug_god_skill_options(host._selected_god_id)
	host._sync_selected_god_skill_id()
	if host._god_skill_definitions.is_empty():
		var empty_label: Label = Label.new()
		empty_label.name = "GodSkillCardsEmpty"
		empty_label.text = "No skill cards for this god yet."
		empty_label.add_theme_font_size_override("font_size", 12)
		host._god_skill_cards.add_child(empty_label)
		host._update_god_skill_button_states()
		host._refresh_state()
		return

	for index in range(host._god_skill_definitions.size()):
		host._add_god_skill_card(host._god_skill_cards, host._god_skill_definitions[index], index)
	host._update_god_skill_button_states()
	host._refresh_state()


func _refresh_god_skill_section() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._populate_god_skill_buttons()
	host._refresh_god_skill_cards()


func _select_god_skill_cards(god_id: StringName) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._selected_god_id = god_id
	host._update_god_skill_button_states()
	host._refresh_god_skill_cards()


func _update_god_skill_button_states() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for god_id_variant: Variant in host._god_skill_buttons.keys():
		var god_id: StringName = StringName(host._string_or(god_id_variant, ""))
		var button: Button = host._god_skill_buttons[god_id_variant] as Button
		if button != null:
			button.set_pressed_no_signal(god_id == host._selected_god_id)


func _sync_selected_god_skill_id() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._god_skill_definitions.is_empty():
		host._selected_god_skill_id = &""
		return
	for skill: Dictionary in host._god_skill_definitions:
		if StringName(host._string_or(skill.get("id", ""), "")) == host._selected_god_skill_id:
			return
	host._selected_god_skill_id = StringName(host._string_or(host._god_skill_definitions[0].get("id", ""), ""))


func _populate_fire_skill_options() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._fire_skill_option == null:
		return
	host._fire_skill_option.clear()
	host._debug_fire_skill_options = host._build_debug_fire_skill_options()
	if host._debug_fire_skill_options.is_empty():
		host._add_disabled_option_header(host._fire_skill_option, "No fire skill options")
		host._update_fire_skill_chain_log({"option_generated": false, "error": "No fire skill options."})
		return
	for option: Dictionary in host._debug_fire_skill_options:
		var skill_id: StringName = host._get_option_learn_skill_id(option)
		if skill_id == &"":
			continue
		var label: String = "%s [%s]" % [
			String(option.get("display_name", skill_id)),
			String(skill_id)
		]
		host._add_option_item(host._fire_skill_option, label, String(skill_id))
	host._select_first_enabled_option(host._fire_skill_option)


func _build_debug_fire_skill_options(god_id: StringName = &"fire") -> Array[Dictionary]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return host._build_debug_god_skill_options(god_id)


func _build_debug_god_skill_options(god_id: StringName) -> Array[Dictionary]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		return []
	if not host._upgrade_pool.has_method("generate_debug_fire_skill_options"):
		return []

	var options: Array[Dictionary] = []
	var seen: Dictionary = {}
	for option_variant: Variant in host._upgrade_pool.call("generate_debug_fire_skill_options", player, god_id):
		var option: Dictionary = host._upgrade_option_to_dictionary(option_variant)
		var skill_id: StringName = host._get_option_learn_skill_id(option)
		if skill_id == &"" or seen.has(skill_id):
			continue
		seen[skill_id] = true
		options.append(option)
	return options


func _clear_player_skills() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if not OS.is_debug_build() and not host._is_developer_mode_enabled():
		host._log_warn("Clear Skills is only available in debug mode.")
		return
	var player: Node = host._get_player()
	if player == null:
		host._log_error("Player missing.")
		return
	var skill_manager: Node = host._get_skill_manager(player)
	if skill_manager == null or not skill_manager.has_method("clear_skills"):
		host._log_error("SkillManager.clear_skills missing.")
		return
	skill_manager.call("clear_skills")
	if player.has_method("_refresh_synergies"):
		player.call("_refresh_synergies")
	host._refresh_state()
	host._log("Cleared current skill slots.")


func _add_god_skill_card(parent: VBoxContainer, skill: Dictionary, skill_index: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var skill_id: StringName = StringName(host._string_or(skill.get("id", ""), ""))
	var button: Button = Button.new()
	button.name = "GodSkillCard_%s" % host._string_or(skill_id, "")
	button.set_meta("skill_index", skill_index)
	button.text = host._format_god_skill_card_text(skill)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 118)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = host._string_or(skill.get("description", ""), "")
	UIButtonSkin.apply(button)
	button.pressed.connect(Callable(host, "_on_god_skill_card_pressed").bind(skill_id))
	parent.add_child(button)


func _format_god_skill_card_text(skill: Dictionary) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var title: String = host._string_or(skill.get("display_name", skill.get("id", "")), "")
	var description: String = host._string_or(skill.get("description", ""), "")
	var vfx_description: String = host._string_or(skill.get("vfx_description", ""), "")
	var effect_description: String = host._get_god_skill_effect_description(skill)
	return "%s\n描述：%s\n特效：%s\n效果：%s" % [
		title,
		description,
		vfx_description,
		effect_description
	]


func _get_god_skill_effect_description(skill: Dictionary) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var effect_description: String = host._string_or(skill.get("effect_description", ""), "")
	if effect_description != "":
		return effect_description
	var summary: String = String(SkillEffectSummaryBuilderScript.build_for_skill(skill))
	if summary != "":
		return summary
	return "No effect summary."


func _on_god_skill_card_pressed(skill_id: StringName) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._select_god_skill_card(skill_id)
	await host._run_god_skill_card(skill_id)


func _select_god_skill_card(skill_id: StringName) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._selected_god_skill_id = skill_id
	host._log("God skill card selected: %s." % host._string_or(skill_id, ""))


func debug_select_god_skill_cards(god_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._select_god_skill_cards(god_id)
	var button_summary: Dictionary = host._build_god_skill_button_summary(god_id)
	return {
		"god_id": god_id,
		"card_count": host._god_skill_definitions.size(),
		"button_count": host._god_skill_buttons.size(),
		"button_ids": button_summary.get("button_ids", []),
		"button_tree_count": int(button_summary.get("button_tree_count", 0)),
		"selected_button_pressed": bool(button_summary.get("selected_button_pressed", false))
	}


func _build_god_skill_button_summary(selected_god_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var button_ids: Array[String] = []
	var button_tree_count: int = 0
	var selected_button_pressed: bool = false
	for button_id_variant: Variant in host._god_skill_buttons.keys():
		var button_id: StringName = StringName(host._string_or(button_id_variant, ""))
		var button: Button = host._god_skill_buttons[button_id_variant] as Button
		button_ids.append(host._string_or(button_id, ""))
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return await host._run_god_skill_card(skill_id)


func _run_god_skill_card(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._select_god_skill_card(skill_id)
	if skill_id == &"":
		return {"skill_id": skill_id, "option_generated": false, "granted": false, "error": "Missing skill id."}
	var option: Dictionary = host._get_god_skill_option(skill_id)
	if option.is_empty():
		var fallback: Dictionary = host._build_fire_skill_chain_result(skill_id)
		fallback["option_generated"] = false
		fallback["error"] = "No god skill debug option for %s." % host._string_or(skill_id, "")
		host._update_fire_skill_chain_log(fallback)
		return fallback
	var selected_skill_id: StringName = host._get_option_learn_skill_id(option)
	var result: Dictionary = host._build_fire_skill_chain_result(selected_skill_id)
	result["option_generated"] = true
	result["option_id"] = host._string_or(option.get("id", ""), "")
	result["granted"] = host._grant_fire_skill_option(option)
	if not bool(result.get("granted", false)):
		result["error"] = "Could not grant %s." % host._string_or(selected_skill_id, "")
		host._update_fire_skill_chain_log(result)
		return result
	host._mark_god_skill_chain_no_target(result)
	var cast_result: Dictionary = await host._cast_fire_skill_once(selected_skill_id, 0)
	host._apply_god_skill_cast_result(result, cast_result, selected_skill_id, option)
	host._update_fire_skill_chain_log(result)
	return result


func _mark_god_skill_chain_no_target(result: Dictionary) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	result["target_spawned"] = false
	result["silent_no_target_allowed"] = true


func _apply_god_skill_cast_result(result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for key_variant: Variant in cast_result.keys():
		result[key_variant] = cast_result[key_variant]
	result["skill_id"] = selected_skill_id
	result["option_id"] = host._string_or(option.get("id", ""), "")
	result["option_generated"] = true
	result["granted"] = true
	host._mark_god_skill_chain_no_target(result)


func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._select_god_skill_cards(&"fire")
	return await host.debug_run_god_skill_chain(skill_id)


func _run_selected_fire_skill_chain() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var result: Dictionary = await host.debug_run_fire_skill_chain(host._get_selected_id(host._fire_skill_option))
	host._log("Fire skill chain %s: %s." % [
		String(result.get("skill_id", "")),
		"ok" if host._is_fire_skill_chain_result_healthy(result) else "needs attention"
	])


func _grant_selected_fire_skill() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var option: Dictionary = host._get_selected_fire_skill_option()
	if option.is_empty():
		host._log_warn("No fire skill option selected.")
		return
	var granted: bool = host._grant_fire_skill_option(option)
	host._update_fire_skill_chain_log({
		"skill_id": host._get_option_learn_skill_id(option),
		"option_id": host._string_or(option.get("id", ""), ""),
		"option_generated": true,
		"granted": granted
	})
	host._log("Grant fire skill %s: %s." % [host._string_or(host._get_option_learn_skill_id(option), ""), str(granted)])


func _cast_selected_fire_skill() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var option: Dictionary = host._get_selected_fire_skill_option()
	if option.is_empty():
		host._log_warn("No fire skill option selected.")
		return
	var skill_id: StringName = host._get_option_learn_skill_id(option)
	var granted: bool = host._grant_fire_skill_option(option)
	if not granted:
		host._update_fire_skill_chain_log({"skill_id": skill_id, "option_generated": true, "granted": false})
		host._log_warn("Cannot cast %s: grant failed." % host._string_or(skill_id, ""))
		return
	var cast_result: Dictionary = await host._cast_fire_skill_once(skill_id)
	cast_result["option_generated"] = true
	cast_result["granted"] = true
	host._update_fire_skill_chain_log(cast_result)
	host._log("Cast fire skill %s; cast_count=%d damage_records=%d." % [
		host._string_or(skill_id, ""),
		int(cast_result.get("cast_count", 0)),
		int(cast_result.get("damage_record_count", 0))
	])


func _spawn_fire_skill_debug_target() -> Node2D:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node2D = host._get_player() as Node2D
	if player == null or player.get_parent() == null:
		host._log_error("Player missing.")
		return null
	var enemy_id: StringName = host._get_selected_id(host._enemy_option)
	if enemy_id == &"":
		enemy_id = &"small_slime"
	var target_position: Vector2 = player.global_position + Vector2(150.0, 0.0)
	var enemy: Node2D = host._spawn_debug_enemy(enemy_id, target_position, player.get_parent(), false)
	if enemy != null:
		enemy.set_meta("debug_fire_skill_target", true)
		host._set_enemy_state_override("idle")
		host._log("Spawned fire skill target: %s." % String(enemy_id))
	return enemy


func _grant_fire_skill_option(option: Dictionary) -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		return false
	var skill_id: StringName = host._get_option_learn_skill_id(option)
	if skill_id == &"":
		return false
	var skill_manager: Node = host._get_skill_manager(player)
	if skill_manager != null and skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
		return true

	var option_id: StringName = StringName(host._string_or(option.get("id", ""), ""))
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var result: Dictionary = host._build_fire_skill_chain_result(skill_id)
	var player: Node = host._get_player()
	if player == null:
		result["error"] = "Player missing."
		return result

	var root: Node = host.get_tree().root if host.get_tree() != null else null
	var particle_count_before: int = host._count_particle_nodes(root)
	var damage_popup_count_before: int = host._count_damage_popup_nodes(root)
	DebugCombatTraceScript.clear(root)
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	host._attack_damage_card_index = 0
	host._reset_attack_damage_scroll()

	var cast_count: int = host._cast_player_skill_once(skill_id, trace_id)
	result["trace_id"] = trace_id
	result["cast_count"] = maxi(cast_count, 0)
	await host._wait_debug_frames(2, false)
	var immediate_particle_delta: int = maxi(host._count_particle_nodes(root) - particle_count_before, 0)
	if max_damage_wait_frames > 0:
		await host._wait_for_fire_skill_damage_record(skill_id, trace_id, max_damage_wait_frames)
	await host._wait_debug_frames(6, false)

	var records: Array = DebugCombatTraceScript.get_records(root)
	var selected_damage_count: int = host._count_damage_records(records, skill_id, trace_id)
	var all_damage_count: int = host._count_damage_records(records, &"", trace_id)
	var final_particle_delta: int = maxi(host._count_particle_nodes(root) - particle_count_before, 0)
	var damage_popup_delta: int = maxi(host._count_damage_popup_nodes(root) - damage_popup_count_before, 0)
	result["damage_record_count"] = selected_damage_count
	result["selected_damage_record_count"] = selected_damage_count
	result["all_damage_record_count"] = all_damage_count
	result["particle_count"] = maxi(immediate_particle_delta, final_particle_delta)
	result["damage_popup_count"] = damage_popup_delta
	host._refresh_attack_damage_text()
	return result


func _cast_player_skill_once(skill_id: StringName, trace_id: int = 0) -> int:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node = host._get_player()
	if player == null:
		host._log_error("Player missing.")
		return -1

	var executor: Node = player.get_node_or_null("SkillExecutor")
	if executor == null:
		host._log_error("SkillExecutor missing.")
		return -1
	if executor.has_method("debug_cast_skill"):
		return int(executor.call("debug_cast_skill", skill_id, trace_id))
	host._log_error("SkillExecutor debug_cast_skill missing.")
	return -1


func _wait_for_fire_skill_damage_record(skill_id: StringName, trace_id: int, max_physics_frames: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var root: Node = host.get_tree().root if host.get_tree() != null else null
	for _frame_index: int in range(maxi(max_physics_frames, 0)):
		await host.get_tree().physics_frame
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if target == null or not is_instance_valid(target):
		return
	target.set("max_health", 240)
	target.set("current_health", 240)
	var player: Node2D = host._get_player() as Node2D
	if player != null:
		target.global_position = player.global_position + Vector2(150.0, 0.0)
	if target.has_signal(&"health_changed"):
		target.emit_signal(&"health_changed", 240, 240)


func _build_fire_skill_chain_result(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
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
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return host._get_fire_skill_option(host._get_selected_id(host._fire_skill_option))


func _get_fire_skill_option(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._debug_fire_skill_options.is_empty():
		host._debug_fire_skill_options = host._build_debug_fire_skill_options()
	for option: Dictionary in host._debug_fire_skill_options:
		if host._get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}


func _get_god_skill_option(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._god_skill_options.is_empty():
		host._god_skill_options = host._build_debug_god_skill_options(host._selected_god_id)
	for option: Dictionary in host._god_skill_options:
		if host._get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}


func _get_option_learn_skill_id(option: Dictionary) -> StringName:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var payload: Dictionary = host._get_dictionary(option.get("payload", {}))
	if payload.has("learn_skill_id"):
		return StringName(host._string_or(payload.get("learn_skill_id", ""), ""))
	var option_id: String = host._string_or(option.get("id", ""), "")
	if option_id.begins_with("level_up_upgrade:"):
		var upgrade_id: StringName = StringName(option_id.substr("level_up_upgrade:".length()))
		var upgrade: Dictionary = LearnRepositoryScript.resolve_upgrade(upgrade_id)
		return StringName(host._string_or(upgrade.get("learn_skill_id", ""), ""))
	return &""


func _update_fire_skill_chain_log(result: Dictionary) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._fire_skill_chain_log_label == null:
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
	host._fire_skill_chain_log_label.text = "\n".join(lines)


func _is_fire_skill_chain_result_healthy(result: Dictionary) -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return bool(result.get("option_generated", false)) \
		and bool(result.get("granted", false)) \
		and int(result.get("cast_count", 0)) >= 1 \
		and int(result.get("damage_record_count", 0)) >= 1 \
		and int(result.get("particle_count", 0)) >= 1 \
		and int(result.get("damage_popup_count", 0)) >= 1
