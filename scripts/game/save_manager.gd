## 文件用途：集中读写货币、解锁、永久成长、局内摘要和设置存档。
## 使用方式：通过静态接口访问 user://save.cfg；自动验证须把 user:// 用户目录隔离到 E:/codex。

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


## 作用：读取现有 ConfigFile 后更新指定 section/key 并写回存档。
## 使用：value 为待保存值；保留其他已有键，只有完整写入成功才返回 true。
static func save_value(section: String, key: String, value: Variant) -> bool:
	var config: ConfigFile = ConfigFile.new()
	if not _load_for_write(config):
		return false
	config.set_value(section, key, value)
	return _commit_config(config)


## 作用：只允许有效旧档或不存在的新档进入写入流程，拒绝覆盖不可读文件。
static func _load_for_write(config: ConfigFile) -> bool:
	var error: int = config.load(SAVE_PATH)
	return error == OK or (error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(SAVE_PATH))


## 作用：先完整保存临时文件，再原子替换旧档；失败保留旧档并返回 false。
static func _commit_config(config: ConfigFile) -> bool:
	var temporary_path: String = SAVE_PATH + ".tmp"
	if config.save(temporary_path) != OK:
		return false
	var error: int = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return false
	return true


## 作用：从存档读取指定 section/key。
## 使用：文件不可读或键不存在时返回 default_value；只读查询。
static func load_value(section: String, key: String, default_value: Variant = null) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(SAVE_PATH)
	if error != OK:
		return default_value

	return config.get_value(section, key, default_value)


## 作用：获取灵魂石，供当前模块后续逻辑使用。
## 使用：本文件由 add_soul_stones、spend_soul_stones、can_purchase_permanent_upgrade 调用；返回计算或读取的数值。
static func get_soul_stones() -> int:
	return maxi(int(load_value(SECTION_CURRENCY, KEY_SOUL_STONES, 0)), 0)


## 作用：获取主音量百分比，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回计算或读取的数值。
static func get_master_volume_percent() -> float:
	return clampf(float(load_value(SECTION_SETTINGS, KEY_MASTER_VOLUME, 70.0)), 0.0, 100.0)


## 作用：设置主音量百分比。
## 使用：供本模块调用者使用；输入 value（值）；可能写入 user:// 存档。
static func set_master_volume_percent(value: float) -> bool:
	return save_value(SECTION_SETTINGS, KEY_MASTER_VOLUME, clampf(value, 0.0, 100.0))


## 作用：获取全屏启用，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回是否满足条件或执行成功。
static func get_fullscreen_enabled() -> bool:
	return bool(load_value(SECTION_SETTINGS, KEY_FULLSCREEN, false))


## 作用：设置全屏启用。
## 使用：供本模块调用者使用；输入 enabled（启用）；可能写入 user:// 存档。
static func set_fullscreen_enabled(enabled: bool) -> bool:
	return save_value(SECTION_SETTINGS, KEY_FULLSCREEN, enabled)


## 作用：获取语言ID，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 String 文本/标识。
static func get_language_id() -> String:
	return String(load_value(SECTION_SETTINGS, KEY_LANGUAGE, "zh"))


## 作用：设置语言ID。
## 使用：供本模块调用者使用；输入 language_id（语言ID）；可能写入 user:// 存档。
static func set_language_id(language_id: String) -> bool:
	if language_id == "":
		return false
	return save_value(SECTION_SETTINGS, KEY_LANGUAGE, language_id)


## 作用：添加灵魂石。
## 使用：amount 为增量；成功返回新余额，写入失败返回 -1。
static func add_soul_stones(amount: int) -> int:
	if amount <= 0:
		return get_soul_stones()

	var new_amount: int = get_soul_stones() + amount
	return new_amount if save_value(SECTION_CURRENCY, KEY_SOUL_STONES, new_amount) else -1


## 作用：获取计数器，供当前模块后续逻辑使用。
## 使用：本文件由 increment_counter、set_counter_max 调用；输入 counter_id（计数器ID）；返回计算或读取的数值。
static func get_counter(counter_id: StringName) -> int:
	return maxi(int(load_value(SECTION_RUN_COUNTERS, String(counter_id), 0)), 0)


## 作用：累加计数器。
## 使用：counter_id/amount 指定计数增量；成功返回新值，写入失败返回 -1。
static func increment_counter(counter_id: StringName, amount: int = 1) -> int:
	if counter_id == &"" or amount == 0:
		return get_counter(counter_id)
	var new_value: int = maxi(get_counter(counter_id) + amount, 0)
	return new_value if save_value(SECTION_RUN_COUNTERS, String(counter_id), new_value) else -1


## 作用：设置计数器上限。
## 使用：counter_id/value 指定计数下限；返回实际保存值，写入失败返回 -1。
static func set_counter_max(counter_id: StringName, value: int) -> int:
	if counter_id == &"":
		return 0
	var current_value: int = get_counter(counter_id)
	var new_value: int = maxi(current_value, value)
	if new_value != current_value:
		if not save_value(SECTION_RUN_COUNTERS, String(counter_id), new_value):
			return -1
	return new_value


## 作用：累加角色专精。
## 使用：character_id/goal_id/amount 指定进度增量；返回新值，写入失败返回 -1。
static func increment_character_specialization(character_id: StringName, goal_id: StringName, amount: int = 1) -> int:
	if character_id == &"" or goal_id == &"":
		return 0
	var key: String = "%s:%s" % [String(character_id), String(goal_id)]
	var new_value: int = maxi(int(load_value(SECTION_CHARACTER_SPECIALIZATION, key, 0)) + amount, 0)
	return new_value if save_value(SECTION_CHARACTER_SPECIALIZATION, key, new_value) else -1


## 作用：获取角色专精进度，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 character_id（角色ID）、goal_id（目标ID）；返回计算或读取的数值。
static func get_character_specialization_progress(character_id: StringName, goal_id: StringName) -> int:
	return maxi(int(load_value(SECTION_CHARACTER_SPECIALIZATION, "%s:%s" % [String(character_id), String(goal_id)], 0)), 0)


## 作用：首次记录指定地图挑战完成。
## 使用：map_id/objective_id 组成持久键；重复记录返回 false；可能写入 user:// 存档。
static func mark_map_challenge_completed(map_id: StringName, objective_id: StringName) -> bool:
	if map_id == &"" or objective_id == &"":
		return false
	var key: String = "%s:%s" % [String(map_id), String(objective_id)]
	if bool(load_value(SECTION_MAP_CHALLENGES, key, false)):
		return false
	return save_value(SECTION_MAP_CHALLENGES, key, true)


## 作用：判断地图挑战已完成，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 map_id（地图ID）、objective_id（挑战目标ID）。
static func is_map_challenge_completed(map_id: StringName, objective_id: StringName) -> bool:
	return bool(load_value(SECTION_MAP_CHALLENGES, "%s:%s" % [String(map_id), String(objective_id)], false))


## 作用：首次记录固定挑战完成。
## 使用：challenge_id 为空或已完成返回 false；首次成功写入存档。
static func mark_challenge_completed(challenge_id: StringName) -> bool:
	if challenge_id == &"":
		return false
	if bool(load_value(SECTION_CHALLENGES, String(challenge_id), false)):
		return false
	return save_value(SECTION_CHALLENGES, String(challenge_id), true)


## 作用：判断挑战已完成，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 challenge_id（挑战ID）。
static func is_challenge_completed(challenge_id: StringName) -> bool:
	return bool(load_value(SECTION_CHALLENGES, String(challenge_id), false))


## 作用：存档上次单局摘要。
## 使用：供本模块调用者使用；输入 summary（摘要）；可能写入 user:// 存档。
static func save_last_run_summary(summary: Dictionary) -> bool:
	return save_value(SECTION_RUN_HISTORY, KEY_LAST_RUN_SUMMARY, summary.duplicate(true))


## 作用：获取上次单局摘要，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回结果字典。
static func get_last_run_summary() -> Dictionary:
	var summary: Variant = load_value(SECTION_RUN_HISTORY, KEY_LAST_RUN_SUMMARY, {})
	if summary is Dictionary:
		var summary_data: Dictionary = summary
		return summary_data.duplicate(true)
	return {}


## 作用：余额足够时扣除灵魂石并保存。
## 使用：amount 非正数视为成功；余额不足返回 false 且不扣款；可能写入 user:// 存档。
static func spend_soul_stones(amount: int) -> bool:
	if amount <= 0:
		return true

	var current_amount: int = get_soul_stones()
	if current_amount < amount:
		return false

	return save_value(SECTION_CURRENCY, KEY_SOUL_STONES, current_amount - amount)


## 作用：获取永久升级等级，供当前模块后续逻辑使用。
## 使用：本文件由 get_permanent_upgrade_cost、can_purchase_permanent_upgrade、purchase_permanent_upgrade 调用；输入 upgrade_id（升级ID）；返回计算或读取的数值。
static func get_permanent_upgrade_level(upgrade_id: StringName) -> int:
	return maxi(int(load_value(SECTION_PERMANENT_UPGRADES, String(upgrade_id), 0)), 0)


## 作用：获取永久升级等级表，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回结果字典。
static func get_permanent_upgrade_levels() -> Dictionary:
	var levels: Dictionary = {}
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(SAVE_PATH)
	if error != OK or not config.has_section(SECTION_PERMANENT_UPGRADES):
		return levels

	for key: String in config.get_section_keys(SECTION_PERMANENT_UPGRADES):
		levels[StringName(key)] = maxi(int(config.get_value(SECTION_PERMANENT_UPGRADES, key, 0)), 0)

	return levels


## 作用：判断地图通关，返回布尔判断结果。
## 使用：本文件由 mark_map_cleared 调用；输入 map_id（地图ID）。
static func is_map_cleared(map_id: StringName) -> bool:
	return bool(load_value(SECTION_MAP_CLEAR_RECORDS, String(map_id), false))


## 作用：仅首次将指定地图标记为已通关。
## 使用：空 ID 或已通关返回 false；首次成功写入存档并返回 true。
static func mark_map_cleared(map_id: StringName) -> bool:
	if map_id == &"" or is_map_cleared(map_id):
		return false

	return save_value(SECTION_MAP_CLEAR_RECORDS, String(map_id), true)


## 作用：获取通关地图ID列表，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 Array[StringName] 列表。
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


## 作用：按基础费用和成长倍率计算当前等级的升级费用。
## 使用：不存在或达到最高等级返回 0；无效价格返回 -1，禁止隐式免费购买。
static func get_permanent_upgrade_cost(upgrade_id: StringName) -> int:
	var upgrade: Dictionary = GameData.get_permanent_upgrade(upgrade_id)
	if upgrade.is_empty():
		return 0

	var current_level: int = get_permanent_upgrade_level(upgrade_id)
	var max_level: int = int(upgrade.get("max_level", 1))
	if current_level >= max_level:
		return 0

	return _permanent_upgrade_cost_at_level(upgrade, current_level)


## 作用：校验显式价格并按等级计算费用；缺失、非法或溢出返回 -1。
static func _permanent_upgrade_cost_at_level(upgrade: Dictionary, level: int) -> int:
	var base: Variant = upgrade.get("cost_base")
	var growth: Variant = upgrade.get("cost_growth")
	if not (base is int or base is float) or not (growth is int or growth is float):
		return -1
	if not is_finite(float(base)) or not is_finite(float(growth)) or float(base) < 1.0 or float(growth) < 1.0:
		return -1
	var cost: float = float(base) * pow(float(growth), level)
	if not is_finite(cost) or cost >= float(9223372036854775807):
		return -1
	return roundi(cost)


## 作用：可否购买永久升级，返回布尔判断结果。
## 使用：本文件由 purchase_permanent_upgrade 调用；输入 upgrade_id（升级ID）。
static func can_purchase_permanent_upgrade(upgrade_id: StringName) -> bool:
	var upgrade: Dictionary = GameData.get_permanent_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false

	var current_level: int = get_permanent_upgrade_level(upgrade_id)
	var max_level: int = int(upgrade.get("max_level", 1))
	if current_level >= max_level:
		return false

	var cost: int = get_permanent_upgrade_cost(upgrade_id)
	var config: ConfigFile = ConfigFile.new()
	return cost > 0 and _load_for_write(config) and get_soul_stones() >= cost


## 作用：检查可购买条件、扣费并将永久升级等级加一。
## 使用：upgrade_id 必须对应配置；返回购买成功标志，成功会写入存档。
static func purchase_permanent_upgrade(upgrade_id: StringName) -> bool:
	var upgrade: Dictionary = GameData.get_permanent_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false
	var config: ConfigFile = ConfigFile.new()
	if not _load_for_write(config):
		return false
	var level: int = maxi(int(config.get_value(SECTION_PERMANENT_UPGRADES, String(upgrade_id), 0)), 0)
	if level >= int(upgrade.get("max_level", 1)):
		return false
	var cost: int = _permanent_upgrade_cost_at_level(upgrade, level)
	var balance: int = maxi(int(config.get_value(SECTION_CURRENCY, KEY_SOUL_STONES, 0)), 0)
	if cost <= 0 or balance < cost:
		return false
	config.set_value(SECTION_CURRENCY, KEY_SOUL_STONES, balance - cost)
	config.set_value(SECTION_PERMANENT_UPGRADES, String(upgrade_id), level + 1)
	return _commit_config(config)


## 作用：获取角色解锁费用，供当前模块后续逻辑使用。
## 使用：本文件由 can_purchase_character、purchase_character 调用；输入 character_id（角色ID）；返回计算或读取的数值。
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


## 作用：判断角色已解锁，返回布尔判断结果。
## 使用：本文件由 can_purchase_character 调用；输入 character_id（角色ID）。
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


## 作用：可否购买角色，返回布尔判断结果。
## 使用：本文件由 purchase_character 调用；输入 character_id（角色ID）。
static func can_purchase_character(character_id: StringName) -> bool:
	if is_character_unlocked(character_id):
		return false

	var cost: int = get_character_unlock_cost(character_id)
	if cost <= 0:
		return false

	return get_soul_stones() >= cost


## 作用：检查解锁费用并扣费、标记角色解锁。
## 使用：character_id 为配置 ID；返回购买结果，已解锁或不能购买时返回 false。
static func purchase_character(character_id: StringName) -> bool:
	if not can_purchase_character(character_id):
		return false

	var config: ConfigFile = ConfigFile.new()
	if not _load_for_write(config):
		return false
	var cost: int = get_character_unlock_cost(character_id)
	var balance: int = maxi(int(config.get_value(SECTION_CURRENCY, KEY_SOUL_STONES, 0)), 0)
	if balance < cost:
		return false
	config.set_value(SECTION_CURRENCY, KEY_SOUL_STONES, balance - cost)
	config.set_value(SECTION_UNLOCKS, "character:%s" % String(character_id), true)
	return _commit_config(config)


## 作用：按已购等级累计所有永久升级的属性修正。
## 使用：返回聚合字典，供角色开局属性计算；不直接修改玩家节点。
static func get_permanent_upgrade_total_modifiers() -> Dictionary:
	var total_modifiers: Dictionary = {}

	for upgrade: Dictionary in GameData.get_permanent_upgrade_pool():
		var upgrade_id: StringName = StringName(String(upgrade.get("id", "")))
		var upgrade_level: int = get_permanent_upgrade_level(upgrade_id)
		if upgrade_level <= 0:
			continue

		var modifiers: Variant = upgrade.get("modifiers_per_level", upgrade.get("modifiers", []))
		var modifier_data: Dictionary = ModifierSourceScript.flatten_effects(modifiers as Array, ModifierSourceScript.SOURCE_UPGRADE)
		for modifier_key_variant: Variant in modifier_data.keys():
			var modifier_key: String = String(modifier_key_variant)
			var current_value: float = float(total_modifiers.get(modifier_key, 0.0))
			total_modifiers[modifier_key] = current_value + float(modifier_data[modifier_key_variant]) * float(upgrade_level)

	return total_modifiers


## 作用：判断已解锁，返回布尔判断结果。
## 使用：本文件由 is_character_unlocked 调用；输入 kind（类型）、item_id（itemID）。
static func is_unlocked(kind: String, item_id: StringName) -> bool:
	return bool(load_value(SECTION_UNLOCKS, "%s:%s" % [kind, String(item_id)], false))


## 作用：设置已解锁。
## 使用：本文件由 purchase_character 调用；输入 kind（类型）、item_id（itemID）、is_item_unlocked（判断item已解锁）；可能写入 user:// 存档。
static func set_unlocked(kind: String, item_id: StringName, is_item_unlocked: bool = true) -> bool:
	return save_value(SECTION_UNLOCKS, "%s:%s" % [kind, String(item_id)], is_item_unlocked)


## 作用：以空 ConfigFile 覆盖存档并清空全部持久化进度。
## 使用：仅在明确需要重置时调用；影响 user://save.cfg 中的设置、货币和成长记录。
static func reset_progress() -> bool:
	var config: ConfigFile = ConfigFile.new()
	return _commit_config(config)
