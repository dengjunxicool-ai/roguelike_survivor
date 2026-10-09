## 文件用途：保存一次受击应用过程的目标、原包、吸收后包、计算值和终止结果。
## 使用方式：DamageApplicationService 创建后按应用阶段共享，阶段设置 result_object 即终止链路。
extends RefCounted
class_name DamageApplicationContext


var target: Node = null
var packet: DamagePacket = null
var damage_result: Dictionary = {}
var final_amount: int = 0
var reason: StringName = &""
var incoming_amount: int = 0
var absorbed_amount: int = 0
var damage_payload: DamagePacket = null
var trait_system: Node = null
var display_damage_type: StringName = &""
var result_object: RefCounted = null


## 作用：创建目标和包绑定的应用上下文，初始 damage_payload 使用原包。
## 使用：target_node 为受击节点；吸收阶段随后可替换计算包。
static func create(target_node: Node, damage_source: DamagePacket) -> RefCounted:
	var context: RefCounted = new()
	context.target = target_node
	context.packet = damage_source
	context.damage_payload = damage_source
	return context


## 作用：判断某阶段是否已设置最终应用结果。
## 使用：管线每个阶段后查询，用于拒绝、吸收或完成后的短路。
func has_result() -> bool:
	return result_object != null


## 作用：记录结果对象并同步伤害量、计算视图和结束原因。
## 使用：result 为 DamageApplicationResult；null 只清除引用。
func set_result(result: RefCounted) -> void:
	result_object = result
	if result == null:
		return
	final_amount = int(result.get("amount"))
	damage_result = result.get("damage_result")
	reason = result.get("reason")
