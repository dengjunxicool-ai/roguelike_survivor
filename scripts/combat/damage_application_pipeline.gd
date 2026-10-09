## 文件用途：按固定受击顺序编排玩家与敌人的检查、护盾、计算、协同和扣血阶段。
## 使用方式：从 DamageApplicationService 进入；非法包必须先拒绝，任一阶段设置结果后立即终止。
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


## 作用：检查包和目标，按玩家/敌人选择管线，其余可受击对象委托 take_damage。
## 使用：返回应用结果；委托路径没有统一伤害量回读，amount 为0。
static func apply(calculation_context: RefCounted) -> RefCounted:
	if _invalid_packet(calculation_context):
		return DamageApplicationResultScript.make(false, 0, {}, &"invalid_packet")
	var target: Node = calculation_context.get("target") as Node
	if target == null:
		return DamageApplicationResultScript.make(false, 0, {}, &"missing_target")
	if target.is_in_group(&"player"):
		return apply_player(calculation_context)
	if target.has_method("_apply_damage_synergies") or target.has_method("is_dead"):
		return apply_enemy(calculation_context)
	if target.has_method("take_damage"):
		target.call("take_damage", calculation_context.get("packet"))
		return DamageApplicationResultScript.make(true, 0, {}, &"delegated")
	return DamageApplicationResultScript.make(false, 0, {}, &"unsupported_target")


## 作用：执行玩家预检查、吸收、计算、Boss重叠保护和生命应用阶段。
## 使用：上下文必须绑定玩家节点及严格包；返回第一个终止结果。
static func apply_player(calculation_context: RefCounted) -> RefCounted:
	return _run_stages(calculation_context, _player_stages())


## 作用：执行敌人死亡检查、计算、协同、Boss核心保护和生命应用阶段。
## 使用：上下文必须绑定敌人节点及严格包；阶段顺序影响副作用。
static func apply_enemy(calculation_context: RefCounted) -> RefCounted:
	return _run_stages(calculation_context, _enemy_stages())


## 作用：创建阶段可使用的统一应用结果。
## 使用：深复制 damage_result；reason 记录终止原因。
static func make_result(applied: bool, amount: int, damage_result: Dictionary = {}, reason: StringName = &"") -> RefCounted:
	return DamageApplicationResultScript.make(applied, amount, damage_result, reason)


## 作用：验证包后顺序调用阶段，共享上下文并在结果产生后短路。
## 使用：stages 为阶段实例数组；未产生结果返回 no_result。
static func _run_stages(application_context: RefCounted, stages: Array) -> RefCounted:
	if _invalid_packet(application_context):
		return DamageApplicationResultScript.make(false, 0, {}, &"invalid_packet")
	for stage: RefCounted in stages:
		stage.call("apply_with_host", load("res://scripts/combat/damage_application_pipeline.gd"), application_context)
		if bool(application_context.call("has_result")):
			return application_context.get("result_object")
	return DamageApplicationResultScript.make(false, 0, application_context.get("damage_result"), &"no_result")


## 作用：创建按预检查、吸收、计算、重叠保护、扣血排列的玩家阶段实例。
## 使用：每次返回新数组与新阶段，避免共享阶段状态。
static func _player_stages() -> Array[RefCounted]:
	return [
		PlayerPrecheckApplicationStageScript.new(),
		PlayerAbsorbApplicationStageScript.new(),
		PlayerCalculationApplicationStageScript.new(),
		PlayerBossOverlapApplicationStageScript.new(),
		PlayerHealthApplicationStageScript.new()
	]


## 作用：创建按预检查、计算、协同、核心保护、扣血排列的敌人阶段实例。
## 使用：每次返回新数组，供应用和顺序诊断共用。
static func _enemy_stages() -> Array[RefCounted]:
	return [
		EnemyPrecheckApplicationStageScript.new(),
		EnemyCalculationApplicationStageScript.new(),
		EnemySynergyApplicationStageScript.new(),
		EnemyBossCoreApplicationStageScript.new(),
		EnemyHealthApplicationStageScript.new()
	]


## 作用：返回玩家应用阶段的执行名称顺序。
## 使用：供验证与诊断检查受击契约。
static func player_stage_names() -> Array[StringName]:
	return _stage_names(_player_stages())


## 作用：返回敌人应用阶段的执行名称顺序。
## 使用：供验证与诊断检查死亡前副作用顺序。
static func enemy_stage_names() -> Array[StringName]:
	return _stage_names(_enemy_stages())


## 作用：从阶段对象读取 stage_name 并生成 StringName 列表。
## 使用：保留 stages 的执行顺序。
static func _stage_names(stages: Array[RefCounted]) -> Array[StringName]:
	var names: Array[StringName] = []
	for stage: RefCounted in stages:
		names.append(StringName(String(stage.get("stage_name"))))
	return names


## 作用：读取 typed 包伤害量并转为整数。
## 使用：供玩家吸收前检查使用，不计算防御或倍率。
static func packet_amount(packet: DamagePacket) -> int:
	return int(packet.amount)

## 作用：克隆包并将 amount 与 raw_amount 同步为调整后伤害量。
## 使用：用于吸收后的入伤计算；原包不改，原始解析错误继续保留。
static func packet_with_amount(packet: DamagePacket, amount: int) -> DamagePacket:
	var adjusted: DamagePacket = packet.clone()
	adjusted.amount = amount
	adjusted.raw_amount = amount
	return adjusted



## 作用：校验上下文的包并对缺失或非法输入输出警告。
## 使用：返回 true 表示必须停止，调用必须先于任何受击副作用。
static func _invalid_packet(context: RefCounted) -> bool:
	var packet: DamagePacket = context.get("packet")
	var errors: Array[String] = packet.validate() if packet != null else ["packet is required"]
	if errors.is_empty():
		return false
	push_warning("Invalid DamagePacket: " + "; ".join(errors))
	return true
