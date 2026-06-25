extends RefCounted
class_name ResultScreenController


signal state_requested(state: String)
signal recommended_loadout_requested(character_id: StringName, map_id: StringName)


const STATE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const STATE_META_UPGRADE: String = "META_UPGRADE"
const STATE_TITLE: String = "TITLE"
const ResultUnlockServiceScript: Script = preload("res://scripts/ui/result_unlock_service.gd")
const ResultScreenViewModelBuilderScript: Script = preload("res://scripts/ui/screens/result_screen_view_model_builder.gd")

var _labels_by_state: Dictionary = {}
var _reason_labels_by_state: Dictionary = {}
var _last_diagnostics_by_state: Dictionary = {}
var _result_unlock_service: RefCounted = ResultUnlockServiceScript.new()
var _view_model_builder: RefCounted = ResultScreenViewModelBuilderScript.new()


func build(body: VBoxContainer, state: String) -> void:
	var labels: Dictionary = {}
	labels["title"] = _add_label(body, "结果：", HORIZONTAL_ALIGNMENT_CENTER)
	labels["character"] = _add_label(body, "角色：", HORIZONTAL_ALIGNMENT_CENTER)
	labels["map"] = _add_label(body, "地图：", HORIZONTAL_ALIGNMENT_CENTER)
	labels["time"] = _add_label(body, "时间：00:00", HORIZONTAL_ALIGNMENT_CENTER)
	labels["kill"] = _add_label(body, "击杀：0", HORIZONTAL_ALIGNMENT_CENTER)
	labels["progress"] = _add_label(body, "初始技能：-", HORIZONTAL_ALIGNMENT_CENTER)
	labels["cause"] = _add_label(body, "死亡原因：")
	labels["boss"] = _add_label(body, "Boss DPS：")
	labels["summary"] = _add_label(body, "构筑摘要：")
	labels["upgrades"] = _add_label(body, "高贡献升级：-")
	labels["damage"] = _add_label(body, "伤害结构：")
	labels["taken"] = _add_label(body, "受伤来源：")
	labels["diagnosis"] = _add_label(body, "诊断：")
	labels["suggestion"] = _add_label(body, "下局建议：")
	labels["soul"] = _add_label(body, "灵魂石：0", HORIZONTAL_ALIGNMENT_CENTER)
	labels["unlock"] = _add_label(body, "解锁：无")
	_labels_by_state[state] = labels

	var reason_label: Label = _add_label(body, "推荐原因：")
	reason_label.visible = false
	_reason_labels_by_state[state] = reason_label

	_add_button(body, "应用推荐配置").pressed.connect(Callable(self, "_emit_recommended_loadout").bind(state))
	_add_button(body, "查看推荐原因").pressed.connect(Callable(self, "_toggle_reason").bind(state))
	_add_state_button(body, "再来一局", STATE_CHARACTER_SELECT)
	_add_state_button(body, "局外强化", STATE_META_UPGRADE)
	_add_state_button(body, "返回主菜单", STATE_TITLE)


func refresh(state: String, run_state: Dictionary) -> void:
	var labels: Dictionary = _labels_by_state.get(state, {})
	if labels.is_empty():
		return

	var selected_map_id: StringName = StringName(String(run_state.get("selected_map_id", "")))
	var selected_map_name: String = String(run_state.get("selected_map_name", selected_map_id))
	var run_seconds: float = float(run_state.get("run_seconds", 0.0))
	var unlocks: Array[String] = _get_result_unlocks(state, run_seconds, selected_map_id, selected_map_name)
	unlocks.append_array(_get_progression_unlocks(run_state))
	var view_model: Dictionary = _view_model_builder.call("build", state, run_state, unlocks)
	_last_diagnostics_by_state[state] = _get_dictionary(view_model.get("diagnostic", {}))
	var label_texts: Dictionary = _get_dictionary(view_model.get("labels", {}))
	for key: Variant in label_texts.keys():
		_set_label(labels, String(key), String(label_texts[key]))
	var reason_label: Label = _reason_labels_by_state.get(state, null) as Label
	if reason_label != null:
		reason_label.text = String(view_model.get("reason", "推荐原因："))
		reason_label.visible = false


func _get_result_unlocks(state: String, run_seconds: float, selected_map_id: StringName, selected_map_name: String) -> Array[String]:
	var unlocks_variant: Variant = _result_unlock_service.call("apply_result_unlocks", state, run_seconds, selected_map_id, selected_map_name)
	var unlocks: Array[String] = []
	if unlocks_variant is Array:
		for unlock_variant: Variant in unlocks_variant:
			unlocks.append(String(unlock_variant))
	return unlocks


func _get_progression_unlocks(run_state: Dictionary) -> Array[String]:
	var summary: Dictionary = _get_dictionary(run_state.get("progression_summary", {}))
	var unlocks_variant: Variant = summary.get("progression_unlocks", [])
	var unlocks: Array[String] = []
	if unlocks_variant is Array:
		for unlock_variant: Variant in unlocks_variant:
			unlocks.append(String(unlock_variant))
	return unlocks


func _toggle_reason(state: String) -> void:
	var label: Label = _reason_labels_by_state.get(state, null) as Label
	if label != null:
		label.visible = not label.visible


func _emit_recommended_loadout(state: String) -> void:
	var diagnostic: Dictionary = _get_dictionary(_last_diagnostics_by_state.get(state, {}))
	recommended_loadout_requested.emit(
		StringName(String(diagnostic.get("recommended_character_id", "mage"))),
		StringName(String(diagnostic.get("recommended_map_id", "abandoned_dungeon")))
	)


func _set_label(labels: Dictionary, key: String, text: String) -> void:
	var label: Label = labels.get(key, null) as Label
	if label != null:
		label.text = text


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _add_state_button(parent: Node, text: String, state: String) -> Button:
	var button: Button = _add_button(parent, text)
	button.pressed.connect(Callable(self, "_emit_state").bind(state))
	return button


func _emit_state(state: String) -> void:
	state_requested.emit(state)


func _add_label(parent: Node, text: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	parent.add_child(label)
	return label


func _add_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIButtonSkin.apply(button)
	parent.add_child(button)
	return button
