## 文件用途：根据生命、技能等级、局内时间和波次规则计算升级出现条件、权重及保底标签。
## 使用方式：UpgradePool 用此策略筛选与推荐；时间从 enemy_spawner 的 _elapsed_time 获取，策略不消费 RNG。
extends RefCounted
class_name UpgradeOfferPolicy


const LearnRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const DEFAULT_PHASE_WEIGHT: float = 30.0
const DEFAULT_LATE_RUN_SECONDS: float = 220.0
const LATE_RUN_GUARANTEE_TAGS: Array[String] = ["boss", "survival", "status"]


## 作用：按基础权重、已选次数衰减、条件修正、阶段标签和低血后期加权计算最终权重。
## 使用：player 为玩家节点。
func get_upgrade_weight(player: Node, upgrade: Dictionary, upgrade_level: int, main_level: int) -> float:
	var weight: float = maxf(float(upgrade.get("base_weight", 0.0)), 0.0)
	weight *= pow(maxf(float(upgrade.get("weight_decay", 1.0)), 0.0), float(upgrade_level))

	var condition: Dictionary = _dictionary(upgrade.get("condition", {}))
	if not condition.is_empty() and condition.has("weight"):
		weight = float(condition.get("weight", weight))
	if condition.has("weight_multiplier"):
		weight *= float(condition.get("weight_multiplier", 1.0))

	var tags: Array = _array(upgrade.get("tags", []))
	var phase_weight: float = _current_phase_tag_weight(player, main_level, tags)
	if phase_weight <= 0.0:
		return 0.0
	weight *= phase_weight / DEFAULT_PHASE_WEIGHT

	if is_late_run(player) and (tags.has("boss") or tags.has("survival")):
		weight *= 1.4
	if is_low_hp(player) and tags.has("survival"):
		weight *= 3.0
	return weight


## 作用：解释升级的低血、至少运行时间或 Boss 阶段条件；未知条件类型拒绝。
## 使用：player 为玩家节点；返回布尔判断或执行是否成功。
func is_upgrade_condition_met(player: Node, upgrade: Dictionary) -> bool:
	var condition: Dictionary = _dictionary(upgrade.get("condition", {}))
	if condition.is_empty():
		return true

	match String(condition.get("type", "")):
		"hp_below_percent":
			var max_health: float = maxf(float(player.get("max_health")), 1.0)
			var current_health: float = clampf(float(player.get("current_health")), 0.0, max_health)
			return current_health / max_health < float(condition.get("value", 1.0))
		"run_time_at_least", "boss_phase":
			return _run_elapsed_time(player) >= float(condition.get("seconds", 0.0))
		_:
			return false


## 作用：检查已有卡片是否缺低血生存或后期构筑标签，并返回需补齐的标签。
## 使用：player 为玩家节点；selected_options 为原地填充的已选卡片；无匹配项时返回空数组。
func get_missing_guarantee_tags(player: Node, selected_options: Array) -> Array[String]:
	if selected_options.is_empty():
		return []

	var low_hp_tags: Array[String] = _low_hp_guarantee_tags()
	if is_low_hp(player) and not options_have_any_tag(selected_options, low_hp_tags):
		return low_hp_tags

	if is_late_run(player) and not options_have_any_tag(selected_options, LATE_RUN_GUARANTEE_TAGS):
		return LATE_RUN_GUARANTEE_TAGS

	return []


## 作用：结合玩家低血、后期及升级标签生成推荐原因。
## 使用：player 为玩家节点。
func build_recommended_reason(player: Node, upgrade: Dictionary) -> String:
	var tags: Array = _array(upgrade.get("tags", []))
	if is_low_hp(player) and tags.has("survival"):
		return "当前生命偏低，优先补生存可以提高进入 Boss 阶段的稳定性。"
	if is_late_run(player) and tags.has("boss"):
		return "Boss 即将出现或已经出现，强敌补强的收益更高。"
	if tags.has("dot") or tags.has("reaction"):
		return "当前技能构筑可走状态链路线，适合补足 DOT / 反应贡献。"
	if tags.has("area") or tags.has("field"):
		return "中后段怪群压力增加，范围覆盖有助于清场。"
	return "与当前技能构筑或局内阶段兼容，可作为稳定成长选择。"


## 作用：判断候选列表中是否至少有一个选项匹配指定升级标签。
## 使用：options 为候选卡片列表；返回布尔判断或执行是否成功。
func options_have_any_tag(options: Array, tags: Array[String]) -> bool:
	for option_variant: Variant in options:
		if option_has_any_tag(option_variant as RefCounted, tags):
			return true
	return false


## 作用：解析卡片载荷中的升级定义后检查其标签交集。
## 使用：由本文件 options_have_any_tag 调用；返回布尔判断或执行是否成功。
func option_has_any_tag(option: RefCounted, tags: Array[String]) -> bool:
	if option == null:
		return false
	var payload_variant: Variant = option.get("payload")
	if not (payload_variant is Dictionary):
		return false

	var payload: Dictionary = payload_variant
	var upgrade_id: StringName = StringName(String(payload.get("upgrade_id", "")))
	if upgrade_id == &"":
		return false

	var upgrade: Dictionary = LearnRepositoryScript.resolve_upgrade(upgrade_id)
	var upgrade_tags: Array = _array(upgrade.get("tags", []))
	for tag: String in tags:
		if upgrade_tags.has(tag):
			return true
	return false


## 作用：用玩家当前血量比例比较波次规则中的低血门槛。
## 使用：player 为玩家节点；返回布尔判断或执行是否成功。
func is_low_hp(player: Node) -> bool:
	if player == null:
		return false
	var max_health: float = maxf(float(player.get("max_health")), 1.0)
	return clampf(float(player.get("current_health")) / max_health, 0.0, 1.0) < _low_hp_threshold()


## 作用：比较局内时间与配置推导的后期阈值。
## 使用：player 为玩家节点。
func is_late_run(player: Node) -> bool:
	return _run_elapsed_time(player) >= _late_run_elapsed_threshold()


## 作用：从波次 low_hp_rule 读取并夹紧低血比例阈值。
## 使用：由本文件 is_low_hp 调用。
func _low_hp_threshold() -> float:
	var low_hp_rule: Dictionary = _dictionary(_spawn_rules().get("low_hp_rule", {}))
	return clampf(float(low_hp_rule.get("threshold_percent", 0.35)), 0.0, 1.0)


## 作用：读取低血保底标签，缺少有效标签时使用 survival。
## 使用：由本文件 get_missing_guarantee_tags 调用。
func _low_hp_guarantee_tags() -> Array[String]:
	var low_hp_rule: Dictionary = _dictionary(_spawn_rules().get("low_hp_rule", {}))
	var tags: Array[String] = []
	for tag_variant: Variant in _array(low_hp_rule.get("guarantee_tags", ["survival"])):
		var tag: String = String(tag_variant)
		if tag != "":
			tags.append(tag)
	if tags.is_empty():
		tags.append("survival")
	return tags


## 作用：在阶段规则中取最早 elapsed_time_min，未配置时使用默认后期秒数。
## 使用：由本文件 is_late_run 调用。
func _late_run_elapsed_threshold() -> float:
	var threshold: float = INF
	for rule_variant: Variant in _array(_spawn_rules().get("upgrade_phase_weights", [])):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		var condition: Dictionary = _dictionary(rule.get("condition", {}))
		if condition.has("elapsed_time_min"):
			threshold = minf(threshold, float(condition.get("elapsed_time_min", threshold)))
	return DEFAULT_LATE_RUN_SECONDS if is_inf(threshold) else threshold


## 作用：在当前阶段权重中选候选标签的最大值，无匹配用默认阶段权重。
## 使用：player 为玩家节点。
func _current_phase_tag_weight(player: Node, main_level: int, tags: Array) -> float:
	var phase_weights: Dictionary = _current_upgrade_phase_weights(player, main_level)
	if phase_weights.is_empty():
		return DEFAULT_PHASE_WEIGHT

	var best_weight: float = -1.0
	for tag_variant: Variant in tags:
		var tag: String = String(tag_variant)
		if phase_weights.has(tag):
			best_weight = maxf(best_weight, float(phase_weights.get(tag, 0.0)))
	return DEFAULT_PHASE_WEIGHT if best_weight < 0.0 else best_weight


## 作用：按顺序遍历满足等级和时间条件的阶段规则，最后匹配者提供权重。
## 使用：player 为玩家节点。
func _current_upgrade_phase_weights(player: Node, main_level: int) -> Dictionary:
	var current_weights: Dictionary = {}
	for rule_variant: Variant in _array(_spawn_rules().get("upgrade_phase_weights", [])):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		if _phase_rule_matches(player, main_level, _dictionary(rule.get("condition", {}))):
			current_weights = _dictionary(rule.get("weights", {}))
	return current_weights


## 作用：检查阶段规则的技能等级上下限和局内时间下限。
## 使用：player 为玩家节点；返回布尔判断或执行是否成功。
func _phase_rule_matches(player: Node, main_level: int, condition: Dictionary) -> bool:
	if condition.is_empty():
		return true
	if condition.has("main_level_min") and main_level < int(condition.get("main_level_min", 0)):
		return false
	if condition.has("main_level_max") and main_level > int(condition.get("main_level_max", 999)):
		return false
	if condition.has("elapsed_time_min") and _run_elapsed_time(player) < float(condition.get("elapsed_time_min", 0.0)):
		return false
	return true


## 作用：从玩家场景树的 enemy_spawner 读取 _elapsed_time，缺节点或属性返回零。
## 使用：player 为玩家节点。
func _run_elapsed_time(player: Node) -> float:
	if player == null:
		return 0.0
	var tree: SceneTree = player.get_tree()
	if tree == null:
		return 0.0
	var spawner: Node = tree.get_first_node_in_group(&"enemy_spawner")
	if spawner == null:
		return 0.0
	for property_info: Dictionary in spawner.get_property_list():
		if String(property_info.get("name", "")) == "_elapsed_time":
			return float(spawner.get("_elapsed_time"))
	return 0.0


## 作用：读取当前 GameData 波次配置的 spawn_rules 副本。
## 使用：由本文件 _low_hp_threshold/_low_hp_guarantee_tags 调用。
func _spawn_rules() -> Dictionary:
	var wave_config: Dictionary = GameData.get_wave_config()
	return _dictionary(wave_config.get("spawn_rules", {}))


## 作用：仅接受 Dictionary；深拷贝输出以隔离调用方修改，其余类型返回空字典。
## 使用：由本文件 get_upgrade_weight/is_upgrade_condition_met 调用；无适用数据时返回空字典。
func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 get_upgrade_weight/build_recommended_reason 调用；无匹配项时返回空数组。
func _array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
