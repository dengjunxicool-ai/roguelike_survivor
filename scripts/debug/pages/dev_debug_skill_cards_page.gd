## 文件用途：构建神系技能调试卡，生成学习选项、授予技能并施放，收集伤害追踪与特效数量。
## 使用方式：以 DevDebugPanel 宿主构造本页控制器；持有 WeakRef，宿主负责控件与回调装配，不能独立挂载到场景。
extends RefCounted

const LearnRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const DebugCombatTraceScript: Script = preload("res://scripts/runtime/debug_combat_trace.gd")
const SkillEffectSummaryBuilderScript: Script = preload("res://scripts/skills/skill_effect_summary_builder.gd")

var _host_ref: WeakRef

## 作用：保存宿主弱引用，技能卡状态、升级池与调试日志由宿主持有。
## 使用：创建页面控制器时传入 DevDebugPanel 宿主，保存弱引用。
func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


## 作用：建立神系切换区、清技能按钮、滚动技能卡列表和技能链诊断日志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：page_root: VBoxContainer。
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


## 作用：从神系定义重新创建切换按钮并绑定 ID，校正选择后同步按下状态。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
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


## 作用：清理旧卡片并加载当前神系定义和调试学习选项，校正技能选择后建立卡片或空列表提示。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
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


## 作用：依次刷新神系按钮和技能卡，供打开技能分类时更新。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _refresh_god_skill_section() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._populate_god_skill_buttons()
	host._refresh_god_skill_cards()


## 作用：设置所选 god_id，同步按钮并重新加载此神系卡片。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：god_id: StringName。
func _select_god_skill_cards(god_id: StringName) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._selected_god_id = god_id
	host._update_god_skill_button_states()
	host._refresh_god_skill_cards()


## 作用：遍历神系按钮，用无信号方式同步其是否为当前所选神系。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _update_god_skill_button_states() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for god_id_variant: Variant in host._god_skill_buttons.keys():
		var god_id: StringName = StringName(host._string_or(god_id_variant, ""))
		var button: Button = host._god_skill_buttons[god_id_variant] as Button
		if button != null:
			button.set_pressed_no_signal(god_id == host._selected_god_id)


## 作用：保持当前技能在定义池中的选择，缺失时选首项，空池时清空选择。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func _sync_selected_god_skill_id() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._god_skill_definitions.is_empty():
		host._selected_god_skill_id = &""
		return
	for skill: Dictionary in host._god_skill_definitions:
		if StringName(host._string_or(skill.get("id", ""), "")) == host._selected_god_skill_id:
			return
	host._selected_god_skill_id = StringName(host._string_or(host._god_skill_definitions[0].get("id", ""), ""))


## 作用：重建火系学习选项下拉框，空池添加禁用提示，否则用学习技能 ID 绑定条目。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
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


## 作用：复用通用神系调试选项生成器，默认 god_id 为 fire。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：god_id: StringName = &"fire"。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
func _build_debug_fire_skill_options(god_id: StringName = &"fire") -> Array[Dictionary]:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return host._build_debug_god_skill_options(god_id)


## 作用：向 UpgradePool 生成指定神系调试学习选项，转字典并按学习技能 ID 去重。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：god_id: StringName。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
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


## 作用：在调试构建或开发模式下清空玩家所有技能槽，刷新协同和宿主摘要。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
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


## 作用：根据技能定义建立带序号元数据的按钮卡片，点击绑定指定技能 ID。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：parent: VBoxContainer, skill: Dictionary, skill_index: int。
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


## 作用：组合名称、描述、特效描述和效果摘要作为技能卡多行文本。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill: Dictionary。 返回 String；具体值及空输入行为见作用说明。
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


## 作用：优先读取 effect_description，否则用 SkillEffectSummaryBuilder 推导摘要，无内容返回占位文本。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill: Dictionary。 返回 String；具体值及空输入行为见作用说明。
func _get_god_skill_effect_description(skill: Dictionary) -> String:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var effect_description: String = host._string_or(skill.get("effect_description", ""), "")
	if effect_description != "":
		return effect_description
	var summary: String = String(SkillEffectSummaryBuilderScript.build_for_skill(skill))
	if summary != "":
		return summary
	return "No effect summary."


## 作用：更新当前选中技能后异步执行该技能的授予与施放链。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。 直接调用时须 await 等待异步流程完成。
func _on_god_skill_card_pressed(skill_id: StringName) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._select_god_skill_card(skill_id)
	await host._run_god_skill_card(skill_id)


## 作用：保存所选技能 ID，并在宿主日志中显示选择。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。
func _select_god_skill_card(skill_id: StringName) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._selected_god_skill_id = skill_id
	host._log("God skill card selected: %s." % host._string_or(skill_id, ""))


## 作用：切换神系后返回卡片数、按钮数、实例数量和选中按钮状态，供自动验证查询。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：god_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：遍历神系按钮，收集按钮 ID、入树数量和指定神系按下状态。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：selected_god_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：异步执行指定神系技能卡调试链并返回结果字典。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。 直接调用时须 await 等待异步流程完成。
func debug_run_god_skill_chain(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return await host._run_god_skill_card(skill_id)


## 作用：解析调试学习选项、授予技能后施放一次，合并结果并更新日志；不主动生成靶子。
## 使用：await 调用并传入所选技能 ID；会授予和施放技能、更新日志，返回诊断结果；该路径允许没有靶子。
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


## 作用：在 result 中标记未生成目标且允许无目标静默施放，避免把此模式误判为强制命中。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：result: Dictionary。
func _mark_god_skill_chain_no_target(result: Dictionary) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	result["target_spawned"] = false
	result["silent_no_target_allowed"] = true


## 作用：把 cast_result 合并进 result，补齐技能、选项、授予状态并恢复无目标标记。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary。
func _apply_god_skill_cast_result(result: Dictionary, cast_result: Dictionary, selected_skill_id: StringName, option: Dictionary) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	for key_variant: Variant in cast_result.keys():
		result[key_variant] = cast_result[key_variant]
	result["skill_id"] = selected_skill_id
	result["option_id"] = host._string_or(option.get("id", ""), "")
	result["option_generated"] = true
	result["granted"] = true
	host._mark_god_skill_chain_no_target(result)


## 作用：先切换 fire 神系，再异步复用通用神系技能调试链。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。 直接调用时须 await 等待异步流程完成。
func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._select_god_skill_cards(&"fire")
	return await host.debug_run_god_skill_chain(skill_id)


## 作用：读取火系下拉选择，执行技能链并按完整诊断条件打印健康或需检查状态。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 直接调用时须 await 等待异步流程完成。
func _run_selected_fire_skill_chain() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var result: Dictionary = await host.debug_run_fire_skill_chain(host._get_selected_id(host._fire_skill_option))
	host._log("Fire skill chain %s: %s." % [
		String(result.get("skill_id", "")),
		"ok" if host._is_fire_skill_chain_result_healthy(result) else "needs attention"
	])


## 作用：授予当前火系选项，将技能和选项标识、授予结果写到诊断日志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
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


## 作用：确保选中的火系技能已授予后异步施放，记录伤害、特效和施放次数。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 直接调用时须 await 等待异步流程完成。
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


## 作用：在玩家右侧 150 像素生成所选敌人或小史莱姆靶子，标记用途并强制敌人为 idle。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 Node2D；具体值及空输入行为见作用说明。
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


## 作用：已有技能直接成功，否则先应用学习升级，失败再 add_skill；新增成功后刷新技能配置与协同。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：option: Dictionary。 返回 bool；具体值及空输入行为见作用说明。
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


## 作用：清理旧 trace、施放指定技能并按帧等待，统计本技能和全部伤害记录、GPU 粒子及伤害弹字增量。
## 使用：await 调用并传入技能 ID、最多等待伤害的物理帧数；零跳过等待伤害。返回含 trace、施放/伤害与可视增量的诊断字典。
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


## 作用：调用 SkillExecutor.debug_cast_skill 施放一个技能并携带 trace_id，缺玩家或入口返回 -1。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName, trace_id: int = 0。 返回 int；具体值及空输入行为见作用说明。
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


## 作用：逐物理帧查找 trace_id 与技能匹配的 damage 记录，首次出现即结束或达到帧数上限。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName, trace_id: int, max_physics_frames: int。 直接调用时须 await 等待异步流程完成。
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


## 作用：把有效靶子血量设为 240 并移到玩家右侧，发出 health_changed 刷新血条。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：target: Node2D。
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


## 作用：创建包含技能 ID、选项、授予、目标、追踪和可视统计默认值的结果字典。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
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


## 作用：由火系下拉框的选中 ID 查询对应学习选项。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_selected_fire_skill_option() -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return host._get_fire_skill_option(host._get_selected_id(host._fire_skill_option))


## 作用：按学习技能 ID 查询火系调试选项；缓存为空时重建，命中后返回深拷贝。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_fire_skill_option(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._debug_fire_skill_options.is_empty():
		host._debug_fire_skill_options = host._build_debug_fire_skill_options()
	for option: Dictionary in host._debug_fire_skill_options:
		if host._get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}


## 作用：按学习技能 ID 查询当前神系调试选项；缓存为空时重建，命中后返回深拷贝。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：skill_id: StringName。 返回 Dictionary；具体值及空输入行为见作用说明。
func _get_god_skill_option(skill_id: StringName) -> Dictionary:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._god_skill_options.is_empty():
		host._god_skill_options = host._build_debug_god_skill_options(host._selected_god_id)
	for option: Dictionary in host._god_skill_options:
		if host._get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}


## 作用：优先读取 payload.learn_skill_id，否则解析 level_up_upgrade: 前缀并由学习仓库解析升级定义。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：option: Dictionary。 返回 StringName；具体值及空输入行为见作用说明。
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


## 作用：将选项生成、授予、目标、施放、伤害、粒子和弹字统计同步到技能链日志 Label。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：result: Dictionary。
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


## 作用：检查选项、授予和施放均成功，且至少有伤害记录、粒子与弹字，返回诊断健康标志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：result: Dictionary。 返回 bool；具体值及空输入行为见作用说明。
func _is_fire_skill_chain_result_healthy(result: Dictionary) -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	return bool(result.get("option_generated", false)) \
		and bool(result.get("granted", false)) \
		and int(result.get("cast_count", 0)) >= 1 \
		and int(result.get("damage_record_count", 0)) >= 1 \
		and int(result.get("particle_count", 0)) >= 1 \
		and int(result.get("damage_popup_count", 0)) >= 1
