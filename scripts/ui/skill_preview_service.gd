## 从最终运行时动作生成可读预览；每次命中为单位，不承诺未知目标数或未来命中。
extends RefCounted
class_name SkillPreviewService
const Definition = preload("res://scripts/skills/skill_definition.gd")
const Instance = preload("res://scripts/skills/skill_instance.gd")
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
const Effects = preload("res://scripts/skills/skill_effect_adapter.gd")
const ModifierResolver = preload("res://scripts/skills/modifier_resolver.gd")
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
	var manager: Node = player.get_node_or_null("SkillManager") if player != null else null
	var owned: RefCounted = manager.get_skill(skill_id) if manager != null else null
	if owned != null:
		for key: String in ["base","components","events","damage_scaling","runtime_rules","base_special_rules"]:
			var value: Variant = owned.definition.get(key)
			if value is Dictionary or value is Array: data[key] = value.duplicate(true)
	elif data.get("skill_type","") == "attack" and not data.get("is_starting_skill",false) and manager != null:
		data = manager._with_inherited_attack_runtime(data,manager._find_replaced_active_skill_id(skill_id,data))
	var instance: RefCounted = Instance.new(Definition.new(data))
	instance.current_level = clampi(level,1,instance.definition.max_level)
	instance.current_rarity = Growth.keep_highest_rarity(owned.current_rarity if owned != null else "normal",rarity)
	var context: Dictionary = {"caster":player,"owner":player,"skill_instance":instance,"skill_id":skill_id,"skill_manager":manager}
	var result: Dictionary = {"damage":0.0,"dps":null,"cooldown":0.0,"radius":0.0,"duration":0.0,"statuses":[],"shield_amount":0,"next_milestone":Profile.describe_next_milestone(data,instance.current_level),"requirements":[],"rarity":instance.current_rarity,"lines":[],"hits":[],"conditional":false,"cooldown_label":"","modifiers":[]}
	var scheduled: bool = not data.get("components",[]).is_empty()
	for rule: Dictionary in data.get("trigger_rules",[]): scheduled = scheduled or rule.get("trigger","") == "cast_skill"
	if data.get("skill_type","") == "dash":
		if player != null and "dash_cooldown" in player: result.cooldown = float(player.dash_cooldown)
		result.cooldown_label = "冲刺冷却"
	elif scheduled and player != null:
		result.cooldown = Runner.new().get_cooldown(instance,context)
		result.cooldown_label = "施放冷却"
	for effect: Dictionary in data.get("effects",[]):
		if effect.get("type","") == "add_modifier" and manager != null:
			var source: Dictionary = manager._modifier_effect_to_source(effect,instance)
			result.modifiers.append(source)
			_describe_modifier(source,result,"常驻：")
		else: _describe_actions(Effects.to_actions([effect],instance),context,result,"")
	for source: Dictionary in data.get("skill_modifiers",[]):
		var scaled: Dictionary = source.duplicate(true)
		if manager != null: manager._scale_modifier_source_values(scaled,instance)
		result.modifiers.append(scaled)
		_describe_modifier(scaled,result,"常驻：")
	for rule: Dictionary in data.get("fusion_rules",[]):
		result.conditional = true
		var prefix: String = "融合触发时（%s）：" % _fusion_context(rule)
		if float(rule.get("cooldown",0)) > 0: _line(result,prefix+"同一目标/交互触发间隔 %.2fs" % float(rule.cooldown))
		_describe_actions(Effects.to_actions(rule.get("effects",[]),instance),context,result,prefix)
		_describe_fusion_utility(rule,context,result,prefix)
		if rule.get("effects",[]).is_empty(): _line(result,localize(str(data.get("description",""))))
	for event: Dictionary in data.get("events",[]):
		_describe_actions(event.get("actions",[]),context,result,"命中时：" if event.get("trigger","") != "on_cast" else "")
	for rule: Dictionary in data.get("trigger_rules",[]):
		var event: Dictionary = Adapter.to_event(rule,instance)
		var conditional: bool = not event.get("conditions",[]).is_empty() or rule.get("trigger","") != "cast_skill"
		result.conditional = result.conditional or conditional
		var prefix: String = "触发时：" if conditional else ""
		var conditions_text: String = _conditions_text(event.get("conditions",[]))
		if not conditions_text.is_empty(): prefix += conditions_text + "："
		if event.has("threshold"): _line(result,prefix+"累计 %d 次有效事件触发" % int(event.threshold))
		if float(event.get("cooldown",0)) > 0 and rule.get("trigger","") != "cast_skill": _line(result,prefix+"触发间隔 %.2fs" % float(event.cooldown))
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
			var snapshot: Dictionary = bus.get_cast_snapshot({"skill_type":"cast"})
			if not snapshot.is_empty():
				var actions: Array = snapshot.actions.duplicate(true)
				Replay.scale_damage(actions,0.4)
				var source: RefCounted = manager.get_skill(snapshot.origin_skill_id)
				if source != null:
					var copy_context: Dictionary = context.duplicate()
					copy_context.skill_instance = source
					copy_context.power = snapshot.get("power",100.0)
					copy_context.status_power_snapshot = true
					_describe_actions(actions,copy_context,result,"回声可复制输出：")
	if result.cooldown > 0.0: result.lines.append("%s %.2fs · 品质%s" % [result.cooldown_label,result.cooldown,rarity_name(result.rarity)])
	if not result.next_milestone.is_empty(): result.lines.append("Lv%d：%s" % [int(result.next_milestone.level),localize(str(result.next_milestone.get("description","效果强化")))])
	if not result.requirements.is_empty(): result.lines.append("前置：" + "、".join(result.requirements))
	return result
static func _describe_actions(actions: Array, context: Dictionary, result: Dictionary, prefix: String) -> void:
	var support: RefCounted = Support.new()
	for action: Dictionary in actions:
		var params: Dictionary = RangeUnits.resolve_action_params(action.get("params",{}))
		var action_prefix: String = prefix
		var conditions: String = _conditions_text(action.get("conditions",params.get("conditions",[])))
		if not conditions.is_empty():
			result.conditional = true
			action_prefix += conditions + "额外："
		if bool(params.get("return_only",false)):
			result.conditional = true
			action_prefix += "仅回程："
		if params.has("every_n_hits"):
			result.conditional = true
			action_prefix += "每%d次区域命中：" % int(params.every_n_hits)
		if params.has("per_target_interval"): action_prefix += "同一目标间隔%.2fs：" % float(params.per_target_interval)
		var action_type: String = str(action.get("type",""))
		var radius: float = float(params.get("radius",params.get("area_radius",0.0)))
		var duration: float = float(params.get("duration",0.0))
		if action_type == "apply_status": duration = float(ModifierResolver.resolve_value(context,"status_duration",params.get("duration",0.0)))
		if action_type == "spawn_area":
			var area: RefCounted = AreaRuntime.new()
			var id: StringName = StringName(str(params.get("area_id","")))
			var rules: Dictionary = area._get_runtime_special_rules(context)
			radius = area._prepare_area_radius_and_geometry_params(id,params.duplicate(true),params,context,"area",rules)
			duration = area._resolve_area_duration(id,params,context,rules)
		result.radius = maxf(result.radius,radius)
		if action_type != "apply_status": result.duration = maxf(result.duration,duration)
		if radius > 0.0: _line(result,action_prefix+"范围 %.0fpx" % radius)
		if duration > 0.0 and action_type != "apply_status": _line(result,action_prefix+"持续 %.2fs" % duration)
		if action_type == "apply_status":
			var name: String = localize(str(params.get("status_id","")))
			var status: Dictionary = {"name":name,"stacks":int(params.get("stack",1)),"duration":duration}
			result.statuses.append(status)
			_line(result,action_prefix + "%s %d层 · %.2fs" % [name,status.stacks,duration])
		if action_type in ["deal_damage","spawn_projectile","spawn_projectiles_at_targets","spawn_projectile_burst","chain_to_targets"]:
			var value: Variant = params.get("amount",params.get("damage",null))
			if value != null:
				var damage: int = maxi(roundi(support._resolve_scaled_amount(value,context,"damage")),0)
				if result.hits.is_empty(): result.damage = float(damage)
				result.hits.append({"damage":damage,"label":action_prefix + "单次命中"})
				_line(result,action_prefix + "单次命中伤害 %d" % damage)
			if int(params.get("count",1)) > 1: _line(result,"弹体 %d枚（实际收益取决于命中）" % int(params.count))
		if action_type in ["grant_shield","heal_owner"]:
			var amount: int = maxi(roundi(support._resolve_scaled_amount(params.get("amount",0),context,"shield")),0)
			var ratio: float = float(params.get("max_health_ratio",0.0))
			if amount <= 0 and context.caster != null and ratio > 0: amount = roundi(float(context.caster.get("max_health"))*ratio)
			if action_type == "grant_shield":
				amount = roundi(amount*maxf(1.0+support._combined_modifier_value("holy_shield_restore_multiplier_add",context,0),0.05))
				result.shield_amount = maxi(result.shield_amount,amount)
			else:
				amount = int(params.get("amount",0)) if float(params.get("amount",0)) > 0 else maxi(roundi(float(context.caster.get("max_health"))*ratio),1) if context.caster != null and ratio > 0 else 0
			var label: String = "护盾" if action_type == "grant_shield" else "治疗"
			_line(result,action_prefix + ("%s %.2f%%最大生命（%d点）" % [label,ratio*100,amount] if ratio > 0 else "%s %d点" % [label,amount]))
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
				var nested_prefix: String = action_prefix
				if key == "actions_on_hit": nested_prefix += "命中时："
				if key == "actions_on_apply": nested_prefix += "生成时："
				if key == "actions_on_expire": nested_prefix += "到期时："
				if action_type == "delayed_output": nested_prefix += "延迟 %.2fs后：" % float(params.get("delay",0.5))
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

static func _describe_modifier(source: Dictionary,result: Dictionary,prefix: String) -> void:
	var names: Dictionary = {"dot_damage":"持续状态伤害","status_duration":"状态持续时间","chilled_duration":"寒冷时长","chilled_freeze_threshold":"冻结所需寒冷层数","conductive_lightning_damage_taken":"导电目标雷电易伤","cursed_low_hp_boss_effect":"Boss低血诅咒收益","cursed_low_hp_damage":"低血诅咒伤害","divine_punishment_judgment_stacks_retained":"神罚后审判保留层数","frost_area_duration":"冰霜区域时长","frozen_damage_taken":"冻结目标易伤","frozen_duration":"冻结时长","holy_damage":"神圣伤害","holy_shield_cap":"神圣护盾上限","holy_shield_restore":"神圣护盾恢复","instability_fission_stacks_retained":"裂变后不稳定保留层数","judgment_damage_dealt":"审判目标伤害","judgment_holy_damage_taken":"审判目标神圣易伤","lightning_chain_range":"闪电连锁范围","overload_conductive_stacks_retained":"过载后导电保留层数","primary_attack_damage":"主攻击伤害","cooldown":"技能冷却"}
	var stat: String = str(source.get("stat",""))
	var op: String = str(source.get("op","multiplier_add"))
	var value: float = float(source.get("value",0))
	var text: String = "%+.2f%%" % (value*100) if op == "multiplier_add" else "%+.2f" % value
	_line(result,prefix+str(names.get(stat,"属性增益"))+" "+text)
static func _conditions_text(conditions: Array) -> String:
	var labels: Array[String] = []
	for condition: Dictionary in conditions:
		var params: Dictionary = condition.get("params",condition)
		var status: String = localize(str(params.get("status_id",params.get("status","指定状态"))))
		match str(condition.get("type","")):
			"target_has_status": labels.append("对"+status+"目标")
			"target_missing_status": labels.append("对无"+status+"的目标")
			"target_status_stacks_at_least": labels.append("对至少%d层%s的目标" % [int(params.get("stacks",1)),status])
			"event_status_is": labels.append(status+"状态事件")
			"chance": labels.append("概率%.0f%%" % (float(params.get("chance",params.get("value",1)))*100))
			_: labels.append("满足触发条件时")
	return "且".join(labels)
static func _fusion_context(rule: Dictionary) -> String:
	var events: Dictionary = {"area_tick":"区域命中","post_damage_hit":"造成伤害后","area_overlap":"区域接触","on_enemy_killed":"敌人死亡","status_tick":"状态伤害","cursed_resolved":"诅咒结算","reaction_resolved":"状态反应","status_applied":"施加状态","status_expired":"状态结束","on_cast":"施放技能","shield_gained":"获得护盾","area_pulse":"区域周期","projectile_area_entered":"弹体进入区域","area_created":"区域生成","chain_select":"连锁选取"}
	var text: String = str(events.get(str(rule.get("event","")),"有效事件"))
	for status: String in rule.get("statuses",[]): text += " · 目标"+localize(status)
	if rule.has("origin"): text += " · "+str(GameData.get_skill(rule.origin).get("display_name","来源技能"))
	if rule.has("area_kind"): text += " · 指定区域内"
	if bool(rule.get("needs_rift",false)): text += " · 需要裂隙"
	return text
static func _describe_fusion_utility(rule: Dictionary,context: Dictionary,result: Dictionary,prefix: String) -> void:
	var op: String = str(rule.get("operation",""))
	match op:
		"curse_charge": _line(result,prefix+"下次诅咒结算增伤 +%.2f%%，上限 +%.2f%%" % [float(rule.amount)*100,float(rule.maximum)*100])
		"curse_shorten_mark","area_curse_shorten","chain_priority": _line(result,prefix+"诅咒剩余结算时间缩短 %.2fs" % float(rule.get("seconds",0)))
		"extend_area": _line(result,prefix+"区域延长 %.2fs" % float(rule.seconds))
		"curse_freeze": _line(result,prefix+"暂停诅咒结算")
		"curse_resume": _line(result,prefix+"恢复诅咒计时")
		"curse_thaw": _line(result,prefix+"恢复并立即结算诅咒")
		"retarget": _line(result,prefix+"优先选择"+localize(str(rule.get("select_status","指定状态")))+"层数最高的目标")
		"copy_curse": _line(result,prefix+"复制诅咒持续 %.2fs，原状态威力的 %.2f%%" % [float(rule.duration),float(rule.damage_scale)*100])
		"reaction_echo","curse_echo": _line(result,prefix+"复制实际反应输出的 %.2f%%，延迟 %.2fs" % [float(rule.damage_scale)*100,float(rule.get("delay",0))])
		"area_clone": _line(result,prefix+"原区域半径增加 %.0fpx；复制区域半径为增加后的 %.2f%%，持续 %.2fs" % [float(rule.radius_add),float(rule.radius_scale)*100,float(rule.duration)])
		"teleport": _line(result,prefix+"传送对象并重置持续 %.2fs" % float(rule.duration))
		"teleport_shard": _line(result,prefix+"传送冰片，原伤害的 %.2f%%" % (float(rule.get("damage_scale",1))*100))
		"store_area_charge","next_charge": _line(result,prefix+"储存一次待触发输出")
		"summon_one":
			_line(result,prefix+"召唤持续 %.2fs" % float(rule.duration))
			_describe_actions(Effects.to_actions([{"type":"damage","power_scale":float(rule.power_scale)},rule.status_effect],context.skill_instance),context,result,prefix+"首次攻击：")
	if float(rule.get("interval",0))>0: _line(result,prefix+"区域周期 %.2fs" % float(rule.interval))
	if float(rule.get("delay",0))>0 and op == "reverse_echo": _line(result,prefix+"延迟 %.2fs" % float(rule.delay))
