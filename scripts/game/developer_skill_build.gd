## 文件用途：为开局流程校验开发者技能构筑，并在角色重置后应用等级、稀有度与技能。
## 使用方式：开局前 validate，开发者模式中向已初始化玩家调用 apply。
extends RefCounted

const Slots := preload("res://scripts/skills/skill_slot_policy.gd")
const Learning := preload("res://scripts/skills/skill_learning_policy.gd")
const RARITIES: Array[String] = ["normal", "rare", "epic", "legendary"]
const LIMITS := {"attack": 1, "dash": 1, "ordinary": 5, "passive": 3, "core": 1, "fusion": 1}
const SLOT_LABELS := {"attack": "攻击", "dash": "冲刺", "ordinary": "主动", "passive": "被动", "core": "核心", "fusion": "融合"}

static func validate(character_id: Variant, entries: Variant) -> Dictionary:
	var errors: Array[String] = []
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	var groups: Dictionary = {}
	var schools: Array[StringName] = []
	var character: Dictionary = GameData.get_character(character_id)
	if character.is_empty(): errors.append("请选择有效角色。")
	if not entries is Array:
		return {"valid": false, "errors": ["技能构筑格式无效。"], "counts": counts}
	for value: Variant in entries:
		if not value is Dictionary:
			errors.append("技能构筑条目无效。")
			continue
		var id: String = str(value.get("skill_id", ""))
		var data: Dictionary = GameData.get_skill(id)
		if data.is_empty():
			errors.append("未知技能：" + id)
			continue
		var label: String = String(data.get("display_name", id))
		if seen.has(id): errors.append("技能重复：" + label)
		seen[id] = true
		if not is_selectable(data, character): errors.append("技能不可选：" + label)
		var level: Variant = value.get("level", 1)
		if not (level is int or level is float) or float(level) != float(int(level)) or int(level) < 1 or int(level) > int(data.get("max_level", 1)):
			errors.append("技能等级超出范围：" + label)
		if not RARITIES.has(str(value.get("rarity", "normal"))): errors.append("技能稀有度无效：" + label)
		var capacity: String = String(Slots.capacity_group(data))
		counts[capacity] = int(counts.get(capacity, 0)) + 1
		var group: String = String(data.get("exclusive_group")) if data.get("exclusive_group") != null else ""
		if group != "":
			if groups.has(group): errors.append("互斥技能不能同时选择：" + label)
			groups[group] = true
		var school: StringName = Learning.definition_primary_god_school(data)
		if school != &"" and not schools.has(school): schools.append(school)
	for capacity: String in LIMITS:
		if int(counts.get(capacity, 0)) > int(LIMITS[capacity]): errors.append("%s槽位已满（上限 %d）。" % [SLOT_LABELS[capacity], LIMITS[capacity]])
	if schools.size() > 2: errors.append("最多选择两个神系。")
	return {"valid": errors.is_empty(), "errors": errors, "counts": counts}

static func is_selectable(data: Dictionary, character: Dictionary) -> bool:
	if not bool(data.get("offer_enabled", true)): return false
	if bool(data.get("is_starting_skill", false)):
		return String(data.get("id", "")) == String(character.get("starting_skill_id", ""))
	return String(data.get("slot_category", "")) in ["active", "passive"] and Learning.is_pool_learnable_skill(data)

static func apply(player: Node, entries: Array, errors: Array[String] = []) -> bool:
	errors.clear()
	if player == null or player.get_tree() == null or not bool(player.get_tree().root.get_meta("developer_mode_enabled", false)):
		return _fail_application(errors, "开发者模式的玩家尚未就绪。")
	var validation: Dictionary = validate(player.get("selected_character_id"), entries)
	if not bool(validation.valid):
		errors.append_array(validation.errors)
		return false
	var manager: Node = player.get_node_or_null("SkillManager")
	if manager == null: return _fail_application(errors, "玩家缺少技能管理器。")
	# Character setup grants a default dash and records its school. A manual build
	# replaces that loadout, retaining only the character's default primary attack.
	var character: Dictionary = GameData.get_character(player.get("selected_character_id"))
	manager.call("clear_skills")
	if not manager.call("set_primary_attack_method", character.get("starting_skill_id", "")):
		return _fail_application(errors, "角色默认攻击初始化失败。")
	# Apply attack replacement first so inherited attack values are captured before passives.
	var ordered: Array = entries.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Slots.is_attack(GameData.get_skill(a.skill_id)) and not Slots.is_attack(GameData.get_skill(b.skill_id)))
	for entry: Dictionary in ordered:
		var id: StringName = StringName(entry.skill_id)
		var data: Dictionary = GameData.get_skill(id)
		var label: String = String(data.get("display_name", id))
		var rarity: String = String(entry.get("rarity", "normal"))
		var skill: RefCounted
		if bool(data.get("is_starting_skill", false)):
			if not manager.call("set_primary_attack_method", id, rarity):
				return _fail_application(errors, "无法设置攻击技能「%s」。" % label)
			skill = manager.call("get_primary_attack_method")
			while int(skill.get("current_level")) < int(entry.get("level", 1)):
				if not skill.call("level_up"):
					return _fail_application(errors, "「%s」无法升级到 Lv.%d。" % [label, entry.get("level", 1)])
			manager.emit_signal("skill_changed")
		else:
			if not manager.call("add_developer_skill", id, rarity):
				return _fail_application(errors, "无法加入技能「%s」（%s槽），请检查当前容量及互斥技能。" % [label, SLOT_LABELS[String(Slots.capacity_group(data))]])
			skill = manager.call("get_skill", id)
			while int(skill.get("current_level")) < int(entry.get("level", 1)):
				if not manager.call("upgrade_skill", id, rarity):
					return _fail_application(errors, "「%s」无法升级到 Lv.%d。" % [label, entry.get("level", 1)])
	if player.has_method("_refresh_synergies"): player.call("_refresh_synergies")
	return true

static func _fail_application(errors: Array[String], message: String) -> bool:
	errors.append(message)
	return false
