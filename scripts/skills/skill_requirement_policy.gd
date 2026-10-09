extends RefCounted
class_name SkillRequirementPolicy
const STATE_CAP := {"fire": "apply_burning", "frost": "apply_chilled", "thunder": "apply_conductive", "curse": "apply_cursed", "holy": "apply_judgment", "chaos": "apply_instability"}
static func player_level(player: Node) -> int:
	var value: Variant = player.get("level") if player != null else null
	return int(value) if value != null else int(player.get_meta("character_level", 1)) if player != null else 1
func evaluate(player: Node, definition: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	var sources: Dictionary = {}
	var counts: Dictionary = {}
	var manager: Node = player.get_node_or_null("SkillManager") if player != null else null
	if manager == null: return {"available": false, "missing_requirements": ["缺少技能管理器"], "capability_sources": {}}
	for skill: RefCounted in manager.get_all_skills():
		var data: Dictionary = GameData.get_skill(skill.skill_id)
		if String(skill.skill_type) in ["core", "fusion"]: continue
		var school: String = String(skill.school)
		counts[school] = int(counts.get(school, 0)) + 1
		for capability: Variant in data.get("capabilities", []):
			if not sources.has(capability): sources[capability] = []
			sources[capability].append(String(skill.skill_id))
	var primary: RefCounted = manager.get_primary_attack_method()
	if primary != null:
		sources["copyable_attack"] = [String(primary.skill_id)]
	var type: String = String(definition.get("skill_type", ""))
	var school: String = String(definition.get("school", ""))
	var group: String = String(definition.get("exclusive_group", "")) if definition.get("exclusive_group") != null else ""
	for owned: RefCounted in manager.get_all_skills():
		if group != "" and String(owned.exclusive_group) == group and String(owned.skill_id) != String(definition.get("id", "")): missing.append("互斥槽位已占用")
	if school != "" and not manager.get_learned_god_schools().has(StringName(school)) and manager.get_learned_god_schools().size() >= 2 and type != "fusion": missing.append("最多两神系")
	var rule: Dictionary = definition.get("offer_rule", {})
	var minimum: int = int(rule.get("min_player_level", 1))
	if type == "core": minimum = maxi(minimum, 8)
	if type == "fusion": minimum = maxi(minimum, 6)
	if player_level(player) < minimum: missing.append("需要角色等级%d" % minimum)
	if not bool(definition.get("offer_enabled", true)): missing.append("迁移中")
	var required: Array = rule.get("required_capabilities", []).duplicate()
	if type == "core":
		if int(counts.get(school, 0)) < 3: missing.append("主神系至少3个基础技能")
		if STATE_CAP.has(school) and not required.has(STATE_CAP[school]): required.append(STATE_CAP[school])
		var reaction: String = {"holy": "divine_punishment", "thunder": "overload", "chaos": "fission"}.get(school, "")
		if reaction != "" and not required.has(reaction): required.append(reaction)
	if type == "fusion":
		var secondary: String = String(definition.get("fusion_school", ""))
		if int(counts.get(school, 0)) < 2: missing.append("主神系至少2个基础技能")
		if int(counts.get(secondary, 0)) < 1: missing.append("副神系至少1个基础技能")
		for cap: String in [String(STATE_CAP.get(school, "")), String(STATE_CAP.get(secondary, ""))]:
			if cap != "" and not required.has(cap): required.append(cap)
	elif school != "" and int(counts.get(school, 0)) == 0 and type in ["passive", "core"]:
		missing.append("先学习该神系输出或状态入口")
	for id: Variant in rule.get("required_skills", []):
		if not manager.has_skill(id): missing.append("需要技能：" + String(id))
	for cap: Variant in required:
		if not sources.has(cap): missing.append("需要机制：" + String(cap))
	if definition.get("id", "") == "chaos_power_echo_cast":
		var eligible: Dictionary = {}
		for cap: String in ["copyable_attack", "copyable_cast"]:
			for id: Variant in sources.get(cap, []): eligible[id] = true
		if eligible.size() < 2 or not sources.has("copyable_cast"): missing.append("至少2个可复制输出，其中1个施法")
	return {"available": missing.is_empty(), "missing_requirements": missing, "capability_sources": sources}
