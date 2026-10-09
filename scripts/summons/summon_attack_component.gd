## 文件用途：实现召唤近战、投射物和区域脉冲攻击、冷却与命中状态。
## 使用方式：由SummonController持有并配置；attack使用玩家Power乘damage_scale，严格伤害来源标记为summon。
extends RefCounted
class_name SummonAttackComponent


const DamagePacketScript: Script = preload("res://scripts/combat/damage_packet.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

var attack_type: String = "melee"
var attack_range: float = 48.0
var attack_cooldown: float = 1.2
var damage_type: StringName = &"neutral"
var damage_scale: float = 0.45
var projectile_id: StringName = &""
var pulse_radius: float = 96.0
var pulse_area_id: StringName = &""
var pulse_duration: float = 0.28
var pulse_tick_interval: float = 0.1
var on_hit_effects: Array = []
var _cooldown_remaining: float = 0.0


## 作用：读取攻击模式、距离、冷却、元素、伤害系数、弹体与脉冲配置。
## 使用：复制on_hit_effects并清冷却使首次可攻击。
func setup(config: Dictionary) -> void:
	attack_type = str(config.get("attack_type", attack_type))
	attack_range = maxf(float(config.get("attack_range", attack_range)), 1.0)
	attack_cooldown = maxf(float(config.get("attack_cooldown", attack_cooldown)), 0.05)
	damage_type = StringName(str(config.get("damage_type", damage_type)))
	damage_scale = maxf(float(config.get("damage_scale", damage_scale)), 0.0)
	projectile_id = StringName(str(config.get("projectile_id", projectile_id)))
	pulse_radius = maxf(float(config.get("pulse_radius", config.get("attack_range", pulse_radius))), 1.0)
	pulse_area_id = StringName(str(config.get("pulse_area_id", "")))
	pulse_duration = maxf(float(config.get("pulse_duration", pulse_duration)), 0.05)
	pulse_tick_interval = maxf(float(config.get("pulse_tick_interval", pulse_tick_interval)), 0.05)
	on_hit_effects = _array(config.get("on_hit_effects", []))
	_cooldown_remaining = 0.0


## 作用：递减剩余攻击冷却并下限为0。
## 使用：delta为有效运行秒数。
func tick(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


## 作用：按攻击模式选择pulse_radius或attack_range检查目标距离。
## 使用：双方非空才可返回true。
func is_in_range(summon: Node2D, target: Node2D) -> bool:
	var range: float = pulse_radius if attack_type == "area_pulse" else attack_range
	return summon != null and target != null and summon.global_position.distance_to(target.global_position) <= range


## 作用：判断剩余冷却是否已为0。
## 使用：只查询，不执行攻击。
func can_attack() -> bool:
	return _cooldown_remaining <= 0.0


## 作用：检查冷却与范围后分派弹体/区域/近战，最后重置冷却。
## 使用：area_pulse不重复检查目标距离；返回是否发起，子动作失败仍会消耗冷却。
func attack(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> bool:
	if summon == null or target == null or not can_attack():
		return false
	if attack_type != "area_pulse" and not is_in_range(summon, target):
		return false
	match attack_type:
		"projectile":
			_fire_projectile(summon, target, player_power, context)
		"area_pulse":
			if not _spawn_area_pulse(summon, player_power, context):
				_apply_area_pulse(summon, player_power, context)
		_:
			_apply_melee(summon, target, player_power, context)
	_cooldown_remaining = attack_cooldown
	return true


## 作用：用Power系数取整构造special/summon_damage包并受击，然后施加命中效果。
## 使用：正伤害量且目标支持take_damage才造成伤害，状态效果仍会尝试。
func _apply_melee(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> void:
	var amount: int = maxi(roundi(player_power * damage_scale), 0)
	if amount > 0 and target.has_method("take_damage"):
		var skill_id: StringName = _source_skill_id(context)
		target.call("take_damage", DamagePacketScript.from_dictionary({
			"raw_amount": amount,
			"amount": amount,
			"damage_origin": &"special",
			"damage_type": &"summon_damage",
			"element": damage_type,
			"source_type": "summon",
			"source_origin_id": _source_origin_id(context),
			"source_skill_id": skill_id,
			"source_instance_id": "%s:%s" % [String(skill_id), str(summon.get_instance_id()) if summon != null else "summon"]
		}))
	_apply_on_hit_effects(target)


## 作用：区域场景不能生成时从注册表查询脉冲圆内目标并逐个用近战入口命中。
## 使用：context.target_group决定索引，无死亡目标参与。
func _apply_area_pulse(summon: Node2D, player_power: float, context: Dictionary) -> void:
	if summon == null:
		return
	var target_group: StringName = StringName(str(context.get("target_group", &"enemies")))
	var radius_squared: float = pulse_radius * pulse_radius
	var registry: Node = CombatTargetRegistryScript.get_or_create(summon)
	var targets: Array = registry.call("get_targets_in_radius", summon.global_position, pulse_radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if target.has_method("is_dead") and bool(target.call("is_dead")):
			continue
		if summon.global_position.distance_squared_to(target.global_position) > radius_squared:
			continue
		_apply_melee(summon, target, player_power, context)


## 作用：通过action_executor生成配置的召唤脉冲区域。
## 使用：无执行器/area_id返回false，供调用方回退直接范围伤害。
func _spawn_area_pulse(summon: Node2D, player_power: float, context: Dictionary) -> bool:
	var action_executor: RefCounted = context.get("action_executor") as RefCounted
	if summon == null or action_executor == null or pulse_area_id == &"":
		return false
	var amount: int = maxi(roundi(player_power * damage_scale), 0)
	var area_context: Dictionary = context.duplicate(true)
	area_context["caster"] = summon
	area_context["source"] = summon
	area_context["parent"] = context.get("parent", summon.get_parent())
	area_context["target_group"] = context.get("target_group", &"enemies")
	area_context["power"] = player_power
	var area_params: Dictionary = {
		"area_id": pulse_area_id,
		"position_mode": "caster",
		"radius": pulse_radius,
		"duration": pulse_duration,
		"tick_interval": pulse_tick_interval,
		"damage": amount,
		"damage_type": "summon_damage",
		"element": str(damage_type),
		"damage_origin": "special",
		"source_type": "summon",
		"source_origin_id": _source_origin_id(context),
		"source_skill_id": _source_skill_id(context)
	}
	_apply_pulse_status_params(area_params)
	return bool(action_executor.call("execute_action", {"type": "spawn_area", "params": area_params}, area_context))


## 作用：把第一个apply_status效果转为区域状态参数。
## 使用：area_params原地修改，多项状态只采用首个。
func _apply_pulse_status_params(area_params: Dictionary) -> void:
	for effect_variant: Variant in on_hit_effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if str(effect.get("type", "")) != "apply_status":
			continue
		area_params["status_id"] = str(effect.get("status", effect.get("status_id", "")))
		area_params["stack"] = int(effect.get("stacks", effect.get("stack", 1)))
		area_params["status_duration"] = float(effect.get("duration", 4.0))
		return


## 作用：用动作执行器生成召唤投射物，缺执行器回退近战。
## 使用：context.owner作为caster，summon作为source，默认弹体thunder_arc_bolt。
func _fire_projectile(summon: Node2D, target: Node2D, player_power: float, context: Dictionary) -> void:
	var action_executor: RefCounted = context.get("action_executor") as RefCounted
	if action_executor == null:
		_apply_melee(summon, target, player_power, context)
		return
	var projectile_context: Dictionary = context.duplicate(true)
	projectile_context["caster"] = context.get("owner")
	projectile_context["target"] = target
	projectile_context["source"] = summon
	action_executor.call("execute_action", {
		"type": "spawn_projectile",
		"params": {
			"damage": roundi(player_power * damage_scale),
			"damage_type": "summon_damage",
			"element": str(damage_type),
			"damage_origin": "special",
			"projectile_id": str(projectile_id) if projectile_id != &"" else "thunder_arc_bolt",
			"speed": 420.0,
			"range": attack_range,
			"source_origin_id": _source_origin_id(context),
			"source_skill_id": _source_skill_id(context),
			"on_hit": on_hit_effects
		}
	}, projectile_context)


## 作用：读取上下文source_origin_id并转StringName。
## 使用：缺失返回空ID。
func _source_origin_id(context: Dictionary) -> StringName:
	return StringName(String(context.get("source_origin_id", "")))


## 作用：优先读取skill_id，否则source_skill_id。
## 使用：返回StringName供召唤伤害归因。
func _source_skill_id(context: Dictionary) -> StringName:
	return StringName(String(context.get("skill_id", context.get("source_skill_id", ""))))


## 作用：仅处理配置中的apply_status效果，向目标传层数和时长。
## 使用：target应有效，非状态效果跳过。
func _apply_on_hit_effects(target: Node2D) -> void:
	for effect_variant: Variant in on_hit_effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if str(effect.get("type", "")) == "apply_status" and target.has_method("apply_status"):
			target.call("apply_status", StringName(str(effect.get("status", effect.get("status_id", "")))), {
				"stacks": int(effect.get("stacks", effect.get("stack", 1))),
				"duration": float(effect.get("duration", 4.0))
			})


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回深复制。
func _array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
