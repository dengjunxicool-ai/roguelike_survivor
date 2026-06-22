extends RefCounted
class_name CodexViewModelBuilder


func build() -> Dictionary:
	return {
		"tabs": [
			{"title": "角色", "rows": _build_character_rows()},
			{"title": "武器", "rows": _build_weapon_rows()},
			{"title": "怪物", "rows": _build_enemy_rows()},
			{"title": "状态", "rows": _build_status_rows()},
			{"title": "遗物", "rows": _build_relic_rows()},
		]
	}


func _build_character_rows() -> Array[String]:
	var rows: Array[String] = []
	for character: Dictionary in GameData.get_character_pool():
		rows.append("%s：%s" % [
			String(character.get("display_name", character.get("id", ""))),
			String(character.get("description", ""))
		])
	return rows


func _build_weapon_rows() -> Array[String]:
	var rows: Array[String] = []
	for weapon: Dictionary in GameData.get_weapon_pool():
		rows.append("%s：%s / %s" % [
			String(weapon.get("display_name", weapon.get("id", ""))),
			String(weapon.get("starting_skill_id", "")),
			String(weapon.get("description", ""))
		])
	return rows


func _build_enemy_rows() -> Array[String]:
	var rows: Array[String] = []
	for enemy: Dictionary in GameData.get_enemy_pool():
		rows.append("%s：%s，HP %s，防御 %s" % [
			String(enemy.get("display_name", enemy.get("id", ""))),
			String(enemy.get("type", "normal")),
			str(_get_dictionary(enemy.get("base_stats", {})).get("max_hp", "-")),
			str(_get_dictionary(enemy.get("base_stats", {})).get("armor", "-"))
		])
	return rows


func _build_status_rows() -> Array[String]:
	var rows: Array[String] = []
	for status: Dictionary in GameData.get_status_pool():
		rows.append("%s：%s / 最大层数 %s" % [
			String(status.get("display_name", status.get("id", ""))),
			String(status.get("type", "")),
			str(status.get("max_stacks", "-"))
		])
	return rows


func _build_relic_rows() -> Array[String]:
	var rows: Array[String] = []
	for relic: Dictionary in GameData.get_relic_pool():
		rows.append("%s：%s" % [
			String(relic.get("display_name", relic.get("id", ""))),
			String(relic.get("description", ""))
		])
	return rows



func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
