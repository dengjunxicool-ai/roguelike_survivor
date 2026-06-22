extends RefCounted
class_name UpgradePool


const UpgradeOptionScript: Script = preload("res://scripts/upgrades/upgrade_option.gd")
const UpgradeOfferPolicyScript: Script = preload("res://scripts/upgrades/upgrade_offer_policy.gd")
const SKILLS_DATA_PATH: String = "res://data/skills.json"
const FIRE_SKILL_LEARN_UPGRADE_PREFIX: String = "learn_fire_skill_"

var rarity_weights: Dictionary = {
	"common": 60.0,
	"rare": 28.0,
	"epic": 10.0,
	"legendary": 2.0
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _offer_policy: RefCounted = UpgradeOfferPolicyScript.new()


func _init() -> void:
	_rng.randomize()
	var configured_weights: Dictionary = GameData.get_rarity_weights()
	if not configured_weights.is_empty():
		rarity_weights = configured_weights.duplicate(true)


func generate_options(player: Node, count: int = 3) -> Array:
	var requested_count: int = maxi(count, 0)
	if requested_count <= 0:
		return []

	var branch_choice_options: Array = _build_branch_choice_options(player)
	if not branch_choice_options.is_empty():
		return _select_branch_choice_stage_options(player, branch_choice_options, requested_count)

	return _select_growth_stage_options(player, requested_count)


func generate_debug_full_weapon_options(player: Node) -> Array:
	var runtime: Node = _get_character_runtime(player)
	if runtime == null:
		return []

	var weapon_id: StringName = _get_current_weapon_id(player)
	var skill_id: StringName = _get_current_weapon_skill_id(player)
	var selected_branch_id: StringName = _get_debug_selected_branch_id(player, runtime, skill_id)
	var options: Array = []
	for branch_id_variant: Variant in runtime.call("get_equipped_weapon_branch_ids"):
		var branch_id: StringName = StringName(String(branch_id_variant))
		var branch: Dictionary = _get_branch_definition(branch_id)
		if branch.is_empty() or StringName(String(branch.get("weapon_id", ""))) != weapon_id:
			continue
		if selected_branch_id == &"":
			options.append(_make_debug_branch_option(skill_id, branch, 2))
			continue
		if branch_id != selected_branch_id:
			continue
		for target_level in [3, 4, 5]:
			if _has_debug_branch_level_applied(player, skill_id, branch_id, int(target_level)):
				continue
			if not _get_branch_level_config(branch, int(target_level)).is_empty():
				options.append(_make_debug_branch_option(skill_id, branch, int(target_level)))

	for upgrade: Dictionary in GameData.get_level_up_upgrade_pool():
		if _is_debug_level_up_upgrade_for_weapon(upgrade, weapon_id):
			options.append(_make_debug_level_up_upgrade_option(player, upgrade))
	return options


func generate_debug_fire_skill_options(player: Node, god_id: StringName = &"fire") -> Array:
	var options: Array = []
	var seen_skill_ids: Dictionary = {}
	var seen_option_ids: Dictionary = {}

	for upgrade: Dictionary in GameData.get_level_up_upgrade_pool():
		var skill_id: StringName = StringName(String(upgrade.get("learn_skill_id", "")))
		if skill_id == &"" or not _is_debug_god_skill(skill_id, god_id):
			continue
		if seen_skill_ids.has(skill_id) or seen_option_ids.has(String(upgrade.get("id", ""))):
			continue
		options.append(_make_debug_fire_level_up_upgrade_option(player, upgrade, god_id))
		seen_skill_ids[skill_id] = true
		seen_option_ids[String(upgrade.get("id", ""))] = true

	for skill: Dictionary in _get_debug_god_skill_definitions(god_id):
		var skill_id: StringName = StringName(String(skill.get("id", "")))
		if skill_id == &"" or seen_skill_ids.has(skill_id):
			continue
		var synthetic_upgrade: Dictionary = _make_debug_learn_skill_upgrade(skill, god_id)
		var option_id: String = String(synthetic_upgrade.get("id", ""))
		if option_id == "" or seen_option_ids.has(option_id):
			continue
		options.append(_make_debug_fire_level_up_upgrade_option(player, synthetic_upgrade, god_id))
		seen_skill_ids[skill_id] = true
		seen_option_ids[option_id] = true

	return options


func _select_branch_choice_stage_options(player: Node, branch_choice_options: Array, requested_count: int) -> Array:
	_shuffle_options(branch_choice_options)
	var selected_options: Array = []
	var weapon_tendency_count: int = maxi(requested_count - 1, 0)
	_add_unique_options(selected_options, _take_options(branch_choice_options, weapon_tendency_count), requested_count)
	_fill_from_weighted_pool(selected_options, _build_level_up_upgrade_options(player), requested_count)
	return selected_options


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
		if not _is_current_weapon_skill(player, skill_id):
			continue

		var next_level: int = int(skill_instance.get("current_level")) + 1
		if next_level < 3 or next_level > 5:
			continue

		var branch_level_config: Dictionary = _get_selected_branch_level_config(player, next_level)
		if branch_level_config.is_empty():
			continue

		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		var skill_name: String = String(skill_id)
		if definition != null:
			skill_name = String(definition.get("display_name"))

		options.append(_make_option({
			"id": "skill_level_up:%s:%d" % [String(skill_id), next_level],
			"type": "skill_level_up",
			"display_name": String(branch_level_config.get("display_name", "%s Lv.%d" % [skill_name, next_level])),
			"description": String(branch_level_config.get("description", "description==分支 Lv.%d?" % next_level)),
			"rarity": String(branch_level_config.get("rarity", "rare")),
			"background_texture": _get_option_background_texture(branch_level_config),
			"tags": ["主攻击", "分支", "Lv%d" % next_level],
			"affected_origin": "主攻击 / 当前分支",
			"does_not_affect": "不直接提高其他未装备武器，也不改变地图奖励。",
			"recommended_reason": "这是当前武器的核心成长，能推进 Lv3 / Lv5 成型节奏。",
			"level_text": "Lv%d / 5" % next_level,
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
			"upgrade_id": StringName(String(upgrade.get("id", ""))),
			"weight": weight
		}
		if upgrade.has("learn_skill_id"):
			payload["learn_skill_id"] = StringName(String(upgrade.get("learn_skill_id", "")))

		options.append(_make_option({
			"id": "level_up_upgrade:%s" % String(upgrade.get("id", "")),
			"type": "level_up_upgrade",
			"display_name": String(upgrade.get("display_name", upgrade.get("id", ""))),
			"description": _get_level_up_upgrade_description(upgrade),
			"rarity": String(upgrade.get("rarity", "common")),
			"background_texture": _get_option_background_texture(upgrade),
			"tags": _get_array(upgrade.get("tags", [])),
			"affected_origin": _infer_affected_origin(upgrade),
			"does_not_affect": _infer_does_not_affect(upgrade),
			"recommended_reason": _build_recommended_reason(player, upgrade),
			"level_text": "Lv%d / %d" % [_get_upgrade_level(player, String(upgrade.get("id", ""))) + 1, maxi(int(upgrade.get("max_level", 1)), 1)],
			"payload": payload
		}))

	return options


func _build_fire_skill_learn_options(player: Node) -> Array:
	var options: Array = []
	for skill: Dictionary in _get_fire_skill_definitions():
		var skill_id: StringName = StringName(String(skill.get("id", "")))
		if not _is_learn_skill_upgrade_available(player, skill_id):
			continue

		var upgrade: Dictionary = _make_fire_skill_learn_upgrade(skill)
		var upgrade_id: StringName = StringName(String(upgrade.get("id", "")))
		if upgrade_id == &"":
			continue

		options.append(_make_option({
			"id": "level_up_upgrade:%s" % String(upgrade_id),
			"type": "level_up_upgrade",
			"display_name": String(upgrade.get("display_name", skill.get("display_name", skill_id))),
			"description": _get_level_up_upgrade_description(upgrade),
			"rarity": String(upgrade.get("rarity", skill.get("rarity", "common"))),
			"background_texture": _get_option_background_texture(skill),
			"tags": _get_array(upgrade.get("tags", [])),
			"affected_origin": "Fire Skill",
			"does_not_affect": "Does not replace the current weapon branch.",
			"recommended_reason": "Learn a new fire skill from the god skill pool.",
			"level_text": "Lv1 / 1",
			"payload": {
				"upgrade_id": upgrade_id,
				"learn_skill_id": skill_id
			}
		}))

	return options


func _build_branch_choice_options(player: Node) -> Array:
	var options: Array = []
	var branch_system: Node = _get_weapon_branch_system(player)
	if branch_system == null or not branch_system.has_method("get_available_branches"):
		return options

	var skill_id: StringName = _get_current_weapon_skill_id(player)
	for branch: Dictionary in branch_system.call("get_available_branches", player):
		var branch_id: StringName = StringName(String(branch.get("id", "")))
		if branch_id == &"":
			continue

		var level_config: Dictionary = _get_branch_level_config(branch, 2)
		options.append(_make_option({
			"id": "branch_choice:%s:%s" % [String(skill_id), String(branch_id)],
			"type": "branch_choice",
			"display_name": String(level_config.get("display_name", branch.get("display_name", "%s" % String(branch_id)))),
			"description": _build_branch_choice_description(branch, level_config),
			"rarity": String(level_config.get("rarity", branch.get("rarity", "rare"))),
			"background_texture": _get_option_background_texture(level_config, branch),
			"tags": _build_branch_tags(branch),
			"affected_origin": _infer_weapon_origin_text(player),
			"does_not_affect": "不直接提高其他分支，也不改变角色基础弱点。",
			"recommended_reason": "首个分支会决定本局武器路线，Lv3 与 Lv5 会沿此方向深化。",
			"level_text": "Lv2 / 5",
			"payload": {
				"skill_id": skill_id,
				"branch_id": branch_id,
				"branch": branch.duplicate(true)
			}
		}))

	return options


func _build_branch_choice_description(branch: Dictionary, level_config: Dictionary) -> String:
	## var role: String = String(branch.get("role", "武器倾向"))
	var immediate: String = String(level_config.get("description", branch.get("description", "选择该成长方向。")))
	var level_3: Dictionary = _get_branch_level_config(branch, 3)
	var level_5: Dictionary = _get_branch_level_config(branch, 5)
	var level_3_description: String = String(level_3.get("description", "Lv3的默认描述"))
	var level_5_description: String = String(level_5.get("description", "Lv5的默认描述"))
	return "效果\n %s\n Lv3: %s\n Lv5: %s\n" % [
		immediate,
		level_3_description,
		level_5_description
	]


func _make_debug_branch_option(skill_id: StringName, branch: Dictionary, target_level: int) -> RefCounted:
	var branch_id: StringName = StringName(String(branch.get("id", "")))
	var level_config: Dictionary = _get_branch_level_config(branch, target_level)
	var display_name: String = String(level_config.get("display_name", branch.get("display_name", branch_id)))
	if target_level > 2 and not display_name.contains("Lv"):
		display_name = "%s Lv%d" % [display_name, target_level]
	return _make_option({
		"id": "branch_choice:%s:%s" % [String(skill_id), String(branch_id)] if target_level == 2 else "skill_level_up:%s:%d:%s" % [String(skill_id), target_level, String(branch_id)],
		"type": "branch_choice" if target_level == 2 else "skill_level_up",
		"display_name": display_name,
		"description": String(level_config.get("description", branch.get("description", "Apply branch level config."))),
		"rarity": String(level_config.get("rarity", branch.get("rarity", "rare"))),
		"background_texture": _get_option_background_texture(level_config, branch),
		"tags": _build_debug_branch_tags(branch, target_level),
		"affected_origin": "Dev / Current weapon full pool",
		"does_not_affect": "Dev mode keeps branch mutual exclusion.",
		"recommended_reason": "Dev card for inspecting current weapon growth within the selected branch.",
		"level_text": "Lv%d / 5" % target_level,
		"payload": {
			"skill_id": skill_id,
			"branch_id": branch_id,
			"level": target_level
		}
	})


func _make_debug_level_up_upgrade_option(player: Node, upgrade: Dictionary) -> RefCounted:
	var upgrade_id: StringName = StringName(String(upgrade.get("id", "")))
	var current_level: int = _get_upgrade_level(player, String(upgrade_id))
	return _make_option({
		"id": "level_up_upgrade:%s" % String(upgrade_id),
		"type": "level_up_upgrade",
		"display_name": String(upgrade.get("display_name", upgrade_id)),
		"description": _get_debug_upgrade_description(upgrade, current_level),
		"rarity": String(upgrade.get("rarity", "common")),
		"background_texture": _get_option_background_texture(upgrade),
		"tags": _get_array(upgrade.get("tags", [])),
		"affected_origin": "Dev / Current weapon full pool",
		"does_not_affect": "Dev list ignores offer count and branch stage selection.",
		"recommended_reason": "Dev full-pool level-up card.",
		"level_text": "Lv%d / %d" % [current_level + 1, maxi(int(upgrade.get("max_level", 1)), 1)],
		"payload": {
			"upgrade_id": upgrade_id
		}
	})


func _make_debug_fire_level_up_upgrade_option(player: Node, upgrade: Dictionary, god_id: StringName) -> RefCounted:
	var option: RefCounted = _make_debug_level_up_upgrade_option(player, upgrade)
	if option == null:
		return option
	var payload: Dictionary = _get_dictionary(option.get("payload"))
	payload["learn_skill_id"] = StringName(String(upgrade.get("learn_skill_id", "")))
	payload["debug_god_id"] = god_id
	option.set("payload", payload)
	return option


func _is_debug_god_skill(skill_id: StringName, god_id: StringName) -> bool:
	var skill: Dictionary = GameData.get_skill(skill_id)
	if skill.is_empty():
		skill = _get_debug_skill_definition_from_file(skill_id)
	return _is_debug_god_skill_definition(skill, god_id)


func _is_debug_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	if skill.is_empty():
		return false
	if StringName(String(skill.get("id", ""))) == &"":
		return false
	if StringName(String(skill.get("god_id", ""))) == god_id:
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
		if not bool(skill.get("offer_in_upgrade_pool", false)):
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
			if StringName(String(skill.get("id", ""))) == skill_id:
				return skill.duplicate(true)
	return {}


func _make_debug_learn_skill_upgrade(skill: Dictionary, god_id: StringName) -> Dictionary:
	var skill_id: String = String(skill.get("id", ""))
	var rarity: String = String(skill.get("rarity", "common"))
	var tags: Array[String] = _to_string_array(_get_array(skill.get("tags", [])))
	if not tags.has("skill"):
		tags.push_front("skill")
	return {
		"id": "debug_learn_%s" % skill_id,
		"display_name": String(skill.get("display_name", skill_id)),
		"description": String(skill.get("description", "Debug learn %s." % skill_id)),
		"rarity": rarity,
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": StringName(skill_id),
		"god_id": god_id,
		"level_descriptions": [String(skill.get("description", "Debug learn %s." % skill_id))]
	}


func _get_fire_skill_definitions() -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	var document: Dictionary = _load_debug_skills_document()
	for skill_variant: Variant in _get_array(document.get("skills", [])):
		if not (skill_variant is Dictionary):
			continue
		var skill: Dictionary = (skill_variant as Dictionary).duplicate(true)
		if StringName(String(skill.get("god_id", ""))) != &"fire":
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)):
			continue
		skills.append(skill)
	return skills


func _make_fire_skill_learn_upgrade(skill: Dictionary) -> Dictionary:
	var skill_id: String = String(skill.get("id", ""))
	if skill_id == "":
		return {}
	var tags: Array[String] = _to_string_array(_get_array(skill.get("tags", [])))
	if not tags.has("skill"):
		tags.push_front("skill")
	if not tags.has("fire"):
		tags.push_front("fire")
	var description: String = String(skill.get("description", "Learn %s." % skill_id))
	return {
		"id": "%s%s" % [FIRE_SKILL_LEARN_UPGRADE_PREFIX, skill_id],
		"display_name": String(skill.get("display_name", skill_id)),
		"description": description,
		"rarity": String(skill.get("rarity", "common")),
		"tags": tags,
		"enabled": true,
		"max_level": 1,
		"learn_skill_id": StringName(skill_id),
		"god_id": "fire",
		"level_descriptions": [description]
	}


func _load_debug_skills_document() -> Dictionary:
	if not FileAccess.file_exists(SKILLS_DATA_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SKILLS_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _get_selected_branch_level_config(player: Node, target_level: int) -> Dictionary:
	var branch_system: Node = _get_weapon_branch_system(player)
	if branch_system == null or not branch_system.has_method("get_selected_branch"):
		return {}

	var branch: Dictionary = branch_system.call("get_selected_branch", player)
	if branch.is_empty():
		return {}

	return _get_branch_level_config(branch, target_level)


func _get_branch_level_config(branch: Dictionary, target_level: int) -> Dictionary:
	var level_path: Dictionary = _get_dictionary(branch.get("level_path", {}))
	return _get_dictionary(level_path.get(str(target_level), level_path.get(target_level, {})))


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


func _get_weapon_branch_system(player: Node) -> Node:
	return player.get_node_or_null("WeaponBranchSystem") if player != null else null


func _get_branch_definition(branch_id: StringName) -> Dictionary:
	var data_manager: Node = Engine.get_main_loop().root.get_node_or_null("DataManager") if Engine.get_main_loop() is SceneTree else null
	if data_manager != null and data_manager.has_method("get_weapon_branch_definition"):
		var branch: Variant = data_manager.call("get_weapon_branch_definition", branch_id)
		if branch is Dictionary:
			return branch
	return GameData.get_weapon_branch(branch_id)


func _get_character_runtime(player: Node) -> Node:
	return player.get_node_or_null("CharacterRuntime") if player != null else null


func _get_current_weapon_id(player: Node) -> StringName:
	var runtime: Node = _get_character_runtime(player)
	if runtime != null:
		return StringName(String(runtime.call("get_equipped_weapon_id")))
	var value: Variant = player.get("selected_weapon_id") if player != null else &""
	return StringName(String(value))


func _get_current_weapon_skill_id(player: Node) -> StringName:
	var runtime: Node = _get_character_runtime(player)
	if runtime != null:
		return StringName(String(runtime.call("get_equipped_weapon_skill_id")))
	var weapon: Dictionary = GameData.get_weapon(_get_current_weapon_id(player))
	return StringName(String(weapon.get("starting_skill_id", "")))


func _is_current_weapon_skill(player: Node, skill_id: StringName) -> bool:
	return skill_id == _get_current_weapon_skill_id(player)


func _get_current_weapon_skill_level(player: Node) -> int:
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return 0

	var skill_instance: RefCounted = skill_manager.call("get_skill", _get_current_weapon_skill_id(player)) as RefCounted
	return int(skill_instance.get("current_level")) if skill_instance != null else 0


func _get_debug_selected_branch_id(player: Node, runtime: Node, skill_id: StringName) -> StringName:
	if runtime != null and runtime.has_method("get_selected_weapon_branch_id"):
		var runtime_branch_id: StringName = StringName(String(runtime.call("get_selected_weapon_branch_id")))
		if runtime_branch_id != &"":
			return runtime_branch_id

	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return &""

	var skill_instance: RefCounted = skill_manager.call("get_skill", skill_id) as RefCounted
	if skill_instance == null:
		return &""

	var applied_levels: Dictionary = _get_dictionary(skill_instance.get("applied_branch_levels"))
	for branch_id_variant: Variant in applied_levels.keys():
		var branch_id: StringName = StringName(String(branch_id_variant))
		var levels: Array = _get_array(applied_levels.get(branch_id_variant, []))
		if levels.has(2):
			return branch_id
	return &""


func _has_debug_branch_level_applied(player: Node, skill_id: StringName, branch_id: StringName, target_level: int) -> bool:
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return false

	var skill_instance: RefCounted = skill_manager.call("get_skill", skill_id) as RefCounted
	if skill_instance == null:
		return false
	if skill_instance.has_method("has_applied_branch_level"):
		return bool(skill_instance.call("has_applied_branch_level", branch_id, target_level))

	var applied_levels: Dictionary = _get_dictionary(skill_instance.get("applied_branch_levels"))
	var levels: Array = _get_array(applied_levels.get(String(branch_id), applied_levels.get(branch_id, [])))
	return levels.has(target_level)


func _add_unique_options(target: Array, source: Array, max_count: int) -> void:
	var existing_ids: Dictionary = {}
	var existing_learn_skill_ids: Dictionary = {}
	for option_variant: Variant in target:
		var option: RefCounted = option_variant as RefCounted
		if option != null:
			existing_ids[String(option.get("id"))] = true
			var learn_skill_id: StringName = _get_option_learn_skill_id(option)
			if learn_skill_id != &"":
				existing_learn_skill_ids[learn_skill_id] = true

	for option_variant: Variant in source:
		if target.size() >= max_count:
			return
		var option: RefCounted = option_variant as RefCounted
		if option == null:
			continue
		var option_id: String = String(option.get("id"))
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
	return maxf(float(rarity_weights.get(String(option.get("rarity")), 1.0)), 0.0)


func _is_level_up_upgrade_available(player: Node, upgrade: Dictionary) -> bool:
	var upgrade_id: String = String(upgrade.get("id", ""))
	if upgrade_id == "" or not bool(upgrade.get("enabled", true)):
		return false
	if upgrade.has("learn_skill_id") and not _is_learn_skill_upgrade_available(player, StringName(String(upgrade.get("learn_skill_id", "")))):
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
			return StringName(String(payload.get("learn_skill_id", "")))
	return &""


func _get_level_up_upgrade_weight(player: Node, upgrade: Dictionary) -> float:
	var upgrade_level: int = _get_upgrade_level(player, String(upgrade.get("id", "")))
	var main_level: int = _get_current_weapon_skill_level(player)
	return float(_offer_policy.call("get_upgrade_weight", player, upgrade, upgrade_level, main_level))


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


func _get_level_up_upgrade_description(upgrade: Dictionary) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if not descriptions.is_empty():
		return String(descriptions[0])
	return String(upgrade.get("description", ""))


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
	return "主攻击 / 通用属性"


func _infer_does_not_affect(upgrade: Dictionary) -> String:
	var tags: Array = _get_array(upgrade.get("tags", []))
	if tags.has("dot"):
		return "不直接提高主攻击命中伤害、陷阱伤害或反应触发次数。"
	if tags.has("reaction"):
		return "不直接提高 DOT tick、普通主攻击伤害或状态施加频率。"
	if tags.has("boss"):
		return "不影响普通怪清场效率，除非描述中另有说明。"
	if tags.has("survival"):
		return "不直接提高伤害输出或资源收益。"
	if tags.has("trap"):
		return "不直接提高非陷阱类主攻击、DOT 或反应伤害。"
	return "不影响未在标签和效果中列出的伤害来源。"


func _build_recommended_reason(player: Node, upgrade: Dictionary) -> String:
	return String(_offer_policy.call("build_recommended_reason", player, upgrade))


func _build_branch_tags(branch: Dictionary) -> Array[String]:
	var tags: Array[String] = ["武器倾向", "分支"]
	var role: String = String(branch.get("role", ""))
	if role != "":
		tags.append(role)
	for tag_variant: Variant in _get_array(branch.get("tags", [])):
		tags.append(String(tag_variant))
	return tags


func _build_debug_branch_tags(branch: Dictionary, target_level: int) -> Array[String]:
	var tags: Array[String] = ["Dev", "分支", "Lv%d" % target_level]
	var role: String = String(branch.get("role", ""))
	if role != "":
		tags.append(role)
	for tag_variant: Variant in _get_array(branch.get("tags", [])):
		tags.append(String(tag_variant))
	return tags


func _is_debug_level_up_upgrade_for_weapon(upgrade: Dictionary, weapon_id: StringName) -> bool:
	if not bool(upgrade.get("enabled", true)):
		return false
	var weapon_tags: Array[String] = _get_debug_weapon_tags(weapon_id)
	for required_tag: String in _to_string_array(_get_array(upgrade.get("required_weapon_tags", []))):
		if not weapon_tags.has(required_tag):
			return false
	for excluded_tag: String in _to_string_array(_get_array(upgrade.get("exclude_tags", []))):
		if weapon_tags.has(excluded_tag):
			return false
	return true


func _get_debug_weapon_tags(weapon_id: StringName) -> Array[String]:
	var tags: Array[String] = []
	var weapon: Dictionary = GameData.get_weapon(weapon_id)
	for key: String in ["tags", "upgrade_tag_pool", "damage_origin_list"]:
		for tag: String in _to_string_array(_get_array(weapon.get(key, []))):
			if not tags.has(tag):
				tags.append(tag)
	return tags


func _get_debug_upgrade_description(upgrade: Dictionary, current_level: int) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if current_level >= 0 and current_level < descriptions.size():
		return String(descriptions[current_level])
	if not descriptions.is_empty():
		return String(descriptions[0])
	return String(upgrade.get("description", ""))


func _infer_weapon_origin_text(player: Node) -> String:
	var weapon: Dictionary = GameData.get_weapon(_get_current_weapon_id(player))
	var origins: Array = _get_array(weapon.get("damage_origin_list", []))
	if origins.is_empty():
		return "当前主攻击"
	var labels: Array[String] = []
	for origin_variant: Variant in origins:
		labels.append(_origin_label(String(origin_variant)))
	return " / ".join(labels)


func _origin_label(origin: String) -> String:
	match origin:
		"direct_physical", "direct_magical", "main_attack":
			return "主攻击"
		"status_dot":
			return "DOT"
		"area_direct":
			return "领域 / 范围"
		"reaction":
			return "反应"
		"trap":
			return "陷阱"
		_:
			return origin


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
		var value: String = String(primary.get(key, ""))
		if value != "":
			return value

	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = String(fallback.get(key, ""))
		if value != "":
			return value

	return ""


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _to_string_array(value: Array) -> Array[String]:
	var strings: Array[String] = []
	for item: Variant in value:
		strings.append(String(item))
	return strings
