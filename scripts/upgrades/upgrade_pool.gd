extends RefCounted
class_name UpgradePool
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const UpgradeOptionScript: Script = preload("res://scripts/upgrades/upgrade_option.gd")
const UpgradeOfferPolicyScript: Script = preload("res://scripts/upgrades/upgrade_offer_policy.gd")
const SkillOfferServiceScript: Script = preload("res://scripts/skills/skill_offer_service.gd")
const SKILLS_DATA_PATH: String = DataPathsScript.SKILLS_PATH
const FIRE_SKILL_LEARN_UPGRADE_PREFIX: String = "learn_fire_skill_"

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
	var fire_skill_learn_options: Array = _build_fire_skill_learn_options(player)
	var priority_options: Array = []
	priority_options.append_array(_take_options(skill_level_up_options, 1))

	var regular_options: Array = []
	regular_options.append_array(skill_level_up_options)
	regular_options.append_array(_build_level_up_upgrade_options(player))
	regular_options.append_array(fire_skill_learn_options)

	var selected_options: Array = []
	_add_unique_options(selected_options, priority_options, requested_count)
	_fill_from_weighted_pool(selected_options, regular_options, requested_count)
	_enforce_guaranteed_options(player, selected_options, requested_count)
	return selected_options


func _fill_from_weighted_pool(selected_options: Array, option_pool: Array, requested_count: int) -> void:
	_shuffle_options(option_pool)
	while selected_options.size() < requested_count and not option_pool.is_empty():
		var option_index: int = _pick_weighted_option_index(option_pool)
		var option: RefCounted = option_pool[option_index]
		option_pool.remove_at(option_index)
		_add_unique_options(selected_options, [option], requested_count)


func _build_skill_level_up_options(player: Node) -> Array:
	var options: Array = []
	for skill_instance: RefCounted in _get_owned_skill_instances(player):
		if skill_instance == null or not bool(skill_instance.call("can_level_up")):
			continue

		var skill_id: StringName = StringName(skill_instance.get("skill_id"))
		var next_level: int = int(skill_instance.get("current_level")) + 1
		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		var skill_name: String = _string_or(skill_id, "")
		var rarity: String = "common"
		var description: String = "提升 %s 至 Lv%d。" % [skill_name, next_level]
		var max_level: int = next_level
		if definition != null:
			skill_name = _get_definition_string(definition, "display_name", skill_name)
			rarity = _get_definition_string(definition, "rarity", "common")
			max_level = int(definition.get("max_level"))
			description = _get_skill_level_description(definition, next_level, description)

		options.append(_make_option({
			"id": "skill_level_up:%s:%d" % [_string_or(skill_id, ""), next_level],
			"type": "skill_level_up",
			"display_name": "%s Lv%d" % [skill_name, next_level],
			"description": description,
			"rarity": rarity,
			"tags": ["skill", "level_up"],
			"affected_origin": "当前技能",
			"does_not_affect": "不学习新的技能。",
			"recommended_reason": "提高已拥有技能的等级。",
			"level_text": "Lv%d / %d" % [next_level, maxi(max_level, next_level)],
			"payload": {
				"skill_id": skill_id,
				"level": next_level
			}
		}))

	return options


func _build_level_up_upgrade_options(player: Node) -> Array:
	var options: Array = []
	for upgrade: Dictionary in GameData.get_level_up_upgrade_pool():
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


func _build_fire_skill_learn_options(player: Node, god_id: StringName = &"fire") -> Array:
	var options: Array = []
	for skill: Dictionary in _get_skill_learn_definitions():
		var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
		if not _is_learn_skill_upgrade_available(player, skill_id):
			continue
		if not bool(_skill_offer_service.call("is_skill_available", player, skill)):
			continue

		var upgrade: Dictionary = _make_god_skill_learn_upgrade(skill, god_id)
		var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
		if upgrade_id == &"":
			continue

		options.append(_make_option({
			"id": "level_up_upgrade:%s" % _string_or(upgrade_id, ""),
			"type": "level_up_upgrade",
			"display_name": _string_or(upgrade.get("display_name", skill.get("display_name", skill_id)), _string_or(skill_id, "")),
			"description": _get_level_up_upgrade_description(upgrade),
			"rarity": _string_or(upgrade.get("rarity", skill.get("rarity", "common")), "common"),
			"background_texture": _get_option_background_texture(skill),
			"tags": _get_array(upgrade.get("tags", [])),
			"affected_origin": "神系技能",
			"does_not_affect": "不替换角色初始技能。",
			"recommended_reason": "从神系技能池学习一个新技能。",
			"level_text": "Lv1 / 1",
			"payload": {
				"upgrade_id": upgrade_id,
				"learn_skill_id": skill_id
			}
		}))

	return options
	

func _get_skill_learn_definitions() -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill: Dictionary in GameData.get_skill_pool():
		if StringName(_string_or(skill.get("id", ""), "")) == &"":
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		skills.append(skill.duplicate(true))
	return skills


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
	if skill.is_empty():
		return false
	if StringName(_string_or(skill.get("id", ""), "")) == &"":
		return false
	if StringName(_string_or(skill.get("god_id", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("school", ""), "")) == god_id:
		return true
	if StringName(_string_or(skill.get("fusion_school", ""), "")) == god_id:
		return true
	if god_id == &"fire" and _to_string_array(_get_array(skill.get("tags", []))).has("fire"):
		return true
	return false


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
	var skill_id: String = _string_or(skill.get("id", ""), "")
	if skill_id == "":
		return {}
	var tags: Array[String] = _to_string_array(_get_array(skill.get("tags", [])))
	if not tags.has("skill"):
		tags.push_front("skill")
	var god_text: String = _string_or(god_id, "")
	if god_text != "" and not tags.has(god_text):
		tags.push_front(god_text)
	var description: String = _string_or(skill.get("description", "Learn %s." % skill_id), "Learn %s." % skill_id)
	return {
		"id": "%s%s" % [FIRE_SKILL_LEARN_UPGRADE_PREFIX, skill_id],
		"display_name": _string_or(skill.get("display_name", skill_id), skill_id),
		"description": description,
		"rarity": _string_or(skill.get("rarity", "common"), "common"),
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": StringName(skill_id),
		"god_id": god_id,
		"level_descriptions": [description]
	}


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
	var existing_ids: Dictionary = {}
	var existing_learn_skill_ids: Dictionary = {}
	for option_variant: Variant in target:
		var option: RefCounted = option_variant as RefCounted
		if option != null:
			existing_ids[_string_or(option.get("id"), "")] = true
			var learn_skill_id: StringName = _get_option_learn_skill_id(option)
			if learn_skill_id != &"":
				existing_learn_skill_ids[learn_skill_id] = true

	for option_variant: Variant in source:
		if target.size() >= max_count:
			return
		var option: RefCounted = option_variant as RefCounted
		if option == null:
			continue
		var option_id: String = _string_or(option.get("id"), "")
		if existing_ids.has(option_id):
			continue
		var learn_skill_id: StringName = _get_option_learn_skill_id(option)
		if learn_skill_id != &"" and existing_learn_skill_ids.has(learn_skill_id):
			continue
		target.append(option)
		existing_ids[option_id] = true
		if learn_skill_id != &"":
			existing_learn_skill_ids[learn_skill_id] = true


func _take_options(options: Array, count: int) -> Array:
	var taken_options: Array = []
	var take_count: int = mini(maxi(count, 0), options.size())
	for option_index in range(take_count):
		taken_options.append(options[option_index])
	return taken_options


func _shuffle_options(options: Array) -> void:
	for option_index in range(options.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, option_index)
		var value: Variant = options[option_index]
		options[option_index] = options[swap_index]
		options[swap_index] = value


func _pick_weighted_option_index(options: Array) -> int:
	if options.is_empty():
		return 0

	var total_weight: float = 0.0
	for option_variant: Variant in options:
		total_weight += _get_option_weight(option_variant as RefCounted)
	if total_weight <= 0.0:
		return _rng.randi_range(0, options.size() - 1)

	var roll: float = _rng.randf_range(0.0, total_weight)
	var accumulated: float = 0.0
	for option_index in range(options.size()):
		accumulated += _get_option_weight(options[option_index] as RefCounted)
		if roll <= accumulated:
			return option_index
	return options.size() - 1


func _get_option_weight(option: RefCounted) -> float:
	if option == null:
		return 0.0
	var payload_variant: Variant = option.get("payload")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		if payload.has("weight"):
			return maxf(float(payload.get("weight", 0.0)), 0.0)
	return maxf(float(rarity_weights.get(_string_or(option.get("rarity"), ""), 1.0)), 0.0)


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


func _get_option_learn_skill_id(option: RefCounted) -> StringName:
	if option == null:
		return &""
	var payload_variant: Variant = option.get("payload")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		if payload.has("learn_skill_id"):
			return StringName(_string_or(payload.get("learn_skill_id", ""), ""))
	return &""


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


func _get_skill_level_description(definition: RefCounted, next_level: int, fallback: String) -> String:
	var descriptions: Array = _get_array(definition.get("level_descriptions"))
	var index: int = next_level - 1
	if index >= 0 and index < descriptions.size():
		return str(descriptions[index])
	return fallback


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
