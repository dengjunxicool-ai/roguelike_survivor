## 文件用途：保存角色配置的独立副本，包括基础属性、特性、初始技能和外观。
## 使用方式：由 CharacterRuntime 或 RunLoadout 用 GameData 的角色字典构造，再通过属性和查询方法读取。
extends RefCounted
class_name CharacterDefinition


var id: StringName = &""
var display_name: String = ""
var description: String = ""
var role: String = ""
var base_stats: Dictionary = {}
var trait_data: Dictionary = {}
var starting_skill_id: StringName = &""
var unlock: Dictionary = {}
var visual: Dictionary = {}


## 作用：从角色配置读取身份、初始技能及显示字段，并深拷贝属性、特性、解锁和外观字典。
## 使用：由 CharacterRuntime 或 RunLoadout 用 GameData 的角色字典构造，再通过属性和查询方法读取。
func _init(data: Dictionary = {}) -> void:
	id = StringName(String(data.get("id", "")))
	display_name = String(data.get("display_name", id))
	description = String(data.get("description", ""))
	role = String(data.get("role", ""))
	base_stats = _get_dictionary(data.get("base_stats", {}))
	trait_data = _get_dictionary(data.get("trait", {}))
	starting_skill_id = StringName(String(data.get("starting_skill_id", "")))
	unlock = _get_dictionary(data.get("unlock", {"type": "default"}))
	visual = _get_dictionary(data.get("visual", {}))


## 作用：读取定义中的单项基础数值，并在未配置时返回调用方默认值。
## 使用：stat_name 为待查询属性键；default_value 为缺值备用结果。
func get_base_stat(stat_name: String, default_value: Variant = 0) -> Variant:
	return base_stats.get(stat_name, default_value)


## 作用：返回角色特性配置副本，供控制器创建本局特性。
## 使用：由 CharacterRuntime 或 RunLoadout 用 GameData 的角色字典构造，再通过属性和查询方法读取。
func get_trait() -> Dictionary:
	return trait_data.duplicate(true)


## 作用：仅接受 Dictionary；深拷贝输出以隔离调用方修改，其余类型返回空字典。
## 使用：由本文件 _init 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}

