## 文件用途：惰性加载并按 ID 缓存全部敌方技能定义，提供单项和列表查询。
## 使用方式：首次查询从 GameData 构建本实例缓存；技能引用与动作执行由 EnemySkillController 整理。

extends RefCounted
class_name EnemySkillRepository


const EnemySkillDefinitionScript: Script = preload("res://scripts/enemies/skills/enemy_skill_definition.gd")
const GameDataScript: Script = preload("res://scripts/game/game_data.gd")

var _definitions: Dictionary = {}
var _loaded: bool = false


## 作用：获取技能，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 skill_id（技能ID）；返回 RefCounted 对象/值。
func get_skill(skill_id: Variant) -> RefCounted:
	_ensure_loaded()
	var id: StringName = StringName(String(skill_id))
	if not _definitions.has(id):
		return null
	return _definitions[id] as RefCounted


## 作用：获取全部技能组，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；返回 Array[RefCounted] 列表。
func get_all_skills() -> Array[RefCounted]:
	_ensure_loaded()
	var result: Array[RefCounted] = []
	for definition: Variant in _definitions.values():
		if definition is RefCounted:
			result.append(definition)
	return result


## 作用：确保已加载。
## 使用：本文件由 get_skill、get_all_skills 调用。
func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_definitions.clear()
	for data: Dictionary in _load_skill_data():
		var definition: RefCounted = EnemySkillDefinitionScript.new(data)
		var id: StringName = StringName(String(definition.get("id")))
		if id != &"":
			_definitions[id] = definition


## 作用：加载技能数据。
## 使用：本文件由 _ensure_loaded 调用；返回 Array[Dictionary] 列表。
func _load_skill_data() -> Array[Dictionary]:
	return GameDataScript.get_enemy_skill_pool()
