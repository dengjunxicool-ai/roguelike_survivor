## 文件用途：提供角色特性的统一接口及参数、Modifier 与初始技能查询辅助方法。
## 使用方式：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果。
extends RefCounted
class_name CharacterTrait


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const DamageAbsorbResultScript: Script = preload("res://scripts/characters/events/damage_absorb_result.gd")

var config: Dictionary = {}
var context: RefCounted


## 作用：深拷贝特性配置并保存角色上下文，供子类共享读取。
## 使用：trait_config 为当前角色特性配置；trait_context 为角色和场景树上下文。
func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	config = trait_config.duplicate(true)
	context = trait_context


## 作用：特性基类帧更新占位入口，当前默认没有计时行为。
## 使用：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果。
func process(_delta: float) -> void:
	pass


## 作用：特性基类事件占位入口，当前默认不处理事件。
## 使用：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果。
func handle_event(_event: RefCounted) -> void:
	pass


## 作用：特性基类属性占位入口，当前默认返回空快照。
## 使用：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果；无适用数据时返回空字典。
func get_modifiers(_query: RefCounted) -> Dictionary:
	return {}


## 作用：特性基类吸收占位入口，默认原样返回伤害且吸收值为零。
## 使用：amount 为本次伤害或动作数值。
func absorb_damage(amount: int, _event: RefCounted) -> RefCounted:
	return DamageAbsorbResultScript.unchanged(amount)


## 作用：特性基类调试占位入口，默认返回空状态。
## 使用：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果；无适用数据时返回空字典。
func get_debug_state() -> Dictionary:
	return {}


## 作用：读取当前特性配置 params 字典；非字典配置按空参数处理。
## 使用：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果。
func _get_params() -> Dictionary:
	return _get_dictionary(config.get("params", {}))


## 作用：仅接受 Dictionary；直接返回原字典引用，其余类型返回空字典。
## 使用：由本文件 _get_params 调用；无适用数据时返回空字典。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：把特性配置效果列表转为带角色特性来源语义的属性快照。
## 使用：TraitRegistry 创建其子类，控制器先 setup，再按事件和帧调度；默认实现不产生属性或吸收效果。
func _get_modifier_values(value: Array) -> Dictionary:
	return ModifierSourceScript.flatten_effects(value, ModifierSourceScript.SOURCE_CHARACTER_TRAIT)


## 作用：比较技能 ID 与上下文角色的初始技能 ID，缺角色上下文时不匹配。
## 使用：skill_id 为标准技能 ID；返回布尔判断或执行是否成功。
func _is_starting_skill(skill_id: Variant) -> bool:
	if context == null or not context.has_method("get_starting_skill_id"):
		return false
	return StringName(String(skill_id)) == StringName(String(context.call("get_starting_skill_id")))
