## 文件用途：构建地图选择、地图信息、敌人预览和当前角色构筑展示。
## 使用方式：build 后 refresh(character_id)；地图确认发 start_requested，选位和战斗由运行服务处理。

extends RefCounted
class_name MapSelectController


signal start_requested(map_id: StringName)
signal back_requested


const MapRuntimeScript: Script = preload("res://scripts/maps/map_runtime.gd")
const UIDisplayHelperScript: Script = preload("res://scripts/ui/ui_display_helper.gd")
const THREAT_LOCKED_LEVEL: int = 1

var selected_map_id: StringName = MapRuntimeScript.DEFAULT_MAP_ID

var _screen: Control
var _map_list: VBoxContainer
var _preview_texture: TextureRect
var _preview_description_label: Label
var _enemy_preview_list: VBoxContainer
var _detail_labels: Dictionary = {}
var _loadout_labels: Dictionary = {}
var _start_button: Button
var _layout_controls: Dictionary = {}
var _selected_character_id: StringName = &"mage"


## 作用：构建地图选择、地图信息、敌人预览和当前角色构筑展示。
## 使用：由页面或局内编排的构建流程调用；构建前应提供有效父容器；返回 Control 对象/值。
func build() -> Control:
	_screen = Control.new()
	_screen.name = "MAP_SELECT"
	_screen.visible = false
	_screen.z_index = 10
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.045, 0.05, 0.055, 0.98)
	_screen.add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	_screen.add_child(margin)
	_layout_controls["margin"] = margin

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	_build_nav_bar(root)
	_build_body(root)
	refresh(_selected_character_id)
	return _screen


## 作用：更新当前角色，并重绘地图卡、已选地图详情和角色开局配置。
## 使用：build 后调用；character_id 为当前角色 ID，无已选地图时先选择默认地图。
func refresh(character_id: StringName) -> void:
	_selected_character_id = character_id
	_select_default_map_if_needed()
	_refresh_map_cards()
	_refresh_selected_map_details()
	_refresh_loadout()


## 作用：设置当前选择地图。
## 使用：供本模块调用者使用；输入 map_id（地图ID）。
func set_selected_map(map_id: Variant) -> void:
	var resolved_map_id: StringName = MapRuntimeScript.resolve_map_id(map_id)
	if resolved_map_id != &"":
		selected_map_id = resolved_map_id


## 作用：更新布局。
## 使用：供本模块调用者使用；输入 viewport_size（视口尺寸）。
func update_layout(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var content_row: BoxContainer = _layout_controls.get("content_row", null) as BoxContainer
	_set_control_min_size("map_list_panel", Vector2(210, 0))
	_set_control_min_size("preview_panel", Vector2(360, 0))
	_set_control_min_size("detail_panel", Vector2(260, 0))
	var is_compact: bool = _horizontal_content_width(content_row) > _available_content_width(viewport_size.x)
	if content_row != null:
		content_row.vertical = is_compact
		content_row.custom_minimum_size = Vector2(0, maxf(300.0, viewport_size.y * 0.55))

	if is_compact:
		_set_control_min_size("map_list_panel", Vector2.ZERO)
		_set_control_min_size("preview_panel", Vector2.ZERO)
		_set_control_min_size("detail_panel", Vector2.ZERO)
	_set_control_min_size("loadout_panel", Vector2(0, maxf(96.0, 120.0)))


## 作用：横向内容宽度。
## 使用：本文件由 update_layout 调用；输入 row（行）；返回计算或读取的数值。
func _horizontal_content_width(row: BoxContainer) -> float:
	if row == null:
		return 0.0
	var width: float = 0.0
	for panel: Control in row.get_children():
		width += panel.get_combined_minimum_size().x
	return width + row.get_theme_constant("separation") * maxi(0, row.get_child_count() - 1)


## 作用：可用内容宽度。
## 使用：本文件由 update_layout 调用；输入 viewport_width（视口宽度）；返回计算或读取的数值。
func _available_content_width(viewport_width: float) -> float:
	var margin: MarginContainer = _layout_controls.get("margin") as MarginContainer
	var scroll: ScrollContainer = _layout_controls.get("body_scroll") as ScrollContainer
	# Reserve the scrollbar even before layout so changing orientation cannot
	# change the breakpoint on the next resize.
	return viewport_width - margin.get_theme_constant("margin_left") - margin.get_theme_constant("margin_right") - scroll.get_v_scroll_bar().get_combined_minimum_size().x


## 作用：构建导航进度条并配置节点/样式所需的属性。
## 使用：本文件由 build 调用；输入 root（root）。
func _build_nav_bar(root: VBoxContainer) -> void:
	var nav_bar: HBoxContainer = HBoxContainer.new()
	nav_bar.custom_minimum_size = Vector2(0, 64)
	nav_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_bar.add_theme_constant_override("separation", 16)
	root.add_child(nav_bar)

	var back_button: Button = _add_button(nav_bar, "返回")
	back_button.custom_minimum_size = Vector2(128, 56)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(Callable(self, "_emit_back_requested"))

	var title_label: Label = _add_label(nav_bar, "战斗准备", HORIZONTAL_ALIGNMENT_CENTER)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var soul_label: Label = _add_label(nav_bar, "灵魂石：0", HORIZONTAL_ALIGNMENT_RIGHT, "MapSoulLabel")
	soul_label.custom_minimum_size = Vector2(148, 0)
	soul_label.size_flags_horizontal = Control.SIZE_SHRINK_END


## 作用：构建主体并配置节点/样式所需的属性。
## 使用：本文件由 build 调用；输入 root（root）。
func _build_body(root: VBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_layout_controls["body_scroll"] = scroll

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)

	var content_row: BoxContainer = BoxContainer.new()
	content_row.name = "MapContentRow"
	content_row.custom_minimum_size = Vector2(0, 380)
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	body.add_child(content_row)
	_layout_controls["content_row"] = content_row

	_build_map_list(content_row)
	_build_preview(content_row)
	_build_detail_panel(content_row)
	_build_loadout_panel(body)


## 作用：构建地图列表并配置节点/样式所需的属性。
## 使用：本文件由 _build_body 调用；输入 parent（父节点）。
func _build_map_list(parent: BoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(210, 0), 0.9)
	panel.name = "MapListPanel"
	parent.add_child(panel)
	_layout_controls["map_list_panel"] = panel
	var margin: MarginContainer = _create_margin_container(14, 14, 14, 14)
	panel.add_child(margin)

	_map_list = VBoxContainer.new()
	_map_list.name = "MapCardList"
	_map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_list.add_theme_constant_override("separation", 10)
	margin.add_child(_map_list)


## 作用：构建预览并配置节点/样式所需的属性。
## 使用：本文件由 _build_body 调用；输入 parent（父节点）。
func _build_preview(parent: BoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(360, 0), 2.1)
	panel.name = "MapPreviewPanel"
	panel.clip_contents = true
	parent.add_child(panel)
	_layout_controls["preview_panel"] = panel
	var margin: MarginContainer = _create_margin_container(10, 10, 10, 10)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	_preview_texture = TextureRect.new()
	_preview_texture.name = "MapPreviewTexture"
	_preview_texture.custom_minimum_size = Vector2(0, 250)
	_preview_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layout.add_child(_preview_texture)

	_preview_description_label = _add_detail_label(layout, "地图描述：-")
	_preview_description_label.custom_minimum_size = Vector2(0, 72)


## 作用：构建详情面板并配置节点/样式所需的属性。
## 使用：本文件由 _build_body 调用；输入 parent（父节点）。
func _build_detail_panel(parent: BoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(260, 0), 1.15)
	panel.name = "MapDetailPanel"
	parent.add_child(panel)
	_layout_controls["detail_panel"] = panel
	var margin: MarginContainer = _create_margin_container(18, 16, 18, 16)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(0, 240)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keep its width stable while switching between stacked and side-by-side panels.
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	layout.add_child(detail_scroll)

	var detail_body: VBoxContainer = VBoxContainer.new()
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_body.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(detail_body)
	for label_key: String in ["name", "difficulty", "duration", "loadout", "traits", "builds", "reward", "clear"]:
		_detail_labels[label_key] = _add_detail_label(detail_body, "")

	var preview_title: Label = _add_detail_label(detail_body, "怪物预览")
	preview_title.add_theme_font_size_override("font_size", 18)
	_enemy_preview_list = VBoxContainer.new()
	_enemy_preview_list.name = "MapEnemyPreviewList"
	_enemy_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_preview_list.add_theme_constant_override("separation", 8)
	detail_body.add_child(_enemy_preview_list)

	_start_button = _add_button(layout, "开始挑战")
	_start_button.name = "MapStartButton"
	_start_button.custom_minimum_size = Vector2(0, 56)
	_start_button.pressed.connect(Callable(self, "_start_selected_map"))


## 作用：构建开局配置面板并配置节点/样式所需的属性。
## 使用：本文件由 _build_body 调用；输入 parent（父节点）。
func _build_loadout_panel(parent: VBoxContainer) -> void:
	var panel: PanelContainer = _create_panel_container(Vector2(0, 120), 1.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	_layout_controls["loadout_panel"] = panel
	var margin: MarginContainer = _create_margin_container(18, 14, 18, 14)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	_loadout_labels["character"] = _add_loadout_label(row, "MapLoadoutCharacterLabel")
	_loadout_labels["skill"] = _add_loadout_label(row, "MapLoadoutSkillLabel")
	_loadout_labels["threat"] = _add_loadout_label(row, "MapLoadoutThreatLabel")


## 作用：添加开局配置标签。
## 使用：本文件由 _build_loadout_panel 调用；输入 parent（父节点）、node_name（节点名称）；返回 Label 对象/值。
func _add_loadout_label(parent: HBoxContainer, node_name: String) -> Label:
	var label: Label = _add_detail_label(parent, "")
	label.name = node_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.0
	return label


## 作用：选择默认地图按条件按需。
## 使用：本文件由 refresh 调用。
func _select_default_map_if_needed() -> void:
	if not GameData.get_map(selected_map_id).is_empty():
		return
	selected_map_id = MapRuntimeScript.get_default_map_id()


## 作用：刷新地图卡片列表。
## 使用：本文件由 refresh、_select_map 调用。
func _refresh_map_cards() -> void:
	_clear_children(_map_list)
	var maps: Array[Dictionary] = GameData.get_map_pool()
	if maps.is_empty():
		_add_detail_label(_map_list, "暂无地图数据")
		return

	for map_data: Dictionary in maps:
		_add_map_card(map_data)


## 作用：添加地图卡片并配置节点/样式所需的属性。
## 使用：本文件由 _refresh_map_cards 调用；输入 map_data（地图数据）。
func _add_map_card(map_data: Dictionary) -> void:
	var map_id: StringName = StringName(str(map_data.get("id", "")))
	if map_id == &"":
		return

	var is_selected: bool = map_id == selected_map_id
	var is_unlocked: bool = MapRuntimeScript.is_map_unlocked(map_data)
	var button: Button = Button.new()
	button.name = "MapCard_%s" % str(map_id)
	button.text = _get_map_card_text(map_data, is_unlocked)
	button.custom_minimum_size = Vector2(0, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", _create_map_card_style(is_selected, false, is_unlocked))
	button.add_theme_stylebox_override("hover", _create_map_card_style(is_selected, true, is_unlocked))
	button.add_theme_stylebox_override("pressed", _create_map_card_style(true, true, is_unlocked))
	UIButtonSkin.apply_text_only(button)
	button.pressed.connect(Callable(self, "_select_map").bind(map_id))
	_map_list.add_child(button)


## 作用：刷新当前选择地图详情。
## 使用：本文件由 refresh、_select_map 调用。
func _refresh_selected_map_details() -> void:
	var map_data: Dictionary = GameData.get_map(selected_map_id)
	if map_data.is_empty():
		_set_detail_label("name", "地图：未配置")
		if _start_button != null:
			_start_button.disabled = true
			_start_button.text = "暂无地图"
		return

	_update_preview(map_data)
	_set_detail_label("name", _get_map_display_name(map_data))
	_set_detail_label("difficulty", "推荐难度：%s" % _get_star_text(int(map_data.get("difficulty", 1))))
	_set_detail_label("duration", "预计时长：%s" % _format_time(float(map_data.get("duration_seconds", 300))))
	_set_detail_label("loadout", _get_loadout_detail_text())
	_set_detail_label("traits", "场景特性：%s" % _get_map_traits_text(map_data))
	_set_detail_label("builds", "推荐构筑：%s\n不推荐：%s" % [
		_get_map_recommended_build_text(map_data),
		_get_map_not_recommended_text(map_data)
	])
	_set_detail_label("reward", "奖励倍率：x%.2f" % float(map_data.get("reward_multiplier", 1.0)))
	_set_detail_label("clear", _get_lock_or_clear_text(map_data))
	if _preview_description_label != null:
		_preview_description_label.text = "地图描述：%s" % _get_map_description(map_data)
	_refresh_enemy_previews(map_data)
	_update_start_button(map_data)


## 作用：更新预览。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）。
func _update_preview(map_data: Dictionary) -> void:
	var texture: Texture2D = MapRuntimeScript.load_texture(MapRuntimeScript.get_background_path(map_data))
	_preview_texture.texture = texture
	_preview_texture.modulate = Color.WHITE if texture != null else Color(0.25, 0.27, 0.3, 1.0)


## 作用：刷新开局配置。
## 使用：本文件由 refresh、_select_map 调用。
func _refresh_loadout() -> void:
	_set_loadout_label("character", "角色\n%s" % _get_character_display_name(GameData.get_character(_selected_character_id)))
	_set_loadout_label("skill", "初始技能\n%s" % _get_starting_skill_display_name())
	_set_loadout_label("threat", "威胁等级\n%d（已锁定，仅 UI）" % THREAT_LOCKED_LEVEL)

	var soul_label: Label = _screen.find_child("MapSoulLabel", true, false) as Label
	if soul_label != null:
		soul_label.text = "灵魂石：%d" % SaveManager.get_soul_stones()


## 作用：刷新敌人预览组。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）。
func _refresh_enemy_previews(map_data: Dictionary) -> void:
	_clear_children(_enemy_preview_list)
	_add_enemy_preview_group("怪物", _get_map_enemy_preview_ids(map_data))
	_add_enemy_preview_group("精英", preload("res://scripts/maps/map_encounter_resolver.gd").get_elite_preview_ids(map_data))
	_add_enemy_preview_group("Boss", [map_data.get("boss_id", "")])


## 作用：添加敌人预览分组并配置节点/样式所需的属性。
## 使用：本文件由 _refresh_enemy_previews 调用；输入 title（标题）、enemy_ids_variant（敌人ID列表变体）。
func _add_enemy_preview_group(title: String, enemy_ids_variant: Variant) -> void:
	var enemy_ids: Array = _get_array(enemy_ids_variant)
	if enemy_ids.is_empty():
		return

	var group_label: Label = _add_detail_label(_enemy_preview_list, title)
	group_label.add_theme_font_size_override("font_size", 15)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	_enemy_preview_list.add_child(row)
	for enemy_id_variant: Variant in enemy_ids:
		var enemy_id: StringName = StringName(str(enemy_id_variant))
		if enemy_id != &"":
			row.add_child(_create_enemy_preview_card(enemy_id))


## 作用：创建敌人预览卡片并配置节点/样式所需的属性。
## 使用：本文件由 _add_enemy_preview_group 调用；输入 enemy_id（敌人ID）；返回 PanelContainer 对象/值。
func _create_enemy_preview_card(enemy_id: StringName) -> PanelContainer:
	var enemy: Dictionary = GameData.get_enemy(enemy_id)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(72, 94)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_enemy_preview_card_style())

	var margin: MarginContainer = _create_margin_container(6, 6, 6, 6)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = _get_enemy_visual_texture(enemy)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = _get_visual_modulate(enemy)
	content.add_child(icon)

	var name_label: Label = _add_detail_label(content, _get_enemy_display_name(enemy, enemy_id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, 34)
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 12)
	return card


## 作用：获取开局配置详情文本，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details 调用；返回 String 文本/标识。
func _get_loadout_detail_text() -> String:
	return "当前选择：\n角色：%s\n初始技能：%s" % [
		_get_character_display_name(GameData.get_character(_selected_character_id)),
		_get_starting_skill_display_name()
	]


## 作用：更新启动按钮。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）。
func _update_start_button(map_data: Dictionary) -> void:
	var can_start: bool = _can_start(map_data)
	_start_button.disabled = not can_start
	_start_button.text = "开始挑战" if can_start else _get_start_blocked_text(map_data)


## 作用：可否启动，返回布尔判断结果。
## 使用：本文件由 _update_start_button、_start_selected_map 调用；输入 map_data（地图数据）。
func _can_start(map_data: Dictionary) -> bool:
	return not GameData.get_character(_selected_character_id).is_empty() and not map_data.is_empty() and MapRuntimeScript.is_map_unlocked(map_data)


## 作用：获取启动阻止文本，供当前模块后续逻辑使用。
## 使用：本文件由 _update_start_button 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_start_blocked_text(map_data: Dictionary) -> String:
	if GameData.get_character(_selected_character_id).is_empty():
		return "请选择角色"
	if map_data.is_empty():
		return "暂无地图"
	if not MapRuntimeScript.is_map_unlocked(map_data):
		return "地图未解锁"
	return "暂不可开始"


## 作用：获取地图卡片文本，供当前模块后续逻辑使用。
## 使用：本文件由 _add_map_card 调用；输入 map_data（地图数据）、is_unlocked（判断已解锁）；返回 String 文本/标识。
func _get_map_card_text(map_data: Dictionary, is_unlocked: bool) -> String:
	var map_id: StringName = StringName(str(map_data.get("id", "")))
	var clear_state: String = "已通关" if SaveManager.is_map_cleared(map_id) else "未通关"
	var lock_state: String = "" if is_unlocked else "\n未解锁"
	return "%s  %s\n难度 %s / %s%s" % [
		_get_map_display_name(map_data),
		"✓" if clear_state == "已通关" else "",
		_get_star_text(int(map_data.get("difficulty", 1))),
		clear_state,
		lock_state
	]


## 作用：获取地图展示名称，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details、_get_map_card_text、_get_lock_or_clear_text 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_map_display_name(map_data: Dictionary) -> String:
	match str(map_data.get("id", "")):
		"abandoned_dungeon":
			return "废弃地牢"
		"toxic_fog_graveyard":
			return "瘟毒墓园"
		"lava_temple":
			return "熔火神殿"
		"abyss_corridor":
			return "深渊回廊"
		_:
			return str(map_data.get("display_name", map_data.get("id", "")))


## 作用：获取地图描述，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_map_description(map_data: Dictionary) -> String:
	match str(map_data.get("id", "")):
		"abandoned_dungeon":
			return "标准开放地形，机制压力低，适合测试初始技能成长和基础构筑。"
		"toxic_fog_graveyard":
			return "随机毒雾区会压缩走位空间，毒系敌人与 DOT 压力更高。"
		"lava_temple":
			return "周期性熔岩裂隙制造爆发伤害，要求更明确的躲避和控制窗口。"
		"abyss_corridor":
			return "窄廊地形提高包围压力，更考验穿透、弹射和区域控制。"
		_:
			return str(map_data.get("description", "未配置"))


## 作用：获取地图特质组文本，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_map_traits_text(map_data: Dictionary) -> String:
	var parts: Array[String] = []
	for entry_variant: Variant in _get_array(map_data.get("map_traits", [])):
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			parts.append("%s - %s" % [str(entry.get("display_name", "")), str(entry.get("description", ""))])
	if not parts.is_empty():
		return "\n".join(parts)
	match str(_get_dictionary(map_data.get("map_variable", {})).get("type", "open")):
		"open":
			return "开放地形：无强机制，标准敌潮和 Boss 节奏。"
		"toxic_fog":
			return "毒雾：周期或随机出现毒区，毒系敌人权重更高，适合 DOT 或净化路线。"
		"lava_fissure":
			return "熔岩裂隙：周期性高伤区域，推荐控制、生存或高机动构筑。"
		"narrow_corridor":
			return "窄廊压力：包围更快形成，穿透、弹射、陷阱和场域收益更高。"
		_:
			return "未配置"


## 作用：获取地图推荐构建文本，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_map_recommended_build_text(map_data: Dictionary) -> String:
	var configured: String = _get_string_list_text(map_data.get("recommended_build_tags", []), "")
	if configured != "":
		return configured
	match str(map_data.get("id", "")):
		"abandoned_dungeon":
			return "任意初始技能成长、稳定拾取、基础伤害。"
		"toxic_fog_graveyard":
			return "DOT、净化、回复、毒抗或远程范围。"
		"lava_temple":
			return "控制、护盾、移速、爆发单体。"
		"abyss_corridor":
			return "穿透、弹射、陷阱、场域控制。"
		_:
			return "未配置"


## 作用：获取地图不满足推荐文本，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_map_not_recommended_text(map_data: Dictionary) -> String:
	var configured: String = _get_string_list_text(map_data.get("not_recommended_build_tags", []), "")
	if configured != "":
		return configured
	match str(map_data.get("id", "")):
		"toxic_fog_graveyard":
			return "纯近战、无回复、低机动。"
		"lava_temple":
			return "站桩、低移速、无防御。"
		"abyss_corridor":
			return "单点低穿透、无控场。"
		_:
			return "-"


## 作用：获取地图敌人预览ID列表，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_enemy_previews 调用；输入 map_data（地图数据）；返回 Array 列表。
func _get_map_enemy_preview_ids(map_data: Dictionary) -> Array:
	var configured: Array = _get_array(map_data.get("enemy_preview_ids", []))
	if not configured.is_empty():
		return configured
	match str(map_data.get("id", "")):
		"toxic_fog_graveyard":
			return [&"toxic_bug", &"small_slime", &"skeleton_priest"]
		"lava_temple":
			return [&"bomber", &"armored_skeleton", &"skeleton"]
		"abyss_corridor":
			return [&"shadow_hunter", &"archer_skeleton", &"bat"]
		_:
			return [&"small_slime", &"skeleton", &"bat"]


## 作用：获取锁定或清除文本，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 map_data（地图数据）；返回 String 文本/标识。
func _get_lock_or_clear_text(map_data: Dictionary) -> String:
	var map_id: StringName = StringName(str(map_data.get("id", "")))
	if SaveManager.is_map_cleared(map_id):
		return "状态：已通关"
	if MapRuntimeScript.is_map_unlocked(map_data):
		return "状态：已解锁"
	var unlock: Dictionary = _get_dictionary(map_data.get("unlock", {}))
	if str(unlock.get("type", "")) == "clear_map":
		var required_map_id: StringName = StringName(str(unlock.get("map_id", "")))
		return "解锁条件：通关 %s" % _get_map_display_name(GameData.get_map(required_map_id))
	return "状态：未解锁"


## 作用：获取角色展示名称，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_loadout、_get_loadout_detail_text 调用；输入 character（角色）；返回 String 文本/标识。
func _get_character_display_name(character: Dictionary) -> String:
	return UIDisplayHelperScript.character_name(character, _selected_character_id)


## 作用：获取起始技能展示名称，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_loadout、_get_loadout_detail_text 调用；返回 String 文本/标识。
func _get_starting_skill_display_name() -> String:
	var character: Dictionary = GameData.get_character(_selected_character_id)
	var starting_skill_id: StringName = StringName(str(character.get("starting_skill_id", "")))
	if starting_skill_id == &"":
		return "未配置"
	return UIDisplayHelperScript.skill_name(starting_skill_id)


## 作用：获取敌人展示名称，供当前模块后续逻辑使用。
## 使用：本文件由 _create_enemy_preview_card 调用；输入 enemy（敌人）、fallback_id（回退ID）；返回 String 文本/标识。
func _get_enemy_display_name(enemy: Dictionary, fallback_id: StringName) -> String:
	return UIDisplayHelperScript.enemy_name(enemy, fallback_id)


## 作用：获取敌人视觉纹理，供当前模块后续逻辑使用。
## 使用：本文件由 _create_enemy_preview_card 调用；输入 enemy（敌人）；返回 Texture2D 对象/值。
func _get_enemy_visual_texture(enemy: Dictionary) -> Texture2D:
	return UIDisplayHelperScript.visual_texture(enemy, "icon")


## 作用：获取视觉调色，供当前模块后续逻辑使用。
## 使用：本文件由 _create_enemy_preview_card 调用；输入 definition（定义）；返回 Color 对象/值。
func _get_visual_modulate(definition: Dictionary) -> Color:
	return UIDisplayHelperScript.visual_modulate(definition)


## 作用：选择地图。
## 使用：本文件由 _add_map_card 调用；输入 map_id（地图ID）。
func _select_map(map_id: StringName) -> void:
	selected_map_id = map_id
	_refresh_map_cards()
	_refresh_selected_map_details()
	_refresh_loadout()


## 作用：启动当前选择地图。
## 使用：本文件由 _build_detail_panel 调用。
func _start_selected_map() -> void:
	var map_data: Dictionary = GameData.get_map(selected_map_id)
	if not _can_start(map_data):
		return
	start_requested.emit(selected_map_id)


## 作用：发出返回请求并衔接对应的事件处理流程。
## 使用：本文件由 _build_nav_bar 调用。
func _emit_back_requested() -> void:
	back_requested.emit()


## 作用：设置详情标签。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 key（键）、text（文本）。
func _set_detail_label(key: String, text: String) -> void:
	var label: Label = _detail_labels.get(key, null) as Label
	if label != null:
		label.text = text


## 作用：设置开局配置标签。
## 使用：本文件由 _refresh_loadout 调用；输入 key（键）、text（文本）。
func _set_loadout_label(key: String, text: String) -> void:
	var label: Label = _loadout_labels.get(key, null) as Label
	if label != null:
		label.text = text


## 作用：设置控件最小尺寸。
## 使用：本文件由 update_layout 调用；输入 key（键）、size（尺寸）。
func _set_control_min_size(key: String, size: Vector2) -> void:
	var control: Control = _layout_controls.get(key, null) as Control
	if control != null:
		control.custom_minimum_size = size


## 作用：添加标签并配置节点/样式所需的属性。
## 使用：本文件由 _build_nav_bar、_add_detail_label 调用；输入 parent（父节点）、text（文本）、alignment（alignment）、node_name（节点名称）；返回 Label 对象/值。
func _add_label(parent: Node, text: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, node_name: String = "") -> Label:
	var label: Label = Label.new()
	if node_name != "":
		label.name = node_name
	label.text = text
	label.horizontal_alignment = alignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


## 作用：添加详情标签。
## 使用：本文件由 _build_preview、_build_detail_panel、_add_loadout_label 调用；输入 parent（父节点）、text（文本）；返回 Label 对象/值。
func _add_detail_label(parent: Node, text: String) -> Label:
	var label: Label = _add_label(parent, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


## 作用：添加按钮并配置节点/样式所需的属性。
## 使用：本文件由 _build_nav_bar、_build_detail_panel 调用；输入 parent（父节点）、text（文本）；返回 Button 对象/值。
func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button


## 作用：创建面板容器并配置节点/样式所需的属性。
## 使用：本文件由 _build_map_list、_build_preview、_build_detail_panel 调用；输入 min_size（最小尺寸）、stretch_ratio（stretchratio）；返回 PanelContainer 对象/值。
func _create_panel_container(min_size: Vector2, stretch_ratio: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	return panel


## 作用：创建边距容器并配置节点/样式所需的属性。
## 使用：本文件由 _build_map_list、_build_preview、_build_detail_panel 调用；输入 left（left）、top（顶部）、right（right）、bottom（bottom）；返回 MarginContainer 对象/值。
func _create_margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


## 作用：创建面板样式并配置节点/样式所需的属性。
## 使用：本文件由 _create_panel_container 调用；返回 StyleBoxFlat 对象/值。
func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.115, 0.13, 0.94)
	style.border_color = Color(0.24, 0.265, 0.31, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


## 作用：创建地图卡片样式并配置节点/样式所需的属性。
## 使用：本文件由 _add_map_card 调用；输入 is_selected（判断当前选择）、is_hovered（判断hovered）、is_unlocked（判断已解锁）；返回 StyleBoxFlat 对象/值。
func _create_map_card_style(is_selected: bool, is_hovered: bool, is_unlocked: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var color: Color = Color(0.135, 0.15, 0.18, 0.96)
	if not is_unlocked:
		color = Color(0.095, 0.1, 0.11, 0.78)
	elif is_selected:
		color = Color(0.26, 0.31, 0.25, 0.98)
	elif is_hovered:
		color = Color(0.18, 0.205, 0.24, 0.98)
	style.bg_color = color
	style.border_color = Color(0.76, 0.68, 0.42, 0.95) if is_selected else Color(0.26, 0.29, 0.33, 0.82)
	style.border_width_left = 2 if is_selected else 1
	style.border_width_top = 2 if is_selected else 1
	style.border_width_right = 2 if is_selected else 1
	style.border_width_bottom = 2 if is_selected else 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## 作用：创建敌人预览卡片样式并配置节点/样式所需的属性。
## 使用：本文件由 _create_enemy_preview_card 调用；返回 StyleBoxFlat 对象/值。
func _create_enemy_preview_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.1, 0.96)
	style.border_color = Color(0.26, 0.29, 0.33, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


## 作用：获取字符串列表文本，为界面/配置读取提供类型和回退处理。
## 使用：本文件由 _get_map_recommended_build_text、_get_map_not_recommended_text 调用；输入 value（值）、fallback（回退）；返回 String 文本/标识。
func _get_string_list_text(value: Variant, fallback: String) -> String:
	var parts: Array[String] = []
	for item_variant: Variant in _get_array(value):
		parts.append(str(item_variant))
	return "\n".join(parts) if not parts.is_empty() else fallback


## 作用：获取星级文本，供当前模块后续逻辑使用。
## 使用：本文件由 _refresh_selected_map_details、_get_map_card_text 调用；输入 value（值）；返回 String 文本/标识。
func _get_star_text(value: int) -> String:
	var clamped_value: int = clampi(value, 1, 5)
	var parts: Array[String] = []
	for star_index: int in range(5):
		parts.append("★" if star_index < clamped_value else "☆")
	return "".join(parts)


## 作用：格式化时间。
## 使用：本文件由 _refresh_selected_map_details 调用；输入 seconds（秒）；返回 String 文本/标识。
func _format_time(seconds: float) -> String:
	var total_seconds: int = maxi(roundi(seconds), 0)
	var minutes: int = floori(float(total_seconds) / 60.0)
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


## 作用：从容器移除子节点并请求释放，供重建列表使用。
## 使用：本文件由 _refresh_map_cards、_refresh_enemy_previews 调用；输入 parent（父节点）。
func _clear_children(parent: Node) -> void:
	UIDisplayHelperScript.clear_children(parent)


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _add_enemy_preview_group、_get_map_traits_text、_get_map_enemy_preview_ids 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	return UIDisplayHelperScript.array(value)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _get_map_traits_text、_get_lock_or_clear_text 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	return UIDisplayHelperScript.dictionary(value)
