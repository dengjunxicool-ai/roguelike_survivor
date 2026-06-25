extends Node
class_name SummonManager


const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SummonFormationServiceScript: Script = preload("res://scripts/summons/summon_formation_service.gd")
const DEFAULT_SUMMON_SCENE: PackedScene = preload("res://scenes/summon_controller.tscn")

var _active_by_id: Dictionary = {}


func spawn_summon(definition_variant: Variant, context: Dictionary = {}) -> Node2D:
	var definition: RefCounted = _resolve_definition(definition_variant)
	if definition == null:
		return null
	var owner: Node2D = context.get("owner", context.get("caster")) as Node2D
	var parent: Node = context.get("parent") as Node
	if parent == null and owner != null:
		parent = owner.get_parent()
	if owner == null or parent == null:
		return null
	var definition_id: StringName = StringName(String(definition.get("id")))
	_prune(definition_id)
	var active: Array = _active_by_id.get(definition_id, [])
	if active.size() >= int(definition.get("max_count")):
		return null
	var scene: PackedScene = load(String(definition.get("scene_path"))) as PackedScene
	if scene == null:
		scene = DEFAULT_SUMMON_SCENE
	var summon: Node2D = scene.instantiate() as Node2D
	if summon == null:
		return null
	parent.add_child(summon)
	var formation_index: int = active.size()
	var movement: Dictionary = definition.get("movement")
	var offset: Vector2 = SummonFormationServiceScript.get_offset(formation_index, float(movement.get("separation_radius", 32.0)), float(movement.get("follow_distance", 80.0)))
	summon.global_position = owner.global_position + offset
	var setup_params: Dictionary = context.duplicate(true)
	setup_params["definition"] = definition
	setup_params["owner"] = owner
	setup_params["formation_index"] = formation_index
	setup_params["player_power"] = float(context.get("player_power", _read_owner_power(owner)))
	if summon.has_method("setup"):
		summon.call("setup", setup_params)
	active.append(summon)
	_active_by_id[definition_id] = active
	return summon


func _resolve_definition(value: Variant) -> RefCounted:
	if value is RefCounted:
		return value
	if value is Dictionary:
		return SummonDefinitionScript.from_dictionary(value)
	return SummonDefinitionScript.from_id(value)


func _prune(definition_id: StringName) -> void:
	var active: Array = _active_by_id.get(definition_id, [])
	for index: int in range(active.size() - 1, -1, -1):
		var summon: Node = active[index] as Node
		if summon == null or not is_instance_valid(summon) or summon.is_queued_for_deletion():
			active.remove_at(index)
	_active_by_id[definition_id] = active


func _read_owner_power(node: Node) -> float:
	if node == null:
		return 1.0
	for property_name: String in ["attack_power", "damage", "base_damage"]:
		var value: Variant = node.get(property_name)
		if value != null and float(value) > 0.0:
			return float(value)
	return 1.0
