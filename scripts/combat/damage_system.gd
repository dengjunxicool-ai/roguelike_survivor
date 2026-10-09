## 文件用途：统一计算typed伤害包，按玩家、百分比真伤或普通伤害选择固定公式管线。
## 使用方式：静态 calculate(packet,target)返回 DamageResult；计算不扣血，由应用管线执行受击副作用。
extends RefCounted
class_name DamageSystem


const DamageRoundingServiceScript: Script = preload("res://scripts/combat/damage_rounding_service.gd")
const DamageCalculationContextScript: Script = preload("res://scripts/combat/damage_calculation_context.gd")
const DamagePacketPreparationScript: Script = preload("res://scripts/combat/damage_packet_preparation.gd")
const DamageResultScript: Script = preload("res://scripts/combat/damage_result.gd")
const DamageStageScript: Script = preload("res://scripts/combat/damage_stage.gd")
const DamagePipelineScript: Script = preload("res://scripts/combat/damage_pipeline.gd")
const OutgoingDamageStageScript: Script = preload("res://scripts/combat/stages/outgoing_damage_stage.gd")
const CriticalDamageStageScript: Script = preload("res://scripts/combat/stages/critical_damage_stage.gd")
const DefenseDamageStageScript: Script = preload("res://scripts/combat/stages/defense_damage_stage.gd")
const ResistanceDamageStageScript: Script = preload("res://scripts/combat/stages/resistance_damage_stage.gd")
const VulnerabilityDamageStageScript: Script = preload("res://scripts/combat/stages/vulnerability_damage_stage.gd")
const SpecialFinalDamageStageScript: Script = preload("res://scripts/combat/stages/special_final_damage_stage.gd")
const RoundingDamageStageScript: Script = preload("res://scripts/combat/stages/rounding_damage_stage.gd")
const TruePercentDamageStageScript: Script = preload("res://scripts/combat/stages/true_percent_damage_stage.gd")
const TruePercentCapStageScript: Script = preload("res://scripts/combat/stages/true_percent_cap_stage.gd")
const PlayerIncomingModifierStageScript: Script = preload("res://scripts/combat/stages/player_incoming_modifier_stage.gd")
const PlayerDefenseStageScript: Script = preload("res://scripts/combat/stages/player_defense_stage.gd")
const PlayerReductionStageScript: Script = preload("res://scripts/combat/stages/player_reduction_stage.gd")
const PlayerDamageTakenStageScript: Script = preload("res://scripts/combat/stages/player_damage_taken_stage.gd")
const PlayerRoundingStageScript: Script = preload("res://scripts/combat/stages/player_rounding_stage.gd")
const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")
const TargetDamageProfileResolverScript: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const DamageTargetMitigationScript: Script = preload("res://scripts/combat/damage_target_mitigation.gd")
const DamageOutputScalingScript: Script = preload("res://scripts/combat/damage_output_scaling.gd")
const DamageCriticalResolverScript: Script = preload("res://scripts/combat/damage_critical_resolver.gd")
const DamageSpecialFinalResolverScript: Script = preload("res://scripts/combat/damage_special_final_resolver.gd")
const DamagePlayerIncomingResolverScript: Script = preload("res://scripts/combat/damage_player_incoming_resolver.gd")
const DamageDefenseResolverScript: Script = preload("res://scripts/combat/damage_defense_resolver.gd")
const DamageTruePercentResolverScript: Script = preload("res://scripts/combat/damage_true_percent_resolver.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageModifierQueryScript: Script = preload("res://scripts/modifiers/damage_modifier_query.gd")

const ELEMENT_NAMES: Array[String] = ["physical", "fire", "ice", "lightning", "poison", "holy", "acid", "arcane", "neutral"]
const ORIGIN_PRIMARY_ATTACK: String = "primary_attack"
const ORIGIN_STATUS_DOT: String = "status_dot"
const ORIGIN_REACTION: String = "reaction"
const ORIGIN_FIELD: String = "field"
const ORIGIN_TRAP: String = "trap"
const ORIGIN_SPECIAL: String = "special"
const TYPE_DIRECT_PHYSICAL: String = "direct_physical"
const TYPE_DIRECT_MAGICAL: String = "direct_magical"
const TYPE_PROJECTILE_SMALL: String = "projectile_small"
const TYPE_PROJECTILE_HEAVY: String = "projectile_heavy"
const TYPE_AREA_DIRECT: String = "area_direct"
const TYPE_STATUS_DOT: String = "status_dot"
const TYPE_REACTION_DAMAGE: String = "reaction_damage"
const TYPE_TRAP_DAMAGE: String = "trap_damage"
const TYPE_SUMMON_DAMAGE: String = "summon_damage"
const TYPE_TRUE_DAMAGE: String = "true_damage"
const TYPE_TRUE_PERCENT_DAMAGE: String = "true_percent_damage"
## 作用：校验并克隆包、创建上下文，计算后返回typed结果。
## 使用：非法输入返回零结果；target为受击节点，生命变更由应用服务负责。
static func calculate(packet: DamagePacket, target: Node) -> DamageResult:
	var calculation_context: RefCounted = _create_calculation_context(packet, target)
	if calculation_context == null:
		return DamageResultScript.make(packet, 0, false, 0.0, 1.0, {}) as DamageResult
	_calculate_context(calculation_context)
	return calculation_context.get("result_object") as DamageResult



## 作用：根据原始伤害量和目标/类型分派零值、玩家、百分比真伤或普通管线。
## 使用：上下文须由准备阶段创建，返回结果字典并保存对象结果。
static func _calculate_context(calculation_context: RefCounted) -> Dictionary:
	var target: Node = calculation_context.get("target") as Node
	var raw_amount: float = maxf(float(calculation_context.get("raw_amount")), 0.0)
	if raw_amount <= 0.0:
		var zero_result: Dictionary = _result_for_context(calculation_context, 0, false, raw_amount, 1.0, {})
		calculation_context.call("finish", 0, false, 0.0, zero_result)
		return zero_result

	if _is_player_target(target):
		return _calculate_player_incoming(calculation_context)
	if String(calculation_context.call("packet_value", "damage_type", "")) == TYPE_TRUE_PERCENT_DAMAGE:
		return _calculate_true_percent(calculation_context)

	return _calculate_standard_damage(calculation_context)


## 作用：聚合攻击者modifier并按输出、暴击、防御、抗性、易伤、特殊、取整计算。
## 使用：保存阶段顺序、倍率与暴击，返回结果字典。
static func _calculate_standard_damage(calculation_context: DamageCalculationContext) -> Dictionary:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var source_attacker: Node = calculation_context.call("packet_value", "attacker", calculation_context.get("attacker")) as Node
	calculation_context.set("attacker", source_attacker)
	var damage_modifiers: Dictionary = _get_attacker_damage_modifiers_for_context(calculation_context)
	calculation_context.set("damage_modifiers", damage_modifiers)
	var stages: Dictionary = calculation_context.get("stages")
	calculation_context.call("set_stage_order", [
		"raw_amount",
		"outgoing",
		"critical",
		"defense",
		"resistance",
		"vulnerability",
		"special",
		"rounding"
	])
	var pipeline: RefCounted = _standard_damage_pipeline()
	var final_amount: int = int(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, raw_amount))
	var after_special: float = float(stages.get("after_special", final_amount))
	var critical: bool = bool(calculation_context.get("critical"))
	var result: Dictionary = _result_for_context(calculation_context, final_amount, critical, raw_amount, after_special / raw_amount if raw_amount > 0.0 else 1.0, stages)
	calculation_context.call("finish", final_amount, critical, after_special, result)
	return result


## 作用：创建普通伤害的七个有序阶段。
## 使用：返回新管线，顺序不可随意更改。
static func _standard_damage_pipeline() -> RefCounted:
	return DamagePipelineScript.create([
		OutgoingDamageStageScript.new(),
		CriticalDamageStageScript.new(),
		DefenseDamageStageScript.new(),
		ResistanceDamageStageScript.new(),
		VulnerabilityDamageStageScript.new(),
		SpecialFinalDamageStageScript.new(),
		RoundingDamageStageScript.new()
	])


## 作用：把通用阶段调用转为原始输出倍率计算。
## 使用：忽略上一输入，使用上下文raw_amount。
static func _standard_outgoing_pipeline_stage(calculation_context: RefCounted, _input_value: Variant) -> Variant:
	return _apply_outgoing_stage(calculation_context)


## 作用：计算暴击并同步上下文critical标记。
## 使用：返回暴击后减伤前伤害。
static func _standard_critical_pipeline_stage(calculation_context: RefCounted, input_value: Variant) -> Variant:
	var critical_result: Dictionary = _apply_critical_stage(calculation_context, float(input_value))
	calculation_context.set("critical", bool(critical_result.get("is_critical", false)))
	return float(critical_result.get("pre_mitigation", input_value))


## 作用：将阶段浮点输入交给统一取整。
## 使用：返回可应用的整数伤害。
static func _standard_rounding_pipeline_stage(calculation_context: RefCounted, input_value: Variant) -> Variant:
	return _apply_rounding_stage(calculation_context, float(input_value))


## 作用：依次乘角色、等级、来源、元素、目标阶级和承伤倍率并逐项记录。
## 使用：输入来自上下文raw_amount；目标来源系数可能消耗韧性窗口。
static func _apply_outgoing_stage(calculation_context: RefCounted) -> float:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	var outgoing: float = raw_amount
	var character_multiplier: float = _get_character_damage_multiplier_for_context(calculation_context)
	var skill_level_coefficient: float = _get_skill_level_coefficient_for_context(calculation_context)
	var origin_bonus_total: float = _get_origin_bonus_total_for_context(calculation_context)
	var origin_multiplier: float = maxf(1.0 + origin_bonus_total, 0.0)
	var element_bonus_total: float = _get_element_bonus_total_for_context(calculation_context)
	var element_multiplier: float = maxf(1.0 + element_bonus_total, 0.0)
	var enemy_type_bonus_total: float = _get_enemy_type_bonus_total_for_context(calculation_context)
	var enemy_type_multiplier: float = maxf(1.0 + enemy_type_bonus_total, 0.0)
	var target_class_modifier: float = DamageTargetMitigationScript.target_class_origin_modifier_for_context(calculation_context)
	stages["raw_amount"] = raw_amount
	stages["character_damage_multiplier"] = character_multiplier
	stages["skill_level_coefficient"] = skill_level_coefficient
	stages["origin_bonus_total"] = origin_bonus_total
	stages["origin_multiplier"] = origin_multiplier
	stages["element_bonus_total"] = element_bonus_total
	stages["element_multiplier"] = element_multiplier
	stages["enemy_type_bonus_total"] = enemy_type_bonus_total
	stages["enemy_type_multiplier"] = enemy_type_multiplier
	stages["target_class_origin_modifier"] = target_class_modifier
	outgoing *= character_multiplier
	outgoing *= skill_level_coefficient
	outgoing *= origin_multiplier
	outgoing *= element_multiplier
	outgoing *= enemy_type_multiplier
	outgoing *= target_class_modifier
	stages["outgoing_damage"] = outgoing
	return outgoing


## 作用：优先沿用已确定暴击，否则合并攻击者和modifier暴击率随机判定并放大输出。
## 使用：outgoing 为未减伤输出；返回暴击标记、倍率和 pre_mitigation，并写入 stages。 本入口委托DamageCriticalResolverScript.apply_critical_stage执行。
static func _apply_critical_stage(calculation_context: RefCounted, outgoing: float) -> Dictionary:
	return DamageCriticalResolverScript.apply_critical_stage(calculation_context, outgoing)


## 作用：以防御、抗性、易伤、特殊顺序执行减伤子管线。
## 使用：pre_mitigation为暴击后伤害，返回取整前终值。
static func _apply_mitigation_stages(calculation_context: RefCounted, pre_mitigation: float) -> float:
	var pipeline: RefCounted = DamagePipelineScript.create([
		DefenseDamageStageScript.new(),
		ResistanceDamageStageScript.new(),
		VulnerabilityDamageStageScript.new(),
		SpecialFinalDamageStageScript.new()
	])
	return float(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, pre_mitigation))


## 作用：计算防御抵扣并把结果保存为 after_defense。
## 使用：pre_mitigation 为暴击后的浮点伤害，返回非负抵扣结果。 本入口委托DamageDefenseResolverScript.apply_defense_stage执行。
static func _apply_defense_stage(calculation_context: RefCounted, pre_mitigation: float) -> float:
	return DamageDefenseResolverScript.apply_defense_stage(calculation_context, pre_mitigation)


## 作用：未忽略抗性时乘以元素系数并记录 after_resistance。
## 使用：输入防御后伤害，返回浮点值。 本入口委托DamageTargetMitigationScript.apply_resistance_stage执行。
static func _apply_resistance_stage(calculation_context: RefCounted, after_defense: float) -> float:
	return DamageTargetMitigationScript.apply_resistance_stage(calculation_context, after_defense)


## 作用：未忽略易伤时乘以非负的1+易伤总量。
## 使用：输入抗性后伤害并记录 after_vulnerability。 本入口委托DamageTargetMitigationScript.apply_vulnerability_stage执行。
static func _apply_vulnerability_stage(calculation_context: RefCounted, after_resistance: float) -> float:
	return DamageTargetMitigationScript.apply_vulnerability_stage(calculation_context, after_resistance)


## 作用：把受限特殊最终系数乘到易伤后伤害并记录 after_special。
## 使用：返回浮点终值，后续仍需取整。 本入口委托DamageSpecialFinalResolverScript.apply_special_stage执行。
static func _apply_special_stage(calculation_context: RefCounted, after_vulnerability: float) -> float:
	return DamageSpecialFinalResolverScript.apply_special_stage(calculation_context, after_vulnerability)


## 作用：用统一取整服务释放整数伤害并记录rounded_amount。
## 使用：可能更新DOT小数余数，amount为取整前终值。
static func _apply_rounding_stage(calculation_context: RefCounted, amount: float) -> int:
	var stages: Dictionary = calculation_context.get("stages")
	var final_amount: int = DamageRoundingServiceScript.resolve_for_context(amount, calculation_context)
	stages["rounded_amount"] = final_amount
	return final_amount


## 作用：依次计算最大生命百分比、阶级上限和取整并记录结果。
## 使用：此管线不使用普通输出/暴击/减伤阶段。
static func _calculate_true_percent(calculation_context: RefCounted) -> Dictionary:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	calculation_context.call("set_stage_order", ["raw_amount", "true_percent", "cap", "rounding"])
	stages["raw_amount"] = raw_amount
	var pipeline: RefCounted = DamagePipelineScript.create([
		TruePercentDamageStageScript.new(),
		TruePercentCapStageScript.new(),
		RoundingDamageStageScript.new()
	])
	var final_amount: int = int(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, raw_amount))
	var damage: float = float(stages.get("after_special", final_amount))
	var result: Dictionary = _result_for_context(calculation_context, final_amount, false, raw_amount, damage / raw_amount if raw_amount > 0.0 else 1.0, stages)
	calculation_context.call("finish", final_amount, false, damage, result)
	return result


## 作用：委托百分比真伤解析器确定百分比，优先配置百分比再按原始值回退。
## 使用：大于1的输入除以100；记录 percent，返回比例值。 本入口委托DamageTruePercentResolverScript.resolve_true_percent执行。
static func _resolve_true_percent(calculation_context: RefCounted) -> float:
	return DamageTruePercentResolverScript.resolve_true_percent(calculation_context)


## 作用：将最大生命乘以非负百分比并记录原始百分比伤害。
## 使用：max_health 为目标最大生命，返回取上限前的浮点值。 本入口委托DamageTruePercentResolverScript.apply_true_percent_stage执行。
static func _apply_true_percent_stage(calculation_context: RefCounted, max_health: float, percent: float) -> float:
	return DamageTruePercentResolverScript.apply_true_percent_stage(calculation_context, max_health, percent)


## 作用：用包中上限或目标快照默认上限裁剪最大生命百分比伤害。
## 使用：cap 大于0才裁剪；记录上限与 after_special，后续负责取整。 本入口委托DamageTruePercentResolverScript.apply_true_percent_cap_stage执行。
static func _apply_true_percent_cap_stage(calculation_context: RefCounted, damage: float, max_health: float) -> float:
	return DamageTruePercentResolverScript.apply_true_percent_cap_stage(calculation_context, damage, max_health)


## 作用：按临时入伤倍率、护甲、比例减伤、承伤属性和取整处理玩家。
## 使用：保存专用顺序，玩家路径不判暴击。
static func _calculate_player_incoming(calculation_context: RefCounted) -> Dictionary:
	var raw_amount: float = float(calculation_context.get("raw_amount"))
	var stages: Dictionary = calculation_context.get("stages")
	calculation_context.call("set_stage_order", ["raw_amount", "incoming_modifiers", "player_defense", "player_reduction", "damage_taken", "rounding"])
	stages["raw_amount"] = raw_amount
	var pipeline: RefCounted = DamagePipelineScript.create([
		PlayerIncomingModifierStageScript.new(),
		PlayerDefenseStageScript.new(),
		PlayerReductionStageScript.new(),
		PlayerDamageTakenStageScript.new(),
		PlayerRoundingStageScript.new()
	])
	var final_amount: int = int(pipeline.call("execute_with_host", load("res://scripts/combat/damage_system.gd"), calculation_context, raw_amount))
	var after_reduction: float = float(stages.get("after_reduction", final_amount))
	var result: Dictionary = _result_for_context(calculation_context, final_amount, false, raw_amount, after_reduction / raw_amount if raw_amount > 0.0 else 1.0, stages)
	calculation_context.call("finish", final_amount, false, after_reduction, result)
	return result


## 作用：将波次/阶段倍率、熔岩/圣盾/遗物防护与敌人减攻状态乘到原始入伤。
## 使用：读取双方临时元数据，记录生效系数和 incoming_damage。 本入口委托DamagePlayerIncomingResolverScript.apply_player_incoming_modifier_stage执行。
static func _apply_player_incoming_modifier_stage(calculation_context: RefCounted) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_incoming_modifier_stage(calculation_context)


## 作用：用玩家护甲抵扣入伤，并将抵扣上限限制为入伤40%。
## 使用：incoming 为已应用入伤倍率的值；记录护甲与实际抵扣。 本入口委托DamagePlayerIncomingResolverScript.apply_player_defense_stage执行。
static func _apply_player_defense_stage(calculation_context: RefCounted, incoming: float) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_defense_stage(calculation_context, incoming)


## 作用：按包内玩家比例减伤抵扣防御后值，减伤限制在0至95%。
## 使用：返回浮点结果并写入 after_reduction。 本入口委托DamagePlayerIncomingResolverScript.apply_player_reduction_stage执行。
static func _apply_player_reduction_stage(calculation_context: RefCounted, after_defense: float) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_reduction_stage(calculation_context, after_defense)


## 作用：将玩家 damage_taken_multiplier 乘到比例减伤结果。
## 使用：倍率限制为非负，覆盖追踪中的 after_reduction。 本入口委托DamagePlayerIncomingResolverScript.apply_player_damage_taken_stage执行。
static func _apply_player_damage_taken_stage(calculation_context: RefCounted, after_reduction: float) -> float:
	return DamagePlayerIncomingResolverScript.apply_player_damage_taken_stage(calculation_context, after_reduction)


## 作用：将正数玩家入伤四舍五入并至少保留1点，非正数返回0。
## 使用：写入 rounded_amount，作为玩家计算最终阶段。 本入口委托DamagePlayerIncomingResolverScript.apply_player_rounding_stage执行。
static func _apply_player_rounding_stage(calculation_context: RefCounted, after_reduction: float) -> int:
	return DamagePlayerIncomingResolverScript.apply_player_rounding_stage(calculation_context, after_reduction)




## 作用：准备严格包，成功后建立目标/攻击者快照上下文。
## 使用：prepare失败返回null，不能继续公式阶段。
static func _create_calculation_context(packet: DamagePacket, target: Node = null) -> RefCounted:
	var prepared: DamagePacket = DamagePacketPreparationScript.prepare(packet, target)
	if prepared == null:
		return null
	return DamageCalculationContextScript.create(prepared, target, prepared.source_context.attacker)

## 作用：从目标现场防御属性与字典包计算固定抵扣。
## 使用：忽略防御或无有效目标时原值返回；抵扣不超过包/规则规定比例。 本入口委托DamageDefenseResolverScript.apply_defense执行。
static func _apply_defense(pre_mitigation: float, packet: Dictionary, target: Node) -> float:
	return DamageDefenseResolverScript.apply_defense(pre_mitigation, packet, target)


## 作用：使用已解析目标快照及包字段计算防御抵扣。
## 使用：读取酸系Boss临时减防与反应限制，返回抵扣后的浮点伤害。 本入口委托DamageDefenseResolverScript.apply_defense_for_context执行。
static func _apply_defense_for_context(calculation_context: RefCounted, pre_mitigation: float) -> float:
	return DamageDefenseResolverScript.apply_defense_for_context(calculation_context, pre_mitigation)


## 作用：查询伤害类型使用的防御权重。
## 使用：来源为 DamageRuleRegistry，零权重表示不做固定防御抵扣。 本入口委托DamageDefenseResolverScript.defense_rate执行。
static func _get_defense_rate(damage_type: String) -> float:
	return DamageDefenseResolverScript.defense_rate(damage_type)


## 作用：从目标快照计算元素承伤系数。
## 使用：neutral或空目标返回1；抗性限制在-75%至90%。 本入口委托DamageTargetMitigationScript.resistance_multiplier执行。
static func _get_resistance_multiplier(target: Node, element: String) -> float:
	return DamageTargetMitigationScript.resistance_multiplier(target, element)


## 作用：使用上下文目标快照计算元素抗性系数。
## 使用：不重新解析目标，neutral返回1。 本入口委托DamageTargetMitigationScript.resistance_multiplier_for_context执行。
static func _get_resistance_multiplier_for_context(calculation_context: RefCounted) -> float:
	return DamageTargetMitigationScript.resistance_multiplier_for_context(calculation_context)


## 作用：累加包、状态管理器和目标承伤倍率后按阶级裁剪易伤。
## 使用：支持状态管理器的易伤接口或倍率接口；返回加法总量。 本入口委托DamageTargetMitigationScript.vulnerability_total执行。
static func _get_vulnerability_total(target: Node, packet: Dictionary) -> float:
	return DamageTargetMitigationScript.vulnerability_total(target, packet)


## 作用：用上下文合并易伤并加入攻击者对受控目标的modifier。
## 使用：返回按快照上下限裁剪的加法总量。 本入口委托DamageTargetMitigationScript.vulnerability_total_for_context执行。
static func _get_vulnerability_total_for_context(calculation_context: RefCounted) -> float:
	return DamageTargetMitigationScript.vulnerability_total_for_context(calculation_context)


## 作用：查目标来源承伤系数并尝试消耗Boss重大反应韧性奖励。
## 使用：ignore开关返回1；此查询可能清除韧性奖励窗口。 本入口委托DamageTargetMitigationScript.target_class_origin_modifier执行。
static func _get_target_class_origin_modifier(packet: Dictionary, target: Node) -> float:
	return DamageTargetMitigationScript.target_class_origin_modifier(packet, target)


## 作用：用目标快照查询来源系数并消费符合条件的Boss韧性奖励。
## 使用：输出阶段每次伤害只应调用一次。 本入口委托DamageTargetMitigationScript.target_class_origin_modifier_for_context执行。
static func _get_target_class_origin_modifier_for_context(calculation_context: RefCounted) -> float:
	return DamageTargetMitigationScript.target_class_origin_modifier_for_context(calculation_context)


## 作用：通过伤害查询聚合攻击者适用的modifier效果。
## 使用：攻击者为空返回空表。
static func _get_attacker_damage_modifiers(packet: DamagePacket, attacker: Node) -> Dictionary:
	if attacker == null:
		return {}
	return ModifierAggregatorScript.collect(ModifierQueryScript.for_damage(packet, attacker))


## 作用：把包、攻击者与目标快照转换为DamageModifierQuery并聚合。
## 使用：返回当次伤害适用modifier快照，不修改来源效果。
static func _get_attacker_damage_modifiers_for_context(calculation_context: DamageCalculationContext) -> Dictionary:
	if calculation_context.attacker == null:
		return {}
	var damage_query: DamageModifierQuery = DamageModifierQueryScript.make(calculation_context.packet, calculation_context.attacker, calculation_context.target_profile)
	return ModifierAggregatorScript.collect(damage_query.to_modifier_query())


## 作用：按开关优先使用包内倍率，否则合并攻击者属性与modifier倍率和加法。
## 使用：返回非负系数，未启用角色倍率时返回1。 本入口委托DamageOutputScalingScript.character_damage_multiplier执行。
static func _get_character_damage_multiplier(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.character_damage_multiplier(packet, attacker, damage_modifiers)


## 作用：从上下文读取角色倍率开关、攻击者及聚合modifier快照。
## 使用：返回与字典入口一致的输出系数，不刷新modifier。 本入口委托DamageOutputScalingScript.character_damage_multiplier_for_context执行。
static func _get_character_damage_multiplier_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.character_damage_multiplier_for_context(calculation_context)


## 作用：读取启用后的技能等级系数，缺失时警告并返回1。
## 使用：包未启用等级缩放时返回1，显式值限制为非负。 本入口委托DamageOutputScalingScript.skill_level_coefficient执行。
static func _get_skill_level_coefficient(packet: Dictionary) -> float:
	return DamageOutputScalingScript.skill_level_coefficient(packet)


## 作用：从上下文查询技能等级缩放并诊断缺失系数。
## 使用：返回非负倍率，未启用时返回1。 本入口委托DamageOutputScalingScript.skill_level_coefficient_for_context执行。
static func _get_skill_level_coefficient_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.skill_level_coefficient_for_context(calculation_context)


## 作用：累加来源专属键在包、modifier和攻击者中的加成。
## 使用：packet 决定 damage_origin；返回加法总量，调用方再转为1+总量。 本入口委托DamageOutputScalingScript.origin_bonus_total执行。
static func _get_origin_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.origin_bonus_total(packet, attacker, damage_modifiers)


## 作用：使用上下文的来源、攻击者与modifier累加来源伤害加成。
## 使用：返回加法总量，不直接乘以伤害。 本入口委托DamageOutputScalingScript.origin_bonus_total_for_context执行。
static func _get_origin_bonus_total_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.origin_bonus_total_for_context(calculation_context)


## 作用：汇总元素对应键在包、modifier和攻击者中的加成。
## 使用：中性或空元素不读取攻击者元素属性；返回加法总量。 本入口委托DamageOutputScalingScript.element_bonus_total执行。
static func _get_element_bonus_total(packet: Dictionary, attacker: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.element_bonus_total(packet, attacker, damage_modifiers)


## 作用：按上下文元素汇总元素加成。
## 使用：使用 ModifierKeyRegistry 的元素键，返回加法总量。 本入口委托DamageOutputScalingScript.element_bonus_total_for_context执行。
static func _get_element_bonus_total_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.element_bonus_total_for_context(calculation_context)


## 作用：按目标 enemy_rank 选择普通/精英/Boss加成键并累加。
## 使用：target 为受击节点，返回包、modifier和攻击者的加法总量。 本入口委托DamageOutputScalingScript.enemy_type_bonus_total执行。
static func _get_enemy_type_bonus_total(packet: Dictionary, attacker: Node, target: Node, damage_modifiers: Dictionary = {}) -> float:
	return DamageOutputScalingScript.enemy_type_bonus_total(packet, attacker, target, damage_modifiers)


## 作用：依据目标快照分类汇总目标阶级伤害加成。
## 使用：不重新查询目标分类；返回加法总量。 本入口委托DamageOutputScalingScript.enemy_type_bonus_total_for_context执行。
static func _get_enemy_type_bonus_total_for_context(calculation_context: RefCounted) -> float:
	return DamageOutputScalingScript.enemy_type_bonus_total_for_context(calculation_context)


## 作用：根据来源和类型决定是否默认使用角色倍率。
## 使用：真伤、百分比真伤和治疗关闭，其余查询来源策略。 本入口委托DamageRuleRegistryScript.default_uses_character_damage执行。
static func _default_uses_character_damage(origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_uses_character_damage(origin, damage_type)


## 作用：为主攻击类型决定默认暴击，排除持续、反应、陷阱、召唤和真伤。
## 使用：field来源默认关闭，即便区域类型允许显式暴击。 本入口委托DamageRuleRegistryScript.default_can_crit执行。
static func _default_can_crit(origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.default_can_crit(origin, damage_type)


## 作用：按伤害类型与包开关检查能否暴击。
## 使用：真伤、百分比伤害和状态DOT始终不允许。 本入口委托DamageCriticalResolverScript.can_crit执行。
static func _can_crit(packet: Dictionary) -> bool:
	return DamageCriticalResolverScript.can_crit(packet)


## 作用：从计算上下文检查类型与 can_crit 开关。
## 使用：用于公式管线，查询本身不消耗随机数。 本入口委托DamageCriticalResolverScript.can_crit_for_context执行。
static func _can_crit_for_context(calculation_context: RefCounted) -> bool:
	return DamageCriticalResolverScript.can_crit_for_context(calculation_context)


## 作用：组合反应限制倍率并检查特殊倍率来源白名单。
## 使用：未知来源只警告并忽略额外倍率，基础反应倍率仍保留。 本入口委托DamageSpecialFinalResolverScript.special_final_modifier执行。
static func _get_special_final_modifier(packet: Dictionary, target: Node) -> float:
	return DamageSpecialFinalResolverScript.special_final_modifier(packet, target)


## 作用：通过上下文读取特殊最终倍率与来源白名单。
## 使用：返回非负系数，非法来源不会影响基础反应倍率。 本入口委托DamageSpecialFinalResolverScript.special_final_modifier_for_context执行。
static func _get_special_final_modifier_for_context(calculation_context: RefCounted) -> float:
	return DamageSpecialFinalResolverScript.special_final_modifier_for_context(calculation_context)




## 作用：判断来源/类型均登记且类型允许该来源。
## 使用：healing不属于合法伤害组合；返回布尔值。 本入口委托DamageRuleRegistryScript.is_legal_origin_type执行。
static func _is_legal_origin_type(origin: String, damage_type: String) -> bool:
	return DamageRuleRegistryScript.is_legal_origin_type(origin, damage_type)


## 作用：检查目标是否属于player组。
## 使用：空节点返回false，用于选择专用入伤管线。
static func _is_player_target(target: Node) -> bool:
	return target != null and target.is_in_group(&"player")


## 作用：解析目标快照并返回分类字符串。
## 使用：用于规则查询，空目标回退normal。
static func _get_target_class(target: Node) -> String:
	var profile: RefCounted = TargetDamageProfileResolverScript.resolve(target)
	return String(profile.get("target_type"))


## 作用：根据字典包与终值创建结果对象并导出字典。
## 使用：stage数据复制进trace，不影响目标生命。
static func _result(packet: Dictionary, final_amount: int, critical: bool, raw_amount: float, multiplier: float, stages: Dictionary) -> Dictionary:
	var result_object: RefCounted = DamageResultScript.make(packet, final_amount, critical, raw_amount, multiplier, stages)
	return result_object.call("to_dictionary")


## 作用：创建typed结果、保存到上下文并导出字典。
## 使用：供各计算分支结束时统一返回对象和视图。
static func _result_for_context(calculation_context: RefCounted, final_amount: int, critical: bool, raw_amount: float, multiplier: float, stages: Dictionary) -> Dictionary:
	var result_object: RefCounted = DamageResultScript.make_for_context(calculation_context, final_amount, critical, raw_amount, multiplier, stages)
	calculation_context.set("result_object", result_object)
	return result_object.call("to_dictionary")


## 作用：读取对象属性并转为浮点值，缺失对象或属性时使用默认值。
## 使用：object/property/fallback 指定对象、属性名和缺失值，供伤害或配置计算使用。
static func _get_float_property(object: Object, property: String, fallback: float) -> float:
	var value: Variant = _get_property(object, property, fallback)
	if value == null:
		return fallback
	return float(value)


## 作用：读取聚合 modifier 快照中的数值，缺少键时使用默认值。
## 使用：modifiers 是已聚合字典，key 指定属性，fallback 指定中性值。
static func _get_modifier_float(modifiers: Dictionary, key: String, fallback: float) -> float:
	if modifiers.is_empty() or not modifiers.has(key):
		return fallback
	return float(modifiers.get(key, fallback))


## 作用：查找对象属性列表中匹配的属性，找不到时返回默认值。
## 使用：用于可选属性访问，避免对没有该属性的对象直接读取。
static func _get_property(object: Object, property: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property:
			return object.get(property)
	return fallback
