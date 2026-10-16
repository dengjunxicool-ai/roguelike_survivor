## 文件用途：为目标防御、输出倍率与动作共享支持读取可选属性，动态对象保留逐读属性白名单。
## 使用方式：read_value/read_float 的 null 使用默认值；动作专用 read_float_preserving_null 将已声明的 null 安全转零，消除旧 float(null) 报错；每次取当前值，不缓存属性表或属性值。
extends RefCounted
class_name OptionalCombatPropertyReader


## 作用：识别会动态提供或修改属性元数据的脚本对象，包含继承的方法。
## 使用：动态对象必须逐次枚举，避免读取未列出的 _get 值或跳过元数据副作用。
static func uses_dynamic_properties(object: Object) -> bool:
	return object != null and (object.has_method("_get") or object.has_method("_get_property_list") or object.has_method("_validate_property"))


## 作用：读取当前可选值，空对象、缺失属性或 null 值返回默认值。
## 使用：动态对象每次保留原先的属性列表查询和 getter 顺序；普通对象避免分配属性表。
static func read_value(object: Object, property: String, fallback: Variant = null) -> Variant:
	if object == null:
		return fallback
	if uses_dynamic_properties(object):
		for property_info: Dictionary in object.get_property_list():
			if String(property_info.get("name", "")) == property:
				var value: Variant = object.get(property)
				return fallback if value == null else value
		return fallback
	var value: Variant = object.get(property)
	return fallback if value == null else value


## 作用：按可选属性规则读取浮点值，保持调用方的缺省数值。
## 使用：不缓存数值，下一次读取可立即看到属性变化。
static func read_float(object: Object, property: String, fallback: float) -> float:
	return float(read_value(object, property, fallback))


## 作用：保持动作读取契约：缺失使用默认值，已声明的 null 转为零。
## 使用：动态对象保留逐读白名单和 getter 顺序；普通 Actor 非空值直接读取，空值才区分缺失与声明。
static func read_float_preserving_null(object: Object, property: String, fallback: float) -> float:
	if object == null:
		return fallback
	if uses_dynamic_properties(object):
		for property_info: Dictionary in object.get_property_list():
			if str(property_info.get("name", "")) == property:
				var dynamic_value: Variant = object.get(property)
				return 0.0 if dynamic_value == null else float(dynamic_value)
		return fallback
	var value: Variant = object.get(property)
	if value != null:
		return float(value)
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property:
			return 0.0
	return fallback
