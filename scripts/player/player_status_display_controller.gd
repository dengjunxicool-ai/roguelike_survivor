## 文件用途：把玩家状态效果和特质护盾整理为最多六段的状态标签。
## 使用方式：setup 绑定玩家；状态展示脏标记触发后 update(snapshot)，不参与状态或伤害结算。

extends RefCounted
class_name PlayerStatusDisplayController


const StatusShortNameFormatterScript: Script = preload("res://scripts/ui/status_short_name_formatter.gd")

var _owner: Node2D
var _status_label: Label


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner
	_ensure_label()


## 作用：把有效状态叠层与可用特质护盾整理为最多六段文字，并刷新玩家状态标签。
## 使用：snapshot 为状态字典数组；空 ID 或非正层数跳过，无展示条目时隐藏标签。
func update(snapshot: Array[Dictionary]) -> void:
	if _owner == null:
		return
	_ensure_label()
	if _status_label == null:
		return

	var fragments: Array[String] = []
	for status: Dictionary in snapshot:
		var status_id: String = String(status.get("id", ""))
		if status_id == "":
			continue
		var stacks: int = int(status.get("stacks", 0))
		if stacks <= 0:
			continue
		fragments.append("%s%d" % [_get_status_short_name(status_id), stacks])
		if fragments.size() >= 6:
			break

	_append_trait_state_fragments(fragments)
	_status_label.text = " ".join(fragments)
	_status_label.visible = not fragments.is_empty()


## 作用：在剩余展示空间内追加有效特质护盾点数。
## 使用：fragments 为已有展示片段的共享数组；读取 CharacterRuntime 的护盾点数与剩余秒数，不消耗护盾。
func _append_trait_state_fragments(fragments: Array[String]) -> void:
	if _owner == null or fragments.size() >= 6:
		return
	var runtime: Node = _owner.get_node_or_null("CharacterRuntime")
	if runtime == null:
		return
	var trait_state_variant: Variant = runtime.get("trait_runtime_state")
	if not (trait_state_variant is Dictionary):
		return
	var trait_state: Dictionary = trait_state_variant
	var shield_points: int = int(trait_state.get("shield_points", 0))
	var shield_remaining: float = float(trait_state.get("shield_remaining_seconds", 0.0))
	if shield_points > 0 and shield_remaining > 0.0:
		fragments.append("Shd%d" % shield_points)


## 作用：复用或创建玩家脚下的 PlayerStatusLabel 控件。
## 使用：setup 和 update 调用；没有 owner 时跳过，新增标签默认隐藏并挂在玩家下。
func _ensure_label() -> void:
	if _owner == null or (_status_label != null and is_instance_valid(_status_label)):
		return

	_status_label = _owner.get_node_or_null("PlayerStatusLabel") as Label
	if _status_label != null:
		return

	_status_label = Label.new()
	_status_label.name = "PlayerStatusLabel"
	_status_label.position = Vector2(-72.0, 32.0)
	_status_label.size = Vector2(144.0, 22.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_label.z_index = 80
	_status_label.visible = false
	_owner.add_child(_status_label)


## 作用：获取状态效果短名名称，供当前模块后续逻辑使用。
## 使用：本文件由 update 调用；输入 status_id（状态效果ID）；返回 String 文本/标识。
func _get_status_short_name(status_id: String) -> String:
	return StatusShortNameFormatterScript.short_name(status_id)
