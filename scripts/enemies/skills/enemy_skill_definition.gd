## 文件用途：封装敌方技能 ID、动作类型与参数配置。
## 使用方式：通过配置构建定义，由 repository/controller 读取；执行参数按定义与覆盖值合成。

extends RefCounted
class_name EnemySkillDefinition


var id: StringName = &""
var display_name: String = ""
var runtime: String = "active"
var cooldown: float = 0.0
var actions: Array[Dictionary] = []
var _data: Dictionary = {}


## 作用：初始化本对象所需的配置与内部状态。
## 使用：对象构造时自动执行；传入构造参数后再使用公开接口；输入 data（数据）。
func _init(data: Dictionary = {}) -> void:
	_data = data.duplicate(true)
	id = StringName(String(data.get("id", "")))
	display_name = String(data.get("display_name", String(id)))
	runtime = String(data.get("runtime", "active"))
	cooldown = maxf(float(data.get("cooldown", 0.0)), 0.0)
	actions = _get_dictionary_array(data.get("actions", []))


## 作用：是否包含动作类型，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 action_type（动作类型）。
func has_action_type(action_type: String) -> bool:
	for action: Dictionary in actions:
		if String(action.get("type", "")) == action_type:
			return true
	return false


## 作用：获取动作列表按类型，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 action_type（动作类型）；返回 Array[Dictionary] 列表。
func get_actions_by_type(action_type: String) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for action: Dictionary in actions:
		if String(action.get("type", "")) == action_type:
			matched.append(action.duplicate(true))
	return matched


## 作用：转换字典。
## 使用：供本模块调用者使用；返回结果字典。
func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


## 作用：获取字典数组，供当前模块后续逻辑使用。
## 使用：本文件由 _init 调用；输入 value（值）；返回 Array[Dictionary] 列表。
func _get_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			result.append(item.duplicate(true))
	return result
