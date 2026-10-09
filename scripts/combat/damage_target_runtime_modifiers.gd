## 文件用途：读取酸系减防、熔岩/圣盾/遗物防护及毒瓶/烟雾减攻的临时运行元数据。
## 使用方式：伤害计算阶段按到期时间与适用范围调用，未生效返回中性值。
extends RefCounted
class_name DamageTargetRuntimeModifiers


## 作用：在临时酸系减防未过期时减少固定防御并下限为0。
## 使用：target、defense 为目标与原防御；过期原值返回。
static func acid_boss_defense(target: Node, defense: float) -> float:
	if target == null:
		return defense
	if _now_seconds() > float(target.get_meta("acid_boss_defense_reduction_until", 0.0)):
		return defense
	return maxf(defense - maxf(float(target.get_meta("acid_boss_defense_reduction", 0.0)), 0.0), 0.0)


## 作用：在熔岩防护未过期且目标仍处于区域时返回承伤系数。
## 使用：从上下文取目标，未生效返回1。
static func protective_lava_player_multiplier(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	if target == null:
		return 1.0
	var until_time: float = float(target.get_meta("protective_lava_reduction_until", 0.0))
	if until_time <= _now_seconds():
		return 1.0
	if not _target_inside_protective_lava(target):
		return 1.0
	return maxf(1.0 + float(target.get_meta("protective_lava_damage_taken_multiplier_add", 0.0)), 0.0)


## 作用：合并接触专用圣盾减伤和圣盾破裂后的临时减伤。
## 使用：接触部分仅 source_type=contact 生效，返回非负倍率。
static func holy_shield_player_multiplier(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	if target == null:
		return 1.0
	var now_seconds: float = _now_seconds()
	var multiplier_add: float = 0.0
	if String(calculation_context.call("packet_value", "source_type", "")) == "contact":
		var contact_until: float = float(target.get_meta("holy_shield_contact_reduction_until", 0.0))
		if contact_until > now_seconds:
			multiplier_add += float(target.get_meta("holy_shield_contact_damage_taken_multiplier_add", 0.0))
	var break_until: float = float(target.get_meta("holy_shield_break_reduction_until", 0.0))
	if break_until > now_seconds:
		multiplier_add += float(target.get_meta("holy_shield_break_damage_taken_multiplier_add", 0.0))
	return maxf(1.0 + multiplier_add, 0.0)


## 作用：读取未过期的遗物场地承伤倍率。
## 使用：过期或空目标返回1。
static func cross_relic_field_player_multiplier(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	if target == null:
		return 1.0
	var until_time: float = float(target.get_meta("cross_relic_field_reduction_until", 0.0))
	if until_time <= _now_seconds():
		return 1.0
	return maxf(1.0 + float(target.get_meta("cross_relic_field_damage_taken_multiplier_add", 0.0)), 0.0)


## 作用：读取攻击者未过期的毒瓶减攻系数。
## 使用：优先上下文攻击者，缺失从包取；返回非负倍率。
static func toxic_vial_enemy_damage_multiplier(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	if attacker == null:
		attacker = calculation_context.call("packet_value", "attacker", null) as Node
	if attacker == null:
		return 1.0
	var until_time: float = float(attacker.get_meta("toxic_vial_enemy_damage_down_until", 0.0))
	if until_time <= _now_seconds():
		return 1.0
	return maxf(1.0 + float(attacker.get_meta("toxic_vial_enemy_damage_multiplier_add", 0.0)), 0.0)


## 作用：读取攻击者未过期的火油烟雾减攻系数。
## 使用：无有效攻击者/已过期返回1。
static func fire_oil_smoke_enemy_damage_multiplier(calculation_context: RefCounted) -> float:
	var attacker: Node = calculation_context.get("attacker") as Node
	if attacker == null:
		attacker = calculation_context.call("packet_value", "attacker", null) as Node
	if attacker == null:
		return 1.0
	var until_time: float = float(attacker.get_meta("fire_oil_smoke_enemy_damage_down_until", 0.0))
	if until_time <= _now_seconds():
		return 1.0
	return maxf(1.0 + float(attacker.get_meta("fire_oil_smoke_enemy_damage_multiplier_add", 0.0)), 0.0)


## 作用：检查目标到防护中心的距离是否不超过半径。
## 使用：非二维节点或缺少空间元数据时按仍在区域处理。
static func _target_inside_protective_lava(target: Node) -> bool:
	if not (target is Node2D):
		return true
	var center_variant: Variant = target.get_meta("protective_lava_center", null)
	if not (center_variant is Vector2):
		return true
	var radius: float = maxf(float(target.get_meta("protective_lava_radius", 0.0)), 0.0)
	if radius <= 0.0:
		return true
	var target_2d: Node2D = target as Node2D
	return target_2d.global_position.distance_to(center_variant) <= radius


## 作用：将引擎毫秒时钟换算为秒。
## 使用：供运行时到期和冷却时间比较使用，不代表游戏内累计时间。
static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
