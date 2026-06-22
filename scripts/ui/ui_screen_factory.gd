extends RefCounted
class_name UIScreenFactory


const UINodeFactoryScript: Script = preload("res://scripts/ui/ui_node_factory.gd")


## Params:
## - owner: Node that owns the screen.
## - screens: Screen registry dictionary to update.
## - state: UI state key for this screen.
## - z_index_value: Canvas z index for ordering.
## Returns:
## - Created full-rect Control screen.
static func create_screen(owner: Node, screens: Dictionary, state: String, z_index_value: int) -> Control:
	var screen: Control = Control.new()
	screen.name = state
	screen.visible = false
	screen.z_index = z_index_value
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(screen)
	screens[state] = screen
	return screen


## Params:
## - owner: Node that owns the screen.
## - screens: Screen registry dictionary to update.
## - responsive_layout: Responsive layout service used to register the panel.
## - state: UI state key for this screen.
## - title: Header text displayed inside the panel.
## - min_size: Design size used by responsive scaling.
## - z_index_value: Canvas z index for ordering.
## - viewport_size: Current visible viewport size.
## Returns:
## - Body VBoxContainer inside the panel scroll view.
static func create_panel_screen(
	owner: Node,
	screens: Dictionary,
	responsive_layout: RefCounted,
	state: String,
	title: String,
	min_size: Vector2,
	z_index_value: int,
	viewport_size: Vector2
) -> VBoxContainer:
	var screen: Control = create_screen(owner, screens, state, z_index_value)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.06, 0.06, 0.065, 0.82)
	screen.add_child(background)

	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	responsive_layout.call("register_panel", panel, margin, min_size, viewport_size)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	UINodeFactoryScript.add_label(body, title, 1)
	return body
