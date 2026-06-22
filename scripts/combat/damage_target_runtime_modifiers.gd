extends RefCounted
class_name DamageTargetRuntimeModifiers


static func acid_boss_defense(target: Node, defense: float) -> float:
	if target == null:
		return defense
	if _now_seconds() > float(target.get_meta("acid_boss_defense_reduction_until", 0.0)):
		return defense
	return maxf(defense - maxf(float(target.get_meta("acid_boss_defense_reduction", 0.0)), 0.0), 0.0)


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


static func cross_relic_field_player_multiplier(calculation_context: RefCounted) -> float:
	var target: Node = calculation_context.get("target") as Node
	if target == null:
		return 1.0
	var until_time: float = float(target.get_meta("cross_relic_field_reduction_until", 0.0))
	if until_time <= _now_seconds():
		return 1.0
	return maxf(1.0 + float(target.get_meta("cross_relic_field_damage_taken_multiplier_add", 0.0)), 0.0)


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


static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
