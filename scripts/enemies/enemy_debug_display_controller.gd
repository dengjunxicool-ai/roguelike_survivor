## 文件用途：显示开发模式血条、滞后血条和战斗伤害数字。
## 使用方式：setup 注入 enemy；update_health 仅在调试构建且开启开发模式时显示血条，show_damage_number 独立创建伤害弹字。

extends RefCounted
class_name EnemyDebugDisplayController


const DamageNumberPopupScript: Script = preload("res://scripts/combat/damage_number_popup.gd")

var _owner: Node2D
var _hp_bar: ProgressBar
var _hp_lag_bar: ProgressBar
var _hp_tween: Tween
var _popup_offset_index: int = 0


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner


## 作用：在开发模式下更新即时血条和滞后血条，仅显示受伤且存活敌人的血量。
## 使用：current_health/max_health 为生命值；非调试构建或未启用开发模式时跳过。
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


## 作用：在敌人上方创建按伤害类型着色并错位的伤害数字。
## 使用：amount 必须为正；damage_result_or_type 可传伤害结果字典或类型 ID，此入口不受开发模式血条开关限制。
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


## 作用：检查调试构建、owner 与场景树及开发模式开关。
## 使用：只在 root 的 developer_mode_enabled 元数据为真时返回 true。
func _debug_health_display_enabled() -> bool:
	if not OS.is_debug_build() or _owner == null:
		return false
	var tree: SceneTree = _owner.get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("developer_mode_enabled", false))


## 作用：复用或创建即时与滞后血条，并移除旧的数值血量标签。
## 使用：由 update_health 调用；新增控件挂在敌人 owner 下。
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


## 作用：立即更新主血条，并让滞后血条通过补间追上降低后的血量。
## 使用：force_instant 或首次更新直接同步；回复血量时立即同步，减少血量时播放滞后效果。
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


## 作用：配置进度条。
## 使用：本文件由 _ensure_health_display 调用；输入 bar（进度条）、fill_color（填充颜色）、z（z）。
func _configure_bar(bar: ProgressBar, fill_color: Color, z: int) -> void:
	bar.position = Vector2(-38.0, -46.0)
	bar.size = Vector2(76.0, 7.0)
	bar.show_percentage = false
	bar.z_index = z
	bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.05, 0.045, 0.04, 0.88)))
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_color))


## 作用：生成进度条样式并配置节点/样式所需的属性。
## 使用：本文件由 _configure_bar 调用；输入 color（颜色）；返回 StyleBoxFlat 对象/值。
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


## 作用：获取伤害结果，供当前模块后续逻辑使用。
## 使用：本文件由 show_damage_number 调用；输入 value（值）；返回字典包含 element/damage_type。
func _get_damage_result(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {
		"element": StringName(String(value)),
		"damage_type": StringName(String(value))
	}
