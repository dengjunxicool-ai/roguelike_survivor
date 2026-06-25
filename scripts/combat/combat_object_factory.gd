extends RefCounted
class_name CombatObjectFactory


const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/fireball_projectile.tscn")
const DEFAULT_AREA_EFFECT_SCENE: PackedScene = preload("res://scenes/area_effect.tscn")
const DEFAULT_ORBIT_OBJECT_SCENE: PackedScene = preload("res://scenes/orbit_object.tscn")


static func create_projectile(params: Dictionary) -> Node2D:
	var object_params: Dictionary = _apply_combat_object_definition(params, String(params.get("projectile_id", params.get("object_id", ""))))
	var projectile_scene: PackedScene = object_params.get("scene", DEFAULT_PROJECTILE_SCENE) as PackedScene
	var parent: Node = _resolve_parent(params.get("parent"))
	var direction: Vector2 = _get_vector2(object_params.get("direction", Vector2.ZERO), Vector2.ZERO)
	if projectile_scene == null or parent == null or direction == Vector2.ZERO:
		return null

	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return null

	if projectile.has_method("setup"):
		projectile.call(&"setup", object_params)
	var spawn_position: Vector2 = _get_vector2(object_params.get("position", Vector2.ZERO), Vector2.ZERO)
	if Engine.is_in_physics_frame():
		parent.call_deferred("add_child", projectile)
		projectile.set_deferred("global_position", spawn_position)
	else:
		parent.add_child(projectile)
		projectile.global_position = spawn_position

	return projectile


static func create_area_effect(params: Dictionary) -> Node2D:
	var object_params: Dictionary = _apply_combat_object_definition(params, String(params.get("area_id", params.get("object_id", ""))))
	var area_effect_scene: PackedScene = object_params.get("scene", DEFAULT_AREA_EFFECT_SCENE) as PackedScene
	var parent: Node = _resolve_parent(params.get("parent"))
	if area_effect_scene == null or parent == null:
		return null

	var area_effect: Node2D = area_effect_scene.instantiate() as Node2D
	if area_effect == null:
		return null

	parent.add_child(area_effect)
	area_effect.global_position = _get_vector2(object_params.get("position", Vector2.ZERO), Vector2.ZERO)
	if area_effect.has_method("setup"):
		area_effect.call(&"setup", object_params)

	return area_effect


static func create_orbit_object(params: Dictionary) -> Node2D:
	var object_params: Dictionary = _apply_combat_object_definition(params, String(params.get("object_id", "")))
	var orbit_scene: PackedScene = object_params.get("scene", DEFAULT_ORBIT_OBJECT_SCENE) as PackedScene
	var parent: Node = _resolve_parent(params.get("parent"))
	if orbit_scene == null or parent == null:
		return null

	var orbit_object: Node2D = orbit_scene.instantiate() as Node2D
	if orbit_object == null:
		return null

	parent.add_child(orbit_object)
	orbit_object.global_position = _get_vector2(object_params.get("position", Vector2.ZERO), Vector2.ZERO)
	if orbit_object.has_method("setup"):
		orbit_object.call("setup", object_params)

	return orbit_object


static func _apply_combat_object_definition(params: Dictionary, object_id: String) -> Dictionary:
	var merged_params: Dictionary = params.duplicate(true)
	if object_id == "":
		return merged_params

	var data_manager: Node = _get_data_manager()
	if data_manager == null or not data_manager.has_method("get_combat_object_definition"):
		return merged_params

	var definition_variant: Variant = data_manager.call("get_combat_object_definition", object_id)
	if not (definition_variant is Dictionary):
		return merged_params

	var definition: Dictionary = definition_variant
	if definition.is_empty():
		return merged_params

	if definition.has("scene") and not merged_params.has("scene"):
		var scene: PackedScene = load(String(definition["scene"])) as PackedScene
		if scene != null:
			merged_params["scene"] = scene
	if definition.has("collision_radius") and not merged_params.has("radius"):
		merged_params["radius"] = float(definition["collision_radius"])
	if definition.has("collision_radius") and not merged_params.has("area_radius"):
		merged_params["area_radius"] = float(definition["collision_radius"])
	for visual_key: String in ["visual_style", "visual_color", "visual_ring_color", "visual_mode", "visual_effect_scene"]:
		if definition.has(visual_key) and not merged_params.has(visual_key):
			merged_params[visual_key] = definition[visual_key]
	if definition.has("visual") and not merged_params.has("visual"):
		merged_params["visual"] = _get_dictionary(definition["visual"])
	if definition.has("animations") and merged_params.has("visual") and merged_params["visual"] is Dictionary:
		var visual: Dictionary = merged_params["visual"]
		if not visual.has("animations"):
			visual["animations"] = _get_dictionary(definition["animations"])
			merged_params["visual"] = visual

	return merged_params


static func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null

	return tree.root.get_node_or_null("DataManager")


static func _resolve_parent(value: Variant) -> Node:
	if value is Node:
		return value

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		return tree.current_scene

	return null


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))

	return fallback


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
