extends RefCounted
class_name RunRewardPool


const REWARD_COUNT: int = 3
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _upgrade_pool: RefCounted = UpgradePoolScript.new()


func _init() -> void:
	_rng.randomize()


func generate_reward_options(player: Node, reward_kind: String) -> Array[Dictionary]:
	if player == null:
		return []

	var options: Array[Dictionary] = []
	match reward_kind:
		"boss_blessing":
			options = _build_boss_blessing_options(player)
		_:
			options = _build_elite_reward_options(player)

	_shuffle(options)
	_ensure_reward_guarantees(player, reward_kind, options)
	return options.slice(0, mini(REWARD_COUNT, options.size()))


func _build_elite_reward_options(player: Node) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		_make_option("reward_main_exp", "主攻击经验", "立即获得 45 点经验，帮助主攻击更快达到 Lv5。", "rare", {"amount": 45, "reward_kind": "elite"}, ["主攻击", "成长"], "主攻击等级", "不直接提高当前伤害数值。", "精英节点后补经验能提高 Lv5 成型稳定性。"),
		_make_option("reward_soul_stones", "灵魂石补给", "获得 18 个灵魂石。", "common", {"amount": 18, "reward_kind": "elite"}, ["资源", "Meta"], "局外资源", "不影响本局战斗。", "死亡也不浪费，适合稳步推进长期成长。"),
		_make_option("reward_heal", "应急治疗", "恢复 25% 最大生命。", "rare", {"heal_percent": 0.25, "reward_kind": "elite"}, ["生存", "治疗"], "生命值", "不直接提高输出。", "补足血量可以降低下一波或 Boss 前暴毙风险。")
	]
	options.append_array(_upgrade_options(player, 2, "elite"))
	var relic_option: Dictionary = _random_relic_option("elite")
	if not relic_option.is_empty():
		options.append(relic_option)
	if _health_percent(player) < 0.40:
		options.insert(0, _make_option("reward_heal_large", "濒危治疗", "恢复 35% 最大生命。", "epic", {"heal_percent": 0.35, "reward_kind": "elite"}, ["生存", "治疗", "保底"], "生命值", "不直接提高输出。", "当前生命低于 40%，先恢复状态比贪输出更稳。"))
	if _health_percent(player) < 0.25:
		options.insert(0, _make_option("reward_shield", "临时护盾", "获得一次性护盾，抵消下一次高额伤害。", "rare", {"upgrade_id": &"survival_defense", "reward_kind": "elite"}, ["生存", "护盾", "保底"], "生存", "不直接提高输出。", "当前生命低于 25%，护盾能防止被下一次接触或技能击杀。"))
	return options


func _build_boss_blessing_options(player: Node) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		_make_option("boss_damage_blessing", "强敌压制", "Boss 战期间输出提高。", "rare", {"upgrade_id": &"boss_damage", "reward_kind": "boss_blessing"}, ["Boss", "输出"], "精英 / Boss", "不影响普通怪清场。", "Boss 即将出现，单体补强更容易转化为胜利。"),
		_make_option("boss_survival_blessing", "稳固防线", "恢复 20% 最大生命，并获得防御补强。", "rare", {"heal_percent": 0.20, "upgrade_id": &"survival_defense", "reward_kind": "boss_blessing"}, ["Boss", "生存"], "Boss 阶段承伤", "不直接提高输出。", "适合对 Boss 技能读条不熟或血量偏低的局。"),
		_make_option("boss_growth_blessing", "临战熟练", "立即获得 60 点经验，补齐未完成的主攻击成长。", "rare", {"amount": 60, "reward_kind": "boss_blessing"}, ["成长", "主攻击"], "主攻击等级", "不直接提高未装备武器。", "若 Boss 前未完成 Lv5，该选项能补齐构筑闭环。"),
		_make_option("boss_status_blessing", "状态共鸣", "Boss 战中 DOT 与反应路线获得补强。", "rare", {"upgrade_id": &"boss_damage", "reward_kind": "boss_blessing"}, ["Boss", "状态", "反应"], "DOT / 反应 Boss 表现", "不影响百分比真伤或普通怪。", "适合冰、毒、闪电等依赖状态链的构筑。"),
		_make_option("boss_control_blessing", "破势训练", "Boss 战中控制路线更容易转化为有效输出窗口。", "rare", {"upgrade_id": &"survival_defense", "reward_kind": "boss_blessing"}, ["Boss", "控制", "生存"], "Boss 韧性 / 生存", "不直接提高普通怪伤害。", "适合冰杖、战锤、陷阱等控制构筑。"),
		_make_option("boss_risk_reward", "危险悬赏", "Boss 生命提高，但本局胜利收益提高。", "epic", {"upgrade_id": &"curse_boss_bounty", "reward_kind": "boss_blessing"}, ["Boss", "风险奖励"], "Boss 难度 / 胜利收益", "不提高生存，且会增加 Boss 血量。", "适合输出已经成型、想换取更高胜利收益的局。")
	]
	options.append_array(_upgrade_options(player, 2, "boss_blessing"))
	var relic_option: Dictionary = _random_relic_option("boss_blessing")
	if not relic_option.is_empty():
		options.append(relic_option)
	return options


func _upgrade_options(player: Node, count: int, reward_kind: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for option_variant: Variant in _upgrade_pool.call("generate_options", player, count):
		var option: RefCounted = option_variant as RefCounted
		if option != null and option.has_method("to_dictionary"):
			var data_variant: Variant = option.call("to_dictionary")
			if data_variant is Dictionary:
				var data: Dictionary = data_variant
				data["description"] = "奖励强化：%s" % String(data.get("description", ""))
				var payload: Dictionary = _get_dictionary(data.get("payload", {}))
				payload["reward_kind"] = reward_kind
				data["payload"] = payload
				options.append(data)
	return options


func _random_relic_option(reward_kind: String) -> Dictionary:
	var relics: Array[Dictionary] = GameData.get_relic_pool()
	if relics.is_empty():
		return {}
	var relic: Dictionary = relics[_rng.randi_range(0, relics.size() - 1)]
	var relic_id: StringName = StringName(String(relic.get("id", "")))
	if relic_id == &"":
		return {}
	return _make_option(
		"reward_relic:%s" % String(relic_id),
		"遗物：%s" % _display_name(relic, relic_id),
		String(relic.get("description", "获得一个改变规则的遗物。")),
		String(relic.get("rarity", "epic")),
		{"relic_id": relic_id, "reward_kind": reward_kind},
		_get_string_array(relic.get("tags", [])),
		"Relic 事件效果",
		"只影响遗物描述中声明的触发条件和效果。",
		"遗物能提供稀有规则变化，适合强化当前构筑方向。"
	)


func _make_option(id: String, title: String, description: String, rarity: String, payload: Dictionary, tags: Array[String] = [], affected_origin: String = "", does_not_affect: String = "", recommended_reason: String = "") -> Dictionary:
	return {
		"id": id,
		"type": "run_reward",
		"display_name": title,
		"description": description,
		"rarity": rarity,
		"payload": payload,
		"tags": tags,
		"affected_origin": affected_origin,
		"does_not_affect": does_not_affect,
		"recommended_reason": recommended_reason,
		"level_text": "奖励"
	}


func _ensure_reward_guarantees(player: Node, reward_kind: String, options: Array[Dictionary]) -> void:
	if reward_kind == "elite" and _health_percent(player) < 0.40 and not _has_tag(options, "生存"):
		options.insert(0, _make_option("reward_heal_guarantee", "低血量补偿", "恢复 25% 最大生命。", "rare", {"heal_percent": 0.25, "reward_kind": "elite"}, ["生存", "治疗", "保底"], "生命值", "不直接提高输出。", "低血量时至少出现一个生存选项。"))
	if reward_kind == "boss_blessing" and not _has_tag(options, "Boss"):
		options.insert(0, _make_option("boss_damage_guarantee", "Boss 补强", "Boss 战期间输出提高。", "rare", {"upgrade_id": &"boss_damage", "reward_kind": "boss_blessing"}, ["Boss", "输出", "保底"], "精英 / Boss", "不影响普通怪清场。", "Boss 前祝福至少提供一个 Boss 相关选项。"))


func _has_tag(options: Array[Dictionary], tag: String) -> bool:
	for option: Dictionary in options:
		if _get_string_array(option.get("tags", [])).has(tag):
			return true
	return false


func _health_percent(player: Node) -> float:
	var max_health: float = maxf(float(player.get("max_health")), 1.0)
	return clampf(float(player.get("current_health")) / max_health, 0.0, 1.0)


func _shuffle(options: Array[Dictionary]) -> void:
	for option_index in range(options.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, option_index)
		var value: Dictionary = options[option_index]
		options[option_index] = options[swap_index]
		options[swap_index] = value


func _display_name(data: Dictionary, fallback: Variant) -> String:
	return String(data.get("display_name", fallback))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(String(item))
	return result
