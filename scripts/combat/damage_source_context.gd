## 文件用途：保存攻击者和角色、技能、动作、槽位、实例来源及标签。
## 使用方式：DamagePacket 将来源子对象与伤害量分开持有；序列化时过滤已释放攻击者引用。
extends RefCounted
class_name DamageSourceContext


var source_type: StringName = &""
var attacker: Node = null
var attacker_id: String = ""
var source_origin_id: StringName = &""
var source_skill_id: StringName = &""
var source_instance_id: String = ""
var source_action_id: StringName = &""
var source_slot_id: StringName = &""
var owner_character_id: StringName = &""
var tags: Array[StringName] = []


## 作用：读取来源标识并过滤无效攻击者引用、规范标签列表。
## 使用：packet 为来源字典；返回独立来源对象。
static func from_dictionary(packet: Dictionary) -> RefCounted:
	var context: RefCounted = new()
	context.source_type = StringName(String(packet.get("source_type", "")))
	context.attacker = _valid_node_or_null(packet.get("attacker"))
	context.attacker_id = String(packet.get("attacker_id", ""))
	context.source_origin_id = StringName(String(packet.get("source_origin_id", "")))
	context.source_skill_id = StringName(String(packet.get("source_skill_id", "")))
	context.source_instance_id = String(packet.get("source_instance_id", ""))
	context.source_action_id = StringName(String(packet.get("source_action_id", "")))
	context.source_slot_id = StringName(String(packet.get("source_slot_id", "")))
	context.owner_character_id = StringName(String(packet.get("owner_character_id", "")))
	context.tags = _string_name_array(packet.get("source_tags", []))
	return context


## 作用：把来源核心字段和非空可选身份写入深复制字典。
## 使用：攻击者失效时导出 null，标签导出副本。
func apply_to_dictionary(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	result["source_type"] = source_type
	result["attacker"] = attacker if attacker != null and is_instance_valid(attacker) else null
	result["attacker_id"] = attacker_id
	result["source_origin_id"] = source_origin_id
	result["source_skill_id"] = source_skill_id
	result["source_instance_id"] = source_instance_id
	if source_action_id != &"":
		result["source_action_id"] = source_action_id
	if source_slot_id != &"":
		result["source_slot_id"] = source_slot_id
	if owner_character_id != &"":
		result["owner_character_id"] = owner_character_id
	if not tags.is_empty():
		result["source_tags"] = tags.duplicate()
	return result


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


## 作用：把仍有效的输入节点返回，无效对象引用转为空。
## 使用：来源解析时使用，防止访问已释放攻击者。
static func _valid_node_or_null(value: Variant) -> Node:
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
		return null
	return value as Node
