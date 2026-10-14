## 文件用途：读取当前玩家和已持有技能，构建暂停页只读快照。
extends RefCounted

const Preview = preload("res://scripts/ui/skill_preview_service.gd")
const Resolver = preload("res://scripts/skills/modifier_resolver.gd")
const TriggerNames: Dictionary = {"attack_hit":"主攻击命中","on_projectile_hit":"弹体命中","projectile_hit":"弹体命中","dash_start":"开始冲刺","dash_tick":"冲刺途中","dash_end":"冲刺结束","cast_skill":"自动施放","on_cast":"自动施放","area_tick":"区域命中","on_enemy_killed":"击杀敌人","enemy_death":"敌人死亡","player_damage_taken":"玩家受伤","on_player_damaged":"玩家受伤","status_applied":"施加状态","status_tick":"状态伤害","status_expired":"状态结束","status_max_stack_reached":"状态满层","shield_gained":"获得护盾","shield_broken":"护盾破裂","summon_attack_hit":"召唤物命中","post_damage_hit":"造成伤害后","always":"持续生效"}
const AttributeNames: Dictionary = {"attack_power":"攻击力","damage_multiplier":"伤害倍率","attack_speed_multiplier":"攻速倍率","crit_chance":"暴击率","crit_damage":"暴击伤害倍率","armor":"护甲","move_speed":"移动速度","pickup_radius":"拾取范围","skill_area_multiplier":"技能范围倍率","status_duration_multiplier":"状态时长倍率","damage_taken_multiplier":"受伤倍率","experience_gain_multiplier":"经验收益倍率","soul_gain_multiplier":"灵魂收益倍率","dash_cooldown":"冲刺冷却","dash_speed":"冲刺速度","dash_duration":"冲刺持续"}

static func build(player: Node, tracker: Node = null) -> Dictionary:
	var result: Dictionary = {"player_id":0,"attributes":{},"attribute_lines":[],"skills":[],"contribution_lines":[]}
	if not is_instance_valid(player): return result
	result.player_id = player.get_instance_id()
	result.attribute_lines.append("生命 %d / %d · 角色等级 Lv%d" % [player.current_health,player.max_health,player.level])
	for key: String in AttributeNames:
		var value: float = float(player.get(key))
		if key == "pickup_radius": value = player.get_effective_pickup_radius()
		elif key == "move_speed": value = player.call("_get_effective_move_speed")
		result.attributes[key] = value
		var text: String = "%.2f" % value
		if key == "crit_chance": text = "%.1f%%" % (value*100.0)
		elif key in ["move_speed","dash_speed"]: text += " px/s"
		elif key == "pickup_radius": text += " px"
		elif key in ["dash_cooldown","dash_duration"]: text += " s"
		elif key.ends_with("multiplier") or key == "crit_damage": text += " 倍"
		result.attribute_lines.append("%s  %s" % [AttributeNames[key],text])
	var manager: Node = player.get_node_or_null("SkillManager")
	var has_dash: bool = false
	var seen: Dictionary = {}
	if manager != null:
		for owned: RefCounted in manager.get_active_skills()+manager.get_passive_skills():
			if owned == null or seen.has(owned.skill_id): continue
			seen[owned.skill_id] = true
			has_dash = has_dash or owned.skill_type == "dash"
			result.skills.append(_build_skill(player,manager,owned))
	if not has_dash:
		result.skills.append({"skill_id":&"basic_dash","name":"基础冲刺","level":1,"rarity":"normal","trigger":"按空格，冷却就绪时冲刺","range":0.0,"preview":{},"lines":["冲刺速度 %.0f px/s · 持续 %.2f s · 冷却 %.2f s" % [player.dash_speed,player.dash_duration,player.dash_cooldown]]})
	if is_instance_valid(tracker) and tracker.has_method("get_summary"):
		var summary: Dictionary = tracker.get_summary()
		result.contribution_lines.append("本局已造成伤害 %d · 击杀 %d" % [int(summary.get("damage_done_total",0)),int(summary.get("kill_count",0))])
	return result

static func _build_skill(player: Node, manager: Node, owned: RefCounted) -> Dictionary:
	var preview: Dictionary = Preview.build_owned(player,owned)
	var context: Dictionary = {"caster":player,"owner":player,"skill_manager":manager,"relic_manager":player.get_node_or_null("RelicManager"),"skill_instance":owned,"skill_id":owned.skill_id}
	var targeting_range: float = 0.0
	for component: Dictionary in owned.definition.components:
		if component.get("type","") == "targeting":
			targeting_range = float(Resolver.resolve_value(context,"range",component.get("params",{}).get("range",0.0)))
	var triggers: Array[String] = []
	for rule: Dictionary in owned.definition.trigger_rules:
		_append_trigger(triggers,str(rule.get("trigger","")))
	for event: Dictionary in owned.definition.events:
		_append_trigger(triggers,str(event.get("trigger","")))
	if not owned.definition.fusion_rules.is_empty(): triggers.append("满足融合条件时（见下方效果）")
	if triggers.is_empty(): triggers.append("持续生效" if owned.skill_type == "power" else "自动触发")
	var lines: Array[String] = []
	if targeting_range > 0: lines.append("索敌范围 %.0f px" % targeting_range)
	for line: String in preview.get("lines",[]):
		if not line.begins_with("Lv") and not line.begins_with("前置："): lines.append(line)
	return {"skill_id":owned.skill_id,"name":owned.definition.display_name,"level":owned.current_level,"rarity":owned.current_rarity,"trigger":"、".join(triggers),"range":targeting_range,"preview":preview,"lines":lines}

static func _append_trigger(labels: Array[String], trigger: String) -> void:
	var label: String = TriggerNames.get(trigger,"满足事件条件时")
	if not labels.has(label): labels.append(label)
