## 文件用途：提供可关闭、警告或报错的伤害包诊断，识别缺字段、不稳定小数来源和反应递归风险。
## 使用方式：作为严格 DamagePacket.validate 之外的开发期诊断，由准备阶段调用。
extends RefCounted
class_name DamagePacketValidator


const DamageRuleRegistryScript: Script = preload("res://scripts/combat/damage_rule_registry.gd")

const MODE_DISABLED: String = "disabled"
const MODE_WARNING: String = "warning"
const MODE_ERROR: String = "error"
static var validation_mode: String = MODE_WARNING

const REQUIRED_PACKET_FIELDS: Array[String] = [
	"raw_amount",
	"damage_origin",
	"damage_type",
	"element",
	"source_origin_id",
	"source_skill_id",
	"source_instance_id",
	"attacker_id",
	"target_id",
	"can_crit",
	"can_trigger_reaction",
	"reaction_depth",
	"uses_character_damage_multiplier",
	"uses_skill_level_coefficient",
	"ignore_defense",
	"ignore_resistance",
	"ignore_vulnerability",
	"ignore_min_damage",
	"special_rule_tags"
]


## 作用：检查字典包必需字段及小数来源、递归、敌人缩放和来源身份。
## 使用：禁用模式无操作；其余按warning/error模式输出诊断，不改变包。
static func validate(packet: Dictionary, target: Node = null) -> void:
	if validation_mode == MODE_DISABLED:
		return
	for key: String in REQUIRED_PACKET_FIELDS:
		if not packet.has(key):
			_report("DamagePacket missing required field: %s." % key)

	_warn_unstable_fractional_source(packet)
	_warn_reaction_recursion_risk(packet)
	_warn_enemy_packet_scaling(packet)
	_warn_missing_source_identity(packet, target)


## 作用：按诊断模式检查 typed 包的严格错误与所需来源/规则字段。
## 使用：禁用模式立即返回；target 仅用于诊断消息。
static func validate_packet(packet: DamagePacket, target: Node = null) -> void:
	if validation_mode == MODE_DISABLED:
		return
	for error: String in packet.validate():
		_report(error)
	_validate_packet_object(packet, target)

## 作用：从计算上下文检查必需字段及小数来源、递归、敌人缩放与来源身份。
## 使用：调用方已创建 DamageCalculationContext；报告级别由 validation_mode 决定。
static func validate_for_context(calculation_context: DamageCalculationContext, target: Node = null) -> void:
	if validation_mode == MODE_DISABLED:
		return
	for key: String in REQUIRED_PACKET_FIELDS:
		if not bool(calculation_context.call("packet_has", key)):
			_report("DamagePacket missing required field: %s." % key)

	_warn_unstable_fractional_source_for_context(calculation_context)
	_warn_reaction_recursion_risk_for_context(calculation_context)
	_warn_enemy_packet_scaling_for_context(calculation_context)
	_warn_missing_source_identity_for_context(calculation_context, target)


## 作用：通过包字段访问接口执行来源和规则诊断。
## 使用：由 validate_packet 使用，不更改包。
static func _validate_packet_object(packet_object: DamagePacket, target: Node = null) -> void:
	for key: String in REQUIRED_PACKET_FIELDS:
		if not bool(packet_object.call("has_value", key)):
			_report("DamagePacket missing required field: %s." % key)

	_warn_unstable_fractional_source_for_packet_object(packet_object)
	_warn_reaction_recursion_risk_for_packet_object(packet_object)
	_warn_enemy_packet_scaling_for_packet_object(packet_object)
	_warn_missing_source_identity_for_packet_object(packet_object, target)


## 作用：使用小数缓冲时检查稳定 source_instance_id，缺失时报告问题。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_unstable_fractional_source(packet: Dictionary) -> void:
	if not DamageRuleRegistryScript.uses_fractional_buffer(packet):
		return

	var source_instance_id: String = String(packet.get("source_instance_id", ""))
	if source_instance_id == "":
		_report("Fractional damage requires a stable source_instance_id.")


## 作用：使用小数缓冲时检查稳定 source_instance_id，缺失时报告问题。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_unstable_fractional_source_for_context(calculation_context: DamageCalculationContext) -> void:
	if not DamageRuleRegistryScript.uses_fractional_buffer_for_context(calculation_context):
		return

	var source_instance_id: String = String(calculation_context.call("packet_value", "source_instance_id", ""))
	if source_instance_id == "":
		_report("Fractional damage requires a stable source_instance_id.")


## 作用：使用小数缓冲时检查稳定 source_instance_id，缺失时报告问题。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_unstable_fractional_source_for_packet_object(packet_object: DamagePacket) -> void:
	if not DamageRuleRegistryScript.uses_fractional_buffer_for_packet_object(packet_object):
		return

	var source_instance_id: String = String(packet_object.call("get_value", "source_instance_id", ""))
	if source_instance_id == "":
		_report("Fractional damage requires a stable source_instance_id.")


## 作用：检查反应来源或已有反应深度是否仍允许触发新反应，报告递归风险。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_reaction_recursion_risk(packet: Dictionary) -> void:
	var origin: String = String(packet.get("damage_origin", ""))
	var reaction_depth: int = int(packet.get("reaction_depth", 0))
	if origin == "reaction" and bool(packet.get("can_trigger_reaction", false)):
		_report("Reaction damage should set can_trigger_reaction=false.")
	if reaction_depth > 0 and bool(packet.get("can_trigger_reaction", false)):
		_report("Nested reaction packet should not trigger another reaction.")


## 作用：检查反应来源或已有反应深度是否仍允许触发新反应，报告递归风险。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_reaction_recursion_risk_for_context(calculation_context: DamageCalculationContext) -> void:
	var origin: String = String(calculation_context.call("packet_value", "damage_origin", ""))
	var reaction_depth: int = int(calculation_context.call("packet_value", "reaction_depth", 0))
	var can_trigger_reaction: bool = bool(calculation_context.call("packet_value", "can_trigger_reaction", false))
	if origin == "reaction" and can_trigger_reaction:
		_report("Reaction damage should set can_trigger_reaction=false.")
	if reaction_depth > 0 and can_trigger_reaction:
		_report("Nested reaction packet should not trigger another reaction.")


## 作用：检查反应来源或已有反应深度是否仍允许触发新反应，报告递归风险。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_reaction_recursion_risk_for_packet_object(packet_object: DamagePacket) -> void:
	var origin: String = String(packet_object.call("get_value", "damage_origin", ""))
	var reaction_depth: int = int(packet_object.call("get_value", "reaction_depth", 0))
	var can_trigger_reaction: bool = bool(packet_object.call("get_value", "can_trigger_reaction", false))
	if origin == "reaction" and can_trigger_reaction:
		_report("Reaction damage should set can_trigger_reaction=false.")
	if reaction_depth > 0 and can_trigger_reaction:
		_report("Nested reaction packet should not trigger another reaction.")


## 作用：检查敌人攻击者的包是否错误启用玩家角色伤害倍率。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_enemy_packet_scaling(packet: Dictionary) -> void:
	var attacker: Node = packet.get("attacker") as Node
	if attacker == null:
		return
	if not attacker.is_in_group(&"enemies") and not attacker.is_in_group(&"enemy"):
		return
	if bool(packet.get("uses_character_damage_multiplier", false)):
		_report("Enemy damage packet should not use player character damage multiplier.")


## 作用：检查敌人攻击者的包是否错误启用玩家角色伤害倍率。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_enemy_packet_scaling_for_context(calculation_context: DamageCalculationContext) -> void:
	var attacker: Node = calculation_context.call("packet_value", "attacker", null) as Node
	if attacker == null:
		return
	if not attacker.is_in_group(&"enemies") and not attacker.is_in_group(&"enemy"):
		return
	if bool(calculation_context.call("packet_value", "uses_character_damage_multiplier", false)):
		_report("Enemy damage packet should not use player character damage multiplier.")


## 作用：检查敌人攻击者的包是否错误启用玩家角色伤害倍率。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_enemy_packet_scaling_for_packet_object(packet_object: DamagePacket) -> void:
	var attacker: Node = packet_object.call("get_value", "attacker", null) as Node
	if attacker == null:
		return
	if not attacker.is_in_group(&"enemies") and not attacker.is_in_group(&"enemy"):
		return
	if bool(packet_object.call("get_value", "uses_character_damage_multiplier", false)):
		_report("Enemy damage packet should not use player character damage multiplier.")


## 作用：检查技能来源与原始来源ID是否同时缺失并报告目标ID。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_missing_source_identity(packet: Dictionary, target: Node) -> void:
	var source_skill_id: String = String(packet.get("source_skill_id", ""))
	var source_origin_id: String = String(packet.get("source_origin_id", ""))
	if source_skill_id == "" and source_origin_id == "":
		var target_id: String = str(target.get_instance_id()) if target != null else String(packet.get("target_id", ""))
		_report("DamagePacket has no source_skill_id or source_origin_id. target=%s" % target_id)


## 作用：检查技能来源与原始来源ID是否同时缺失并报告目标ID。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_missing_source_identity_for_context(calculation_context: DamageCalculationContext, target: Node) -> void:
	var source_skill_id: String = String(calculation_context.call("packet_value", "source_skill_id", ""))
	var source_origin_id: String = String(calculation_context.call("packet_value", "source_origin_id", ""))
	if source_skill_id == "" and source_origin_id == "":
		var target_id: String = str(target.get_instance_id()) if target != null else String(calculation_context.call("packet_value", "target_id", ""))
		_report("DamagePacket has no source_skill_id or source_origin_id. target=%s" % target_id)


## 作用：检查技能来源与原始来源ID是否同时缺失并报告目标ID。
## 使用：从对应字典、计算上下文或 typed 包读取；仅输出诊断，不修正输入。
static func _warn_missing_source_identity_for_packet_object(packet_object: DamagePacket, target: Node) -> void:
	var source_skill_id: String = String(packet_object.call("get_value", "source_skill_id", ""))
	var source_origin_id: String = String(packet_object.call("get_value", "source_origin_id", ""))
	if source_skill_id == "" and source_origin_id == "":
		var target_id: String = str(target.get_instance_id()) if target != null else String(packet_object.call("get_value", "target_id", ""))
		_report("DamagePacket has no source_skill_id or source_origin_id. target=%s" % target_id)


## 作用：按诊断模式输出错误或警告消息。
## 使用：message 为校验问题，MODE_ERROR 用 push_error，其余用 push_warning。
static func _report(message: String) -> void:
	if validation_mode == MODE_ERROR:
		push_error("[DamagePacketValidator] %s" % message)
	else:
		push_warning("[DamagePacketValidator] %s" % message)

