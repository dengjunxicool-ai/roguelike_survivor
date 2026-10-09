## 文件用途：将配置与解锁信息格式化为图鉴条目。
## 使用方式：图鉴页创建实例后调用 build；各 _build_*_rows 生成展示文本数组。

extends RefCounted
class_name CodexViewModelBuilder


## 作用：整理上下文和配置为页面展示模型。
## 使用：由页面或局内编排的构建流程调用；结果按声明类型供后续展示/执行使用；返回字典包含 tabs。
func build() -> Dictionary:
	return {
		"tabs": [
			{"title": "角色", "rows": _build_character_rows()},
			{"title": "技能", "rows": _build_skill_rows()},
			{"title": "怪物", "rows": _build_enemy_rows()},
			{"title": "状态", "rows": _build_status_rows()},
			{"title": "遗物", "rows": _build_relic_rows()},
		]
	}


## 作用：构建角色行列表。
## 使用：本文件由 build 调用；返回 Array[String] 列表。
func _build_character_rows() -> Array[String]:
	var rows: Array[String] = []
	for character: Dictionary in GameData.get_character_pool():
		rows.append("%s：%s" % [
			String(character.get("display_name", character.get("id", ""))),
			String(character.get("description", ""))
		])
	return rows


## 作用：构建技能行列表。
## 使用：本文件由 build 调用；返回 Array[String] 列表。
func _build_skill_rows() -> Array[String]:
	var rows: Array[String] = []
	for skill: Dictionary in GameData.get_skill_pool():
		rows.append("%s：%s / %s" % [
			String(skill.get("display_name", skill.get("id", ""))),
			String(skill.get("school", "")),
			String(skill.get("description", ""))
		])
	return rows


## 作用：构建敌人行列表。
## 使用：本文件由 build 调用；返回 Array[String] 列表。
func _build_enemy_rows() -> Array[String]:
	var rows: Array[String] = []
	for enemy: Dictionary in GameData.get_enemy_pool():
		rows.append("%s：%s，HP %s，防御 %s" % [
			String(enemy.get("display_name", enemy.get("id", ""))),
			String(enemy.get("enemy_rank", "normal")),
			str(_get_dictionary(enemy.get("base_stats", {})).get("max_hp", "-")),
			str(_get_dictionary(enemy.get("base_stats", {})).get("armor", "-"))
		])
	return rows


## 作用：构建状态效果行列表。
## 使用：本文件由 build 调用；返回 Array[String] 列表。
func _build_status_rows() -> Array[String]:
	var rows: Array[String] = []
	for status: Dictionary in GameData.get_status_pool():
		rows.append("%s：%s / 最大层数 %s" % [
			String(status.get("display_name", status.get("id", ""))),
			String(status.get("type", "")),
			str(status.get("max_stacks", "-"))
		])
	return rows


## 作用：构建遗物行列表。
## 使用：本文件由 build 调用；返回 Array[String] 列表。
func _build_relic_rows() -> Array[String]:
	var rows: Array[String] = []
	for relic: Dictionary in GameData.get_relic_pool():
		rows.append("%s：%s" % [
			String(relic.get("display_name", relic.get("id", ""))),
			String(relic.get("description", ""))
		])
	return rows


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _build_enemy_rows 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
