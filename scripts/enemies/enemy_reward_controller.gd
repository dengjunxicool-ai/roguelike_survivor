## 文件用途：执行敌人灵魂、经验、击杀事件与 Boss 核心统计。
## 使用方式：setup 绑定 enemy；死亡流水线调用奖励入口，避免在行为策略内直接发奖。

extends RefCounted
class_name EnemyRewardController


const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")

var _owner: Node2D


## Params:
## - owner: Enemy node that owns reward and kill-side effects.
## Returns:
## - Nothing.
## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner


## Params:
## - None.
## Returns:
## - Nothing.
## 作用：读取敌人灵魂掉落并应用目标的灵魂收益倍率，将正数结果存入 SaveManager。
## 使用：死亡奖励流水线调用；找不到目标时倍率为 1，零掉落或无 owner 跳过；可能写入 user:// 存档。
func award_soul_stones() -> void:
	if _owner == null:
		return

	var soul_drop: int = int(_owner.get("soul_drop"))
	if soul_drop <= 0:
		return

	var multiplier: float = 1.0
	var target: Node = _owner.get("target") as Node
	if target == null:
		target = _find_target_in_group()
	if target != null:
		var multiplier_variant: Variant = target.get("soul_gain_multiplier")
		if multiplier_variant != null:
			multiplier = float(multiplier_variant)

	var final_amount: int = maxi(roundi(float(soul_drop) * multiplier), 0)
	if final_amount > 0:
		SaveManager.add_soul_stones(final_amount)


## Params:
## - amount: Raw incoming damage after normal damage calculation.
## - damage_type: Damage type or element for synergy systems.
## Returns:
## - Damage amount after synergy adjustments.
## 作用：把即将对敌人结算的伤害交给玩家协同服务调整。
## 使用：amount 为正常计算后伤害；服务返回 amount 时取非负结果，没有服务或有效结果则返回原伤害。
func apply_damage_synergies(amount: int, damage_type: Variant) -> int:
	var synergy_manager: Node = _get_synergy_manager()
	if synergy_manager == null or not synergy_manager.has_method("on_damage_dealt"):
		return amount

	var event_variant: Variant = synergy_manager.call("on_damage_dealt", {
		"target": _owner,
		"amount": amount,
		"damage_type": StringName(String(damage_type))
	})
	if event_variant is Dictionary:
		var event: Dictionary = event_variant
		return maxi(int(event.get("amount", amount)), 0)

	return amount


## Params:
## - amount: Damage after normal synergy adjustments.
## Returns:
## - Damage after boss-core protection reduction.
## 作用：按存活核心数量降低 Boss 承伤，每个核心 10%，最多 20%。
## 使用：仅 owner 等阶为 boss 且输入伤害为正时生效；结果取整后至少为 1；返回计算或读取的数值。
func apply_boss_core_damage_reduction(amount: int) -> int:
	if _owner == null or amount <= 0 or String(_owner.get_meta("enemy_rank", "")) != "boss":
		return amount
	var tree: SceneTree = _owner.get_tree()
	if tree == null:
		return amount
	var core_count: int = tree.get_nodes_in_group(&"boss_cores").size()
	if core_count <= 0:
		return amount
	var reduction: float = minf(float(core_count) * 0.10, 0.20)
	return maxi(roundi(float(amount) * (1.0 - reduction)), 1)


## Params:
## - amount: Final damage amount applied to the owner.
## - damage_result: Full damage calculation result.
## - source_packet: Original damage packet or amount.
## Returns:
## - Nothing.
## 作用：记录输出伤害；具体处理委托给 tracker.record_damage_done。
## 使用：供本模块调用者使用；输入 amount（数量）、damage_result（伤害结果）、source_packet（来源伤害包）。
func record_damage_done(amount: int, damage_result: Dictionary, source_packet: DamagePacket) -> void:
	if _owner == null:
		return
	var tracker: Node = RunStatsTrackerScript.get_active(_owner.get_tree())
	if tracker != null and tracker.has_method("record_damage_done"):
		tracker.call("record_damage_done", _owner, amount, damage_result, source_packet)


## Params:
## - None.
## Returns:
## - Nothing.
## 作用：记录Boss核心销毁；具体处理委托给 tracker.record_boss_core_destroyed。
## 使用：供本模块调用者使用。
func record_boss_core_destroyed() -> void:
	if _owner == null or String(_owner.get_meta("enemy_rank", "")) != "boss_core":
		return
	var tracker: Node = RunStatsTrackerScript.get_active(_owner.get_tree())
	if tracker != null and tracker.has_method("record_boss_core_destroyed"):
		tracker.call("record_boss_core_destroyed", _owner)


## Params:
## - None.
## Returns:
## - Nothing.
## 作用：构建含死亡位置、等阶、生成来源及伤害溯源的击杀事件并通知协同、特质和技能。
## 使用：死亡流水线调用一次；事件携带 enemy 与节点引用，当前局依赖失效时跳过对应分发。
func notify_enemy_killed_synergies() -> void:
	if _owner == null:
		return

	var event: Dictionary = {
		"enemy": _owner,
		"position": _owner.global_position,
		"parent": _owner.get_parent(),
		"target_group": &"enemies",
		"enemy_rank": String(_owner.get_meta("enemy_rank", "normal")),
		"spawn_source_type": String(_owner.get_meta("spawn_source_type", "unknown")),
		"source_key": String(_owner.get_meta("last_damage_source_key", "unknown")),
		"debug_attack_trace_id": DamageTraceContextScript.get_last_damage_trace_id(_owner)
	}

	var synergy_manager: Node = _get_synergy_manager()
	if synergy_manager != null and synergy_manager.has_method("on_enemy_killed"):
		synergy_manager.call("on_enemy_killed", event)

	var player: Node = _get_player()
	var trait_system: Node = player.get_node_or_null("CharacterTraitSystem") if player != null else null
	if trait_system != null and trait_system.has_method("handle_enemy_killed"):
		trait_system.call("handle_enemy_killed", event)
	_emit_skill_enemy_killed(player, event)


## 作用：发出技能敌人击杀并衔接对应的事件处理流程。
## 使用：本文件由 notify_enemy_killed_synergies 调用；输入 player（玩家）、event（事件）。
func _emit_skill_enemy_killed(player: Node, event: Dictionary) -> void:
	if player == null:
		return
	var event_bus: Node = player.get_node_or_null("SkillEventBus")
	if event_bus == null or not event_bus.has_method("emit_skill_event"):
		return
	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null or not skill_manager.has_method("get_skill"):
		return
	var skill_id: StringName = StringName(String(runtime.call("get_starting_skill_id")))
	var skill_instance: RefCounted = skill_manager.call("get_skill", skill_id) as RefCounted
	if skill_instance == null:
		return
	var skill_event: Dictionary = event.duplicate(true)
	skill_event["caster"] = player
	skill_event["owner"] = player
	skill_event["skill_id"] = skill_id
	skill_event["skill_instance"] = skill_instance
	skill_event["skill_manager"] = skill_manager
	skill_event["relic_manager"] = player.get_node_or_null("RelicManager")
	skill_event["event_bus"] = event_bus
	event_bus.call("emit_skill_event", &"on_enemy_killed", skill_event)


## Params:
## - None.
## Returns:
## - Player synergy manager node when available.
## 作用：获取协同管理服务，供当前模块后续逻辑使用。
## 使用：本文件由 apply_damage_synergies、notify_enemy_killed_synergies 调用；返回 Node 对象/值。
func _get_synergy_manager() -> Node:
	var player: Node = _get_player()
	if player == null:
		return null
	return player.get_node_or_null("SynergyManager")


## Params:
## - None.
## Returns:
## - Current target node resolved from the owner target group.
## 作用：查找目标范围内分组，供当前模块后续逻辑使用。
## 使用：本文件由 award_soul_stones 调用；返回 Node 对象/值。
func _find_target_in_group() -> Node:
	if _owner == null or _owner.get_tree() == null:
		return null
	return _owner.get_tree().get_first_node_in_group(_owner.get("target_group"))


## Params:
## - None.
## Returns:
## - Player node when available.
## 作用：获取玩家，供当前模块后续逻辑使用。
## 使用：本文件由 notify_enemy_killed_synergies、_get_synergy_manager 调用；返回 Node 对象/值。
func _get_player() -> Node:
	if _owner == null or _owner.get_tree() == null:
		return null
	return _owner.get_tree().get_first_node_in_group(&"player")
