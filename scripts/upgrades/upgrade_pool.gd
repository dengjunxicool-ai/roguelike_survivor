## 文件用途：编排技能升级、神系学习、属性升级候选的随机选取和构筑保底。
## 使用方式：generate_options 传玩家和卡片数量；专属 RNG 在编排器中使用，卡片效果由后续玩家选择入口应用。
extends RefCounted
class_name UpgradePool


const UpgradeOptionBuilderScript: Script = preload("res://scripts/upgrades/upgrade_option_builder.gd")
const UpgradeOptionScript: Script = preload("res://scripts/upgrades/upgrade_option.gd")
const UpgradeOfferPolicyScript: Script = preload("res://scripts/upgrades/upgrade_offer_policy.gd")
const UpgradeSelectionHelperScript: Script = preload("res://scripts/upgrades/upgrade_selection_helper.gd")
const SkillLearnDefinitionRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const SkillLearnOptionBuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")
const SkillOfferServiceScript: Script = preload("res://scripts/skills/skill_offer_service.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")
const SKILL_LEARN_UPGRADE_PREFIX: String = "learn_skill_"

var rarity_weights: Dictionary = {
	"common": 60.0,
	"rare": 28.0,
	"epic": 10.0,
	"legendary": 2.0
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _offer_policy: RefCounted = UpgradeOfferPolicyScript.new()
var _skill_offer_service: RefCounted = SkillOfferServiceScript.new()


## 作用：随机化升级池专属 RNG，并使用 GameData 配置覆盖默认稀有度权重。
## 使用：generate_options 传玩家和卡片数量；专属 RNG 在编排器中使用，卡片效果由后续玩家选择入口应用。
func _init() -> void:
	_rng.randomize()
	var configured_weights: Dictionary = GameData.get_rarity_weights()
	if not configured_weights.is_empty():
		rarity_weights = configured_weights.duplicate(true)


## 作用：将数量截断到非负后生成本次升级选项。
## 使用：player 为玩家节点；count 为所需数量；无匹配项时返回空数组。
func generate_options(player: Node, count: int = 3) -> Array:
	var requested_count: int = maxi(count, 0)
	if requested_count <= 0:
		return []
	return _select_growth_stage_options(player, requested_count)


## 作用：按指定神系收集调试学习卡，合并已有升级与动态技能定义并双重去重。
## 使用：player 为玩家节点；god_id 为筛选神系 ID。
func generate_debug_fire_skill_options(player: Node, god_id: StringName = &"fire") -> Array:
	var options: Array = []
	var seen_skill_ids: Dictionary = {}
	var seen_option_ids: Dictionary = {}

	for upgrade: Dictionary in GameData.get_level_up_upgrade_pool():
		var skill_id: StringName = StringName(_string_or(upgrade.get("learn_skill_id", ""), ""))
		if skill_id == &"" or not _is_debug_god_skill(skill_id, god_id):
			continue
		var upgrade_option_id: String = _string_or(upgrade.get("id", ""), "")
		if seen_skill_ids.has(skill_id) or seen_option_ids.has(upgrade_option_id):
			continue
		options.append(_make_debug_god_skill_option(player, upgrade, god_id))
		seen_skill_ids[skill_id] = true
		seen_option_ids[upgrade_option_id] = true

	for skill: Dictionary in _get_debug_god_skill_definitions(god_id):
		var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
		if skill_id == &"" or seen_skill_ids.has(skill_id):
			continue
		var synthetic_upgrade: Dictionary = _make_god_skill_learn_upgrade(skill, god_id)
		var option_id: String = _string_or(synthetic_upgrade.get("id", ""), "")
		if option_id == "" or seen_option_ids.has(option_id):
			continue
		options.append(_make_debug_god_skill_option(player, synthetic_upgrade, god_id))
		seen_skill_ids[skill_id] = true
		seen_option_ids[option_id] = true

	return options


## 作用：优先保留一张已拥有技能升级卡，再加权填充并顺序执行生存、神系及主动学习保底。
## 使用：player 为玩家节点；requested_count 为请求卡片数。
func _select_growth_stage_options(player: Node, requested_count: int) -> Array:
	var skill_level_up_options: Array = _build_skill_level_up_options(player)
	var god_skill_learn_options: Array = _build_god_skill_learn_options(player)
	var priority_options: Array = []
	priority_options.append_array(_take_options(skill_level_up_options, 1))

	var regular_options: Array = []
	regular_options.append_array(skill_level_up_options)
	regular_options.append_array(god_skill_learn_options)
	regular_options.append_array(_build_level_up_upgrade_options(player))

	var selected_options: Array = []
	_add_unique_options(selected_options, priority_options, requested_count)
	_fill_from_weighted_pool(selected_options, regular_options, requested_count)
	_enforce_guaranteed_options(player, selected_options, requested_count)
	_enforce_god_skill_learn_option(player, selected_options, requested_count)
	_enforce_ordinary_active_learn_option(player, selected_options, requested_count)
	return selected_options


## 作用：先洗牌候选，再按权重抽取并移除候选，去重填充至所需数量。
## 使用：selected_options 为原地填充的已选卡片；option_pool 为抽取时消耗的候选池；requested_count 为请求卡片数。
func _fill_from_weighted_pool(selected_options: Array, option_pool: Array, requested_count: int) -> void:
	UpgradeSelectionHelperScript.fill_from_weighted_pool(selected_options, option_pool, requested_count, _rng, rarity_weights)


## 作用：遍历可升级技能，隐藏初始技能升级卡，为其下一等级抽稀有度并生成选项。
## 使用：player 为玩家节点。
func _build_skill_level_up_options(player: Node) -> Array:
	var options: Array = []
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance == null or not bool(skill_instance.call("can_level_up")):
			continue

		var skill_id: StringName = StringName(skill_instance.get("skill_id"))
		if _is_hidden_skill_level_up(skill_instance, skill_id):
			continue
		var next_level: int = int(skill_instance.get("current_level")) + 1
		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		var skill_name: String = _string_or(skill_id, "")
		var rarity: String = "common"
		var current_rarity: String = _string_or(skill_instance.get("current_rarity"), "normal")
		var max_level: int = next_level
		if definition != null:
			skill_name = _get_definition_string(definition, "display_name", skill_name)
			max_level = int(definition.get("max_level"))
			rarity = current_rarity

		options.append(_make_option(UpgradeOptionBuilderScript.build_skill_level_up_data(skill_id, next_level, skill_name, rarity, current_rarity, max_level)))

	return options


## 作用：过滤遗物相关、不可选及零权重升级，生成携带实际选择次数的卡片。
## 使用：player 为玩家节点。
func _build_level_up_upgrade_options(player: Node) -> Array:
	var options: Array = []
	for upgrade: Dictionary in GameData.get_level_up_upgrade_pool():
		if _is_relic_related_upgrade(upgrade):
			continue
		if not _is_level_up_upgrade_available(player, upgrade):
			continue
		var weight: float = _get_level_up_upgrade_weight(player, upgrade)
		if weight <= 0.0:
			continue

		options.append(_make_option(UpgradeOptionBuilderScript.build_upgrade_data(upgrade, _get_upgrade_level(player, _string_or(upgrade.get("id", ""), "")), weight, _string_or(_offer_policy.call("build_recommended_reason", player, upgrade), ""))))

	return options


## 作用：筛选未学且准入的神系技能，生成动态学习定义并抽稀有度构建卡片。
## 使用：player 为玩家节点。
func _build_god_skill_learn_options(player: Node) -> Array:
	var options: Array = []
	for skill: Dictionary in _get_skill_learn_definitions():
		var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
		if not _is_learn_skill_upgrade_available(player, skill_id):
			continue
		if not bool(_skill_offer_service.call("is_skill_available", player, skill)):
			continue

		var upgrade: Dictionary = _make_god_skill_learn_upgrade(skill, _get_skill_god_id(skill))
		var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
		if upgrade_id == &"":
			continue
		var max_level: int = maxi(int(skill.get("max_level", upgrade.get("max_level", 1))), 1)
		var rarity: String = SkillGrowthScalingScript.pick_rarity_for_max_level(max_level, _rng)

		var option_data: Dictionary = SkillLearnOptionBuilderScript.build_option_data(skill, upgrade, rarity)
		if option_data.is_empty():
			continue
		options.append(_make_option(option_data))

	return options


## 作用：从通用神系学习卡中筛选指定神系，仅保留有效学习引用。
## 使用：player 为玩家节点；god_id 为筛选神系 ID。
func _build_fire_skill_learn_options(player: Node, god_id: StringName = &"fire") -> Array:
	var options: Array = []
	for option_variant: Variant in _build_god_skill_learn_options(player):
		var option: RefCounted = option_variant as RefCounted
		if option == null:
			continue
		var learn_skill_id: StringName = _get_option_learn_skill_id(option)
		if learn_skill_id == &"" or not _is_debug_god_skill(learn_skill_id, god_id):
			continue
		options.append(option)
	return options
	

## 作用：从 GameData 技能池查询具备 offer_rule 的可学习定义。
## 使用：由本文件 _build_god_skill_learn_options 调用。
func _get_skill_learn_definitions() -> Array[Dictionary]:
	return SkillLearnDefinitionRepositoryScript.get_skill_learn_definitions(GameData.get_skill_pool(), "offer_rule")


## 作用：按玩家实际升级选择次数和神系构建调试选项对象。
## 使用：player 为玩家节点；god_id 为筛选神系 ID。
func _make_debug_god_skill_option(player: Node, upgrade: Dictionary, god_id: StringName) -> RefCounted:
	var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
	var current_level: int = _get_upgrade_level(player, _string_or(upgrade_id, ""))
	var option: RefCounted = _make_option(UpgradeOptionBuilderScript.build_debug_data(upgrade, current_level, god_id))
	return option


## 作用：读取技能定义并判断是否归属指定调试神系。
## 使用：skill_id 为标准技能 ID；god_id 为筛选神系 ID。
func _is_debug_god_skill(skill_id: StringName, god_id: StringName) -> bool:
	return _is_debug_god_skill_definition(GameData.get_skill(skill_id), god_id)


## 作用：委托学习定义仓库检查主神系或融合神系归属。
## 使用：skill 为技能实例或定义；god_id 为筛选神系 ID。
func _is_debug_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	return SkillLearnDefinitionRepositoryScript.is_debug_god_skill_definition(skill, god_id)


## 作用：保持技能池顺序筛出指定神系且具有学习供给入口的定义副本。
## 使用：god_id 为筛选神系 ID。
func _get_debug_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill_data: Dictionary in GameData.get_skill_pool():
		var skill: Dictionary = skill_data.duplicate(true)
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		if not _is_debug_god_skill_definition(skill, god_id):
			continue
		skills.append(skill)
	return skills


## 作用：使用 learn_skill_ 稳定前缀创建动态神系学习升级。
## 使用：skill 为技能实例或定义；god_id 为筛选神系 ID。
func _make_god_skill_learn_upgrade(skill: Dictionary, god_id: StringName) -> Dictionary:
	return SkillLearnDefinitionRepositoryScript.make_god_skill_learn_upgrade(skill, god_id, SKILL_LEARN_UPGRADE_PREFIX)


## 作用：读取玩家技能管理器拥有的全部主动与被动实例，不含独立主攻击方法。
## 使用：player 为玩家节点；无匹配项时返回空数组。
func _get_owned_skill_instances(player: Node) -> Array:
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var skills_variant: Variant = skill_manager.call("get_all_skills")
		if skills_variant is Array:
			return skills_variant
	return []


## 作用：先查玩家 SkillManager 子节点，再尝试玩家公开 getter。
## 使用：player 为玩家节点；无法解析或创建时返回 null。
func _get_skill_manager(player: Node) -> Node:
	if player == null:
		return null
	var manager: Node = player.get_node_or_null("SkillManager")
	if manager != null:
		return manager
	if player.has_method("get_skill_manager"):
		var manager_variant: Variant = player.call("get_skill_manager")
		if manager_variant is Node:
			return manager_variant
	return null


## 作用：按选项 ID 与 learn_skill_id 双重去重，将候选追加到数量上限。
## 使用：target 为本次命中目标；source 为来源数据或对象；max_count 为数量上限。
func _add_unique_options(target: Array, source: Array, max_count: int) -> void:
	UpgradeSelectionHelperScript.add_unique_options(target, source, max_count)


## 作用：按原顺序取前 count 项引用，数量截断到有效范围。
## 使用：options 为候选卡片列表；count 为所需数量。
func _take_options(options: Array, count: int) -> Array:
	return UpgradeSelectionHelperScript.take_options(options, count)


## 作用：使用传入随机流原地执行 Fisher–Yates 洗牌。
## 使用：options 为候选卡片列表。
func _shuffle_options(options: Array) -> void:
	UpgradeSelectionHelperScript.shuffle_options(options, _rng)


## 作用：按候选权重累计区间抽取下标，总权重非正时改为均匀抽取。
## 使用：options 为候选卡片列表。
func _pick_weighted_option_index(options: Array) -> int:
	return UpgradeSelectionHelperScript.pick_weighted_option_index(options, _rng, rarity_weights)


## 作用：优先取载荷显式 weight，否则按卡片 rarity 查询权重并截断非负。
## 使用：generate_options 传玩家和卡片数量；专属 RNG 在编排器中使用，卡片效果由后续玩家选择入口应用。
func _get_option_weight(option: RefCounted) -> float:
	return UpgradeSelectionHelperScript.get_option_weight(option, rarity_weights)


## 作用：检查升级 ID、启用状态、学习技能资格、已选次数上限和出现条件。
## 使用：player 为玩家节点；返回布尔判断或执行是否成功。
func _is_level_up_upgrade_available(player: Node, upgrade: Dictionary) -> bool:
	var upgrade_id: String = _string_or(upgrade.get("id", ""), "")
	if upgrade_id == "" or not bool(upgrade.get("enabled", true)):
		return false
	if upgrade.has("learn_skill_id") and not _is_learn_skill_upgrade_available(player, StringName(_string_or(upgrade.get("learn_skill_id", ""), ""))):
		return false
	var max_level: int = maxi(int(upgrade.get("max_level", 1)), 1)
	if _get_upgrade_level(player, upgrade_id) >= max_level:
		return false
	return bool(_offer_policy.call("is_upgrade_condition_met", player, upgrade))


## 作用：拒绝空 ID、已拥有或已学习技能，并确认 GameData 定义存在。
## 使用：player 为玩家节点；skill_id 为标准技能 ID；返回布尔判断或执行是否成功。
func _is_learn_skill_upgrade_available(player: Node, skill_id: StringName) -> bool:
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null:
		return false
	if skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
		return false
	if skill_manager.has_method("has_learned_skill") and bool(skill_manager.call("has_learned_skill", skill_id)):
		return false
	return not GameData.get_skill(skill_id).is_empty()


## 作用：依据定义或 GameData 的 is_starting_skill 标记隐藏初始技能等级选项。
## 使用：skill_instance 为技能运行实例；skill_id 为标准技能 ID。
func _is_hidden_skill_level_up(skill_instance: RefCounted, skill_id: StringName) -> bool:
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null and definition.get("is_starting_skill") == true:
		return true
	var skill: Dictionary = GameData.get_skill(skill_id)
	return skill.get("is_starting_skill", false) == true


## 作用：按 relic_id、ID 或标签判断升级是否属于遗物相关条目。
## 使用：由本文件 _build_level_up_upgrade_options 调用；返回布尔判断或执行是否成功。
func _is_relic_related_upgrade(upgrade: Dictionary) -> bool:
	if upgrade.has("relic_id"):
		return true
	var id_text: String = _string_or(upgrade.get("id", ""), "").to_lower()
	if id_text.contains("relic"):
		return true
	for tag_variant: Variant in _get_array(upgrade.get("tags", [])):
		var tag: String = _string_or(tag_variant, "").to_lower()
		if tag == "relic" or tag.contains("relic"):
			return true
	return false


## 作用：读取卡片载荷 learn_skill_id，非学习卡返回空 ID。
## 使用：由本文件 _build_fire_skill_learn_options/_enforce_god_skill_learn_option 调用。
func _get_option_learn_skill_id(option: RefCounted) -> StringName:
	return UpgradeSelectionHelperScript.get_option_learn_skill_id(option)


## 作用：读取已选次数和最高已拥有技能等级，交给供给策略计算候选权重。
## 使用：player 为玩家节点。
func _get_level_up_upgrade_weight(player: Node, upgrade: Dictionary) -> float:
	var upgrade_level: int = _get_upgrade_level(player, _string_or(upgrade.get("id", ""), ""))
	var main_level: int = _get_highest_owned_skill_level(player)
	return float(_offer_policy.call("get_upgrade_weight", player, upgrade, upgrade_level, main_level))


## 作用：遍历已拥有技能并返回最高当前等级。
## 使用：player 为玩家节点。
func _get_highest_owned_skill_level(player: Node) -> int:
	var highest_level: int = 0
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance != null:
			highest_level = maxi(highest_level, int(skill_instance.get("current_level")))
	return highest_level


## 作用：查询缺少的低血或后期标签，用匹配卡片替换最后一项。
## 使用：player 为玩家节点；selected_options 为原地填充的已选卡片；requested_count 为请求卡片数。
func _enforce_guaranteed_options(player: Node, selected_options: Array, requested_count: int) -> void:
	var missing_tags: Array = _offer_policy.call("get_missing_guarantee_tags", player, selected_options)
	if not missing_tags.is_empty():
		_replace_with_tagged_option(player, selected_options, requested_count, _to_string_array(missing_tags))


## 作用：已有列表缺学习卡时，随机候选中取一张有效神系学习卡替换或追加。
## 使用：player 为玩家节点；selected_options 为原地填充的已选卡片；requested_count 为请求卡片数。
func _enforce_god_skill_learn_option(player: Node, selected_options: Array, requested_count: int) -> void:
	if requested_count <= 0 or _options_have_skill_learn(selected_options):
		return
	var candidates: Array = _build_god_skill_learn_options(player)
	_shuffle_options(candidates)
	for candidate_variant: Variant in candidates:
		var candidate: RefCounted = candidate_variant as RefCounted
		if candidate == null or _get_option_learn_skill_id(candidate) == &"":
			continue
		_replace_or_append_guaranteed_option(selected_options, requested_count, candidate)
		return


## 作用：直接主动技能不足两项时，按施法、直接主动、一般主动优先级补入学习卡。
## 使用：player 为玩家节点；selected_options 为原地填充的已选卡片；requested_count 为请求卡片数。
func _enforce_ordinary_active_learn_option(player: Node, selected_options: Array, requested_count: int) -> void:
	if requested_count <= 0 or _count_owned_direct_active_skills(player) >= 2:
		return
	if _options_have_direct_active_learn(selected_options):
		return
	var candidates: Array = _build_god_skill_learn_options(player)
	_shuffle_options(candidates)
	for candidate_variant: Variant in candidates:
		var candidate: RefCounted = candidate_variant as RefCounted
		if candidate == null or not _is_cast_active_learn_option(candidate):
			continue
		_replace_or_append_guaranteed_option(selected_options, requested_count, candidate)
		return
	for candidate_variant: Variant in candidates:
		var candidate: RefCounted = candidate_variant as RefCounted
		if candidate == null or not _is_direct_active_learn_option(candidate):
			continue
		_replace_or_append_guaranteed_option(selected_options, requested_count, candidate)
		return
	for candidate_variant: Variant in candidates:
		var candidate: RefCounted = candidate_variant as RefCounted
		if candidate == null or not _is_ordinary_active_learn_option(candidate):
			continue
		_replace_or_append_guaranteed_option(selected_options, requested_count, candidate)
		return


## 作用：列表达到请求容量时替换末项，否则直接追加保证卡。
## 使用：selected_options 为原地填充的已选卡片；requested_count 为请求卡片数。
func _replace_or_append_guaranteed_option(selected_options: Array, requested_count: int, candidate: RefCounted) -> void:
	if selected_options.size() >= requested_count and not selected_options.is_empty():
		selected_options[selected_options.size() - 1] = candidate
	else:
		selected_options.append(candidate)


## 作用：统计已拥有且不属初始攻击、攻击、冲刺或被动的普通主动技能。
## 使用：player 为玩家节点。
func _count_owned_ordinary_active_skills(player: Node) -> int:
	var count: int = 0
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance == null:
			continue
		var skill_id: StringName = StringName(String(skill_instance.get("skill_id")))
		var skill: Dictionary = GameData.get_skill(skill_id)
		if _is_ordinary_active_skill(skill):
			count += 1
	return count


## 作用：统计非初始技能中 cast 与 summon 类型的已拥有数量。
## 使用：player 为玩家节点。
func _count_owned_direct_active_skills(player: Node) -> int:
	var count: int = 0
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance == null:
			continue
		var skill_id: StringName = StringName(String(skill_instance.get("skill_id")))
		var skill: Dictionary = GameData.get_skill(skill_id)
		if bool(skill.get("is_starting_skill", false)):
			continue
		var skill_type: String = _string_or(skill.get("skill_type", ""), "")
		if skill_type == "cast" or skill_type == "summon":
			count += 1
	return count


## 作用：检查列表是否包含符合普通主动技能分类的学习卡。
## 使用：options 为候选卡片列表；返回布尔判断或执行是否成功。
func _options_have_ordinary_active_learn(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and _is_ordinary_active_learn_option(option):
			return true
	return false


## 作用：检查列表是否包含 cast 或 summon 类型的学习卡。
## 使用：options 为候选卡片列表；返回布尔判断或执行是否成功。
func _options_have_direct_active_learn(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and _is_direct_active_learn_option(option):
			return true
	return false


## 作用：检查卡片列表是否至少有一项携带非空 learn_skill_id。
## 使用：options 为候选卡片列表；返回布尔判断或执行是否成功。
func _options_have_skill_learn(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and _get_option_learn_skill_id(option) != &"":
			return true
	return false


## 作用：解析学习卡目标定义后判断是否是普通主动技能。
## 使用：由本文件 _enforce_ordinary_active_learn_option/_options_have_ordinary_active_learn 调用；返回布尔判断或执行是否成功。
func _is_ordinary_active_learn_option(option: RefCounted) -> bool:
	var learn_skill_id: StringName = _get_option_learn_skill_id(option)
	if learn_skill_id == &"":
		return false
	return _is_ordinary_active_skill(GameData.get_skill(learn_skill_id))


## 作用：判断学习卡目标技能类型是否为 cast 或 summon。
## 使用：由本文件 _enforce_ordinary_active_learn_option/_options_have_direct_active_learn 调用；返回布尔判断或执行是否成功。
func _is_direct_active_learn_option(option: RefCounted) -> bool:
	var learn_skill_id: StringName = _get_option_learn_skill_id(option)
	if learn_skill_id == &"":
		return false
	var skill: Dictionary = GameData.get_skill(learn_skill_id)
	var skill_type: String = _string_or(skill.get("skill_type", ""), "")
	return skill_type == "cast" or skill_type == "summon"


## 作用：判断学习卡目标是否为 cast 技能，以优先补充直接施法卡。
## 使用：由本文件 _enforce_ordinary_active_learn_option 调用；返回布尔判断或执行是否成功。
func _is_cast_active_learn_option(option: RefCounted) -> bool:
	var learn_skill_id: StringName = _get_option_learn_skill_id(option)
	if learn_skill_id == &"":
		return false
	var skill: Dictionary = GameData.get_skill(learn_skill_id)
	var skill_type: String = _string_or(skill.get("skill_type", ""), "")
	return skill_type == "cast"


## 作用：排除初始技能、攻击冲刺互斥组以及 attack、dash、passive 类型。
## 使用：skill 为技能实例或定义；返回布尔判断或执行是否成功。
func _is_ordinary_active_skill(skill: Dictionary) -> bool:
	if skill.is_empty():
		return false
	if bool(skill.get("is_starting_skill", false)):
		return false
	if _string_or(skill.get("exclusive_group", ""), "") == "attack_school":
		return false
	if _string_or(skill.get("exclusive_group", ""), "") == "dash_school":
		return false
	var skill_type: String = _string_or(skill.get("skill_type", ""), "")
	return skill_type != "attack" and skill_type != "dash" and skill_type != "passive"


## 作用：随机查找带保底标签的属性升级卡，并替换已选末项或追加首项。
## 使用：player 为玩家节点；selected_options 为原地填充的已选卡片。
func _replace_with_tagged_option(player: Node, selected_options: Array, _requested_count: int, tags: Array[String]) -> void:
	var candidates: Array = _build_level_up_upgrade_options(player)
	_shuffle_options(candidates)
	for candidate_variant: Variant in candidates:
		var candidate: RefCounted = candidate_variant as RefCounted
		if candidate == null or not bool(_offer_policy.call("option_has_any_tag", candidate, tags)):
			continue
		if selected_options.size() >= 1:
			selected_options[selected_options.size() - 1] = candidate
		else:
			selected_options.append(candidate)
		return


## 作用：读取定义字符串字段，null、空或 <null> 文本时使用备用值。
## 使用：definition 为技能定义；fallback 为缺值备用结果。
func _get_definition_string(definition: RefCounted, property_name: String, fallback: String) -> String:
	if definition == null:
		return fallback
	var value: Variant = definition.get(property_name)
	if value == null:
		return fallback
	var text: String = str(value)
	if text == "" or text == "<null>":
		return fallback
	return text


## 作用：从玩家 level_up_upgrade_levels 元数据读取实际已选次数。
## 使用：player 为玩家节点。
func _get_upgrade_level(player: Node, upgrade_id: String) -> int:
	if player == null or upgrade_id == "":
		return 0
	var levels_variant: Variant = player.get_meta("level_up_upgrade_levels", {})
	if levels_variant is Dictionary:
		var levels: Dictionary = levels_variant
		return int(levels.get(upgrade_id, 0))
	return 0


## 作用：用构建器的字典创建可被升级 UI 和选择流程消费的选项对象。
## 使用：由本文件 _build_skill_level_up_options/_build_level_up_upgrade_options 调用。
func _make_option(data: Dictionary) -> RefCounted:
	return UpgradeOptionScript.new(data)


## 作用：读取技能配置 school 并转换为稳定神系 ID。
## 使用：skill 为技能实例或定义。
func _get_skill_god_id(skill: Dictionary) -> StringName:
	return StringName(_string_or(skill.get("school", ""), ""))

## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 _is_relic_related_upgrade 调用；无匹配项时返回空数组。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 _get_debug_god_skill_definitions 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)


## 作用：按输入数组顺序转换元素为字符串，返回独立的强类型数组。
## 使用：由本文件 _enforce_guaranteed_options 调用。
func _to_string_array(value: Array) -> Array[String]:
	var strings: Array[String] = []
	for item: Variant in value:
		strings.append(_string_or(item, ""))
	return strings
