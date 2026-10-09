## 文件用途：表示玩家、技能或伤害属性查询的作用域与来源、元素、目标等过滤条件。
## 使用方式：使用 for_player、for_skill 或 for_damage 构建，再用 with_* 增补对象、目标或状态条件。
extends RefCounted
class_name ModifierQuery


const SCOPE_PLAYER: StringName = &"player"
const SCOPE_SKILL: StringName = &"skill"
const SCOPE_MOVEMENT: StringName = &"movement"
const SCOPE_PICKUP: StringName = &"pickup"
const SCOPE_DAMAGE: StringName = &"damage"

var scope: StringName = SCOPE_PLAYER
var owner: Node
var skill_instance: RefCounted
var skill_id: StringName = &""
var source_origin_id: StringName = &""
var damage_origin: StringName = &""
var element: StringName = &""
var object_type: StringName = &""
var target_type: StringName = &""
var status_id: StringName = &""
var tags: Array[StringName] = []


## 作用：创建拥有者为玩家的指定作用域查询。
## 使用：player 为玩家节点。
static func for_player(player: Node, query_scope: StringName = SCOPE_PLAYER) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = query_scope
	query.owner = player
	return query


## 作用：创建技能查询并从定义补充技能 ID 和标签。
## 使用：skill 为技能实例或定义；player 为玩家节点。
static func for_skill(skill: RefCounted, player: Node = null) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = SCOPE_SKILL
	query.owner = player
	query.skill_instance = skill
	if skill != null:
		query.skill_id = StringName(String(skill.get("skill_id")))
		var definition: RefCounted = skill.get("definition") as RefCounted
		if definition != null:
			query.tags = _parse_string_name_array(definition.get("tags"))
	return query


## 作用：从 DamagePacket 来源上下文提取技能、来源、元素、对象及目标信息，构建伤害查询。
## 使用：packet 为待修饰伤害包视图。
static func for_damage(packet: DamagePacket, attacker: Node = null) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = SCOPE_DAMAGE
	query.owner = attacker
	query.source_origin_id = packet.source_context.source_origin_id
	query.skill_id = packet.source_context.source_skill_id
	query.damage_origin = packet.damage_origin
	query.element = packet.element
	query.object_type = packet.source_context.source_type
	query.target_type = StringName(String(packet.get_value("target_type", "")))
	query.status_id = StringName(String(packet.get_value("status_id", "")))
	query.skill_instance = packet.get_value("skill_instance") as SkillInstance
	return query


## 作用：设置查询的战斗对象类型并返回同一查询，支持链式补充。
## 使用：使用 for_player、for_skill 或 for_damage 构建，再用 with_* 增补对象、目标或状态条件。
func with_object_type(value: Variant) -> ModifierQuery:
	object_type = StringName(String(value))
	return self


## 作用：设置查询的目标类型并返回同一查询。
## 使用：使用 for_player、for_skill 或 for_damage 构建，再用 with_* 增补对象、目标或状态条件。
func with_target_type(value: Variant) -> ModifierQuery:
	target_type = StringName(String(value))
	return self


## 作用：设置查询的状态 ID 并返回同一查询。
## 使用：使用 for_player、for_skill 或 for_damage 构建，再用 with_* 增补对象、目标或状态条件。
func with_status_id(value: Variant) -> ModifierQuery:
	status_id = StringName(String(value))
	return self


## 作用：将数组元素转换为非空 StringName 标签列表。
## 使用：由本文件 for_skill 调用。
static func _parse_string_name_array(value: Variant) -> Array[StringName]:
	var parsed: Array[StringName] = []
	if not (value is Array):
		return parsed
	for item: Variant in value:
		var id: StringName = StringName(String(item))
		if id != &"":
			parsed.append(id)
	return parsed
