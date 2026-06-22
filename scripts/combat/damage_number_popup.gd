extends RefCounted
class_name DamageNumberPopup


const COLOR_DEFAULT: Color = Color(1.0, 0.95, 0.62, 1.0)
const COLOR_PHYSICAL: Color = Color(1.0, 0.32, 0.28, 1.0)
const COLOR_FIRE: Color = Color(1.0, 0.45, 0.12, 1.0)
const COLOR_ICE: Color = Color(0.55, 0.86, 1.0, 1.0)
const COLOR_LIGHTNING: Color = Color(0.58, 0.92, 1.0, 1.0)
const COLOR_POISON: Color = Color(0.42, 1.0, 0.28, 1.0)
const COLOR_ACID: Color = Color(0.74, 1.0, 0.18, 1.0)
const COLOR_ARCANE: Color = Color(0.78, 0.48, 1.0, 1.0)
const COLOR_HOLY: Color = Color(1.0, 0.9, 0.34, 1.0)
const COLOR_DOT: Color = Color(0.62, 1.0, 0.42, 1.0)
const COLOR_REACTION: Color = Color(1.0, 0.35, 0.78, 1.0)
const COLOR_TRAP: Color = Color(0.95, 0.62, 0.28, 1.0)
const COLOR_TRUE_DAMAGE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_INCOMING: Color = Color(1.0, 0.16, 0.18, 1.0)


static func show(owner: Node2D, amount: int, damage_result: Dictionary = {}, options: Dictionary = {}) -> void:
	if owner == null or amount <= 0:
		return

	var parent: Node = _get_popup_parent(owner, options)
	if parent == null:
		return

	var label: Label = Label.new()
	label.name = String(options.get("name", "DamageNumber"))
	label.text = "%s%d" % [String(options.get("prefix", "-")), amount]
	label.size = Vector2(float(options.get("width", 76.0)), float(options.get("height", 24.0)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(options.get("font_size", 17)))
	label.add_theme_color_override("font_color", _get_damage_color(damage_result, options))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = int(options.get("z_index", 120))
	parent.add_child(label)
	label.global_position = owner.global_position + _get_start_position(options)

	if bool(damage_result.get("is_critical", false)):
		label.text = "%d" % amount
		label.add_theme_font_size_override("font_size", int(options.get("critical_font_size", 22)))
		label.scale = Vector2(1.08, 1.08)

	var rise: float = float(options.get("rise", 32.0))
	var duration: float = float(options.get("duration", 0.62))
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - rise, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:x", label.global_position.x + float(options.get("drift_x", 0.0)), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


static func _get_popup_parent(owner: Node2D, options: Dictionary) -> Node:
	var configured_parent: Node = options.get("parent") as Node
	if configured_parent != null:
		return configured_parent
	var owner_parent: Node = owner.get_parent()
	if owner_parent != null:
		return owner_parent
	var tree: SceneTree = owner.get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return owner


static func _get_start_position(options: Dictionary) -> Vector2:
	var offset: Vector2 = Vector2(float(options.get("x", -38.0)), float(options.get("y", -78.0)))
	var index: int = int(options.get("offset_index", 0))
	offset.x += float((index % 5) - 2) * float(options.get("spread_x", 10.0))
	offset.y -= float(index % 2) * float(options.get("stack_y", 6.0))
	return offset


static func _get_damage_color(damage_result: Dictionary, options: Dictionary) -> Color:
	if bool(options.get("incoming", false)):
		return COLOR_INCOMING
	var damage_type: StringName = StringName(String(damage_result.get("damage_type", options.get("damage_type", ""))))
	var element: StringName = StringName(String(damage_result.get("element", options.get("element", ""))))
	match damage_type:
		&"status_dot":
			return COLOR_DOT
		&"reaction_damage":
			return COLOR_REACTION
		&"trap_damage":
			return COLOR_TRAP
		&"true_damage", &"true_percent_damage":
			return COLOR_TRUE_DAMAGE

	match element:
		&"physical":
			return COLOR_PHYSICAL
		&"fire", &"burn":
			return COLOR_FIRE
		&"ice", &"freeze":
			return COLOR_ICE
		&"lightning", &"shock":
			return COLOR_LIGHTNING
		&"poison":
			return COLOR_POISON
		&"acid":
			return COLOR_ACID
		&"arcane":
			return COLOR_ARCANE
		&"holy":
			return COLOR_HOLY

	match damage_type:
		&"direct_physical", &"projectile_heavy":
			return COLOR_PHYSICAL
		&"direct_magical", &"projectile_small", &"area_direct", &"summon_damage":
			return COLOR_DEFAULT
		_:
			return COLOR_DEFAULT
