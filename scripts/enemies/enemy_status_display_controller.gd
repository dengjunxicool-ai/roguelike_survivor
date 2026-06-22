extends RefCounted
class_name EnemyStatusDisplayController


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
		if OS.is_debug_build():
			var tick_damage: float = float(status.get("tick_damage", 0.0))
			var tick_interval: float = float(status.get("tick_interval", 0.0))
			if tick_damage > 0:
				fragments.append("%s%d -%.1f/%.1fs" % [_get_status_short_name(status_id), stacks, tick_damage * float(maxi(stacks, 1)), tick_interval])
			else:
				fragments.append("%s%d" % [_get_status_short_name(status_id), stacks])
		else:
			fragments.append("%s%d" % [_get_status_short_name(status_id), stacks])
		if fragments.size() >= 5:
			break

	_status_label.text = " ".join(fragments)
	_status_label.visible = not fragments.is_empty()
	if OS.is_debug_build():
		_status_label.position = Vector2(-88.0, -62.0)
		_status_label.size = Vector2(176.0, 20.0)


func _ensure_label() -> void:
	if _owner == null or (_status_label != null and is_instance_valid(_status_label)):
		return

	_status_label = _owner.get_node_or_null("StatusLabel") as Label
	if _status_label != null:
		return

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector2(-44.0, -54.0)
	_status_label.size = Vector2(88.0, 18.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_label.z_index = 50
	_status_label.visible = false
	_owner.add_child(_status_label)


func _get_status_short_name(status_id: String) -> String:
	match status_id:
		"burn":
			return "Brn"
		"poison":
			return "Psn"
		"bleed":
			return "Bld"
		"freeze":
			return "Frz"
		"slow":
			return "Slw"
		"stun":
			return "Stn"
		"paralyze":
			return "Prz"
		"armor_break":
			return "Arm"
		"shock":
			return "Shk"
		"heat":
			return "Heat"
		"flame_core":
			return "Core"
		"soul_ember":
			return "Embr"
		"soulburn_hint":
			return "Soul"
		"chill":
			return "Chil"
		"frost_lock":
			return "Lock"
		"frostbite":
			return "Fbt"
		"charge":
			return "Chg"
		"voltage":
			return "Volt"
		"arcane_mark":
			return "Arc"
		"arcane_seal":
			return "Seal"
		"wound":
			return "Wnd"
		"eagle_mark":
			return "Egl"
		"burst_mark":
			return "Bst"
		"prey_mark":
			return "Prey"
		"root":
			return "Root"
		"holy_mark":
			return "Hol"
		"judgment":
			return "Jdg"
		"impurity":
			return "Imp"
		"toxin_seed":
			return "Seed"
		"toxic_core":
			return "TCore"
		"flammable_mark":
			return "Fla"
		"oil_stack":
			return "Oil"
		"acid_mark":
			return "Acid"
		"acid_residue":
			return "ARes"
		_:
			return status_id.substr(0, mini(status_id.length(), 4))
