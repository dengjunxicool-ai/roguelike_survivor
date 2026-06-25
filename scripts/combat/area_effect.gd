extends Area2D
class_name AreaEffect


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

@export_range(0, 10000, 1, "or_greater") var damage: int = 4
@export_range(0.05, 30.0, 0.05, "or_greater") var duration: float = 3.0
@export_range(0.05, 10.0, 0.05, "or_greater") var tick_interval: float = 0.5
@export_range(1.0, 1000.0, 1.0, "or_greater") var radius: float = 52.0
@export_range(0, 1000, 1, "or_greater") var max_targets: int = 0
@export_range(0.0, 360.0, 1.0) var cone_width_degrees: float = 0.0
@export var cone_direction: Vector2 = Vector2.RIGHT
@export var status_on_hit: StringName = &""
@export var statuses_on_hit: Array[StringName] = []
@export var status_params: Dictionary = {}
@export var status_normal_only: bool = false
@export var damage_type: StringName = &""
@export var damage_packet: Dictionary = {}
@export var target_group: StringName = &"enemies"
@export var source_id: StringName = &""
@export var event_on_hit: StringName = &""
@export var event_on_expire: StringName = &""
@export var finish_after_damage: bool = false
@export var damage_once_per_body: bool = false
@export var impact_target_id: String = ""
@export var impact_target_damage_multiplier: float = 1.0

var _age: float = 0.0
var _tick_timer: float = 0.0
var _visual_config: Dictionary = {}
var _visual_mode: String = ""
var _visual_style: String = ""
var _visual_color: Color = Color(0.35, 0.95, 0.2, 0.32)
var _visual_ring_color: Color = Color(0.75, 1.0, 0.25, 0.66)
var _visual_seed: float = 0.0
var _damage_window_finished: bool = false
var _finished_by_damage: bool = false
var _base_radius: float = 52.0
var _expand_from_radius: float = -1.0
var _expand_to_radius: float = -1.0
var _damaged_body_ids: Dictionary = {}
var _current_tick_targets_hit: int = 0
var event_bus: Node
var skill_instance: RefCounted
var caster: Node
var skill_manager: Node
var relic_manager: Node
var impact_target: Node
var actions_on_apply: Array = []
var actions_on_tick: Array = []
var actions_on_hit: Array = []
var actions_on_expire: Array = []
var actions_on_death: Array = []


func _ready() -> void:
	_visual_seed = float(get_instance_id() % 997) / 997.0 * TAU
	_apply_radius(radius)


func setup(params: Dictionary) -> void:
	damage = maxi(int(params.get("damage", damage)), 0)
	duration = maxf(float(params.get("duration", duration)), 0.05)
	tick_interval = maxf(float(params.get("tick_interval", tick_interval)), 0.05)
	radius = maxf(float(params.get("radius", params.get("area_radius", radius))), 1.0)
	max_targets = maxi(int(params.get("max_targets", max_targets)), 0)
	cone_width_degrees = clampf(float(params.get("cone_width_degrees", cone_width_degrees)), 0.0, 360.0)
	cone_direction = _get_vector2(params.get("cone_direction", cone_direction), Vector2.RIGHT)
	if cone_direction.length_squared() <= 0.0001:
		cone_direction = Vector2.RIGHT
	else:
		cone_direction = cone_direction.normalized()
	status_on_hit = StringName(String(params.get("status_on_hit", status_on_hit)))
	statuses_on_hit = _get_status_array(params.get("statuses_on_hit", []), status_on_hit)
	status_params = _get_dictionary(params.get("status_params", status_params))
	status_normal_only = bool(params.get("status_normal_only", status_normal_only))
	damage_type = StringName(String(params.get("damage_type", damage_type)))
	damage_packet = _get_dictionary(params.get("damage_packet", damage_packet))
	target_group = StringName(String(params.get("target_group", target_group)))
	source_id = StringName(String(params.get("source_id", source_id)))
	event_on_hit = StringName(String(params.get("event_on_hit", event_on_hit)))
	event_on_expire = StringName(String(params.get("event_on_expire", event_on_expire)))
	actions_on_apply = _get_array(params.get("actions_on_apply", []))
	actions_on_tick = _get_array(params.get("actions_on_tick", []))
	actions_on_hit = _get_array(params.get("actions_on_hit", []))
	actions_on_expire = _get_array(params.get("actions_on_expire", []))
	actions_on_death = _get_array(params.get("actions_on_death", []))
	finish_after_damage = bool(params.get("finish_after_damage", finish_after_damage))
	damage_once_per_body = bool(params.get("damage_once_per_body", damage_once_per_body))
	impact_target_id = String(params.get("impact_target_id", impact_target_id))
	impact_target_damage_multiplier = maxf(float(params.get("impact_target_damage_multiplier", impact_target_damage_multiplier)), 0.0)
	_stabilize_damage_packet_source("area", params)
	DamageTraceContextScript.apply_to_node_meta(self, params)
	damage_packet = DamageTraceContextScript.apply_to_packet(damage_packet, params)
	event_bus = params.get("event_bus") as Node
	skill_instance = params.get("skill_instance") as RefCounted
	caster = params.get("caster") as Node
	skill_manager = params.get("skill_manager") as Node
	relic_manager = params.get("relic_manager") as Node
	impact_target = params.get("impact_target") as Node
	_visual_mode = String(params.get("visual_mode", _visual_mode))
	_visual_style = String(params.get("visual_style", ""))
	_visual_color = _get_color(params.get("visual_color", _visual_color), _visual_color)
	_visual_ring_color = _get_color(params.get("visual_ring_color", _visual_ring_color), _visual_ring_color)
	_age = 0.0
	_tick_timer = 0.0
	_damage_window_finished = false
	_finished_by_damage = false
	_base_radius = radius
	_expand_from_radius = float(params.get("expand_from_radius", -1.0))
	_expand_to_radius = float(params.get("expand_to_radius", -1.0))
	_damaged_body_ids.clear()
	_current_tick_targets_hit = 0
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if _uses_expanding_radius():
		radius = maxf(_expand_from_radius, 1.0)
	_apply_radius(radius)
	_apply_visual(params)
	_execute_apply_actions()


func extend_duration(target_duration: float, max_duration: float = 5.0) -> void:
	var remaining: float = maxf(duration - _age, 0.0)
	var new_remaining: float = minf(maxf(remaining, target_duration), max_duration)
	duration = _age + new_remaining


func set_effect_radius(new_radius: float) -> void:
	radius = maxf(new_radius, 1.0)
	_apply_radius(radius)
	queue_redraw()


func apply_immediate_tick_once() -> void:
	if _damage_window_finished:
		return
	_apply_tick_damage()
	_tick_timer = duration + tick_interval


func _physics_process(delta: float) -> void:
	if _damage_window_finished:
		return

	_age += delta
	_update_expanding_radius()
	if _uses_programmatic_visual():
		queue_redraw()

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick_damage()

	if _age >= duration:
		_finish_damage_window()


func _apply_tick_damage() -> void:
	if damage <= 0 and status_on_hit == &"" and statuses_on_hit.is_empty() and event_on_hit == &"" and actions_on_tick.is_empty() and actions_on_hit.is_empty() and actions_on_death.is_empty():
		return

	var targets: Array[Node] = _collect_tick_damage_targets()
	_current_tick_targets_hit = targets.size()
	for body: Node in targets:
		if _damage_window_finished:
			break
		_damage_body(body)
	_current_tick_targets_hit = 0


func _collect_tick_damage_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var damaged_bodies: Dictionary = {}
	var damaged_count: int = 0
	if monitoring:
		for body: Node in get_overlapping_bodies():
			if _damage_window_finished:
				break
			if max_targets > 0 and damaged_count >= max_targets:
				break
			if not _can_damage_body(body):
				continue
			if not _body_in_effect_shape(body):
				continue
			damaged_bodies[body] = true
			targets.append(body)
			damaged_count += 1

	var tree: SceneTree = get_tree()
	if tree == null:
		return targets

	var radius_squared: float = radius * radius
	for node: Node in tree.get_nodes_in_group(target_group):
		if _damage_window_finished:
			break
		if max_targets > 0 and damaged_count >= max_targets:
			break
		var body: Node2D = node as Node2D
		if body == null or damaged_bodies.has(body):
			continue
		if not _can_damage_body(body):
			continue
		if global_position.distance_squared_to(body.global_position) <= radius_squared and _body_in_effect_shape(body):
			targets.append(body)
			damaged_bodies[body] = true
			damaged_count += 1
	return targets


func _can_damage_body(body: Node) -> bool:
	if body == null or not body.is_in_group(target_group):
		return false
	if damage_once_per_body and _damaged_body_ids.has(body.get_instance_id()):
		return false
	return true


func _body_in_effect_shape(body: Node) -> bool:
	var body_node: Node2D = body as Node2D
	if body_node == null:
		return false
	var to_body: Vector2 = body_node.global_position - global_position
	if to_body.length_squared() > radius * radius:
		return false
	if cone_width_degrees <= 0.0 or cone_width_degrees >= 360.0:
		return true
	if to_body.length_squared() <= 0.0001:
		return true
	var half_angle: float = deg_to_rad(cone_width_degrees) * 0.5
	return absf(cone_direction.angle_to(to_body.normalized())) <= half_angle


func _damage_body(body: Node) -> bool:
	if body == null or not body.is_in_group(target_group):
		return false
	var body_id: int = body.get_instance_id()
	if damage_once_per_body and _damaged_body_ids.has(body_id):
		return false

	if damage > 0 and body.has_method("take_damage"):
		body.call(&"take_damage", _get_damage_payload(body), damage_type)
	_apply_status(body)
	_emit_area_event(event_on_hit, body)
	_execute_adapted_actions(actions_on_tick, body)
	_execute_adapted_actions(actions_on_hit, body)
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		_execute_adapted_actions(actions_on_death, body)
	if damage_once_per_body:
		_damaged_body_ids[body_id] = true
	if finish_after_damage:
		_finished_by_damage = true
		_finish_damage_window()
	return true


func _get_damage_payload(target: Node = null) -> Variant:
	var adjusted_damage: int = _get_adjusted_damage_for_target(target)
	var packet_template: Dictionary = damage_packet.duplicate(true)
	if adjusted_damage != damage:
		packet_template["raw_amount"] = adjusted_damage
		packet_template["amount"] = adjusted_damage
	return DamagePacketBuilderScript.from_combat_object_hit({
		"template": packet_template,
		"target": target,
		"amount": adjusted_damage,
		"source_type": "area",
		"source_id": source_id,
		"source_origin_id": StringName(String(damage_packet.get("source_origin_id", ""))),
		"source_skill_id": StringName(String(damage_packet.get("source_skill_id", source_id))),
		"source_instance_id": str(get_instance_id()),
		"instance_id": get_instance_id(),
		"default_damage_origin": "field",
		"default_damage_type": damage_type if damage_type != &"" else &"area_direct",
		"default_element": &"physical"
	})


func _get_adjusted_damage_for_target(target: Node = null) -> int:
	if target == null or impact_target_id == "" or impact_target_damage_multiplier == 1.0:
		return damage
	if str(target.get_instance_id()) == impact_target_id:
		return maxi(roundi(float(damage) * impact_target_damage_multiplier), 0)
	return damage


func _stabilize_damage_packet_source(default_source_type: String, params: Dictionary = {}) -> void:
	if damage_packet.is_empty():
		return
	if not damage_packet.has("source_instance_id") or String(damage_packet.get("source_instance_id", "")) == "":
		damage_packet["source_instance_id"] = str(get_instance_id())
	if not damage_packet.has("source_type") or String(damage_packet.get("source_type", "")) == "":
		damage_packet["source_type"] = default_source_type
	if (not damage_packet.has("source_id") or String(damage_packet.get("source_id", "")) == "") and source_id != &"":
		damage_packet["source_id"] = source_id
	if not damage_packet.has("source_skill_id") or String(damage_packet.get("source_skill_id", "")) == "":
		damage_packet["source_skill_id"] = StringName(String(params.get("source_skill_id", params.get("skill_id", source_id))))
	if not damage_packet.has("source_origin_id") or String(damage_packet.get("source_origin_id", "")) == "":
		damage_packet["source_origin_id"] = StringName(String(params.get("source_origin_id", "")))


func _apply_status(body: Node) -> void:
	if statuses_on_hit.is_empty() and status_on_hit != &"":
		statuses_on_hit = [status_on_hit]
	if statuses_on_hit.is_empty():
		return
	if status_normal_only and _is_strong_target(body):
		return

	for status_id: StringName in statuses_on_hit:
		if status_id == &"":
			continue

		if body.has_method("apply_status"):
			body.call(&"apply_status", status_id, status_params)
		elif body.has_method("add_status_effect"):
			body.call(&"add_status_effect", status_id)


func _is_strong_target(body: Node) -> bool:
	return body != null and (body.is_in_group(&"elites") or body.is_in_group(&"bosses") or bool(body.get_meta("is_elite", false)) or bool(body.get_meta("is_boss", false)) or String(body.get_meta("enemy_rank", "")) == "elite" or String(body.get_meta("enemy_rank", "")) == "boss")


func _apply_radius(new_radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is CircleShape2D):
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = maxf(new_radius, 1.0)


func _uses_expanding_radius() -> bool:
	return _expand_from_radius >= 0.0 and _expand_to_radius > 0.0


func _update_expanding_radius() -> void:
	if not _uses_expanding_radius():
		return
	var progress: float = clampf(_age / maxf(duration, 0.05), 0.0, 1.0)
	radius = lerpf(_expand_from_radius, _expand_to_radius, progress)
	_apply_radius(radius)


func _apply_visual(params: Dictionary) -> void:
	if _uses_programmatic_visual():
		var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			sprite.visible = false
		var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if animated_sprite != null:
			animated_sprite.visible = false
			animated_sprite.stop()
		z_index = int(params.get("z_index", z_index))
		queue_redraw()
		return

	_visual_config = _get_dictionary(params.get("visual", {}))
	if _visual_config.is_empty():
		_visual_config["modulate"] = _visual_color
	if not _visual_config.has("scale"):
		_visual_config["scale"] = [radius / 64.0, radius / 64.0]
	VisualConfigApplierScript.play_state(self, _visual_config, "loop", "idle")


func _draw() -> void:
	match _visual_style:
		"fire_burst":
			_draw_fire_burst()
			return
		"frost_patch":
			_draw_frost_patch()
			return
		"trap_circle":
			_draw_trap_circle()
			return
		"holy_field":
			_draw_holy_field()
			return
		"holy_shield_pulse":
			_draw_holy_shield_pulse()
			return
		"holy_shield_break", "holy_shield_shockwave", "holy_shield_break_shockwave":
			_draw_holy_shield_pulse()
			return
		"hammer_shockwave":
			_draw_hammer_shockwave()
			return
		"warhammer_crack_field", "warhammer_execution_shockwave":
			_draw_hammer_shockwave()
			return
		"lava_zone":
			_draw_lava_zone()
			return
		"protective_lava_zone":
			_draw_protective_lava_zone()
			return
		"smoke_zone":
			_draw_smoke_zone()
			return
		"acid_cone":
			_draw_acid_cone()
			return
		"poison_zone", "poison_cloud":
			pass
		_:
			return

	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.5 + _visual_seed)
	var center: Vector2 = Vector2.ZERO
	var mist_color: Color = Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.62 + pulse * 0.18) * fade)
	draw_circle(center, radius, mist_color)

	for layer: int in range(3):
		var layer_radius: float = radius * (0.55 + float(layer) * 0.18 + pulse * 0.025)
		var layer_alpha: float = _visual_color.a * (0.18 - float(layer) * 0.035) * fade
		draw_circle(center, layer_radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, layer_alpha))

	var ring_alpha: float = _visual_ring_color.a * (0.65 + pulse * 0.25) * fade
	draw_arc(center, radius * (0.96 + pulse * 0.015), 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, ring_alpha), 2.0, true)
	draw_arc(center, radius * 0.72, _visual_seed + _age * 0.45, _visual_seed + _age * 0.45 + TAU * 0.55, 48, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, ring_alpha * 0.45), 1.5, true)

	for index: int in range(8):
		var offset_angle: float = _visual_seed + float(index) * TAU / 8.0 + _age * (0.32 + float(index % 3) * 0.05)
		var offset_distance: float = radius * (0.16 + float(index % 4) * 0.12)
		var bubble_radius: float = radius * (0.045 + float(index % 3) * 0.012) * (0.82 + pulse * 0.32)
		var bubble_position: Vector2 = Vector2(cos(offset_angle), sin(offset_angle)) * offset_distance
		var bubble_alpha: float = (0.18 + float(index % 2) * 0.06) * fade
		draw_circle(bubble_position, bubble_radius, Color(0.83, 1.0, 0.32, bubble_alpha))
		draw_arc(bubble_position, bubble_radius, 0.0, TAU, 20, Color(0.95, 1.0, 0.58, bubble_alpha * 0.9), 1.0, true)


func _draw_fire_burst() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 12.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.68 + pulse * 0.12) * fade))
	draw_circle(Vector2.ZERO, radius * (0.48 + pulse * 0.06), Color(1.0, 0.72, 0.18, 0.24 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.4, true)
	for index: int in range(8):
		var angle: float = _visual_seed + float(index) * TAU / 8.0 + pulse * 0.2
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius * (0.72 + pulse * 0.12), Color(1.0, 0.48, 0.08, 0.16 * fade), 1.4, true)


func _draw_frost_patch() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.5 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.0, true)
	for index: int in range(6):
		var angle: float = _visual_seed + float(index) * TAU / 6.0
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius * (0.78 + pulse * 0.04), Color(0.88, 0.96, 1.0, 0.28 * fade), 1.6, true)
		draw_circle(Vector2(cos(angle), sin(angle)) * radius * 0.42, radius * 0.035, Color(1.0, 1.0, 1.0, 0.35 * fade))


func _draw_trap_circle() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * 0.55, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.42 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 80, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.4, true)
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0
		var inner: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.70
		var outer: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.92
		draw_line(inner, outer, Color(0.34, 0.24, 0.12, 0.42 * fade), 1.8, true)


func _draw_holy_field() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.98, 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 2.5, true)
	draw_arc(Vector2.ZERO, radius * (0.62 + pulse * 0.025), 0.0, TAU, 96, Color(1.0, 1.0, 0.82, 0.36 * fade), 1.8, true)
	draw_line(Vector2(-radius * 0.28, 0.0), Vector2(radius * 0.28, 0.0), Color(1.0, 1.0, 0.84, 0.46 * fade), 2.0, true)
	draw_line(Vector2(0.0, -radius * 0.32), Vector2(0.0, radius * 0.34), Color(1.0, 1.0, 0.84, 0.46 * fade), 2.0, true)


func _draw_holy_shield_pulse() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.36 * fade))
	draw_arc(Vector2.ZERO, radius * (0.55 + 0.42 * life_ratio), 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.74, 0.0, TAU, 96, Color(1.0, 1.0, 0.86, 0.36 * fade), 1.8, true)


func _draw_hammer_shockwave() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.42 * fade))
	draw_arc(Vector2.ZERO, radius * (0.35 + life_ratio * 0.62), 0.0, TAU, 96, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 3.0, true)
	for index: int in range(5):
		var angle: float = _visual_seed + float(index) * TAU / 5.0
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.22
		var end: Vector2 = Vector2(cos(angle + 0.08 * sin(_visual_seed)), sin(angle + 0.08 * sin(_visual_seed))) * radius * 0.82
		draw_line(start, end, Color(0.42, 0.28, 0.10, 0.34 * fade), 2.2, true)


func _draw_lava_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 6.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.12, 0.02, 0.26 * fade))
	draw_circle(Vector2.ZERO, radius * (0.72 + pulse * 0.04), Color(1.0, 0.34, 0.04, 0.18 * fade))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 96, Color(1.0, 0.72, 0.12, 0.72 * fade), 2.0, true)
	for index: int in range(6):
		var angle: float = _visual_seed + float(index) * TAU / 6.0 - _age * 0.28
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.2 + float(index % 3) * 0.16)
		draw_circle(pos, radius * (0.05 + pulse * 0.018), Color(1.0, 0.84, 0.18, 0.28 * fade))


func _draw_protective_lava_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.0 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	draw_arc(Vector2.ZERO, radius * 0.98, 0.0, TAU, 128, Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, _visual_ring_color.a * fade), 3.0, true)
	draw_arc(Vector2.ZERO, radius * (0.76 + pulse * 0.02), 0.0, TAU, 96, Color(1.0, 0.75, 0.16, 0.58 * fade), 2.0, true)
	for index: int in range(10):
		var angle: float = _visual_seed + float(index) * TAU / 10.0 + _age * 0.35
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.86
		draw_circle(pos, radius * 0.025, Color(0.55, 1.0, 0.62, 0.45 * fade))


func _draw_smoke_zone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 3.7 + _visual_seed)
	draw_circle(Vector2.ZERO, radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * fade))
	for layer: int in range(4):
		var angle: float = _visual_seed + float(layer) * TAU / 4.0 + _age * (0.08 + float(layer) * 0.03)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.10 + float(layer) * 0.09)
		var layer_radius: float = radius * (0.42 + float(layer) * 0.10 + pulse * 0.03)
		var alpha: float = _visual_color.a * (0.34 - float(layer) * 0.045) * fade
		draw_circle(offset, layer_radius, Color(_visual_color.r, _visual_color.g, _visual_color.b, alpha))
	draw_arc(Vector2.ZERO, radius * 0.96, 0.0, TAU, 80, Color(0.78, 0.80, 0.82, 0.30 * fade), 1.5, true)


func _draw_acid_cone() -> void:
	var life_ratio: float = clampf(_age / maxf(duration, 0.01), 0.0, 1.0)
	var fade: float = clampf(1.0 - life_ratio * life_ratio, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * 9.0 + _visual_seed)
	var direction_angle: float = cone_direction.angle()
	var width: float = deg_to_rad(clampf(cone_width_degrees, 1.0, 360.0))
	var start_angle: float = direction_angle - width * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	var segments: int = maxi(int(width / TAU * 96.0), 8)
	for index: int in range(segments + 1):
		var angle: float = start_angle + width * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * (0.68 + pulse * 0.12) * fade))
	draw_arc(Vector2.ZERO, radius * (0.96 + pulse * 0.012), start_angle, start_angle + width, segments, Color(0.86, 1.0, 0.28, 0.72 * fade), 2.5, true)
	for index: int in range(5):
		var angle: float = start_angle + width * (float(index) + 0.5) / 5.0
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius * (0.88 + pulse * 0.03), Color(0.86, 1.0, 0.28, 0.18 * fade), 1.0, true)


func _finish_damage_window() -> void:
	if _damage_window_finished:
		return
	_damage_window_finished = true
	if not _finished_by_damage:
		_emit_area_event(event_on_expire, null)
		_execute_adapted_actions(actions_on_expire, null)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if _uses_programmatic_visual():
		queue_free()
		return
	if not _wait_for_non_loop_visual_finish():
		queue_free()


func _wait_for_non_loop_visual_finish() -> bool:
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	var animation_name: StringName = animated_sprite.animation
	if animation_name == &"" or not animated_sprite.sprite_frames.has_animation(animation_name):
		return false
	if animated_sprite.sprite_frames.get_animation_loop(animation_name):
		return false
	if not animated_sprite.is_playing():
		return false
	if not animated_sprite.animation_finished.is_connected(Callable(self, "_on_visual_animation_finished")):
		animated_sprite.animation_finished.connect(Callable(self, "_on_visual_animation_finished"), CONNECT_ONE_SHOT)
	return true


func _on_visual_animation_finished() -> void:
	queue_free()


func _emit_area_event(event_name: StringName, target: Node) -> void:
	if event_bus == null or event_name == &"" or not event_bus.has_method("emit_skill_event"):
		return
	event_bus.call("emit_skill_event", event_name, DamageTraceContextScript.normalize_event_context({
		"caster": caster,
		"owner": caster,
		"target": target,
		"enemy": target,
		"area": self,
		"source": self,
		"source_id": source_id,
		"source_key": String(damage_packet.get("source_id", source_id)),
		"source_instance_id": String(damage_packet.get("source_instance_id", str(get_instance_id()))),
		"explosion_targets_hit": _current_tick_targets_hit,
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else &"",
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_type": damage_type,
		"damage_packet": damage_packet,
		"position": global_position
	}))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		var items: Array = value
		return items.duplicate(true)
	return []


func _execute_adapted_actions(actions: Array, target: Node) -> void:
	if actions.is_empty() or event_bus == null or not event_bus.has_method("execute_adapted_actions"):
		return
	event_bus.call("execute_adapted_actions", actions, DamageTraceContextScript.normalize_event_context({
		"caster": caster,
		"owner": caster,
		"target": target,
		"enemy": target,
		"area": self,
		"source": self,
		"source_id": source_id,
		"source_key": String(damage_packet.get("source_id", source_id)),
		"source_instance_id": String(damage_packet.get("source_instance_id", str(get_instance_id()))),
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else &"",
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_type": damage_type,
		"damage_packet": damage_packet,
		"position": global_position
	}))


func _execute_apply_actions() -> void:
	if actions_on_apply.is_empty():
		return
	if impact_target != null:
		_execute_adapted_actions(actions_on_apply, impact_target)
		return
	for target: Node in _collect_tick_damage_targets():
		_execute_adapted_actions(actions_on_apply, target)


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			var alpha: float = float(items[3]) if items.size() > 3 else fallback.a
			return Color(float(items[0]), float(items[1]), float(items[2]), alpha)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return fallback


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	if value is Dictionary:
		var dictionary: Dictionary = value
		return Vector2(float(dictionary.get("x", fallback.x)), float(dictionary.get("y", fallback.y)))
	return fallback


func _get_status_array(value: Variant, fallback_status: StringName = &"") -> Array[StringName]:
	var statuses: Array[StringName] = []
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			var status_id: StringName = StringName(String(item))
			if status_id != &"" and not statuses.has(status_id):
				statuses.append(status_id)

	if statuses.is_empty() and fallback_status != &"":
		statuses.append(fallback_status)

	return statuses


func _uses_programmatic_visual() -> bool:
	if _visual_mode == "asset":
		return false
	return [
		"fire_burst",
		"frost_patch",
		"trap_circle",
		"holy_field",
		"holy_shield_pulse",
		"holy_shield_break",
		"holy_shield_shockwave",
		"holy_shield_break_shockwave",
		"hammer_shockwave",
		"warhammer_crack_field",
		"warhammer_execution_shockwave",
		"poison_zone",
		"poison_cloud",
		"lava_zone",
		"protective_lava_zone",
		"smoke_zone",
		"acid_cone"
	].has(_visual_style)

