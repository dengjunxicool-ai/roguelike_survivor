## 文件用途：为调试神系技能卡与状态选项提供 GameData 查询门面，按学习入口条件筛选技能定义。
## 使用方式：通过预加载脚本调用静态方法；配置由 DataManager 发布后读取，调用方不需要自行读 JSON。
extends RefCounted
class_name DevDebugDataSource

## 作用：取得 GameData 已发布的神系有序池，供调试页建立神系切换按钮。
## 使用：通过预加载脚本的 get_god_definitions(...) 静态入口调用。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
static func get_god_definitions() -> Array[Dictionary]:
	return GameData.get_god_pool()

## 作用：筛选 school 或 fusion_school 属于 god_id 且具有升级池入口或 offer_rule 的技能，返回定义深拷贝。
## 使用：通过预加载脚本的 get_god_skill_definitions(...) 静态入口调用。 入参：god_id: StringName。 返回 Array[Dictionary]；具体值及空输入行为见作用说明。
static func get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for skill: Dictionary in GameData.get_all_skill_pool():
		if not is_god_skill_definition(skill, god_id):
			continue
		if not bool(skill.get("offer_in_upgrade_pool", false)) and _get_dictionary(skill.get("offer_rule", {})).is_empty():
			continue
		definitions.append(skill.duplicate(true))
	return definitions

## 作用：判断技能的主神系或融合神系是否匹配 god_id，供调试卡筛选。
## 使用：通过预加载脚本的 is_god_skill_definition(...) 静态入口调用。 入参：skill: Dictionary, god_id: StringName。 返回 bool；具体值及空输入行为见作用说明。
static func is_god_skill_definition(skill: Dictionary, god_id: StringName) -> bool:
	return StringName(_string_or(skill.get("school", ""))) == god_id or StringName(_string_or(skill.get("fusion_school", ""))) == god_id

## 作用：把状态标识转为 StringName 后从 GameData 查询定义；_owner 保留接口但不参与查询。
## 使用：通过预加载脚本的 get_status_definition_for_option(...) 静态入口调用。 入参：_owner: Node, status_id: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
static func get_status_definition_for_option(_owner: Node, status_id: Variant) -> Dictionary:
	return GameData.get_status(StringName(_string_or(status_id)))

## 作用：将 Dictionary 原样返回，其他类型转换为空字典，供读取 offer_rule 时保护类型。
## 使用：通过预加载脚本的 _get_dictionary(...) 静态入口调用。 入参：value: Variant。 返回 Dictionary；具体值及空输入行为见作用说明。
static func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

## 作用：把非空 Variant 转为字符串；null 使用 default_value。
## 使用：通过预加载脚本的 _string_or(...) 静态入口调用。 入参：value: Variant, default_value: String = ""。 返回 String；具体值及空输入行为见作用说明。
static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
