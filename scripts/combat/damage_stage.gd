## 文件用途：定义按方法名转发的通用伤害计算阶段。
## 使用方式：create 传阶段名与宿主处理方法；宿主缺失该方法时原值透传。
extends RefCounted
class_name DamageStage


var stage_name: StringName = &""
var processor_name: StringName = &""


## 作用：保存阶段名称与待调用宿主处理方法名。
## 使用：两项转换为 StringName，返回通用阶段对象。
static func create(name_value: Variant, processor_value: Variant) -> RefCounted:
	var stage: RefCounted = new()
	stage.stage_name = StringName(String(name_value))
	stage.processor_name = StringName(String(processor_value))
	return stage


## 作用：调用配置的宿主方法处理上下文和输入；无有效方法则透传输入。
## 使用：host 要实现 processor_name，返回值供下一阶段继续计算。
func apply_with_host(host: Object, calculation_context: RefCounted, input_value: Variant) -> Variant:
	if host == null or processor_name == &"" or not host.has_method(processor_name):
		return input_value
	return host.call(processor_name, calculation_context, input_value)


## 作用：导出阶段名称与处理器方法名称。
## 使用：用于诊断，不执行伤害计算。
func to_dictionary() -> Dictionary:
	return {
		"name": stage_name,
		"processor": processor_name
	}
