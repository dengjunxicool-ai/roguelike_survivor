extends Area2D
class_name Projectile


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

@export_range(0, 10000, 1, "or_greater") var damage: int = 15
@export_range(1.0, 3000.0, 10.0, "or_greater") var speed: float = 520.0
@export var direction: Vector2 = Vector2.RIGHT
@export_range(0, 100, 1, "or_greater") var pierce: int = 0
@export var status_on_hit: StringName = &""
@export var statuses_on_hit: Array[StringName] = []
@export var status_params: Dictionary = {}
@export var damage_type: StringName = &""
@export var damage_packet: Dictionary = {}
@export_range(0.1, 20.0, 0.1, "or_greater") var lifetime: float = 2.0
@export var target_group: StringName = &"enemies"
@export var source_id: StringName = &""
@export var event_on_hit: StringName = &""
@export var homing_enabled: bool = false
@export_range(0.1, 40.0, 0.1, "or_greater") var homing_turn_rate: float = 8.0
@export_range(0.0, 5000.0, 10.0, "or_greater") var homing_seek_range: float = 0.0
@export var visual_effect_scene: String = ""

var _age: float = 0.0
var _hits_remaining: int = 1
var _hit_bodies: Array[Object] = []
var event_bus: Node
var skill_instance: RefCounted
var caster: Node
var skill_manager: Node
var relic_manager: Node
var _visual_config: Dictionary = {}
var _visual_style: String = ""
var _visual_color: Color = Color(1.0, 0.45, 0.12, 0.9)
var _visual_ring_color: Color = Color(1.0, 0.9, 0.35, 0.95)
var _visual_seed: float = 0.0
var _is_destroying: bool = false
var _trajectory_mode: String = "linear"
var _curve_start_position: Vector2 = Vector2.ZERO
var _curve_target_position: Vector2 = Vector2.ZERO
var _curve_height: float = 0.0
var _curve_duration: float = 0.0
var _curve_elapsed: float = 0.0
var _visual_effect_node: Node2D
var _collision_radius: float = 12.0


func _ready() -> void:
	_visual_seed = float(get_instance_id() % 997) / 997.0 * TAU
	if not body_entered.is_connected(Callable(self, "_on_body_entered")):
		body_entered.connect(Callable(self, "_on_body_entered"))
	_update_direction_state()
	_reset_pierce_counter()


func setup(params: Dictionary) -> void:
	damage = maxi(int(params.get("damage", damage)), 0)
	speed = maxf(float(params.get("speed", speed)), 1.0)
	direction = _get_vector2(params.get("direction", direction), direction)
	pierce = maxi(int(params.get("pierce", pierce)), 0)
	status_on_hit = StringName(String(params.get("status_on_hit", status_on_hit)))
	statuses_on_hit = _get_status_array(params.get("statuses_on_hit", []), status_on_hit)
	status_params = _get_dictionary(params.get("status_params", status_params))
	damage_type = StringName(String(params.get("damage_type", damage_type)))
	damage_packet = _get_dictionary(params.get("damage_packet", damage_packet))
	lifetime = maxf(float(params.get("lifetime", lifetime)), 0.1)
	target_group = StringName(String(params.get("target_group", target_group)))
	source_id = StringName(String(params.get("source_id", source_id)))
	homing_enabled = bool(params.get("homing_enabled", homing_enabled))
	homing_turn_rate = maxf(float(params.get("homing_turn_rate", homing_turn_rate)), 0.1)
	homing_seek_range = maxf(float(params.get("homing_seek_range", homing_seek_range)), 0.0)
	visual_effect_scene = String(params.get("visual_effect_scene", visual_effect_scene))
	_stabilize_damage_packet_source("projectile")
	event_on_hit = StringName(String(params.get("event_on_hit", event_on_hit)))
	event_bus = params.get("event_bus") as Node
	skill_instance = params.get("skill_instance") as RefCounted
	caster = params.get("caster") as Node
	skill_manager = params.get("skill_manager") as Node
	relic_manager = params.get("relic_manager") as Node
	_visual_style = String(params.get("visual_style", _visual_style))
	_visual_color = _get_color(params.get("visual_color", _visual_color), _visual_color)
	_visual_ring_color = _get_color(params.get("visual_ring_color", _visual_ring_color), _visual_ring_color)
	_setup_trajectory(params)
	if params.has("cast_instance_id"):
		set_meta("cast_instance_id", String(params["cast_instance_id"]))
	DamageTraceContextScript.apply_to_node_meta(self, params)
	damage_packet = DamageTraceContextScript.apply_to_packet(damage_packet, params)
	if params.has("hot_rapid_fire_crit"):
		set_meta("hot_rapid_fire_crit", bool(params["hot_rapid_fire_crit"]))
	if params.has("hot_rapid_fire_crit_chance_add"):
		set_meta("hot_rapid_fire_crit_chance_add", float(params["hot_rapid_fire_crit_chance_add"]))
	if params.has("forbidden_page"):
		set_meta("forbidden_page", bool(params["forbidden_page"]))
	if params.has("arcane_page_copy"):
		set_meta("arcane_page_copy", bool(params["arcane_page_copy"]))
	if params.has("arcane_page_hit_ids"):
		set_meta("arcane_page_hit_ids", params["arcane_page_hit_ids"])
	_hit_bodies.clear()
	_is_destroying = false
	monitoring = true
	monitorable = true
	_age = 0.0
	_update_direction_state()
	_reset_pierce_counter()
	_collision_radius = maxf(float(params.get("radius", params.get("area_radius", 12.0))), 1.0)
	_apply_area_radius(_collision_radius)
	_apply_visual_config(params)
	_attach_visual_effect_scene()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_destroying:
		return

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if _trajectory_mode == "curve":
		_update_curve_trajectory(delta)
	else:
		_update_homing_direction(delta)
		var previous_position: Vector2 = global_position
		var next_position: Vector2 = global_position + direction * speed * delta
		if homing_enabled and _resolve_swept_homing_hit(previous_position, next_position):
			return
		global_position = next_position
	if _visual_style == "lightning_orb":
		queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _is_destroying or body == null or not body.is_in_group(target_group) or _hit_bodies.has(body):
		return

	_hit_bodies.append(body)
	if _emit_hit_event(body):
		_consume_pierce()
		return

	if body.has_method("take_damage"):
		body.call(&"take_damage", _get_damage_payload(body), damage_type)
	_apply_status(body)
	_consume_pierce()


func _emit_hit_event(body: Node) -> bool:
	if event_bus == null or event_on_hit == &"" or not event_bus.has_method("emit_skill_event"):
		return false

	event_bus.call_deferred("emit_skill_event", event_on_hit, DamageTraceContextScript.normalize_event_context({
		"caster": caster,
		"owner": caster,
		"target": body,
		"projectile": self,
		"source": self,
		"source_id": source_id,
		"source_weapon_id": StringName(String(damage_packet.get("source_weapon_id", ""))),
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else StringName(String(damage_packet.get("source_skill_id", ""))),
		"source_skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else StringName(String(damage_packet.get("source_skill_id", ""))),
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_type": damage_type,
		"hot_rapid_fire_crit": bool(get_meta("hot_rapid_fire_crit", false)),
		"hot_rapid_fire_crit_chance_add": float(get_meta("hot_rapid_fire_crit_chance_add", 0.0))
	}))
	return true


func _consume_pierce() -> void:
	_hits_remaining -= 1
	pierce = maxi(_hits_remaining - 1, 0)
	if _hits_remaining <= 0:
		_play_hit_visual_then_free()


func _play_hit_visual_then_free() -> void:
	if _is_destroying:
		return

	_is_destroying = true
	speed = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if not _has_visual_state("hit"):
		queue_free()
		return

	_play_visual_state("hit", true)
	_free_when_hit_visual_finishes()


func _free_when_hit_visual_finishes() -> void:
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		queue_free()
		return

	var animation_name: StringName = animated_sprite.animation
	if animation_name == &"":
		animation_name = &"hit"
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		queue_free()
		return
	if animated_sprite.sprite_frames.get_animation_loop(animation_name):
		push_warning("[Projectile] Hit animation must be non-looping to free on animation_finished: %s" % String(animation_name))
		queue_free()
		return
	if not animated_sprite.animation_finished.is_connected(Callable(self, "_on_hit_visual_finished")):
		animated_sprite.animation_finished.connect(Callable(self, "_on_hit_visual_finished"), CONNECT_ONE_SHOT)


func _on_hit_visual_finished() -> void:
	queue_free()


func _get_damage_payload(target: Node = null) -> Variant:
	return DamagePacketBuilderScript.from_combat_object_hit({
		"template": damage_packet,
		"target": target,
		"owner": caster,
		"amount": damage,
		"source_type": "projectile",
		"source_id": source_id,
		"source_instance_id": str(get_instance_id()),
		"instance_id": get_instance_id(),
		"default_damage_origin": "primary_attack",
		"default_damage_type": damage_type if damage_type != &"" else &"direct_physical",
		"default_element": &"physical"
	})


func _stabilize_damage_packet_source(default_source_type: String) -> void:
	if damage_packet.is_empty():
		return
	if not damage_packet.has("source_instance_id") or String(damage_packet.get("source_instance_id", "")) == "":
		damage_packet["source_instance_id"] = str(get_instance_id())
	if not damage_packet.has("source_type"):
		damage_packet["source_type"] = default_source_type
	if not damage_packet.has("source_id") and source_id != &"":
		damage_packet["source_id"] = source_id
	if not damage_packet.has("source_skill_id"):
		damage_packet["source_skill_id"] = StringName(String(source_id))
	if not damage_packet.has("source_weapon_id"):
		damage_packet["source_weapon_id"] = StringName("")


func _apply_status(body: Node) -> void:
	if statuses_on_hit.is_empty() and status_on_hit != &"":
		statuses_on_hit = [status_on_hit]
	if statuses_on_hit.is_empty():
		return

	for status_id: StringName in statuses_on_hit:
		if status_id == &"":
			continue

		if body.has_method("apply_status"):
			body.call(&"apply_status", status_id, status_params)
		elif body.has_method("add_status_effect"):
			body.call(&"add_status_effect", status_id)


func _update_direction_state() -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()


func _reset_pierce_counter() -> void:
	_hits_remaining = pierce + 1


func _setup_trajectory(params: Dictionary) -> void:
	_trajectory_mode = String(params.get("trajectory_mode", "linear"))
	_curve_elapsed = 0.0
	if _trajectory_mode != "curve":
		return
	_curve_start_position = _get_vector2(params.get("curve_start_position", global_position), global_position)
	_curve_target_position = _get_vector2(params.get("curve_target_position", _curve_start_position + direction * speed * lifetime), _curve_start_position + direction * speed * lifetime)
	_curve_height = maxf(float(params.get("curve_height", 64.0)), 0.0)
	var distance: float = maxf(_curve_start_position.distance_to(_curve_target_position), 1.0)
	_curve_duration = clampf(distance / speed, 0.08, lifetime)
	global_position = _curve_start_position
	direction = _curve_start_position.direction_to(_curve_target_position)
	_update_direction_state()


func _update_curve_trajectory(delta: float) -> void:
	if _curve_duration <= 0.0:
		var fallback_start: Vector2 = global_position
		var fallback_end: Vector2 = global_position + direction * speed * delta
		if homing_enabled and _resolve_swept_homing_hit(fallback_start, fallback_end):
			return
		global_position = fallback_end
		return
	_curve_elapsed += delta
	var t: float = clampf(_curve_elapsed / _curve_duration, 0.0, 1.0)
	var line_position: Vector2 = _curve_start_position.lerp(_curve_target_position, t)
	var chord: Vector2 = _curve_target_position - _curve_start_position
	var normal: Vector2 = Vector2(-chord.y, chord.x).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.UP
	var previous_position: Vector2 = global_position
	global_position = line_position + normal * sin(t * PI) * _curve_height
	var travel_direction: Vector2 = previous_position.direction_to(global_position)
	if travel_direction != Vector2.ZERO:
		direction = travel_direction
		_update_direction_state()
	if homing_enabled and _resolve_swept_homing_hit(previous_position, global_position):
		return
	if t >= 1.0:
		queue_free()


func _update_homing_direction(delta: float) -> void:
	if not homing_enabled:
		return
	var target: Node2D = _find_nearest_homing_target()
	if target == null:
		return
	var desired_direction: Vector2 = global_position.direction_to(target.global_position)
	if desired_direction == Vector2.ZERO:
		return
	direction = direction.lerp(desired_direction.normalized(), clampf(homing_turn_rate * delta, 0.0, 1.0)).normalized()
	_update_direction_state()


func _find_nearest_homing_target() -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var seek_range: float = homing_seek_range
	if seek_range <= 0.0:
		seek_range = maxf(speed * lifetime, 1.0)
	var nearest: Node2D = null
	var nearest_distance_squared: float = seek_range * seek_range
	for node: Node in tree.get_nodes_in_group(target_group):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if target.has_method("is_dead") and bool(target.call("is_dead")):
			continue
		var distance_squared: float = global_position.distance_squared_to(target.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = target
	return nearest


func _resolve_swept_homing_hit(from_position: Vector2, to_position: Vector2) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or from_position == to_position:
		return false

	var nearest_target: Node = null
	var nearest_t: float = INF
	var segment: Vector2 = to_position - from_position
	var segment_length_squared: float = segment.length_squared()
	for node: Node in tree.get_nodes_in_group(target_group):
		var target: Node2D = node as Node2D
		if target == null or _hit_bodies.has(target) or not _is_valid_homing_target(target):
			continue
		var t: float = clampf((target.global_position - from_position).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_position: Vector2 = from_position.lerp(to_position, t)
		var hit_radius: float = _collision_radius + _get_target_hit_radius(target)
		if closest_position.distance_squared_to(target.global_position) > hit_radius * hit_radius:
			continue
		if t < nearest_t:
			nearest_t = t
			nearest_target = target

	if nearest_target == null:
		return false

	var impact_target: Node2D = nearest_target as Node2D
	global_position = impact_target.global_position
	_on_body_entered(impact_target)
	return true


func _is_valid_homing_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	return true


func _get_target_hit_radius(target: Node2D) -> float:
	var collision_shape: CollisionShape2D = target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 12.0
	var shape: Shape2D = collision_shape.shape
	if shape is CircleShape2D:
		return maxf((shape as CircleShape2D).radius, 1.0)
	if shape is RectangleShape2D:
		var size: Vector2 = (shape as RectangleShape2D).size
		return maxf(size.length() * 0.5, 1.0)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return maxf(maxf(capsule.radius, capsule.height * 0.5), 1.0)
	return 12.0


func _apply_area_radius(radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is CircleShape2D):
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = maxf(radius, 1.0)


func _apply_visual_config(params: Dictionary) -> void:
	_visual_config = _get_dictionary(params.get("visual", {}))
	if _visual_config.is_empty() and params.has("visual_color"):
		_visual_config["modulate"] = params["visual_color"]
	if _visual_config.is_empty():
		_hide_sprite_nodes()
		return
	_play_visual_state("fly", true)


func _attach_visual_effect_scene() -> void:
	if visual_effect_scene == "":
		return
	if _visual_effect_node != null and is_instance_valid(_visual_effect_node):
		_visual_effect_node.queue_free()
		_visual_effect_node = null
	var scene: PackedScene = load(visual_effect_scene) as PackedScene
	if scene == null:
		push_warning("[Projectile] Could not load visual_effect_scene: %s" % visual_effect_scene)
		return
	_visual_effect_node = scene.instantiate() as Node2D
	if _visual_effect_node == null:
		return
	add_child(_visual_effect_node)
	_visual_effect_node.position = Vector2.ZERO
	_visual_effect_node.rotation = 0.0
	if _visual_effect_node.has_method("set_continuous"):
		_visual_effect_node.call("set_continuous", false)
	_visual_effect_node.set_process(false)


func _play_visual_state(state: String, force: bool = false) -> void:
	if _visual_config.is_empty():
		return
	if force:
		VisualConfigApplierScript.play_state(self, _visual_config, state, "idle")
	else:
		VisualConfigApplierScript.play_state(self, _visual_config, state, "idle")


func _has_visual_state(state: String) -> bool:
	return VisualConfigApplierScript.has_state_visual(_visual_config, state)


func _draw() -> void:
	match _visual_style:
		"fireball_orb":
			_draw_fireball_orb()
		"hail_orb":
			_draw_hail_orb()
		"lightning_orb":
			_draw_lightning_orb()
		"arcane_page":
			_draw_arcane_page()
		"throwing_knife":
			_draw_throwing_knife()
		"hunter_arrow":
			_draw_hunter_arrow()
		"poison_bottle":
			_draw_poison_bottle()
		"oil_pot":
			_draw_oil_pot()


func _draw_fireball_orb() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.78))
	draw_circle(Vector2(-4.0, -2.0), 7.0, Color(1.0, 0.82, 0.24, 0.82))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 36, _visual_ring_color, 2.0, true)
	draw_line(Vector2(-22.0, 0.0), Vector2(-8.0, 0.0), Color(_visual_color.r, _visual_color.g, _visual_color.b, 0.38), 5.0, true)


func _draw_hail_orb() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(12.0, -4.0),
		Vector2(8.0, 12.0),
		Vector2(-8.0, 12.0),
		Vector2(-12.0, -4.0)
	])
	draw_colored_polygon(points, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.78))
	draw_polyline(points + PackedVector2Array([points[0]]), _visual_ring_color, 2.0, true)
	draw_line(Vector2(-6.0, 0.0), Vector2(7.0, -6.0), Color(1.0, 1.0, 1.0, 0.65), 1.5, true)


func _draw_lightning_orb() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 18.0 + _visual_seed)
	draw_circle(Vector2.ZERO, 12.0 + pulse * 2.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.62))
	draw_arc(Vector2.ZERO, 17.0, _age * 6.0, _age * 6.0 + TAU * 0.65, 28, _visual_ring_color, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(-14.0, -3.0), Vector2(-3.0, 4.0), Vector2(2.0, -5.0), Vector2(14.0, 2.0)]), Color(0.96, 1.0, 1.0, 0.9), 2.0, true)


func _draw_arcane_page() -> void:
	var page: PackedVector2Array = PackedVector2Array([
		Vector2(-11.0, -14.0),
		Vector2(10.0, -9.0),
		Vector2(11.0, 13.0),
		Vector2(-10.0, 9.0)
	])
	draw_colored_polygon(page, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.72))
	draw_polyline(page + PackedVector2Array([page[0]]), _visual_ring_color, 1.8, true)
	draw_line(Vector2(-5.0, -5.0), Vector2(6.0, -2.0), Color(1.0, 0.86, 1.0, 0.62), 1.2, true)
	draw_line(Vector2(-5.0, 1.0), Vector2(5.0, 4.0), Color(1.0, 0.86, 1.0, 0.50), 1.2, true)


func _draw_throwing_knife() -> void:
	draw_line(Vector2(-16.0, 0.0), Vector2(14.0, 0.0), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.92), 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(14.0, 0.0), Vector2(5.0, -5.0), Vector2(7.0, 0.0), Vector2(5.0, 5.0)]), _visual_color)
	draw_line(Vector2(-20.0, 0.0), Vector2(-9.0, 0.0), Color(0.65, 0.82, 1.0, 0.34), 2.0, true)


func _draw_hunter_arrow() -> void:
	draw_line(Vector2(-26.0, 0.0), Vector2(18.0, 0.0), Color(_visual_color.r, _visual_color.g, _visual_color.b, 0.9), 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(22.0, 0.0), Vector2(10.0, -6.0), Vector2(13.0, 0.0), Vector2(10.0, 6.0)]), _visual_ring_color)
	draw_line(Vector2(-26.0, 0.0), Vector2(-34.0, -5.0), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.55), 1.5, true)
	draw_line(Vector2(-26.0, 0.0), Vector2(-34.0, 5.0), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.55), 1.5, true)


func _draw_poison_bottle() -> void:
	draw_circle(Vector2(2.0, 2.0), 11.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.66))
	draw_rect(Rect2(Vector2(-5.0, -14.0), Vector2(9.0, 9.0)), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.82), false, 2.0)
	draw_arc(Vector2(2.0, 2.0), 12.0, 0.0, TAU, 28, _visual_ring_color, 1.8, true)


func _draw_oil_pot() -> void:
	draw_circle(Vector2(1.0, 2.0), 12.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.70))
	draw_rect(Rect2(Vector2(-5.0, -15.0), Vector2(10.0, 9.0)), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.86), false, 2.0)
	draw_line(Vector2(-13.0, 8.0), Vector2(-24.0, 14.0), Color(1.0, 0.28, 0.05, 0.42), 3.0, true)
	draw_arc(Vector2(1.0, 2.0), 13.0, 0.0, TAU, 28, _visual_ring_color, 2.0, true)


func _hide_sprite_nodes() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.visible = false
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.visible = false
		animated_sprite.stop()


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))

	return fallback


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


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
