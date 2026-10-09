## 文件用途：保存目标分类、护甲抗性、易伤边界、百分比上限和来源承伤系数快照。
## 使用方式：TargetDamageProfileResolver 创建，计算上下文持有后各阶段共用。
extends RefCounted
class_name TargetDamageProfile


var target_type: StringName = &"normal"
var armor: float = 0.0
var defense: float = 0.0
var resistances: Dictionary = {}
var vulnerability_cap: float = 0.30
var vulnerability_floor: float = -0.60
var true_percent_cap: float = 1.0
var incoming_damage_reduction: float = 0.0
var can_receive_reaction: bool = true
var origin_taken_modifiers: Dictionary = {}


## 作用：判断快照分类是否为 player。
## 使用：返回布尔值，不重新读取目标节点。
func is_player() -> bool:
	return target_type == &"player"


## 作用：判断快照分类是否为 boss。
## 使用：返回布尔值，分类来源为解析时的 enemy_rank。
func is_boss() -> bool:
	return target_type == &"boss"


## 作用：判断快照分类是否为 elite。
## 使用：返回布尔值，不查询组或生命。
func is_elite() -> bool:
	return target_type == &"elite"
