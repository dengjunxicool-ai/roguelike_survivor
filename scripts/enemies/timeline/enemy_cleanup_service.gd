extends RefCounted
class_name EnemyCleanupService


var _owner: Node
var _target_group: StringName = &"player"


func setup(owner: Node, target_group: StringName = &"player") -> void:
	_owner = owner
	_target_group = target_group


func get_alive_normal_enemy_count() -> int:
	return get_alive_enemy_count("normal")


func get_alive_boss_minion_count() -> int:
	return get_alive_enemy_count("boss_minion")


func get_alive_enemy_count(enemy_type_filter: String) -> int:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return 0

	var count: int = 0
	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy_type: String = String(enemy.get_meta("enemy_type", "normal"))
		if enemy_type == enemy_type_filter:
			count += 1
	return count


func despawn_far_enemies(despawn_radius: float) -> void:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return

	var target: Node2D = tree.get_first_node_in_group(_target_group) as Node2D
	if target == null:
		return

	var despawn_radius_squared: float = despawn_radius * despawn_radius
	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue

		var enemy_type: String = String(enemy_node.get_meta("enemy_type", "normal"))
		if enemy_type != "normal" and enemy_type != "boss_minion":
			continue

		if enemy_node.global_position.distance_squared_to(target.global_position) > despawn_radius_squared:
			enemy_node.queue_free()


func clear_normal_enemies() -> void:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return

	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue

		var enemy_type: String = String(enemy_node.get_meta("enemy_type", "normal"))
		if enemy_type == "normal" or enemy_type == "boss_minion":
			enemy_node.queue_free()


func collect_all_experience_crystals() -> void:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return

	var player: Node2D = tree.get_first_node_in_group(_target_group) as Node2D
	if player == null:
		return

	for crystal_node: Node in tree.get_nodes_in_group(&"experience_crystal"):
		var crystal: Node2D = crystal_node as Node2D
		if crystal == null or not is_instance_valid(crystal):
			continue
		if crystal.has_method("collect_to_player"):
			crystal.call("collect_to_player", player)
		elif player.has_method("add_experience") and crystal.get("experience_amount") != null:
			player.call("add_experience", int(crystal.get("experience_amount")))
			if crystal.has_method("despawn_or_free"):
				crystal.call("despawn_or_free")
			else:
				crystal.call("queue_free")


func _get_tree() -> SceneTree:
	if _owner == null:
		return null
	return _owner.get_tree()
