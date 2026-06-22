extends RefCounted
class_name CharacterLoadoutText


const UIDisplayHelperScript: Script = preload("res://scripts/ui/ui_display_helper.gd")
const TEXTS_PATH: String = "res://data/character_texts.json"

static var _text_cache: Dictionary = {}
static var _missing_warning_keys: Dictionary = {}


static func selection_status_text(character: Dictionary, is_unlocked: bool) -> String:
	if is_unlocked:
		return "状态：已解锁"
	return lock_detail(character)


static func lock_detail(character: Dictionary) -> String:
	var character_id: StringName = StringName(String(character.get("id", "")))
	var unlock: Dictionary = UIDisplayHelperScript.dictionary(character.get("unlock", {}))
	match String(unlock.get("type", "default")):
		"soul_cost":
			return "解锁条件：消耗 %d 灵魂石（当前 %d）" % [SaveManager.get_character_unlock_cost(character_id), SaveManager.get_soul_stones()]
		"achievement":
			return "解锁条件：完成成就 %s" % String(unlock.get("achievement_id", ""))
		"default":
			return "状态：默认解锁"
		_:
			return "解锁条件：未配置"


static func action_text(character: Dictionary, is_unlocked: bool) -> String:
	if is_unlocked:
		return "选择"
	var character_id: StringName = StringName(String(character.get("id", "")))
	var cost: int = SaveManager.get_character_unlock_cost(character_id)
	if cost > 0:
		return "解锁 %d" % cost if SaveManager.can_purchase_character(character_id) else "灵魂石不足"
	return "未解锁"


static func role_text(character: Dictionary) -> String:
	var character_id: String = String(character.get("id", ""))
	var text_role: String = _get_character_text_field(character_id, "role", "")
	if text_role != "":
		return text_role
	return String(character.get("role", "未配置"))


static func trait_text(character: Dictionary) -> String:
	var trait_data: Dictionary = UIDisplayHelperScript.dictionary(character.get("trait", {}))
	var character_id: String = String(character.get("id", ""))
	return "%s：%s" % [_trait_display_name(character_id, trait_data), _trait_description(character_id)]


static func difficulty_text(character: Dictionary) -> String:
	return _get_character_text_field(String(character.get("id", "")), "difficulty", "普通")


static func stats_text(character: Dictionary) -> String:
	var stats: Dictionary = UIDisplayHelperScript.dictionary(character.get("base_stats", {}))
	if stats.is_empty():
		return "基础数值：未配置"
	return "基础数值：生命 %d / 移速 %d / 护甲 %d\n输出 x%.2f / 攻速 x%.2f\n暴击 %.0f%% / 暴伤 x%.1f / 拾取 %d" % [
		int(stats.get("max_hp", 0)),
		int(stats.get("move_speed", 0)),
		int(stats.get("armor", 0)),
		float(stats.get("damage_multiplier", 1.0)),
		float(stats.get("attack_speed_multiplier", 1.0)),
		float(stats.get("crit_chance", 0.0)) * 100.0,
		float(stats.get("crit_damage", 1.5)),
		int(stats.get("pickup_radius", 0))
	]


static func drawback_text(character: Dictionary) -> String:
	return _get_character_text_field(String(character.get("id", "")), "drawback", "未配置")


static func weapon_description_text(weapon: Dictionary) -> String:
	var skill_id: StringName = StringName(String(weapon.get("starting_skill_id", "")))
	var tags: String = string_list_text(weapon.get("tags", []), "未配置")
	var origins: String = string_list_text(weapon.get("damage_origin_list", []), "未配置")
	return "武器说明：%s\n初始技能：%s\n伤害类型：%s\n标签：%s" % [
		weapon_role_text(String(weapon.get("id", ""))),
		UIDisplayHelperScript.skill_name(skill_id) if skill_id != &"" else "未配置",
		origins,
		tags
	]


static func weapon_role_text(weapon_id: String) -> String:
	var text: String = _get_weapon_text_field(weapon_id, "role", "")
	if text != "":
		return text
	return "未配置"


static func branch_preview_text(weapon: Dictionary) -> String:
	var names: Array[String] = []
	for branch_id_variant: Variant in UIDisplayHelperScript.array(weapon.get("branch_ids", [])):
		var branch: Dictionary = GameData.get_weapon_branch(StringName(String(branch_id_variant)))
		if not branch.is_empty():
			names.append(UIDisplayHelperScript.branch_name(branch, branch.get("id", "")))
	return "分支预览：%s" % " / ".join(names)


static func string_list_text(value: Variant, fallback: String) -> String:
	var parts: Array[String] = []
	for item_variant: Variant in UIDisplayHelperScript.array(value):
		parts.append(String(item_variant))
	if parts.is_empty():
		return fallback
	return " / ".join(parts)


static func _trait_display_name(character_id: String, trait_data: Dictionary) -> String:
	var text: String = _get_character_text_field(character_id, "trait_display_name", "")
	if text != "":
		return text
	return String(trait_data.get("display_name", "未配置天赋"))


static func _trait_description(character_id: String) -> String:
	return _get_character_text_field(character_id, "trait_description", "未配置")


static func _get_character_text_field(character_id: String, field: String, fallback: String) -> String:
	var document: Dictionary = _get_text_document()
	var characters: Dictionary = UIDisplayHelperScript.dictionary(document.get("characters", {}))
	var text: Dictionary = UIDisplayHelperScript.dictionary(characters.get(character_id, {}))
	if text.has(field):
		return String(text.get(field, fallback))
	_warn_missing_once("character:%s:%s" % [character_id, field])
	return fallback


static func _get_weapon_text_field(weapon_id: String, field: String, fallback: String) -> String:
	var document: Dictionary = _get_text_document()
	var weapons: Dictionary = UIDisplayHelperScript.dictionary(document.get("weapons", {}))
	var text: Dictionary = UIDisplayHelperScript.dictionary(weapons.get(weapon_id, {}))
	if text.has(field):
		return String(text.get(field, fallback))
	_warn_missing_once("weapon:%s:%s" % [weapon_id, field])
	return fallback


static func _get_text_document() -> Dictionary:
	if not _text_cache.is_empty():
		return _text_cache

	if not FileAccess.file_exists(TEXTS_PATH):
		push_warning("[CharacterLoadoutText] Missing text config: %s" % TEXTS_PATH)
		_text_cache = {}
		return _text_cache

	var file: FileAccess = FileAccess.open(TEXTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("[CharacterLoadoutText] Could not open text config: %s" % TEXTS_PATH)
		_text_cache = {}
		return _text_cache

	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK or not (json.data is Dictionary):
		push_warning("[CharacterLoadoutText] Could not parse text config: %s" % TEXTS_PATH)
		_text_cache = {}
		return _text_cache

	_text_cache = (json.data as Dictionary).duplicate(true)
	return _text_cache


static func _warn_missing_once(key: String) -> void:
	if _missing_warning_keys.has(key):
		return
	_missing_warning_keys[key] = true
	push_warning("[CharacterLoadoutText] Missing text config field: %s" % key)
