extends RefCounted
class_name RunSceneCoordinator


const PLAYER_GROUP: StringName = &"player"
const ENEMY_SPAWNER_GROUP: StringName = &"enemy_spawner"
const RUN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MapRuntimeScript: Script = preload("res://scripts/maps/map_runtime.gd")
const MapVariableRuntimeScript: Script = preload("res://scripts/maps/map_variable_runtime.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")

var _active_run_scene: Node
var _map_variable_runtime: Node
var _run_stats_tracker: Node


## Params:
## - context: Run setup values, including tree, scene_parent, map_id, run_loadout, choice_modal, and stat_event_callable.
## Returns:
## - Dictionary with resolved map_id, map_name, map_data, and run_stats_tracker.
func start_run(context: Dictionary) -> Dictionary:
	var tree: SceneTree = context.get("tree", null) as SceneTree
	var scene_parent: Node = context.get("scene_parent", null) as Node
	var loadout: RefCounted = _resolve_run_loadout(context)
	if loadout == null:
		push_error("[RunSceneCoordinator] start_run requires a valid RunLoadout.")
		return {}
	var character_id: StringName = StringName(String(loadout.get("character_id")))
	var selected_map_id: StringName = resolve_map_id(context.get("map_id", &""))
	var map_data: Dictionary = GameData.get_map(selected_map_id)
	var selected_map_name: String = String(map_data.get("display_name", selected_map_id)) if not map_data.is_empty() else String(selected_map_id)

	_ensure_run_scene(tree, scene_parent)
	_set_run_debug_enabled(bool(context.get("debug", false)))
	_setup_run_stats_tracker(
		map_data,
		get_run_scene_parent(tree),
		character_id,
		selected_map_id,
		selected_map_name,
		context.get("stat_event_callable", Callable())
	)
	_reset_choice_modal(context.get("choice_modal", null))
	MapRuntimeScript.apply_background(tree, map_data)
	clear_runtime_nodes(tree)
	_reset_runtime_sources(tree, loadout)
	_setup_map_variable_runtime(map_data, get_run_scene_parent(tree))

	return {
		"map_id": selected_map_id,
		"map_name": selected_map_name,
		"map_data": map_data,
		"debug": bool(context.get("debug", false)),
		"run_stats_tracker": _run_stats_tracker
	}


## Params:
## - context: Run setup values that must contain a RunLoadout.
## Returns:
## - Valid RunLoadout when resolvable, otherwise null.
func _resolve_run_loadout(context: Dictionary) -> RefCounted:
	var loadout: RefCounted = context.get("run_loadout", null) as RefCounted
	if loadout != null and bool(loadout.call("is_valid")):
		return loadout
	return null


## Params:
## - tree: Scene tree whose transient combat nodes should be cleared.
## Returns:
## - Nothing.
func teardown(tree: SceneTree) -> void:
	clear_runtime_nodes(tree)
	if _map_variable_runtime != null and is_instance_valid(_map_variable_runtime):
		_map_variable_runtime.queue_free()
	_map_variable_runtime = null
	if _run_stats_tracker != null and is_instance_valid(_run_stats_tracker):
		_run_stats_tracker.queue_free()
	_run_stats_tracker = null
	if _active_run_scene != null and is_instance_valid(_active_run_scene):
		_active_run_scene.queue_free()
	_active_run_scene = null


## Params:
## - tree: Scene tree used as fallback when the active run scene has not been created.
## Returns:
## - Active run scene when available, otherwise the tree current_scene.
func get_run_scene_parent(tree: SceneTree) -> Node:
	if _active_run_scene != null and is_instance_valid(_active_run_scene):
		return _active_run_scene
	return tree.current_scene if tree != null else null


## Params:
## - map_id: Raw map id value from UI or config.
## Returns:
## - Canonical map id.
func resolve_map_id(map_id: Variant) -> StringName:
	return MapRuntimeScript.resolve_map_id(map_id)


## Params:
## - map_data: Map dictionary from GameData.
## Returns:
## - Background texture path for the map.
func get_background_path(map_data: Dictionary) -> String:
	return MapRuntimeScript.get_background_path(map_data)


## Params:
## - tree: Scene tree whose transient runtime nodes should be removed.
## Returns:
## - Nothing.
func clear_runtime_nodes(tree: SceneTree) -> void:
	if tree == null:
		return
	for group_name: StringName in [&"enemy", &"experience_crystal", &"map_hazard"]:
		for node: Node in tree.get_nodes_in_group(group_name):
			node.queue_free()


## Params:
## - tree: Scene tree used to locate or parent the run scene.
## - scene_parent: Preferred parent for the run scene.
## Returns:
## - Nothing.
func _ensure_run_scene(tree: SceneTree, scene_parent: Node) -> void:
	if _active_run_scene != null and is_instance_valid(_active_run_scene):
		return

	var parent: Node = scene_parent
	if parent == null and tree != null:
		parent = tree.current_scene
	if parent == null:
		push_error("Cannot create run scene without a scene parent.")
		return

	_active_run_scene = RUN_SCENE.instantiate()
	_active_run_scene.name = "Main"
	parent.add_child(_active_run_scene)
	parent.move_child(_active_run_scene, 0)


func _set_run_debug_enabled(enabled: bool) -> void:
	if _active_run_scene == null or not is_instance_valid(_active_run_scene):
		return
	_active_run_scene.set_meta("debug", enabled)


## Params:
## - map_data: Map dictionary from GameData.
## - parent: Node that owns map runtime helpers.
## Returns:
## - Nothing.
func _setup_map_variable_runtime(map_data: Dictionary, parent: Node) -> void:
	if parent == null:
		return
	if _map_variable_runtime == null or not is_instance_valid(_map_variable_runtime):
		_map_variable_runtime = MapVariableRuntimeScript.new()
		_map_variable_runtime.name = "MapVariableRuntime"
		parent.add_child(_map_variable_runtime)
	if _map_variable_runtime.has_method("setup"):
		_map_variable_runtime.call("setup", map_data, PLAYER_GROUP)


## Params:
## - map_data: Map dictionary from GameData.
## - parent: Node that owns the run stats tracker.
## - character_id: Selected character id.
## - map_id: Resolved selected map id.
## - map_name: Display name for the selected map.
## - event_callable: Callback for stat events.
## Returns:
## - Nothing.
func _setup_run_stats_tracker(
	map_data: Dictionary,
	parent: Node,
	character_id: StringName,
	map_id: StringName,
	map_name: String,
	event_callable: Callable
) -> void:
	if parent == null:
		return
	if _run_stats_tracker == null or not is_instance_valid(_run_stats_tracker):
		_run_stats_tracker = RunStatsTrackerScript.new()
		_run_stats_tracker.name = "RunStatsTracker"
		parent.add_child(_run_stats_tracker)
	if _run_stats_tracker.has_signal("event_recorded") and event_callable.is_valid():
		if not _run_stats_tracker.is_connected("event_recorded", event_callable):
			_run_stats_tracker.connect("event_recorded", event_callable)
	if _run_stats_tracker.has_method("reset_run"):
		_run_stats_tracker.call("reset_run", character_id, map_id, String(map_data.get("display_name", map_name)))


## Params:
## - choice_modal: Run choice modal controller to reset.
## Returns:
## - Nothing.
func _reset_choice_modal(choice_modal: Variant) -> void:
	if choice_modal != null and choice_modal.has_method("reset_run"):
		choice_modal.call("reset_run")


## Params:
## - tree: Scene tree used to locate runtime nodes.
## - loadout: Resolved run loadout.
## Returns:
## - Nothing.
func _reset_runtime_sources(tree: SceneTree, loadout: RefCounted) -> void:
	if tree == null:
		return
	var spawner: Node = tree.get_first_node_in_group(ENEMY_SPAWNER_GROUP)
	if spawner != null and spawner.has_method("reset_for_run"):
		spawner.call(&"reset_for_run")

	var player: Node = tree.get_first_node_in_group(PLAYER_GROUP)
	if player != null:
		player.call(&"reset_for_loadout", loadout)
