extends RefCounted
class_name DamageApplicationPipeline


const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const DamageApplicationResultScript: Script = preload("res://scripts/combat/damage_application_result.gd")
const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const PlayerPrecheckApplicationStageScript: Script = preload("res://scripts/combat/application_stages/player_precheck_application_stage.gd")
const PlayerAbsorbApplicationStageScript: Script = preload("res://scripts/combat/application_stages/player_absorb_application_stage.gd")
const PlayerCalculationApplicationStageScript: Script = preload("res://scripts/combat/application_stages/player_calculation_application_stage.gd")
const PlayerBossOverlapApplicationStageScript: Script = preload("res://scripts/combat/application_stages/player_boss_overlap_application_stage.gd")
const PlayerHealthApplicationStageScript: Script = preload("res://scripts/combat/application_stages/player_health_application_stage.gd")
const EnemyPrecheckApplicationStageScript: Script = preload("res://scripts/combat/application_stages/enemy_precheck_application_stage.gd")
const EnemyCalculationApplicationStageScript: Script = preload("res://scripts/combat/application_stages/enemy_calculation_application_stage.gd")
const EnemySynergyApplicationStageScript: Script = preload("res://scripts/combat/application_stages/enemy_synergy_application_stage.gd")
const EnemyBossCoreApplicationStageScript: Script = preload("res://scripts/combat/application_stages/enemy_boss_core_application_stage.gd")
const EnemyHealthApplicationStageScript: Script = preload("res://scripts/combat/application_stages/enemy_health_application_stage.gd")


static func apply(calculation_context: RefCounted) -> RefCounted:
	var target: Node = calculation_context.get("target") as Node
	if target == null:
		return DamageApplicationResultScript.make(false, 0, {}, &"missing_target")
	if target.is_in_group(&"player"):
		return apply_player(calculation_context)
	if target.has_method("_apply_damage_synergies") or target.has_method("is_dead"):
		return apply_enemy(calculation_context)
	if target.has_method("take_damage"):
		target.call("take_damage", calculation_context.get("amount_or_packet"), calculation_context.get("legacy_damage_type"))
		return DamageApplicationResultScript.make(true, 0, {}, &"delegated")
	return DamageApplicationResultScript.make(false, 0, {}, &"unsupported_target")


static func apply_player(calculation_context: RefCounted) -> RefCounted:
	return _run_stages(calculation_context, _player_stages())


static func apply_enemy(calculation_context: RefCounted) -> RefCounted:
	return _run_stages(calculation_context, _enemy_stages())


static func make_result(applied: bool, amount: int, damage_result: Dictionary = {}, reason: StringName = &"") -> RefCounted:
	return DamageApplicationResultScript.make(applied, amount, damage_result, reason)


static func _run_stages(application_context: RefCounted, stages: Array) -> RefCounted:
	for stage: RefCounted in stages:
		stage.call("apply_with_host", load("res://scripts/combat/damage_application_pipeline.gd"), application_context)
		if bool(application_context.call("has_result")):
			return application_context.get("result_object")
	return DamageApplicationResultScript.make(false, 0, application_context.get("damage_result"), &"no_result")


static func _player_stages() -> Array[RefCounted]:
	return [
		PlayerPrecheckApplicationStageScript.new(),
		PlayerAbsorbApplicationStageScript.new(),
		PlayerCalculationApplicationStageScript.new(),
		PlayerBossOverlapApplicationStageScript.new(),
		PlayerHealthApplicationStageScript.new()
	]


static func _enemy_stages() -> Array[RefCounted]:
	return [
		EnemyPrecheckApplicationStageScript.new(),
		EnemyCalculationApplicationStageScript.new(),
		EnemySynergyApplicationStageScript.new(),
		EnemyBossCoreApplicationStageScript.new(),
		EnemyHealthApplicationStageScript.new()
	]


static func player_stage_names() -> Array[StringName]:
	return _stage_names(_player_stages())


static func enemy_stage_names() -> Array[StringName]:
	return _stage_names(_enemy_stages())


static func _stage_names(stages: Array[RefCounted]) -> Array[StringName]:
	var names: Array[StringName] = []
	for stage: RefCounted in stages:
		names.append(StringName(String(stage.get("stage_name"))))
	return names


static func packet_amount(amount_or_packet: Variant) -> int:
	if amount_or_packet is RefCounted and amount_or_packet.has_method("get_value"):
		return int(amount_or_packet.call("get_value", "amount", amount_or_packet.call("get_value", "damage", amount_or_packet.call("get_value", "raw_amount", 0))))
	if amount_or_packet is Dictionary:
		var packet: Dictionary = amount_or_packet
		return int(packet.get("amount", packet.get("damage", packet.get("raw_amount", 0))))
	return int(amount_or_packet)


static func packet_with_amount(amount_or_packet: Variant, amount: int) -> Variant:
	if amount_or_packet is RefCounted and amount_or_packet.has_method("to_dictionary"):
		var object_packet: Dictionary = amount_or_packet.call("to_dictionary")
		object_packet["amount"] = amount
		object_packet["raw_amount"] = amount
		return DamagePacketScript.from_dictionary(object_packet)
	if amount_or_packet is Dictionary:
		var packet: Dictionary = (amount_or_packet as Dictionary).duplicate(true)
		packet["amount"] = amount
		packet["raw_amount"] = amount
		return packet
	return amount
