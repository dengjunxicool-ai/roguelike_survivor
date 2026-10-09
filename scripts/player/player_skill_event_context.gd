## 文件用途：构建突进、玩家受击和技能专属伤害规则所需的事件上下文。
## 使用方式：Player 发出事件或执行规则前静态调用 build_*；保留施法者、技能管理器、来源伤害与突进路径。

extends RefCounted
class_name PlayerSkillEventContext


## 作用：构建突进上下文。
## 使用：供本模块调用者使用；输入 player（玩家）、dash_direction（突进方向）、skill_manager（技能管理服务）、relic_manager（遗物管理服务）、event_bus（事件bus）；返回字典包含 player/caster/owner/position/dash_direction/dash_path_start/dash_path_end/skill_manager 等字段。
static func build_dash_context(player: Node2D, dash_direction: Vector2, skill_manager: Node, relic_manager: Node, event_bus: Node) -> Dictionary:
	var dash_start: Vector2 = player.global_position if player != null else Vector2.ZERO
	var dash_end: Vector2 = dash_start + dash_direction.normalized() * _dash_remaining_distance(player)
	return {
		"player": player,
		"caster": player,
		"owner": player,
		"position": player.global_position,
		"dash_direction": dash_direction,
		"dash_path_start": dash_start,
		"dash_path_end": dash_end,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": _resolve_parent(player),
		"target_group": &"enemies"
	}


## 作用：突进剩余距离。
## 使用：本文件由 build_dash_context 调用；输入 player（玩家）；返回计算或读取的数值。
static func _dash_remaining_distance(player: Node) -> float:
	if player == null:
		return 0.0
	return maxf(float(player.get("dash_speed")) * float(player.get("_dash_time_remaining")), 0.0)


## 作用：构建承伤上下文。
## 使用：供本模块调用者使用；输入 player（玩家）、source_packet（来源伤害包）、damage_result（伤害结果）、amount（数量）、skill_manager（技能管理服务）、relic_manager（遗物管理服务）、event_bus（事件bus）；返回字典包含 player/caster/owner/target/parent/source_packet/damage_result/amount 等字段。
static func build_damage_taken_context(player: Node2D, source_packet: Variant, damage_result: Dictionary, amount: int, skill_manager: Node, relic_manager: Node, event_bus: Node) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"owner": player,
		"target": player,
		"parent": _resolve_parent(player),
		"source_packet": source_packet,
		"damage_result": damage_result,
		"amount": amount,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"target_group": &"enemies"
	}


## 作用：构建技能实例伤害上下文。
## 使用：供本模块调用者使用；输入 player（玩家）、source_packet（来源伤害包）、damage_result（伤害结果）、amount（数量）、skill_instance（技能实例）、skill_manager（技能管理服务）、relic_manager（遗物管理服务）；返回字典包含 player/caster/parent/source_packet/damage_result/amount/skill_instance/skill_manager 等字段。
static func build_skill_instance_damage_context(player: Node2D, source_packet: Variant, damage_result: Dictionary, amount: int, skill_instance: RefCounted, skill_manager: Node, relic_manager: Node) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"parent": _resolve_parent(player),
		"source_packet": source_packet,
		"damage_result": damage_result,
		"amount": amount,
		"skill_instance": skill_instance,
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"target_group": &"enemies"
	}


## 作用：构建伤害规则上下文。
## 使用：供本模块调用者使用；输入 player（玩家）、source_packet（来源伤害包）、damage_result（伤害结果）、skill_instance（技能实例）；返回字典包含 player/caster/parent/source_packet/damage_result/skill_instance/target_group。
static func build_damage_rule_context(player: Node2D, source_packet: Variant, damage_result: Dictionary, skill_instance: RefCounted) -> Dictionary:
	return {
		"player": player,
		"caster": player,
		"parent": _resolve_parent(player),
		"source_packet": source_packet,
		"damage_result": damage_result,
		"skill_instance": skill_instance,
		"target_group": &"enemies"
	}


## 作用：解析父节点，供当前模块后续逻辑使用。
## 使用：本文件由 build_dash_context、build_damage_taken_context、build_skill_instance_damage_context 调用；输入 player（玩家）；返回 Node 对象/值。
static func _resolve_parent(player: Node) -> Node:
	if player == null:
		return null
	var tree: SceneTree = player.get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return player.get_parent()
