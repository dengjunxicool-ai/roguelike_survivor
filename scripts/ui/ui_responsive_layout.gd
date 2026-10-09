## 文件用途：计算 UI 缩放、断点和设计坐标并刷新登记面板。
## 使用方式：创建实例后登记设计尺寸，视口变化时 update；通过 apply_design_rect/apply_design_margins 适配控件。

extends RefCounted
class_name UIResponsiveLayout


const PANEL_MIN_SCALE: float = 0.55
const PANEL_MAX_SCALE: float = 1.15
const PANEL_MARGIN_RATIO: float = 0.045
const PANEL_MIN_MARGIN: float = 20.0
const DESIGN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const UI_MIN_SCALE: float = 0.65
const UI_MAX_SCALE: float = 1.15
const COMPACT_MAX_WIDTH: float = 900.0
const COMPACT_MAX_HEIGHT: float = 600.0
const MEDIUM_MAX_WIDTH: float = 1400.0

var _panels: Array[Dictionary] = []


## 作用：取视口宽高相对 1280×720 设计尺寸比例的较小值。
## 使用：viewport_size 为像素；宽高非正时返回 1。
func get_raw_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return minf(
		viewport_size.x / maxf(DESIGN_SIZE.x, 1.0),
		viewport_size.y / maxf(DESIGN_SIZE.y, 1.0)
	)


## 作用：将原始 UI 缩放限制到 0.65～1.15。
## 使用：viewport_size 为像素；供设计矩形和字体布局适配；返回计算或读取的数值。
func get_fit_scale(viewport_size: Vector2) -> float:
	return clampf(get_raw_scale(viewport_size), UI_MIN_SCALE, UI_MAX_SCALE)


## 作用：获取UI缩放，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 viewport_size（视口尺寸）；返回计算或读取的数值。
func get_ui_scale(viewport_size: Vector2) -> float:
	return get_fit_scale(viewport_size)


## 作用：按视口宽高判定 compact/medium/desktop 布局档位。
## 使用：返回 StringName；无效尺寸按 desktop，紧凑档优先判定。
func get_breakpoint(viewport_size: Vector2) -> StringName:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return &"desktop"
	if viewport_size.x < COMPACT_MAX_WIDTH or viewport_size.y < COMPACT_MAX_HEIGHT:
		return &"compact"
	if viewport_size.x < MEDIUM_MAX_WIDTH:
		return &"medium"
	return &"desktop"


## 作用：判断紧凑，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 viewport_size（视口尺寸）。
func is_compact(viewport_size: Vector2) -> bool:
	return get_breakpoint(viewport_size) == &"compact"


## 作用：获取设计偏移，供当前模块后续逻辑使用。
## 使用：本文件由 apply_design_rect 调用；输入 viewport_size（视口尺寸）；返回 Vector2 对象/值。
func get_design_offset(viewport_size: Vector2) -> Vector2:
	var scale: float = get_fit_scale(viewport_size)
	var scaled_design_size: Vector2 = DESIGN_SIZE * scale
	return Vector2(
		maxf((viewport_size.x - scaled_design_size.x) * 0.5, 0.0),
		maxf((viewport_size.y - scaled_design_size.y) * 0.5, 0.0)
	)


## 作用：按 UI 缩放和居中偏移将设计矩形应用到控件。
## 使用：rect 为 1280×720 设计坐标，viewport_size 为实际像素；同时更新偏移和最小尺寸。
func apply_design_rect(control: Control, rect: Rect2, viewport_size: Vector2) -> void:
	if control == null:
		return
	var scale: float = get_fit_scale(viewport_size)
	var offset: Vector2 = get_design_offset(viewport_size)
	var scaled_position: Vector2 = offset + rect.position * scale
	var scaled_size: Vector2 = rect.size * scale
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = scaled_position.x
	control.offset_top = scaled_position.y
	control.offset_right = scaled_position.x + scaled_size.x
	control.offset_bottom = scaled_position.y + scaled_size.y
	control.custom_minimum_size = scaled_size


## 作用：应用设计边距组。
## 使用：供本模块调用者使用；输入 margin（边距）、left（left）、top（顶部）、right（right）、bottom（bottom）、viewport_size（视口尺寸）。
func apply_design_margins(margin: MarginContainer, left: float, top: float, right: float, bottom: float, viewport_size: Vector2) -> void:
	if margin == null:
		return
	var scale: float = get_fit_scale(viewport_size)
	margin.add_theme_constant_override("margin_left", roundi(left * scale))
	margin.add_theme_constant_override("margin_top", roundi(top * scale))
	margin.add_theme_constant_override("margin_right", roundi(right * scale))
	margin.add_theme_constant_override("margin_bottom", roundi(bottom * scale))


## 作用：登记面板、边距容器和设计尺寸并立即应用布局。
## 使用：后续视口变化 update 会重算所有已登记面板。
func register_panel(panel: Panel, margin: MarginContainer, design_size: Vector2, viewport_size: Vector2) -> void:
	_panels.append({
		"panel": panel,
		"margin": margin,
		"design_size": design_size
	})
	apply_panel_layout(panel, margin, design_size, viewport_size)


## 作用：更新。
## 使用：供本模块调用者使用；输入 viewport_size（视口尺寸）。
func update(viewport_size: Vector2) -> void:
	for panel_data: Dictionary in _panels:
		var panel: Panel = panel_data.get("panel", null) as Panel
		var margin: MarginContainer = panel_data.get("margin", null) as MarginContainer
		var design_size: Vector2 = panel_data.get("design_size", Vector2.ZERO)
		if panel != null and margin != null:
			apply_panel_layout(panel, margin, design_size, viewport_size)


## 作用：应用面板布局。
## 使用：本文件由 register_panel、update 调用；输入 panel（面板）、margin（边距）、design_size（设计尺寸）、viewport_size（视口尺寸）。
func apply_panel_layout(panel: Panel, margin: MarginContainer, design_size: Vector2, viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var layout_scale: float = clampf(
		minf(viewport_size.x / maxf(design_size.x, 1.0), viewport_size.y / maxf(design_size.y, 1.0)),
		PANEL_MIN_SCALE,
		PANEL_MAX_SCALE
	)
	var screen_margin: Vector2 = Vector2(
		maxf(viewport_size.x * PANEL_MARGIN_RATIO, PANEL_MIN_MARGIN),
		maxf(viewport_size.y * PANEL_MARGIN_RATIO, PANEL_MIN_MARGIN)
	)
	var max_size: Vector2 = Vector2(
		maxf(viewport_size.x - screen_margin.x * 2.0, 1.0),
		maxf(viewport_size.y - screen_margin.y * 2.0, 1.0)
	)
	var panel_size: Vector2 = Vector2(
		minf(design_size.x * layout_scale, max_size.x),
		minf(design_size.y * layout_scale, max_size.y)
	)

	panel.custom_minimum_size = panel_size
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5

	var horizontal_margin: int = roundi(20.0 * layout_scale)
	var vertical_margin: int = roundi(18.0 * layout_scale)
	margin.add_theme_constant_override("margin_left", horizontal_margin)
	margin.add_theme_constant_override("margin_top", vertical_margin)
	margin.add_theme_constant_override("margin_right", horizontal_margin)
	margin.add_theme_constant_override("margin_bottom", vertical_margin)
