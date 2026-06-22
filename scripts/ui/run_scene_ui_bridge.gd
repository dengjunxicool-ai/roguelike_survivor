extends RefCounted
class_name RunSceneUIBridge


const PLAYER_GROUP: StringName = &"player"
const ENEMY_SPAWNER_GROUP: StringName = &"enemy_spawner"


var _connected_player_id: int = 0
var _connected_spawner_id: int = 0
var _tracked_enemy_ids: Dictionary = {}


func reset() -> void:
	_connected_player_id = 0
	_connected_spawner_id = 0
	_tracked_enemy_ids.clear()


func connect_runtime_sources(tree: SceneTree, target: Object) -> void:
	if tree == null or target == null:
		return
	_connect_player(tree.get_first_node_in_group(PLAYER_GROUP), target)
	_connect_spawner(tree.get_first_node_in_group(ENEMY_SPAWNER_GROUP), target)


func connect_enemy_death_signals(tree: SceneTree, target: Object) -> void:
	if tree == null or target == null:
		return
	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy_instance_id: int = int(enemy.get_instance_id())
		if _tracked_enemy_ids.has(enemy_instance_id):
			continue
		if not enemy.has_signal(&"died"):
			continue
		_tracked_enemy_ids[enemy_instance_id] = true
		var death_callable: Callable = Callable(target, "_on_enemy_died").bind(enemy)
		if not enemy.is_connected(&"died", death_callable):
			enemy.connect(&"died", death_callable)


func _connect_player(player: Node, target: Object) -> void:
	if player == null:
		return
	var player_id: int = int(player.get_instance_id())
	if _connected_player_id == player_id:
		return
	_connected_player_id = player_id
	_connect_if_available(player, &"leveled_up", Callable(target, "_on_player_leveled_up"))
	_connect_if_available(player, &"died", Callable(target, "_on_player_died"))
	_connect_if_available(player, &"upgrade_applied", Callable(target, "_on_player_upgrade_applied"))


func _connect_spawner(spawner: Node, target: Object) -> void:
	if spawner == null:
		return
	var spawner_id: int = int(spawner.get_instance_id())
	if _connected_spawner_id != spawner_id:
		_connected_spawner_id = spawner_id
		_connect_if_available(spawner, &"timeline_event_started", Callable(target, "_on_timeline_event_started"))
		_connect_if_available(spawner, &"wave_changed", Callable(target, "_on_wave_changed"))
		_connect_if_available(spawner, &"wave_timer_changed", Callable(target, "_on_wave_timer_changed"))
		_connect_if_available(spawner, &"wave_cleared", Callable(target, "_on_wave_cleared"))

	_connect_if_available(spawner, &"run_time_changed", Callable(target, "_on_run_time_changed"))
	_connect_if_available(spawner, &"boss_defeated", Callable(target, "_on_boss_defeated"))


func _connect_if_available(node: Node, signal_name: StringName, callable: Callable) -> void:
	if node == null or not node.has_signal(signal_name):
		return
	if not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)
