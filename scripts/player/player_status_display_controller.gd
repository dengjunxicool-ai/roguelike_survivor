extends RefCounted
class_name PlayerStatusDisplayController


const StatusShortNameFormatterScript: Script = preload("res://scripts/ui/status_short_name_formatter.gd")

var _owner: Node2D
var _status_label: Label


func setup(owner: Node2D) -> void:
	_owner = owner
	_ensure_label()


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


func _get_status_short_name(status_id: String) -> String:
	return StatusShortNameFormatterScript.short_name(status_id)
