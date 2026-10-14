## 文件用途：组装暂停检视内容，仅展示当前局属性、技能和已有统计。
extends RefCounted

const Nodes = preload("res://scripts/ui/ui_node_factory.gd")
const ViewModel = preload("res://scripts/ui/screens/pause_inspection_view_model_builder.gd")
const Preview = preload("res://scripts/ui/skill_preview_service.gd")
var _stats_toggle: Button
var _skills_toggle: Button
var _stats: Label
var _skills: VBoxContainer
var _contribution: Label
var _scroll: ScrollContainer
var _snapshot: Dictionary = {}

func build(body: VBoxContainer) -> void:
	_scroll = body.get_parent() as ScrollContainer
	_scroll.name = "PauseInspectionScroll"
	_stats_toggle = Nodes.add_button(body,"当前属性 ▸")
	_stats_toggle.name = "PauseStatsToggle"
	_stats_toggle.toggle_mode = true
	_stats = _label(body,"PauseStatsDetails")
	_stats_toggle.toggled.connect(func(open: bool) -> void:
		_stats.visible = open
		_stats_toggle.text = "当前属性 ▾" if open else "当前属性 ▸")
	_skills_toggle = Nodes.add_button(body,"已学技能 ▸")
	_skills_toggle.name = "PauseSkillsToggle"
	_skills_toggle.toggle_mode = true
	_skills = Nodes.add_vbox(body)
	_skills.name = "PauseSkillsDetails"
	_skills_toggle.toggled.connect(func(open: bool) -> void:
		_skills.visible = open
		_skills_toggle.text = "已学技能 ▾" if open else "已学技能 ▸")
	_contribution = _label(body,"PauseRunContribution")
	_stats.visible = false
	_skills.visible = false

func refresh(player: Node, tracker: Node = null) -> void:
	_snapshot = ViewModel.build(player,tracker)
	_stats_toggle.set_pressed_no_signal(false)
	_skills_toggle.set_pressed_no_signal(false)
	_stats_toggle.text = "当前属性 ▸"
	_skills_toggle.text = "已学技能（%d） ▸" % _snapshot.skills.size()
	_stats.visible = false
	_skills.visible = false
	_stats.text = "\n".join(_snapshot.attribute_lines)
	for child: Node in _skills.get_children():
		_skills.remove_child(child)
		child.queue_free()
	for skill: Dictionary in _snapshot.skills:
		var label: Label = _label(_skills,"")
		label.text = "%s · Lv%d · %s\n触发：%s\n%s" % [skill.name,skill.level,Preview.rarity_name(skill.rarity),skill.trigger,"\n".join(skill.lines)]
		label.add_theme_constant_override("line_spacing",4)
	_contribution.text = "\n".join(_snapshot.contribution_lines)
	_scroll.scroll_vertical = 0

func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func _label(parent: Node, node_name: String) -> Label:
	var label: Label = Nodes.add_label(parent,"",0,node_name)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",17)
	return label
