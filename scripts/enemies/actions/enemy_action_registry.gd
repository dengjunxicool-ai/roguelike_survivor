extends RefCounted
class_name EnemyActionRegistry


const EnemyDamagePacketBuilderScript: Script = preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")


func execute(context: Dictionary) -> bool:
	var action: Dictionary = _get_dictionary(context.get("action", {}))
	match String(action.get("type", "")):
		"projectile":
			return _execute_projectile(context)
		"damage_area":
			return _execute_damage_area(context)
		"summon":
			return _execute_summon(context)
		"ring_projectiles":
			return _execute_ring_projectiles(context)
		"delayed_area_blast", "shockwave", "corruption_gaze":
			return _execute_damage_area(context)
		"corrupted_cores":
			return _execute_corrupted_cores(context)
		"self_explode":
			return _execute_self_explode(context)
		"dash":
			return _execute_dash_marker(context)
		"contact_status":
			return _execute_contact_status(context)
		_:
			push_warning("[EnemyActionRegistry] Unsupported enemy action type: %s" % String(action.get("type", "")))
			return false


func _execute_projectile(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or owner.get("enemy_projectile_scene") == null or owner.get_parent() == null:
		return false

	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var skill: Dictionary = _get_dictionary(context.get("skill", {}))
	var skill_id: StringName = StringName(String(skill.get("id", "enemy_projectile")))
	var projectile_scene: PackedScene = owner.get("enemy_projectile_scene") as PackedScene
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return false

	var direction: Vector2 = _get_vector2(runtime.get("direction", Vector2.RIGHT), Vector2.RIGHT)
	var normalized_direction: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	var amount: int = _get_damage_amount(owner, params, "damage", int(owner.get("contact_damage")))
	owner.get_parent().add_child(projectile)
	projectile.add_to_group(&"enemy_projectiles")
	projectile.add_to_group(&"enemy_projectile")
	projectile.global_position = owner.global_position + normalized_direction * float(params.get("spawn_offset", params.get("projectile_spawn_offset", 20.0)))
	if projectile.has_method("setup"):
		projectile.call(&"setup", {
			"direction": normalized_direction,
			"damage": amount,
			"speed": float(params.get("speed", params.get("projectile_speed", 280.0))),
			"target_group": owner.get("target_group"),
			"pierce": int(params.get("pierce", params.get("projectile_pierce", 0))),
			"radius": float(params.get("radius", params.get("projectile_radius", 8.0))),
			"lifetime": float(params.get("lifetime", params.get("projectile_lifetime", 3.0))),
			"source_id": StringName(String(EnemyDamagePacketBuilderScript.source_id_for(owner, "projectile"))),
			"damage_packet": EnemyDamagePacketBuilderScript.build(owner, amount, "projectile", skill_id, params),
			"visual_color": params.get("visual_color", params.get("projectile_color", [1.0, 0.9, 0.08, 1.0])),
			"visual": _get_dictionary(params.get("visual", params.get("projectile_visual", {})))
		})
	return true


func _execute_damage_area(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or owner.get("damage_area_scene") == null or owner.get_parent() == null:
		return false

	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var skill: Dictionary = _get_dictionary(context.get("skill", {}))
	var skill_id: StringName = StringName(String(skill.get("id", "enemy_area")))
	var damage_area_scene: PackedScene = owner.get("damage_area_scene") as PackedScene
	var damage_area: Node2D = damage_area_scene.instantiate() as Node2D
	if damage_area == null:
		return false

	var amount: int = _get_damage_amount(owner, params, "damage", int(runtime.get("damage", owner.get("contact_damage"))))
	var area_position: Vector2 = _get_vector2(runtime.get("position", owner.global_position), owner.global_position)
	owner.get_parent().add_child(damage_area)
	damage_area.global_position = area_position
	if damage_area.has_method("setup"):
		damage_area.call(&"setup", {
			"damage": amount,
			"duration": _get_area_duration(action, params, runtime),
			"tick_interval": _get_area_tick_interval(action, params, runtime),
			"target_group": owner.get("target_group"),
			"area_radius": float(params.get("radius", params.get("area_radius", runtime.get("radius", 72.0)))),
			"visual_color": _get_color(params.get("visual_color", runtime.get("visual_color", Color(0.35, 0.95, 0.2, 0.32)))),
			"source_id": StringName(String(EnemyDamagePacketBuilderScript.source_id_for(owner, "area"))),
			"source_type": &"area",
			"damage_packet": EnemyDamagePacketBuilderScript.build(owner, amount, "area", skill_id, params)
		})
	return true


func _execute_summon(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or not owner.has_method("_spawn_enemies_around"):
		return false

	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var enemy_id: StringName = StringName(String(params.get("enemy_id", runtime.get("enemy_id", "small_slime"))))
	var count: int = int(params.get("count", runtime.get("count", 1)))
	var center: Vector2 = _get_vector2(runtime.get("center", owner.global_position), owner.global_position)
	var radius: float = float(params.get("radius", params.get("spawn_radius", runtime.get("radius", 72.0))))
	owner.call("_spawn_enemies_around", enemy_id, count, center, radius)
	return true


func _execute_ring_projectiles(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null:
		return false

	var params: Dictionary = _get_action_params(context)
	var count: int = maxi(int(params.get("projectile_count", params.get("count", 8))), 1)
	var safe_gap_count: int = maxi(int(params.get("safe_gap_count", 0)), 0)
	var safe_gap_start: int = maxi(int(params.get("safe_gap_start", 0)), 0)
	var executed: bool = false
	for projectile_index in range(count):
		if projectile_index >= safe_gap_start and projectile_index < safe_gap_start + safe_gap_count:
			continue
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(projectile_index) / float(count))
		var child_context: Dictionary = context.duplicate(true)
		var child_action: Dictionary = _get_dictionary(context.get("action", {})).duplicate(true)
		child_action["type"] = "projectile"
		var child_params: Dictionary = params.duplicate(true)
		child_params["speed"] = float(params.get("speed", 240.0))
		child_params["radius"] = float(params.get("radius", params.get("projectile_radius", 8.0)))
		child_params["pierce"] = int(params.get("pierce", 0))
		child_action["params"] = child_params
		var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {})).duplicate(true)
		runtime["direction"] = direction
		child_context["action"] = child_action
		child_context["runtime_params"] = runtime
		executed = _execute_projectile(child_context) or executed
	return executed


func _execute_corrupted_cores(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or not owner.has_method("_spawn_corrupted_cores"):
		return false
	var params: Dictionary = _get_action_params(context)
	return bool(owner.call("_spawn_corrupted_cores", int(params.get("count", 2)), int(params.get("hp", 120))))


func _execute_self_explode(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or not owner.has_method("_run_self_explosion_action"):
		return false
	return bool(owner.call("_run_self_explosion_action"))


func _execute_dash_marker(_context: Dictionary) -> bool:
	return true


func _execute_contact_status(context: Dictionary) -> bool:
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var target: Object = runtime.get("target", params.get("target", null))
	if target == null or not target.has_method("apply_status"):
		return false

	var status_id: StringName = StringName(String(params.get("status_id", "")))
	if status_id == &"":
		return false

	var status_params: Dictionary = _get_dictionary(params.get("status_params", {}))
	if params.has("duration"):
		status_params["duration"] = float(params["duration"])
	if params.has("damage"):
		status_params["damage"] = int(params["damage"])
	if params.has("tick_interval"):
		status_params["tick_interval"] = float(params["tick_interval"])
	if params.has("stack"):
		status_params["stacks"] = int(params["stack"])
	if params.has("max_stacks"):
		status_params["max_stacks"] = int(params["max_stacks"])
	return bool(target.call("apply_status", status_id, status_params))


func _get_damage_amount(owner: Node, params: Dictionary, key: String, fallback: int) -> int:
	if params.has(key):
		return maxi(roundi(float(params.get(key, fallback)) * float(owner.get("damage_multiplier"))), 0)
	return maxi(fallback, 0)


func _get_action_params(context: Dictionary) -> Dictionary:
	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_dictionary(action.get("params", {}))
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var boss_skill: Dictionary = _get_dictionary(runtime.get("boss_skill", {}))
	for key: Variant in boss_skill.keys():
		if key == "type" or key == "skill_id" or key == "cooldown":
			continue
		params[String(key)] = boss_skill[key]
	for key: Variant in runtime.keys():
		if key == "boss_skill" or key == "behavior" or key == "skill_ref":
			continue
		if not params.has(key):
			params[key] = runtime[key]
	return params


func _get_area_duration(action: Dictionary, params: Dictionary, runtime: Dictionary) -> float:
	var action_type: String = String(action.get("type", "damage_area"))
	if params.has("duration"):
		return float(params["duration"])
	if action_type == "delayed_area_blast":
		return maxf(float(params.get("delay", runtime.get("delay", 1.0))) + 0.25, 0.3)
	if action_type == "shockwave":
		return maxf(float(params.get("warning_time", runtime.get("warning_time", 0.8))) + 0.2, 0.25)
	return float(runtime.get("duration", 3.0))


func _get_area_tick_interval(action: Dictionary, params: Dictionary, runtime: Dictionary) -> float:
	var action_type: String = String(action.get("type", "damage_area"))
	if params.has("tick_interval"):
		return float(params["tick_interval"])
	if action_type == "delayed_area_blast":
		return maxf(float(params.get("delay", runtime.get("delay", 1.0))), 0.05)
	if action_type == "shockwave":
		return maxf(float(params.get("warning_time", runtime.get("warning_time", 0.8))), 0.05)
	return float(runtime.get("tick_interval", 0.5))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			return Color(float(items[0]), float(items[1]), float(items[2]), float(items[3]) if items.size() > 3 else 1.0)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return Color(0.35, 0.95, 0.2, 0.32)
