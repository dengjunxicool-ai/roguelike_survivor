## 共享卡片和 HUD 图标解析；具体配置优先，其余按神系、类型或属性识别。
extends RefCounted
class_name SkillIconService
const ROOT: String = "res://assets/ui/skill_icons/"
const STARTERS: Dictionary = {"ranger_bolt":"bow","paladin_smite":"holy","alchemist_flask":"flask"}
const STAT_ICONS: Dictionary = {"max_hp":"health","armor":"armor","pickup_radius":"pickup","heal":"heal","heal_percent_max":"heal","move_speed":"dash","damage":"sword","boss_damage":"sword"}

static func icon_path_for_skill(skill_id: String) -> String:
	if skill_id == "basic_dash": return ROOT+"dash.svg"
	var skill: Dictionary = GameData.get_skill(StringName(skill_id))
	var configured: String = _configured_texture(skill)
	if configured != "": return configured
	if STARTERS.has(skill_id): return ROOT+str(STARTERS[skill_id])+".svg"
	var school: String = str(skill.get("school",""))
	if school in ["fire","frost","thunder","curse","holy","chaos"]: return ROOT+school+".svg"
	match str(skill.get("skill_type","")):
		"attack": return ROOT+"sword.svg"
		"dash": return ROOT+"dash.svg"
	return ROOT+"arcane.svg"

static func icon_path_for_option(option: Dictionary) -> String:
	var configured: String = _configured_texture(option)
	if configured != "": return configured
	var payload: Dictionary = _dictionary(option.get("payload",{}))
	var skill_id: String = str(payload.get("learn_skill_id",payload.get("skill_id",option.get("skill_id",""))))
	if skill_id.is_empty() and str(option.get("id","")).begins_with("skill_level_up:"):
		skill_id = str(option.id).get_slice(":",1)
	if skill_id != "": return icon_path_for_skill(skill_id)
	var id: String = str(payload.get("upgrade_id",option.get("upgrade_id","")))
	var upgrade: Dictionary = GameData.get_upgrade(StringName(id)) if id != "" else {}
	configured = _configured_texture(upgrade)
	if configured != "": return configured
	for effect: Dictionary in upgrade.get("modifiers",[]):
		var stat: String = str(effect.get("stat",""))
		if STAT_ICONS.has(stat): return ROOT+str(STAT_ICONS[stat])+".svg"
	return ROOT+"arcane.svg"

static func icon_path_for_value(line: String) -> String:
	if line.contains("治疗") or line.contains("恢复"): return ROOT+"heal.svg"
	if line.contains("生命"): return ROOT+"health.svg"
	if line.contains("护甲") or line.contains("防御"): return ROOT+"armor.svg"
	if line.contains("拾取") or line.contains("范围") or line.contains("半径"): return ROOT+"pickup.svg"
	if line.contains("冷却") or line.contains("CD"): return ROOT+"dash.svg"
	if line.contains("伤害"): return ROOT+"sword.svg"
	return ROOT+"arcane.svg"

static func _configured_texture(data: Dictionary) -> String:
	for source: Dictionary in [data,_dictionary(data.get("visual",{}))]:
		for key: String in ["icon","icon_texture","texture"]:
			var path: String = str(source.get(key,""))
			if path != "" and path != "res://icon.svg": return path
	return ""

static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
