## 从最终运行时动作生成可读预览；每次命中为单位，不承诺未知目标数或未来命中。
extends RefCounted
class_name SkillPreviewService
const Definition = preload("res://scripts/skills/skill_definition.gd")
const Instance = preload("res://scripts/skills/skill_instance.gd")
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
const Growth = preload("res://scripts/skills/skill_growth_scaling.gd")
const Profile = preload("res://scripts/skills/skill_growth_profile.gd")
const AreaRuntime = preload("res://scripts/skills/skill_action_area_executor.gd")
const Support = preload("res://scripts/skills/skill_action_support.gd")
const Runner = preload("res://scripts/skills/skill_component_runner.gd")
const RangeUnits = preload("res://scripts/skills/skill_range_unit.gd")
const Summon = preload("res://scripts/summons/summon_controller.gd")
const Replay = preload("res://scripts/skills/skill_replay_service.gd")
const Names: Dictionary = {"burning":"燃烧","chilled":"寒冷","frozen":"冻结","conductive":"导电","cursed":"诅咒","judgment":"审判","instability":"不稳定"}
const CapabilityNames: Dictionary = {"apply_burning":"施加燃烧","apply_chilled":"施加寒冷","apply_conductive":"施加导电","apply_cursed":"施加诅咒","apply_judgment":"施加审判","apply_instability":"施加不稳定","fire_ground":"火焰地面","frost_area":"冰霜领域","chaos_rift":"混沌裂隙","divine_barrier":"神圣结界","overload":"过载","divine_punishment":"神罚","fission":"裂变","copyable_cast":"可复制施法","copyable_attack":"可复制攻击"}
static func build(player: Node, skill_id: StringName, level: int, rarity: String) -> Dictionary:
	var data: Dictionary = GameData.get_skill(skill_id)
	if data.is_empty(): return {}
	var instance: RefCounted = Instance.new(Definition.new(data))
	instance.current_level = clampi(level,1,instance.definition.max_level)
	var manager: Node = player.get_node_or_null("SkillManager") if player != null else null
	var owned: RefCounted = manager.get_skill(skill_id) if manager != null else null
	instance.current_rarity = Growth.keep_highest_rarity(owned.current_rarity if owned != null else "normal",rarity)
	var context: Dictionary = {"caster":player,"owner":player,"skill_instance":instance,"skill_id":skill_id,"skill_manager":manager}
	var result: Dictionary = {"damage":0.0,"dps":null,"cooldown":0.0,"radius":0.0,"duration":0.0,"statuses":[],"shield_amount":0,"next_milestone":Profile.describe_next_milestone(data,instance.current_level),"requirements":[],"rarity":instance.current_rarity,"lines":[],"hits":[],"conditional":false}
	if player != null: result.cooldown = Runner.new().get_cooldown(instance,context)
	for rule: Dictionary in data.get("trigger_rules",[]):
		var event: Dictionary = Adapter.to_event(rule,instance)
		var conditional: bool = not event.get("conditions",[]).is_empty() or rule.get("trigger","") != "cast_skill"
		result.conditional = result.conditional or conditional
		var prefix: String = "触发时：" if conditional else ""
		_describe_actions(event.get("actions",[]),context,result,prefix)
	if player != null:
		var admission: Dictionary = preload("res://scripts/skills/skill_requirement_policy.gd").new().evaluate(player,data)
		for missing: String in admission.missing_requirements:
			var text: String = missing
			for id: String in data.get("offer_rule",{}).get("required_skills",[]): text = text.replace(id,str(GameData.get_skill(id).get("display_name","指定技能")))
			for cap: String in CapabilityNames: text = text.replace(cap,CapabilityNames[cap])
			result.requirements.append(text)
	for required: String in data.get("offer_rule",{}).get("required_skills",[]):
		result.requirements.append(str(GameData.get_skill(required).get("display_name","指定前置技能")))
	if player != null:
		var bus: Node = player.get_node_or_null("SkillEventBus")
		if bus != null and skill_id == &"chaos_power_echo_cast":
			var snapshot: Dictionary = bus.get_cast_snapshot()
			if not snapshot.is_empty():
				var actions: Array = snapshot.actions.duplicate(true)
				Replay.scale_damage(actions,0.4)
				var source: RefCounted = manager.get_skill(snapshot.origin_skill_id)
				if source != null:
					var copy_context: Dictionary = context.duplicate()
					copy_context.skill_instance = source
					copy_context.power = snapshot.get("power",100.0)
					copy_context.status_power_snapshot = true
					_describe_actions(actions,copy_context,result,"回声就绪（复制）：")
	if result.cooldown > 0.0: result.lines.append("冷却 %.2fs · 品质%s" % [result.cooldown,rarity_name(result.rarity)])
	if not result.next_milestone.is_empty(): result.lines.append("Lv%d：%s" % [int(result.next_milestone.level),localize(str(result.next_milestone.get("description","效果强化")))])
	if not result.requirements.is_empty(): result.lines.append("前置：" + "、".join(result.requirements))
	return result
static func _describe_actions(actions: Array, context: Dictionary, result: Dictionary, prefix: String) -> void:
	var support: RefCounted = Support.new()
	for action: Dictionary in actions:
		var params: Dictionary = RangeUnits.resolve_action_params(action.get("params",{}))
		var action_type: String = str(action.get("type",""))
		var radius: float = float(params.get("radius",params.get("area_radius",0.0)))
		var duration: float = float(params.get("duration",0.0))
		if action_type == "spawn_area":
			var area: RefCounted = AreaRuntime.new()
			var id: StringName = StringName(str(params.get("area_id","")))
			var rules: Dictionary = area._get_runtime_special_rules(context)
			radius = area._prepare_area_radius_and_geometry_params(id,params.duplicate(true),params,context,"area",rules)
			duration = area._resolve_area_duration(id,params,context,rules)
		result.radius = maxf(result.radius,radius)
		result.duration = maxf(result.duration,duration)
		if radius > 0.0: _line(result,"范围 %.0fpx" % radius)
		if duration > 0.0: _line(result,"持续 %.2fs" % duration)
		if action_type == "apply_status":
			var name: String = localize(str(params.get("status_id","")))
			var status: Dictionary = {"name":name,"stacks":int(params.get("stack",1)),"duration":duration}
			result.statuses.append(status)
			_line(result,prefix + "%s %d层 · %.2fs" % [name,status.stacks,duration])
		if action_type in ["deal_damage","spawn_projectile","spawn_projectiles_at_targets","spawn_projectile_burst","chain_to_targets"]:
			var value: Variant = params.get("amount",params.get("damage",null))
			if value != null:
				var damage: int = maxi(roundi(support._resolve_scaled_amount(value,context,"damage")),0)
				result.damage = maxf(result.damage,float(damage))
				result.hits.append({"damage":damage,"label":prefix + "单次命中"})
				_line(result,prefix + "单次命中伤害 %d" % damage)
			if int(params.get("count",1)) > 1: _line(result,"弹体 %d枚（实际收益取决于命中）" % int(params.count))
		if action_type in ["grant_shield","heal_owner"]:
			var amount: int = maxi(roundi(support._resolve_scaled_amount(params.get("amount",0),context,"shield")),0)
			var ratio: float = float(params.get("max_health_ratio",0.0))
			if amount <= 0 and context.caster != null and ratio > 0: amount = roundi(float(context.caster.get("max_health"))*ratio)
			amount = roundi(amount*maxf(1.0+support._combined_modifier_value("holy_shield_restore_multiplier_add",context,0),0.05))
			result.shield_amount = maxi(result.shield_amount,amount)
			_line(result,prefix + "%s %.2f%%最大生命（%d点）" % ["护盾" if action_type == "grant_shield" else "治疗",ratio*100,amount])
		if action_type == "spawn_summon" and params.has("summon_definition_id"):
			var summon: Dictionary = GameData.get_summon(params.summon_definition_id)
			var node: Node = Summon.new()
			var attack: Dictionary = node._scaled_attack_config(summon.get("attack",{}),context.skill_instance)
			node.free()
			var power: float = support._get_caster_attack_power(context)
			var damage: int = roundi(power*float(attack.get("damage_scale",0)))
			var interval: float = float(attack.get("attack_cooldown",1))
			result.damage = maxf(result.damage,float(damage))
			result.dps = damage/interval if damage > 0 else null
			result.duration = Growth.apply_to_number(float(summon.get("duration",0)),context.skill_instance,"duration")
			_line(result,"召唤持续 %.2fs · 每 %.2fs 单次伤害 %d" % [result.duration,interval,damage])
			_line(result,"召唤持续命中时 %.2f伤害/秒" % (damage/interval))
		for key: String in ["actions_on_apply","actions_on_hit","actions_on_tick","actions_on_expire","actions_on_interval","actions"]:
			if params.has(key):
				var nested_prefix: String = prefix
				if key == "actions_on_tick": nested_prefix += "每 %.2fs：" % float(params.get("tick_interval",1.0))
				if key == "actions_on_interval": nested_prefix += "每 %.2fs：" % float(params.get("action_interval",1.0))
				_describe_actions(params[key],context,result,nested_prefix)
static func _line(result: Dictionary, line: String) -> void:
	if not result.lines.has(line): result.lines.append(line)
static func rarity_name(rarity: String) -> String:
	return {"normal":"普通","common":"普通","rare":"稀有","epic":"史诗","legendary":"传奇"}.get(rarity,"普通")
static func localize(text: String) -> String:
	for key: String in Names:
		text = text.replace(key,Names[key]).replace(key.capitalize(),Names[key])
	return text
