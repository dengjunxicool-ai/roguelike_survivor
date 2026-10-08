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


static func for_player(player: Node, query_scope: StringName = SCOPE_PLAYER) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = query_scope
	query.owner = player
	return query


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


func with_object_type(value: Variant) -> ModifierQuery:
	object_type = StringName(String(value))
	return self


func with_target_type(value: Variant) -> ModifierQuery:
	target_type = StringName(String(value))
	return self


func with_status_id(value: Variant) -> ModifierQuery:
	status_id = StringName(String(value))
	return self


static func _parse_string_name_array(value: Variant) -> Array[StringName]:
	var parsed: Array[StringName] = []
	if not (value is Array):
		return parsed
	for item: Variant in value:
		var id: StringName = StringName(String(item))
		if id != &"":
			parsed.append(id)
	return parsed
