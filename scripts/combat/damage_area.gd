extends Area2D
class_name DamageArea


const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

@export_range(0, 10000, 1, "or_greater") var damage: int = 4
@export_range(0.05, 30.0, 0.05, "or_greater") var duration: float = 3.0
@export_range(0.05, 10.0, 0.05, "or_greater") var tick_interval: float = 0.5
@export_range(1.0, 1000.0, 1.0, "or_greater") var area_radius: float = 52.0
@export var target_group: StringName = &"player"
@export var source_id: StringName = &"area"
@export var source_type: StringName = &"area"
@export var damage_packet: Dictionary = {}

var _age: float = 0.0
var _tick_timer: float = 0.0
var _one_shot: bool = false


func _ready() -> void:
	_apply_area_radius(area_radius)


func prepare_for_pool_spawn(params: Dictionary) -> void:
	visible = true
	set_process(true)
	set_physics_process(true)
	setup(params)


func prepare_for_pool_despawn() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	damage_packet.clear()
	_age = 0.0
	_tick_timer = 0.0
	_one_shot = false
	visible = false


func despawn_or_free() -> void:
	if has_meta(&"runtime_pool_owner") and has_meta(&"runtime_pool_key"):
		var pool_variant: Variant = get_meta(&"runtime_pool_owner")
		var key: StringName = StringName(String(get_meta(&"runtime_pool_key")))
		if pool_variant is Node and is_instance_valid(pool_variant) and (pool_variant as Node).has_method("despawn"):
			prepare_for_pool_despawn()
			(pool_variant as Node).call("despawn", key, self)
			return
	queue_free()


func setup(
	new_damage: Variant,
	new_duration: float = 3.0,
	new_tick_interval: float = 0.5,
	new_target_group: StringName = &"player",
	new_area_radius: float = 52.0,
	visual_color: Color = Color(0.35, 0.95, 0.2, 0.32),
	new_source_id: StringName = &"area",
	new_source_type: StringName = &"area"
) -> void:
	if new_damage is Dictionary:
		_setup_from_dictionary(new_damage)
		return

	damage = maxi(int(new_damage), 0)
	duration = maxf(new_duration, 0.05)
	tick_interval = maxf(new_tick_interval, 0.05)
	target_group = new_target_group
	source_id = new_source_id
	source_type = new_source_type
	area_radius = maxf(new_area_radius, 1.0)
	damage_packet.clear()
	_age = 0.0
	_tick_timer = tick_interval
	_one_shot = _is_one_shot_duration()
	_apply_area_radius(area_radius)
	_enable_area_monitoring()
	_apply_visual_color(visual_color)


func _setup_from_dictionary(params: Dictionary) -> void:
	damage = maxi(int(params.get("damage", damage)), 0)
	duration = maxf(float(params.get("duration", duration)), 0.05)
	tick_interval = maxf(float(params.get("tick_interval", tick_interval)), 0.05)
	target_group = StringName(String(params.get("target_group", target_group)))
	source_id = StringName(String(params.get("source_id", source_id)))
	source_type = StringName(String(params.get("source_type", source_type)))
	area_radius = maxf(float(params.get("radius", params.get("area_radius", area_radius))), 1.0)
	damage_packet = _get_dictionary(params.get("damage_packet", params.get("damage_packet_template", damage_packet)))
	DamageTraceContextScript.apply_to_node_meta(self, params)
	damage_packet = DamageTraceContextScript.apply_to_packet(damage_packet, params)
	_age = 0.0
	_tick_timer = tick_interval
	_one_shot = _is_one_shot_duration()
	_apply_area_radius(area_radius)
	_enable_area_monitoring()
	_apply_visual_color(_get_color(params.get("visual_color", Color(0.35, 0.95, 0.2, 0.32))))


func _apply_visual_color(visual_color: Color) -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = visual_color
		sprite.scale = Vector2.ONE * (area_radius / 64.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _one_shot:
		_apply_damage_to_overlaps()
		despawn_or_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_damage_to_overlaps()

	if _age >= duration:
		despawn_or_free()


func _apply_damage_to_overlaps() -> void:
	if damage <= 0:
		return

	for body: Node in _get_overlap_bodies():
		if body == null or not body.is_in_group(target_group):
			continue
		if body.has_method("take_damage"):
			body.call(&"take_damage", _get_damage_payload(body))


func _get_overlap_bodies() -> Array[Node]:
	var bodies: Array[Node] = []
	for body: Node in get_overlapping_bodies():
		bodies.append(body)
	if not bodies.is_empty():
		return bodies

	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null or get_world_2d() == null:
		return bodies

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 64)
	for result: Dictionary in results:
		var collider: Node = result.get("collider") as Node
		if collider != null and not bodies.has(collider):
			bodies.append(collider)
	return bodies


func _is_one_shot_duration() -> bool:
	return duration <= tick_interval + 0.05


func _get_damage_payload(target: Node) -> Dictionary:
	var is_reaction: bool = String(source_type) == "reaction"
	return DamagePacketBuilderScript.from_combat_object_hit({
		"template": damage_packet,
		"target": target,
		"amount": damage,
		"source_type": String(source_type),
		"source_id": source_id,
		"source_skill_id": source_id,
		"source_instance_id": str(get_instance_id()),
		"instance_id": get_instance_id(),
		"default_damage_origin": "reaction" if is_reaction else "field",
		"default_damage_type": &"reaction_damage" if is_reaction else &"area_direct",
		"default_element": &"physical",
		"overwrite_amount": false,
		"can_crit": false,
		"can_trigger_reaction": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false
	})


func _apply_area_radius(radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is CircleShape2D):
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = maxf(radius, 1.0)


func _enable_area_monitoring() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			var alpha: float = float(items[3]) if items.size() > 3 else 1.0
			return Color(float(items[0]), float(items[1]), float(items[2]), alpha)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return Color(0.35, 0.95, 0.2, 0.32)
