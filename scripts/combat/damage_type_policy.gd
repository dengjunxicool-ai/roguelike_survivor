## 文件用途：保存某种伤害类型的防御权重、暴击默认、忽略规则和允许来源。
## 使用方式：由 DamageRuleRegistry 创建，供包默认值和合法组合检查。
extends RefCounted
class_name DamageTypePolicy


var damage_type: StringName = &""
var defense_rate: float = 0.0
var ignores_resistance: bool = false
var ignores_vulnerability: bool = false
var can_crit_by_default: bool = false
var allowed_origins: Array[StringName] = []


## 作用：按类型名解析防御、忽略、暴击和来源集合。
## 使用：values 为登记策略，返回类型策略对象。
static func from_dictionary(type_value: String, values: Dictionary) -> RefCounted:
	var policy: RefCounted = new()
	policy.damage_type = StringName(type_value)
	policy.defense_rate = float(values.get("defense_rate", 0.0))
	policy.ignores_resistance = bool(values.get("ignore_resistance", false))
	policy.ignores_vulnerability = bool(values.get("ignore_vulnerability", false))
	policy.can_crit_by_default = bool(values.get("can_crit_by_default", false))
	policy.allowed_origins = _string_name_array(values.get("allowed_origins", []))
	return policy


## 作用：检查来源是否在该类型允许的列表中。
## 使用：origin 转为 StringName 后查表，不做回退。
func allows_origin(origin: String) -> bool:
	return allowed_origins.has(StringName(origin))


## 作用：将数组内容转换为去空、去重的 StringName 列表。
## 使用：非数组返回空列表，用于来源标签或状态等标识符集合。
static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			var name: StringName = StringName(String(item))
			if name != &"" and not result.has(name):
				result.append(name)
	return result
