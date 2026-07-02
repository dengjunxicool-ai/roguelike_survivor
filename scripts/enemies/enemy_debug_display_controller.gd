extends RefCounted
class_name EnemyDebugDisplayController


const DamageNumberPopupScript: Script = preload("res://scripts/combat/damage_number_popup.gd")

var _owner: Node2D
var _hp_bar: ProgressBar
var _hp_lag_bar: ProgressBar
var _hp_tween: Tween
var _popup_offset_index: int = 0


func setup(owner: Node2D) -> void:
	_owner = owner


func update_health(current_health: int, max_health: int) -> void:
	if not _debug_health_display_enabled() or _owner == null:
		return

	_ensure_health_display()
	if _hp_bar != null:
		var max_value: float = maxf(float(max_health), 1.0)
		var target_value: float = clampf(float(current_health), 0.0, max_value)
		var max_changed: bool = not is_equal_approx(float(_hp_bar.max_value), max_value)
		_hp_bar.max_value = max_value
		if _hp_lag_bar != null:
			_hp_lag_bar.max_value = max_value
			_hp_lag_bar.visible = current_health > 0 and current_health < max_health
		_hp_bar.visible = current_health > 0 and current_health < max_health
		_tween_health_value(target_value, max_changed)


func show_damage_number(amount: int, damage_result_or_type: Variant = &"") -> void:
	if _owner == null or amount <= 0:
		return

	var damage_result: Dictionary = _get_damage_result(damage_result_or_type)
	DamageNumberPopupScript.show(_owner, amount, damage_result, {
		"name": "DamageNumber",
		"offset_index": _popup_offset_index,
		"prefix": "",
		"y": -78.0,
		"font_size": 17,
		"drift_x": float((_popup_offset_index % 3) - 1) * 5.0
	})
	_popup_offset_index += 1


func _debug_health_display_enabled() -> bool:
	if not OS.is_debug_build() or _owner == null:
		return false
	var tree: SceneTree = _owner.get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("developer_mode_enabled", false))


func _ensure_health_display() -> void:
	if _owner == null:
		return

	if _hp_lag_bar == null or not is_instance_valid(_hp_lag_bar):
		_hp_lag_bar = _owner.get_node_or_null("DebugHpLagBar") as ProgressBar
		if _hp_lag_bar == null:
			_hp_lag_bar = ProgressBar.new()
			_hp_lag_bar.name = "DebugHpLagBar"
			_configure_bar(_hp_lag_bar, Color(1.0, 0.68, 0.64, 0.78), 59)
			_owner.add_child(_hp_lag_bar)
	if _hp_bar == null or not is_instance_valid(_hp_bar):
		_hp_bar = _owner.get_node_or_null("DebugHpBar") as ProgressBar
		if _hp_bar == null:
			_hp_bar = ProgressBar.new()
			_hp_bar.name = "DebugHpBar"
			_configure_bar(_hp_bar, Color(0.93, 0.18, 0.10, 0.96), 60)
			_owner.add_child(_hp_bar)
	var stale_label: Label = _owner.get_node_or_null("DebugHpLabel") as Label
	if stale_label != null:
		stale_label.queue_free()


func _tween_health_value(target_value: float, force_instant: bool) -> void:
	if _hp_bar == null:
		return
	if force_instant or _hp_bar.value <= 0.0:
		_hp_bar.value = target_value
		if _hp_lag_bar != null:
			_hp_lag_bar.value = target_value
		return
	var previous_value: float = float(_hp_bar.value)
	_hp_bar.value = target_value
	if _hp_lag_bar == null:
		return
	if target_value >= previous_value:
		_hp_lag_bar.value = target_value
		return
	if _hp_lag_bar.value < previous_value:
		_hp_lag_bar.value = previous_value
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	if _owner == null or not _owner.is_inside_tree():
		_hp_lag_bar.value = target_value
		return
	_hp_tween = _owner.create_tween()
	_hp_tween.set_trans(Tween.TRANS_QUAD)
	_hp_tween.set_ease(Tween.EASE_OUT)
	_hp_tween.tween_property(_hp_lag_bar, "value", target_value, 2.0)


func _configure_bar(bar: ProgressBar, fill_color: Color, z: int) -> void:
	bar.position = Vector2(-38.0, -46.0)
	bar.size = Vector2(76.0, 7.0)
	bar.show_percentage = false
	bar.z_index = z
	bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.05, 0.045, 0.04, 0.88)))
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_color))


func _make_bar_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _get_damage_result(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {
		"element": StringName(String(value)),
		"damage_type": StringName(String(value))
	}
