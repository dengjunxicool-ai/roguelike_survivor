## 只读升级配置与玩家属性，生成不会应用效果的选择预览。
extends RefCounted
class_name UpgradePreviewService
const Source = preload("res://scripts/modifiers/modifier_source.gd")
const Query = preload("res://scripts/modifiers/modifier_query.gd")
const Aggregator = preload("res://scripts/modifiers/modifier_aggregator.gd")
const Names: Dictionary = {"max_hp":"最大生命","armor":"护甲","pickup_radius":"拾取范围","move_speed":"移动速度","attack_speed":"攻击速度","damage":"伤害加成","boss_damage":"Boss伤害加成","coin_gain":"金币收益","soul_gain":"灵魂收益","experience_gain":"经验收益","heal":"立即治疗","heal_percent_max":"立即治疗"}

static func build_for_option(option: Dictionary, player: Node) -> String:
	var payload: Dictionary = option.get("payload",{}) if option.get("payload",{}) is Dictionary else {}
	var id: StringName = StringName(str(payload.get("upgrade_id",option.get("upgrade_id",""))))
	if id == &"": return ""
	return build_for_upgrade(GameData.get_upgrade(id),player,int(payload.get("level",0)))

static func build_for_upgrade(upgrade: Dictionary, player: Node, target_level: int = 0) -> String:
	if upgrade.is_empty() or upgrade.has("learn_skill_id"): return ""
	var level_index: int = maxi(target_level-1,0)
	if target_level <= 0 and player != null and player.has_method("_get_level_up_upgrade_level"):
		level_index = int(player.call("_get_level_up_upgrade_level",StringName(str(upgrade.get("id","")))))
	var levels: Array = upgrade.get("level_modifiers",[])
	var effects: Array = levels[level_index] if level_index < levels.size() else upgrade.get("modifiers",[])
	var lines: Array[String] = []
	var candidate: Dictionary = Source.flatten(effects)
	var sustained: Dictionary = _sustained_snapshot(player)
	var after: Dictionary = sustained.duplicate(true)
	if player != null:
		Source.merge_flat_values(after,player.call("_get_snapshot_modifiers",effects))
	else:
		Source.merge_flat_values(after,candidate)
	var max_after: int = int(player.get("max_health")) if player != null else 0
	var handled: Array[String] = []
	for effect: Dictionary in effects:
		var stat: String = str(effect.get("stat",""))
		if handled.has(stat): continue
		handled.append(stat)
		if stat == "max_hp" and player != null:
			var base: float = _base_value(player,"max_health")
			max_after = int(base) + int(after.get("max_hp_add",0))
			if float(after.get("max_hp_multiplier_add",0.0)) != 0.0:
				max_after = maxi(roundi(max_after*(1.0+float(after.max_hp_multiplier_add))),1)
			lines.append(_change("最大生命",float(player.get("max_health")),max_after))
		elif stat == "armor" and player != null:
			lines.append(_change("护甲",float(player.get("armor")),_base_value(player,"armor")+int(after.get("armor_add",0))))
		elif stat == "pickup_radius" and player != null:
			var pickup: Dictionary = Aggregator.collect(Query.for_player(player,Query.SCOPE_PICKUP))
			var next_pickup: Dictionary = pickup.duplicate(true)
			Source.merge_flat_values(next_pickup,Source.flatten(effects,Source.SOURCE_UPGRADE,Query.for_player(player,Query.SCOPE_PICKUP)))
			var radius: float = float(player.get("pickup_radius"))
			var before_radius: float = maxf(radius*maxf(1.0+float(pickup.get("pickup_radius_multiplier_add",0.0)),0.05)+float(pickup.get("pickup_radius_add",0.0)),1.0)
			var after_radius: float = maxf(radius*maxf(1.0+float(next_pickup.get("pickup_radius_multiplier_add",0.0)),0.05)+float(next_pickup.get("pickup_radius_add",0.0)),1.0)
			lines.append(_change("拾取范围",before_radius,after_radius)+"px")
		elif stat != "heal" and stat != "heal_percent_max":
			lines.append(_effect_text(effect))
	var heal: int = int(candidate.get("heal",0))+roundi(max_after*float(candidate.get("heal_percent_max",0.0)))
	if heal > 0:
		if player != null:
			var current: int = mini(int(player.get("current_health"))+maxi(max_after-int(player.get("max_health")),0),max_after)
			lines.append("立即治疗 %d→%d（恢复%d，实际+%d）" % [current,mini(current+heal,max_after),heal,mini(heal,max_after-current)])
		else: lines.append("立即治疗 +%d" % heal)
	return "\n".join(lines)

static func _sustained_snapshot(player: Node) -> Dictionary:
	var result: Dictionary = {}
	if player == null: return result
	var store: Node = player.get_node_or_null("ModifierStore")
	if store == null: return result
	for source: Dictionary in store.call("get_debug_sources").values():
		var scopes: Array = source.get("scopes",[])
		if not scopes.is_empty() and not scopes.has(Query.SCOPE_PLAYER): continue
		for entry: Dictionary in source.get("entries",[]):
			Source.merge_flat_values(result,player.call("_get_snapshot_modifiers",entry.get("effects",entry.get("snapshot",{}))))
	return result

static func _base_value(player: Node, field: String) -> float:
	var applier: RefCounted = player.get("_modifier_applier")
	var bases: Dictionary = applier.get("_base_snapshot")
	var last: Dictionary = applier.get("_last_snapshot")
	var current: float = float(player.get(field))
	return float(bases.get(field,current))+current-float(last.get(field,current))

static func _effect_text(effect: Dictionary) -> String:
	var stat: String = str(effect.get("stat",""))
	var name: String = str(Names.get(stat,stat))
	var value: float = float(effect.get("value",0.0))
	match str(effect.get("op","add")):
		"multiplier_add": return "%s %s%%" % [name,_signed(value*100.0)]
		"multiply": return "%s ×%s" % [name,_fmt(value)]
		"override": return "%s 设为%s" % [name,_fmt(value)]
	return "%s %s" % [name,_signed(value)]

static func _change(name: String, before: float, after: float) -> String:
	return "%s %s→%s（%s）" % [name,_fmt(before),_fmt(after),_signed(after-before)]

static func _signed(value: float) -> String:
	return ("+" if value >= 0 else "")+_fmt(value)

static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value,roundf(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
