## 文件用途：集中提供神系规则共用的敌人分类、目标身份、元数据 key、血量比例和容器读取。
## 使用方式：各规则族通过宿主或静态调用使用；分类依赖目标公开信息，key 使用项目统一元数据规范。
extends RefCounted
class_name SpecialRuleCommon


const MetadataKeyScript: Script = preload("res://scripts/core/metadata_key.gd")


## 作用：根据目标的标准敌人等级判断 Boss。
## 使用：target 为本次命中目标。
static func is_boss(target: Node) -> bool:
	return target != null and String(target.get_meta("enemy_rank", "")) == "boss"


## 作用：根据目标的标准敌人等级判断精英。
## 使用：target 为本次命中目标。
static func is_elite(target: Node) -> bool:
	return target != null and String(target.get_meta("enemy_rank", "")) == "elite"


## 作用：判断目标是否为 Boss 核心，供核心专属规则使用。
## 使用：target 为本次命中目标。
static func is_boss_core(target: Node) -> bool:
	return target != null and String(target.get_meta("enemy_rank", "")) == "boss_core"


## 作用：使用有效目标实例身份构造同目标冷却和命中记录键。
## 使用：target 为本次命中目标。
static func target_key(target: Node) -> String:
	return str(target.get_instance_id()) if target != null else "none"


## 作用：通过项目 MetadataKey 规范组合规则命名空间与后缀。
## 使用：各规则族通过宿主或静态调用使用；分类依赖目标公开信息，key 使用项目统一元数据规范。
static func metadata_key(namespace_text: String, suffix: String) -> String:
	return MetadataKeyScript.key(namespace_text, suffix, "skill_rule")


## 作用：将规则键转换为项目允许的统一元数据标识。
## 使用：各规则族通过宿主或静态调用使用；分类依赖目标公开信息，key 使用项目统一元数据规范。
static func metadata_identifier(raw_key: String) -> String:
	return MetadataKeyScript.identifier(raw_key, "skill_rule")


## 作用：读取目标生命比例并夹紧到零至一。
## 使用：target 为本次命中目标。
static func health_ratio(target: Node) -> float:
	if target == null:
		return 1.0
	var max_health: float = maxf(float(target.get("max_health")), 1.0)
	return clampf(float(target.get("current_health")) / max_health, 0.0, 1.0)


## 作用：从目标运动属性判断其是否正在移动。
## 使用：target 为本次命中目标；返回布尔判断或执行是否成功。
static func is_target_moving(target: Node) -> bool:
	if target == null:
		return false
	var velocity_variant: Variant = target.get("velocity")
	if velocity_variant is Vector2:
		return (velocity_variant as Vector2).length_squared() > 1.0
	return false


## 作用：把引擎单调毫秒计时转换为冷却使用的秒数。
## 使用：各规则族通过宿主或静态调用使用；分类依赖目标公开信息，key 使用项目统一元数据规范。
static func now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## 作用：仅接受 Dictionary；深拷贝输出以隔离调用方修改，其余类型返回空字典。
## 使用：各规则族通过宿主或静态调用使用；分类依赖目标公开信息，key 使用项目统一元数据规范；无适用数据时返回空字典。
static func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：仅接受 Array；深拷贝输出以隔离调用方修改，其余类型返回空数组。
## 使用：各规则族通过宿主或静态调用使用；分类依赖目标公开信息，key 使用项目统一元数据规范；无匹配项时返回空数组。
static func get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
