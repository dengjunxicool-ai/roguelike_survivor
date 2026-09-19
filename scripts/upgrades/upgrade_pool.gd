extends RefCounted
class_name UpgradePool
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const UpgradeOptionScript: Script = preload("res://scripts/upgrades/upgrade_option.gd")
const UpgradeOfferPolicyScript: Script = preload("res://scripts/upgrades/upgrade_offer_policy.gd")
const UpgradeSelectionHelperScript: Script = preload("res://scripts/upgrades/upgrade_selection_helper.gd")
const SkillLearnDefinitionRepositoryScript: Script = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
const SkillLearnOptionBuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")
const SkillOfferServiceScript: Script = preload("res://scripts/skills/skill_offer_service.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")
const SKILLS_DATA_PATH: String = DataPathsScript.SKILLS_PATH
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


func _init() -> void:
	_rng.randomize()
	var configured_weights: Dictionary = GameData.get_rarity_weights()
	if not configured_weights.is_empty():
		rarity_weights = configured_weights.duplicate(true)


func generate_options(player: Node, count: int = 3) -> Array:
	var requested_count: int = maxi(count, 0)
	if requested_count <= 0:
		return []
	return _select_growth_stage_options(player, requested_count)


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


func _fill_from_weighted_pool(selected_options: Array, option_pool: Array, requested_count: int) -> void:
	UpgradeSelectionHelperScript.fill_from_weighted_pool(selected_options, option_pool, requested_count, _rng, rarity_weights)


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
			rarity = SkillGrowthScalingScript.pick_rarity_for_max_level(max_level, _rng)

		options.append(_make_option({
			"id": "skill_level_up:%s:%d:%s" % [_string_or(skill_id, ""), next_level, rarity],
			"type": "skill_level_up",
			"display_name": "%s Lv%d" % [skill_name, next_level],
			"description": _build_skill_level_up_description(skill_name, next_level),
			"rarity": rarity,
			"tags": ["skill", "level_up"],
			"affected_origin": "当前技能",
			"does_not_affect": "不学习新的技能。",
			"recommended_reason": "提高已拥有技能的等级。",
			"level_text": "Lv%d / %d" % [next_level, maxi(max_level, next_level)],
			"payload": {
				"skill_id": skill_id,
				"level": next_level,
				"current_rarity": current_rarity,
				"target_rarity": rarity
			}
		}))

	return options


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

		var payload: Dictionary = {
			"upgrade_id": StringName(_string_or(upgrade.get("id", ""), "")),
			"weight": weight
		}
		if upgrade.has("learn_skill_id"):
			payload["learn_skill_id"] = StringName(_string_or(upgrade.get("learn_skill_id", ""), ""))

		options.append(_make_option({
			"id": "level_up_upgrade:%s" % _string_or(upgrade.get("id", ""), ""),
			"type": "level_up_upgrade",
			"display_name": _string_or(upgrade.get("display_name", upgrade.get("id", "")), _string_or(upgrade.get("id", ""), "")),
			"description": _get_level_up_upgrade_description(upgrade),
			"rarity": _string_or(upgrade.get("rarity", "common"), "common"),
			"background_texture": _get_option_background_texture(upgrade),
			"tags": _get_array(upgrade.get("tags", [])),
			"affected_origin": _infer_affected_origin(upgrade),
			"does_not_affect": _infer_does_not_affect(upgrade),
			"recommended_reason": _string_or(_offer_policy.call("build_recommended_reason", player, upgrade), ""),
			"level_text": "Lv%d / %d" % [_get_upgrade_level(player, _string_or(upgrade.get("id", ""), "")) + 1, maxi(int(upgrade.get("max_level", 1)), 1)],
			"payload": payload
		}))

	return options


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
	

func _get_skill_learn_definitions() -> Array[Dictionary]:
	return SkillLearnDefinitionRepositoryScript.get_skill_learn_definitions(GameData.get_skill_pool(), "offer_rule")


func _make_debug_god_skill_option(player: Node, upgrade: Dictionary, god_id: StringName) -> RefCounted:
	var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
	var current_level: int = _get_upgrade_level(player, _string_or(upgrade_id, ""))
	var option: RefCounted = _make_option({
		"id": "level_up_upgrade:%s" % _string_or(upgrade_id, ""),
		"type": "level_up_upgrade",
		"display_name": _string_or(upgrade.get("display_name", upgrade_id), _string_or(upgrade_id, "")),
		"description": _get_debug_upgrade_description(upgrade, current_level),
		"rarity": _string_or(upgrade.get("rarity", "common"), "common"),
		"background_texture": _get_option_background_texture(upgrade),
		"tags": _get_array(upgrade.get("tags", [])),
		"affected_origin": "Dev / God skill pool",
		"does_not_affect": "Dev list ignores normal offer count.",
		"recommended_reason": "Dev card for inspecting god skill runtime behavior.",
		"level_text": "Lv%d / %d" % [current_level + 1, maxi(int(upgrade.get("max_level", 1)), 1)],
		"payload": {
			"upgrade_id": upgrade_id,
			"learn_skill_id": StringName(_string_or(upgrade.get("learn_skill_id", ""), "")),
			"debug_god_id": god_id
		}
	})
	return option


func _is_debug_god_skill(skill_id: StringName, god_id: StringName) -> bool:
	var skill: Dictionary = GameData.get_skill(skill_id)
	if skill.is_empty():
		skill = _get_debug_skill_definition_from_file(skill_id)
	return _is_debug_god_skill_definition(skill, god_id)


func _is_debug_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	return SkillLearnDefinitionRepositoryScript.is_debug_god_skill_definition(skill, god_id)


func _get_debug_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	var document: Dictionary = _load_debug_skills_document()
	for skill_variant: Variant in _get_array(document.get("skills", [])):
		if not (skill_variant is Dictionary):
			continue
		var skill: Dictionary = (skill_variant as Dictionary).duplicate(true)
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		if not _is_debug_god_skill_definition(skill, god_id):
			continue
		skills.append(skill)
	return skills


func _get_debug_skill_definition_from_file(skill_id: StringName) -> Dictionary:
	var document: Dictionary = _load_debug_skills_document()
	for section_name: String in ["skills", "starting_skills"]:
		for skill_variant: Variant in _get_array(document.get(section_name, [])):
			if not (skill_variant is Dictionary):
				continue
			var skill: Dictionary = skill_variant
			if StringName(_string_or(skill.get("id", ""), "")) == skill_id:
				return skill.duplicate(true)
	return {}


func _make_god_skill_learn_upgrade(skill: Dictionary, god_id: StringName) -> Dictionary:
	return SkillLearnDefinitionRepositoryScript.make_god_skill_learn_upgrade(skill, god_id, SKILL_LEARN_UPGRADE_PREFIX)


func _load_debug_skills_document() -> Dictionary:
	return JsonDataLoaderScript.load_dictionary(SKILLS_DATA_PATH, "UpgradePool", JsonDataLoaderScript.REPORT_SILENT)


func _get_owned_skill_instances(player: Node) -> Array:
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var skills_variant: Variant = skill_manager.call("get_all_skills")
		if skills_variant is Array:
			return skills_variant
	return []


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


func _add_unique_options(target: Array, source: Array, max_count: int) -> void:
	UpgradeSelectionHelperScript.add_unique_options(target, source, max_count)


func _take_options(options: Array, count: int) -> Array:
	return UpgradeSelectionHelperScript.take_options(options, count)


func _shuffle_options(options: Array) -> void:
	UpgradeSelectionHelperScript.shuffle_options(options, _rng)


func _pick_weighted_option_index(options: Array) -> int:
	return UpgradeSelectionHelperScript.pick_weighted_option_index(options, _rng, rarity_weights)


func _get_option_weight(option: RefCounted) -> float:
	return UpgradeSelectionHelperScript.get_option_weight(option, rarity_weights)


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
	if not GameData.get_skill(skill_id).is_empty():
		return true
	return not _get_debug_skill_definition_from_file(skill_id).is_empty()


func _is_hidden_skill_level_up(skill_instance: RefCounted, skill_id: StringName) -> bool:
	if skill_id == &"fireball":
		return true
	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition != null and definition.get("is_starting_skill") == true:
		return true
	var skill: Dictionary = GameData.get_skill(skill_id)
	return skill.get("is_starting_skill", false) == true


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


func _get_option_learn_skill_id(option: RefCounted) -> StringName:
	return UpgradeSelectionHelperScript.get_option_learn_skill_id(option)


func _get_level_up_upgrade_weight(player: Node, upgrade: Dictionary) -> float:
	var upgrade_level: int = _get_upgrade_level(player, _string_or(upgrade.get("id", ""), ""))
	var main_level: int = _get_highest_owned_skill_level(player)
	return float(_offer_policy.call("get_upgrade_weight", player, upgrade, upgrade_level, main_level))


func _get_highest_owned_skill_level(player: Node) -> int:
	var highest_level: int = 0
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance != null:
			highest_level = maxi(highest_level, int(skill_instance.get("current_level")))
	return highest_level


func _enforce_guaranteed_options(player: Node, selected_options: Array, requested_count: int) -> void:
	var missing_tags: Array = _offer_policy.call("get_missing_guarantee_tags", player, selected_options)
	if not missing_tags.is_empty():
		_replace_with_tagged_option(player, selected_options, requested_count, _to_string_array(missing_tags))


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


func _replace_or_append_guaranteed_option(selected_options: Array, requested_count: int, candidate: RefCounted) -> void:
	if selected_options.size() >= requested_count and not selected_options.is_empty():
		selected_options[selected_options.size() - 1] = candidate
	else:
		selected_options.append(candidate)


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


func _count_owned_direct_active_skills(player: Node) -> int:
	var count: int = 0
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance == null:
			continue
		var skill_id: StringName = StringName(String(skill_instance.get("skill_id")))
		if skill_id == &"fireball":
			continue
		var skill: Dictionary = GameData.get_skill(skill_id)
		var skill_type: String = _string_or(skill.get("skill_type", skill.get("type", skill.get("category", ""))), "")
		if skill_type == "cast" or skill_type == "summon":
			count += 1
	return count


func _options_have_ordinary_active_learn(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and _is_ordinary_active_learn_option(option):
			return true
	return false


func _options_have_direct_active_learn(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and _is_direct_active_learn_option(option):
			return true
	return false


func _options_have_skill_learn(options: Array) -> bool:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and _get_option_learn_skill_id(option) != &"":
			return true
	return false


func _is_ordinary_active_learn_option(option: RefCounted) -> bool:
	var learn_skill_id: StringName = _get_option_learn_skill_id(option)
	if learn_skill_id == &"":
		return false
	return _is_ordinary_active_skill(GameData.get_skill(learn_skill_id))


func _is_direct_active_learn_option(option: RefCounted) -> bool:
	var learn_skill_id: StringName = _get_option_learn_skill_id(option)
	if learn_skill_id == &"":
		return false
	var skill: Dictionary = GameData.get_skill(learn_skill_id)
	var skill_type: String = _string_or(skill.get("skill_type", skill.get("type", skill.get("category", ""))), "")
	return skill_type == "cast" or skill_type == "summon"


func _is_cast_active_learn_option(option: RefCounted) -> bool:
	var learn_skill_id: StringName = _get_option_learn_skill_id(option)
	if learn_skill_id == &"":
		return false
	var skill: Dictionary = GameData.get_skill(learn_skill_id)
	var skill_type: String = _string_or(skill.get("skill_type", skill.get("type", skill.get("category", ""))), "")
	return skill_type == "cast"


func _is_ordinary_active_skill(skill: Dictionary) -> bool:
	if skill.is_empty():
		return false
	if bool(skill.get("is_starting_skill", false)):
		return false
	if _string_or(skill.get("exclusive_group", ""), "") == "attack_school":
		return false
	if _string_or(skill.get("exclusive_group", ""), "") == "dash_school":
		return false
	var skill_type: String = _string_or(skill.get("skill_type", skill.get("type", skill.get("category", ""))), "")
	return skill_type != "attack" and skill_type != "dash" and skill_type != "passive"


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


func _build_skill_level_up_description(skill_name: String, next_level: int) -> String:
	return "提升 %s 至 Lv%d。" % [skill_name, next_level]


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


func _get_level_up_upgrade_description(upgrade: Dictionary) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


func _infer_affected_origin(upgrade: Dictionary) -> String:
	var tags: Array = _get_array(upgrade.get("tags", []))
	if tags.has("dot"):
		return "DOT"
	if tags.has("reaction"):
		return "反应"
	if tags.has("trap"):
		return "陷阱"
	if tags.has("field") or tags.has("area"):
		return "领域 / 范围"
	if tags.has("boss"):
		return "精英 / Boss"
	if tags.has("survival"):
		return "生存"
	if tags.has("mobility"):
		return "移动"
	return "通用属性"


func _infer_does_not_affect(upgrade: Dictionary) -> String:
	var tags: Array = _get_array(upgrade.get("tags", []))
	if tags.has("dot"):
		return "不直接提高命中伤害、陷阱伤害或反应触发次数。"
	if tags.has("reaction"):
		return "不直接提高 DOT tick、普通命中伤害或状态施加频率。"
	if tags.has("boss"):
		return "不影响普通怪清场效率，除非描述中另有说明。"
	if tags.has("survival"):
		return "不直接提高伤害输出或资源收益。"
	if tags.has("trap"):
		return "不直接提高非陷阱类技能、DOT 或反应伤害。"
	return "不影响未在标签和效果中列出的伤害来源。"


func _get_debug_upgrade_description(upgrade: Dictionary, current_level: int) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if current_level >= 0 and current_level < descriptions.size():
		return _string_or(descriptions[current_level], "")
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


func _get_upgrade_level(player: Node, upgrade_id: String) -> int:
	if player == null or upgrade_id == "":
		return 0
	var levels_variant: Variant = player.get_meta("level_up_upgrade_levels", {})
	if levels_variant is Dictionary:
		var levels: Dictionary = levels_variant
		return int(levels.get(upgrade_id, 0))
	return 0


func _make_option(data: Dictionary) -> RefCounted:
	return UpgradeOptionScript.new(data)


func _get_option_background_texture(primary: Dictionary, fallback: Dictionary = {}) -> String:
	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(primary.get(key, ""), "")
		if value != "":
			return value

	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(fallback.get(key, ""), "")
		if value != "":
			return value

	return ""


func _get_skill_god_id(skill: Dictionary) -> StringName:
	for key: String in ["god_id", "school", "fusion_school"]:
		var value: String = _string_or(skill.get(key, ""), "")
		if value != "":
			return StringName(value)
	for tag_variant: Variant in _get_array(skill.get("tags", [])):
		var tag: String = _string_or(tag_variant, "")
		if tag in ["fire", "frost", "thunder", "curse", "holy", "chaos"]:
			return StringName(tag)
	return &""


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)


func _to_string_array(value: Array) -> Array[String]:
	var strings: Array[String] = []
	for item: Variant in value:
		strings.append(_string_or(item, ""))
	return strings
