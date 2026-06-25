extends Area2D
class_name OrbitObject


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageTraceContextScript: Script = preload("res://scripts/debug/damage_trace_context.gd")

@export_range(0, 10000, 1, "or_greater") var damage: int = 8
@export_range(1.0, 1000.0, 1.0, "or_greater") var orbit_radius: float = 72.0
@export_range(1.0, 1440.0, 1.0, "or_greater") var rotation_speed: float = 220.0
@export_range(0.05, 10.0, 0.05, "or_greater") var hit_interval: float = 0.45
@export_range(1.0, 300.0, 1.0, "or_greater") var area_radius: float = 24.0
@export var damage_type: StringName = &"physical"
@export var damage_packet: Dictionary = {}
@export var target_group: StringName = &"enemies"
@export var status_on_hit: StringName = &""
@export var statuses_on_hit: Array[StringName] = []
@export var status_params: Dictionary = {}
@export var source_id: StringName = &""
@export var event_on_hit: StringName = &""
@export_range(0.0, 60.0, 0.05, "or_greater") var duration: float = 0.0
@export_range(0, 1000, 1, "or_greater") var max_targets: int = 0

var owner_node: Node2D
var angle: float = 0.0
var _hit_cooldowns: Dictionary = {}
var _unique_hit_ids: Array[int] = []
var _age: float = 0.0
var event_bus: Node
var skill_instance: RefCounted
var skill_manager: Node
var relic_manager: Node
var _visual_config: Dictionary = {}
var _debug_last_attack_nonce: int = -1


func setup(params: Dictionary) -> void:
	damage = maxi(int(params.get("damage", damage)), 0)
	orbit_radius = maxf(float(params.get("orbit_radius", orbit_radius)), 1.0)
	rotation_speed = float(params.get("rotation_speed", rotation_speed))
	hit_interval = maxf(float(params.get("hit_interval", hit_interval)), 0.05)
	area_radius = maxf(float(params.get("area_radius", params.get("radius", area_radius))), 1.0)
	damage_type = StringName(String(params.get("damage_type", damage_type)))
	damage_packet = _get_dictionary(params.get("damage_packet", damage_packet))
	target_group = StringName(String(params.get("target_group", target_group)))
	status_on_hit = StringName(String(params.get("status_on_hit", status_on_hit)))
	statuses_on_hit = _get_status_array(params.get("statuses_on_hit", []), status_on_hit)
	status_params = _get_dictionary(params.get("status_params", status_params))
	source_id = StringName(String(params.get("source_id", source_id)))
	_stabilize_damage_packet_source("orbit")
	DamageTraceContextScript.apply_to_node_meta(self, params)
	damage_packet = DamageTraceContextScript.apply_to_packet(damage_packet, params)
	event_on_hit = StringName(String(params.get("event_on_hit", event_on_hit)))
	duration = maxf(float(params.get("duration", duration)), 0.0)
	max_targets = maxi(int(params.get("max_targets", max_targets)), 0)
	event_bus = params.get("event_bus") as Node
	skill_instance = params.get("skill_instance") as RefCounted
	skill_manager = params.get("skill_manager") as Node
	relic_manager = params.get("relic_manager") as Node
	owner_node = params.get("owner") as Node2D
	angle = float(params.get("angle", angle))
	if bool(params.get("reset_hit_cooldowns", false)):
		_hit_cooldowns.clear()
	_apply_area_radius()
	_apply_visual_config(params)


func _physics_process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	if duration > 0.0:
		_age += delta
		if _age >= duration:
			queue_free()
			return

	angle += deg_to_rad(rotation_speed) * delta
	global_position = owner_node.global_position + Vector2.RIGHT.rotated(angle) * orbit_radius
	_update_hit_cooldowns(delta)
	if _is_debug_control_mode() and not _consume_debug_attack_nonce():
		return

	_emit_nearby_enemy_projectile_events()
	_damage_overlapping_enemies()


func _update_hit_cooldowns(delta: float) -> void:
	var ids_to_remove: Array[int] = []
	for enemy_id_variant: Variant in _hit_cooldowns.keys():
		var enemy_id: int = int(enemy_id_variant)
		var remaining_time: float = float(_hit_cooldowns[enemy_id]) - delta
		if remaining_time <= 0.0:
			ids_to_remove.append(enemy_id)
		else:
			_hit_cooldowns[enemy_id] = remaining_time

	for enemy_id: int in ids_to_remove:
		_hit_cooldowns.erase(enemy_id)


func _damage_overlapping_enemies() -> void:
	for body: Node2D in get_overlapping_bodies():
		_try_damage_body(body)


func _try_damage_body(body: Node) -> void:
	if body == null or not body.is_in_group(target_group):
		return

	var enemy_id: int = int(body.get_instance_id())
	if _hit_cooldowns.has(enemy_id):
		return
	if max_targets > 0 and not _unique_hit_ids.has(enemy_id) and _unique_hit_ids.size() >= max_targets:
		return

	if _emit_hit_event(body):
		_hit_cooldowns[enemy_id] = hit_interval
		_record_unique_hit(enemy_id)
		return

	if body.has_method("take_damage"):
		body.call("take_damage", _get_damage_payload(body), damage_type)
		_apply_status(body)
		_hit_cooldowns[enemy_id] = hit_interval
		_record_unique_hit(enemy_id)


func _record_unique_hit(enemy_id: int) -> void:
	if not _unique_hit_ids.has(enemy_id):
		_unique_hit_ids.append(enemy_id)


func _get_damage_payload(target: Node = null) -> Variant:
	return DamagePacketBuilderScript.from_combat_object_hit({
		"template": damage_packet,
		"target": target,
		"owner": owner_node if not damage_packet.is_empty() else null,
		"amount": damage,
		"source_type": "orbit",
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
	if not damage_packet.has("source_origin_id"):
		damage_packet["source_origin_id"] = StringName("")


func _emit_hit_event(body: Node) -> bool:
	if event_bus == null or event_on_hit == &"" or not event_bus.has_method("emit_skill_event"):
		return false

	event_bus.call("emit_skill_event", event_on_hit, DamageTraceContextScript.normalize_event_context({
		"caster": owner_node,
		"owner": owner_node,
		"target": body,
		"orbit_object": self,
		"source": self,
		"source_id": source_id,
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else &"",
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_type": damage_type
	}))
	return true


func _emit_nearby_enemy_projectile_events() -> void:
	if event_bus == null or not event_bus.has_method("emit_skill_event"):
		return
	if not _skill_has_runtime_trigger(&"on_enemy_projectile_near_orbit"):
		return

	var radius_squared: float = area_radius * area_radius
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	for group_name: StringName in [&"enemy_projectiles", &"enemy_projectile"]:
		for node: Node in tree.get_nodes_in_group(group_name):
			var projectile: Node2D = node as Node2D
			if projectile == null or not is_instance_valid(projectile):
				continue
			if projectile.global_position.distance_squared_to(global_position) > radius_squared:
				continue

			event_bus.call("emit_skill_event", &"on_enemy_projectile_near_orbit", {
				"caster": owner_node,
				"owner": owner_node,
				"target": projectile,
				"projectile": projectile,
				"orbit_object": self,
				"source": self,
				"source_id": source_id,
				"skill_instance": skill_instance,
				"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else &"",
				"skill_manager": skill_manager,
				"relic_manager": relic_manager,
				"event_bus": event_bus,
				"parent": get_parent(),
				"target_group": target_group,
				"damage_type": damage_type
			})


func _skill_has_runtime_trigger(trigger: StringName) -> bool:
	if skill_instance == null:
		return false

	var runtime_events_variant: Variant = skill_instance.get("runtime_events")
	if not (runtime_events_variant is Array):
		return false

	var runtime_events: Array = runtime_events_variant
	for event_variant: Variant in runtime_events:
		if event_variant is Dictionary and StringName(String((event_variant as Dictionary).get("trigger", ""))) == trigger:
			return true

	return false


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


func _apply_area_radius() -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		circle_shape.radius = area_radius

	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.scale = Vector2.ONE * (area_radius / 64.0)


func _apply_visual_config(params: Dictionary) -> void:
	_visual_config = _get_dictionary(params.get("visual", {}))
	if _visual_config.is_empty():
		return
	if not _visual_config.has("scale"):
		_visual_config["scale"] = [area_radius / 64.0, area_radius / 64.0]
	VisualConfigApplierScript.play_state(self, _visual_config, "loop", "idle")


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


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


func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


func _consume_debug_attack_nonce() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return false

	var nonce: int = int(tree.root.get_meta("debug_player_attack_nonce", 0))
	if _debug_last_attack_nonce < 0:
		_debug_last_attack_nonce = nonce
		return false
	if nonce == _debug_last_attack_nonce:
		return false

	_debug_last_attack_nonce = nonce
	return true


func debug_allow_current_nonce() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	_debug_last_attack_nonce = int(tree.root.get_meta("debug_player_attack_nonce", 0)) - 1
