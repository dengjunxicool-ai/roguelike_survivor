## 文件用途：合并战斗对象定义并生成投射物、区域或环绕物，前两类支持runtime对象池。
## 使用方式：技能动作调用create_*传parent、位置、方向和payload；返回节点或创建失败的null。
extends RefCounted
class_name CombatObjectFactory


const RuntimePoolRegistryScript: Script = preload("res://scripts/runtime/runtime_pool_registry.gd")
const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/combat/fireball_projectile.tscn")
const DEFAULT_AREA_EFFECT_SCENE: PackedScene = preload("res://scenes/combat/area_effect.tscn")
const DEFAULT_ORBIT_OBJECT_SCENE: PackedScene = preload("res://scenes/combat/orbit_object.tscn")


## 作用：合并定义并从池生成投射物，设位置后准备spawn或setup。
## 使用：params须含非零direction和可用parent；物理帧位置deferred写入。
static func create_projectile(params: Dictionary) -> Node2D:
	var object_params: Dictionary = _apply_combat_object_definition(params, String(params.get("projectile_id", params.get("object_id", ""))))
	var projectile_scene: PackedScene = object_params.get("scene", DEFAULT_PROJECTILE_SCENE) as PackedScene
	var parent: Node = _resolve_parent(params.get("parent"))
	var direction: Vector2 = _get_vector2(object_params.get("direction", Vector2.ZERO), Vector2.ZERO)
	if projectile_scene == null or parent == null or direction == Vector2.ZERO:
		return null

	var projectile: Node2D = _spawn_pooled_combat_node(projectile_scene, parent, &"projectile") as Node2D
	if projectile == null:
		return null

	var spawn_position: Vector2 = _get_vector2(object_params.get("position", Vector2.ZERO), Vector2.ZERO)
	if Engine.is_in_physics_frame():
		projectile.set_deferred("global_position", spawn_position)
	else:
		projectile.global_position = spawn_position
	if projectile.has_method("prepare_for_pool_spawn"):
		projectile.call(&"prepare_for_pool_spawn", object_params)
	elif projectile.has_method("setup"):
		projectile.call(&"setup", object_params)

	return projectile


## 作用：合并定义并从池生成区域，设位置后配置。
## 使用：物理帧时位置与setup均deferred，避免初始化期间触碰物理状态。
static func create_area_effect(params: Dictionary) -> Node2D:
	var object_params: Dictionary = _apply_combat_object_definition(params, String(params.get("area_id", params.get("object_id", ""))))
	var area_effect_scene: PackedScene = object_params.get("scene", DEFAULT_AREA_EFFECT_SCENE) as PackedScene
	var parent: Node = _resolve_parent(params.get("parent"))
	if area_effect_scene == null or parent == null:
		return null

	var area_effect: Node2D = _spawn_pooled_combat_node(area_effect_scene, parent, &"area") as Node2D
	if area_effect == null:
		return null

	var spawn_position: Vector2 = _get_vector2(object_params.get("position", Vector2.ZERO), Vector2.ZERO)
	if Engine.is_in_physics_frame():
		area_effect.set_deferred("global_position", spawn_position)
		if area_effect.has_method("prepare_for_pool_spawn"):
			area_effect.call_deferred(&"prepare_for_pool_spawn", object_params)
		elif area_effect.has_method("setup"):
			area_effect.call_deferred(&"setup", object_params)
	else:
		area_effect.global_position = spawn_position
		if area_effect.has_method("prepare_for_pool_spawn"):
			area_effect.call(&"prepare_for_pool_spawn", object_params)
		elif area_effect.has_method("setup"):
			area_effect.call(&"setup", object_params)

	return area_effect


## 作用：实例化环绕场景、挂父节点并配置位置和setup。
## 使用：此路径不经对象池，params含owner等环绕上下文。
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


## 作用：复制参数并用DataManager定义补缺失场景、碰撞与视觉字段。
## 使用：显式params优先，object_id空或定义缺失返回原参数副本。
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


## 作用：从SceneTree根查询DataManager。
## 使用：无有效树返回null；仅查询已发布配置。
static func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null

	return tree.root.get_node_or_null("DataManager")


## 作用：优先返回参数节点，否则使用当前主场景。
## 使用：找不到父节点返回null。
static func _resolve_parent(value: Variant) -> Node:
	if value is Node:
		return value

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		return tree.current_scene

	return null


## 作用：按场景与类别池键请求节点，缺池时直接实例化并挂父节点。
## 使用：物理帧下挂节点deferred；返回Node或null。
static func _spawn_pooled_combat_node(scene: PackedScene, parent: Node, category: StringName) -> Node:
	if scene == null:
		return null
	var pool: Node = RuntimePoolRegistryScript.get_or_create(parent)
	var key: StringName = _pool_key_for_scene(scene, category)
	var factory: Callable = Callable(CombatObjectFactory, "_instantiate_scene").bind(scene)
	if pool != null and pool.has_method("spawn"):
		return pool.call("spawn", key, factory, parent) as Node
	var node: Node = scene.instantiate()
	if node != null and parent != null:
		if Engine.is_in_physics_frame():
			parent.call_deferred("add_child", node)
		else:
			parent.add_child(node)
	return node


## 作用：实例化指定PackedScene。
## 使用：用作池工厂Callable，空场景返回null。
static func _instantiate_scene(scene: PackedScene) -> Node:
	return scene.instantiate() if scene != null else null


## 作用：用类别和场景路径构成池键。
## 使用：匿名场景用anonymous，返回StringName。
static func _pool_key_for_scene(scene: PackedScene, category: StringName) -> StringName:
	var scene_path: String = scene.resource_path
	if scene_path == "":
		scene_path = "anonymous"
	return StringName("combat_scene:%s:%s" % [String(category), scene_path])


## 作用：将Vector2或至少两个成员的[x,y]数组解析为二维值。
## 使用：无法解析时返回fallback；不修改输入。
static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))

	return fallback


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回深复制，嵌套修改不会污染输入。
static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
