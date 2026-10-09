## 文件用途：统计存活敌人、清理远处敌人及收集全场经验。
## 使用方式：setup 绑定 owner 和玩家组；波次/地图编排调用，清理和真实死亡奖励分离。

extends RefCounted
class_name EnemyCleanupService


var _owner: Node
var _target_group: StringName = &"player"


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node, target_group: StringName = &"player") -> void:
	_owner = owner
	_target_group = target_group


## 作用：获取存活普通敌人数量，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回计算或读取的数值。
func get_alive_normal_enemy_count() -> int:
	return _get_alive_enemy_count(false)


## 作用：获取存活Boss随从数量，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回计算或读取的数值。
func get_alive_boss_minion_count() -> int:
	return _get_alive_enemy_count(true)


## 作用：获取存活敌人数量，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回计算或读取的数值。
func get_alive_enemy_count() -> int:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		if _is_alive(enemy):
			count += 1
	return count


## 作用：判断存活，返回布尔判断结果；具体处理委托给 enemy.is_dead。
## 使用：本文件由 get_alive_enemy_count、_get_alive_enemy_count、despawn_far_enemies 调用；输入 enemy（敌人）。
func _is_alive(enemy: Node) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not (enemy.has_method("is_dead") and bool(enemy.call("is_dead")))


## 作用：获取存活敌人数量，供当前模块后续逻辑使用。
## 使用：本文件由 get_alive_normal_enemy_count、get_alive_boss_minion_count 调用；输入 boss_minions（Bossminions）；返回计算或读取的数值。
func _get_alive_enemy_count(boss_minions: bool) -> int:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		if not _is_alive(enemy):
			continue
		var is_minion: bool = String(enemy.get_meta("spawn_source_type", "")) == "boss_minion"
		if (is_minion if boss_minions else String(enemy.get_meta("enemy_rank", "normal")) == "normal" and not is_minion):
			count += 1
	return count


## 作用：回收远处敌人组。
## 使用：供本模块调用者使用；输入 despawn_radius（回收半径）。
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
		if enemy_node == null or not _is_alive(enemy_node) or bool(enemy_node.get_meta("spawn_reveal_pending", false)):
			continue

		if String(enemy_node.get_meta("enemy_rank", "normal")) != "normal":
			continue

		if enemy_node.global_position.distance_squared_to(target.global_position) > despawn_radius_squared:
			enemy_node.queue_free()


## 作用：清除普通敌人组。
## 使用：供本模块调用者使用。
func clear_normal_enemies() -> void:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return

	for enemy: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue

		if String(enemy_node.get_meta("enemy_rank", "normal")) == "normal":
			enemy_node.queue_free()


## 作用：收集全部经验晶体组。
## 使用：供本模块调用者使用。
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


## 作用：获取场景树，供当前模块后续逻辑使用。
## 使用：本文件由 get_alive_enemy_count、_get_alive_enemy_count、despawn_far_enemies 调用；返回 SceneTree 对象/值。
func _get_tree() -> SceneTree:
	if _owner == null:
		return null
	return _owner.get_tree()
