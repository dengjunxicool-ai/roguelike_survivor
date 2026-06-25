extends Node
class_name SaveManager


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const SAVE_PATH: String = "user://save.cfg"
const SECTION_CURRENCY: String = "currency"
const SECTION_PERMANENT_UPGRADES: String = "permanent_upgrades"
const SECTION_UNLOCKS: String = "unlocks"
const SECTION_MAP_CLEAR_RECORDS: String = "map_clear_records"
const SECTION_RUN_COUNTERS: String = "run_counters"
const SECTION_CHARACTER_SPECIALIZATION: String = "character_specialization"
const SECTION_MAP_CHALLENGES: String = "map_challenges"
const SECTION_CHALLENGES: String = "challenges"
const SECTION_RUN_HISTORY: String = "run_history"
const SECTION_SETTINGS: String = "settings"
const KEY_SOUL_STONES: String = "soul_stones"
const KEY_LAST_RUN_SUMMARY: String = "last_run_summary"
const KEY_MASTER_VOLUME: String = "master_volume"
const KEY_FULLSCREEN: String = "fullscreen"
const KEY_LANGUAGE: String = "language"


static func save_value(section: String, key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(section, key, value)
	config.save(SAVE_PATH)


static func load_value(section: String, key: String, default_value: Variant = null) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(SAVE_PATH)
	if error != OK:
		return default_value

	return config.get_value(section, key, default_value)


static func get_soul_stones() -> int:
	return maxi(int(load_value(SECTION_CURRENCY, KEY_SOUL_STONES, 0)), 0)


static func get_master_volume_percent() -> float:
	return clampf(float(load_value(SECTION_SETTINGS, KEY_MASTER_VOLUME, 70.0)), 0.0, 100.0)


static func set_master_volume_percent(value: float) -> void:
	save_value(SECTION_SETTINGS, KEY_MASTER_VOLUME, clampf(value, 0.0, 100.0))


static func get_fullscreen_enabled() -> bool:
	return bool(load_value(SECTION_SETTINGS, KEY_FULLSCREEN, false))


static func set_fullscreen_enabled(enabled: bool) -> void:
	save_value(SECTION_SETTINGS, KEY_FULLSCREEN, enabled)


static func get_language_id() -> String:
	return String(load_value(SECTION_SETTINGS, KEY_LANGUAGE, "zh"))


static func set_language_id(language_id: String) -> void:
	if language_id == "":
		return
	save_value(SECTION_SETTINGS, KEY_LANGUAGE, language_id)


static func add_soul_stones(amount: int) -> int:
	if amount <= 0:
		return get_soul_stones()

	var new_amount: int = get_soul_stones() + amount
	save_value(SECTION_CURRENCY, KEY_SOUL_STONES, new_amount)
	return new_amount


static func get_counter(counter_id: StringName) -> int:
	return maxi(int(load_value(SECTION_RUN_COUNTERS, String(counter_id), 0)), 0)


static func increment_counter(counter_id: StringName, amount: int = 1) -> int:
	if counter_id == &"" or amount == 0:
		return get_counter(counter_id)
	var new_value: int = maxi(get_counter(counter_id) + amount, 0)
	save_value(SECTION_RUN_COUNTERS, String(counter_id), new_value)
	return new_value


static func set_counter_max(counter_id: StringName, value: int) -> int:
	if counter_id == &"":
		return 0
	var current_value: int = get_counter(counter_id)
	var new_value: int = maxi(current_value, value)
	if new_value != current_value:
		save_value(SECTION_RUN_COUNTERS, String(counter_id), new_value)
	return new_value


static func increment_character_specialization(character_id: StringName, goal_id: StringName, amount: int = 1) -> int:
	if character_id == &"" or goal_id == &"":
		return 0
	var key: String = "%s:%s" % [String(character_id), String(goal_id)]
	var new_value: int = maxi(int(load_value(SECTION_CHARACTER_SPECIALIZATION, key, 0)) + amount, 0)
	save_value(SECTION_CHARACTER_SPECIALIZATION, key, new_value)
	return new_value


static func get_character_specialization_progress(character_id: StringName, goal_id: StringName) -> int:
	return maxi(int(load_value(SECTION_CHARACTER_SPECIALIZATION, "%s:%s" % [String(character_id), String(goal_id)], 0)), 0)


static func mark_map_challenge_completed(map_id: StringName, objective_id: StringName) -> bool:
	if map_id == &"" or objective_id == &"":
		return false
	var key: String = "%s:%s" % [String(map_id), String(objective_id)]
	if bool(load_value(SECTION_MAP_CHALLENGES, key, false)):
		return false
	save_value(SECTION_MAP_CHALLENGES, key, true)
	return true


static func is_map_challenge_completed(map_id: StringName, objective_id: StringName) -> bool:
	return bool(load_value(SECTION_MAP_CHALLENGES, "%s:%s" % [String(map_id), String(objective_id)], false))


static func mark_challenge_completed(challenge_id: StringName) -> bool:
	if challenge_id == &"":
		return false
	if bool(load_value(SECTION_CHALLENGES, String(challenge_id), false)):
		return false
	save_value(SECTION_CHALLENGES, String(challenge_id), true)
	return true


static func is_challenge_completed(challenge_id: StringName) -> bool:
	return bool(load_value(SECTION_CHALLENGES, String(challenge_id), false))


static func save_last_run_summary(summary: Dictionary) -> void:
	save_value(SECTION_RUN_HISTORY, KEY_LAST_RUN_SUMMARY, summary.duplicate(true))


static func get_last_run_summary() -> Dictionary:
	var summary: Variant = load_value(SECTION_RUN_HISTORY, KEY_LAST_RUN_SUMMARY, {})
	if summary is Dictionary:
		var summary_data: Dictionary = summary
		return summary_data.duplicate(true)
	return {}


static func spend_soul_stones(amount: int) -> bool:
	if amount <= 0:
		return true

	var current_amount: int = get_soul_stones()
	if current_amount < amount:
		return false

	save_value(SECTION_CURRENCY, KEY_SOUL_STONES, current_amount - amount)
	return true


static func get_permanent_upgrade_level(upgrade_id: StringName) -> int:
	return maxi(int(load_value(SECTION_PERMANENT_UPGRADES, String(upgrade_id), 0)), 0)


static func get_permanent_upgrade_levels() -> Dictionary:
	var levels: Dictionary = {}
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(SAVE_PATH)
	if error != OK or not config.has_section(SECTION_PERMANENT_UPGRADES):
		return levels

	for key: String in config.get_section_keys(SECTION_PERMANENT_UPGRADES):
		levels[StringName(key)] = maxi(int(config.get_value(SECTION_PERMANENT_UPGRADES, key, 0)), 0)

	return levels


static func is_map_cleared(map_id: StringName) -> bool:
	return bool(load_value(SECTION_MAP_CLEAR_RECORDS, String(map_id), false))


static func mark_map_cleared(map_id: StringName) -> bool:
	if map_id == &"" or is_map_cleared(map_id):
		return false

	save_value(SECTION_MAP_CLEAR_RECORDS, String(map_id), true)
	return true


static func get_cleared_map_ids() -> Array[StringName]:
	var cleared_ids: Array[StringName] = []
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(SAVE_PATH)
	if error != OK or not config.has_section(SECTION_MAP_CLEAR_RECORDS):
		return cleared_ids

	for key: String in config.get_section_keys(SECTION_MAP_CLEAR_RECORDS):
		if bool(config.get_value(SECTION_MAP_CLEAR_RECORDS, key, false)):
			cleared_ids.append(StringName(key))

	return cleared_ids


static func get_permanent_upgrade_cost(upgrade_id: StringName) -> int:
	var upgrade: Dictionary = GameData.get_permanent_upgrade(upgrade_id)
	if upgrade.is_empty():
		return 0

	var current_level: int = get_permanent_upgrade_level(upgrade_id)
	var max_level: int = int(upgrade.get("max_level", 1))
	if current_level >= max_level:
		return 0

	var cost_base: float = float(upgrade.get("cost_base", 0.0))
	var cost_growth: float = float(upgrade.get("cost_growth", 1.0))
	return maxi(roundi(cost_base * pow(cost_growth, current_level)), 0)


static func can_purchase_permanent_upgrade(upgrade_id: StringName) -> bool:
	var upgrade: Dictionary = GameData.get_permanent_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false

	var current_level: int = get_permanent_upgrade_level(upgrade_id)
	var max_level: int = int(upgrade.get("max_level", 1))
	if current_level >= max_level:
		return false

	return get_soul_stones() >= get_permanent_upgrade_cost(upgrade_id)


static func purchase_permanent_upgrade(upgrade_id: StringName) -> bool:
	if not can_purchase_permanent_upgrade(upgrade_id):
		return false

	var cost: int = get_permanent_upgrade_cost(upgrade_id)
	if not spend_soul_stones(cost):
		return false

	var new_level: int = get_permanent_upgrade_level(upgrade_id) + 1
	save_value(SECTION_PERMANENT_UPGRADES, String(upgrade_id), new_level)
	return true


static func get_character_unlock_cost(character_id: StringName) -> int:
	var character: Dictionary = GameData.get_character(character_id)
	if character.is_empty():
		return 0

	var unlock_variant: Variant = character.get("unlock", {})
	if not (unlock_variant is Dictionary):
		return 0

	var unlock: Dictionary = unlock_variant
	if String(unlock.get("type", "default")) != "soul_cost":
		return 0

	return maxi(int(unlock.get("cost", 0)), 0)


static func is_character_unlocked(character_id: StringName) -> bool:
	var character: Dictionary = GameData.get_character(character_id)
	if character.is_empty():
		return false

	var unlock_variant: Variant = character.get("unlock", {})
	if not (unlock_variant is Dictionary):
		return true

	var unlock: Dictionary = unlock_variant
	var unlock_type: String = String(unlock.get("type", "default"))
	if unlock_type == "default":
		return true

	if is_unlocked("character", character_id):
		return true

	if unlock_type == "achievement":
		var achievement_id: StringName = StringName(String(unlock.get("achievement_id", "")))
		return is_unlocked("achievement", achievement_id)

	return false


static func can_purchase_character(character_id: StringName) -> bool:
	if is_character_unlocked(character_id):
		return false

	var cost: int = get_character_unlock_cost(character_id)
	if cost <= 0:
		return false

	return get_soul_stones() >= cost


static func purchase_character(character_id: StringName) -> bool:
	if not can_purchase_character(character_id):
		return false

	var cost: int = get_character_unlock_cost(character_id)
	if not spend_soul_stones(cost):
		return false

	set_unlocked("character", character_id)
	return true


static func get_permanent_upgrade_total_modifiers() -> Dictionary:
	var total_modifiers: Dictionary = {}

	for upgrade: Dictionary in GameData.get_permanent_upgrade_pool():
		var upgrade_id: StringName = StringName(String(upgrade.get("id", "")))
		var upgrade_level: int = get_permanent_upgrade_level(upgrade_id)
		if upgrade_level <= 0:
			continue

		var modifiers: Variant = upgrade.get("modifiers_per_level", upgrade.get("modifiers", {}))
		var modifier_data: Dictionary = ModifierSourceScript.flatten(modifiers, ModifierSourceScript.SOURCE_UPGRADE)
		for modifier_key_variant: Variant in modifier_data.keys():
			var modifier_key: String = String(modifier_key_variant)
			var current_value: float = float(total_modifiers.get(modifier_key, 0.0))
			total_modifiers[modifier_key] = current_value + float(modifier_data[modifier_key_variant]) * float(upgrade_level)

	return total_modifiers


static func is_unlocked(kind: String, item_id: StringName) -> bool:
	return bool(load_value(SECTION_UNLOCKS, "%s:%s" % [kind, String(item_id)], false))


static func set_unlocked(kind: String, item_id: StringName, is_item_unlocked: bool = true) -> void:
	save_value(SECTION_UNLOCKS, "%s:%s" % [kind, String(item_id)], is_item_unlocked)


static func reset_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.save(SAVE_PATH)
