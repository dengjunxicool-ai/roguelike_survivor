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
var weapon_id: StringName = &""
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
	query.weapon_id = _get_runtime_weapon_id(player)
	return query


static func for_skill(skill: RefCounted, player: Node = null) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = SCOPE_SKILL
	query.owner = player
	query.skill_instance = skill
	query.weapon_id = _get_runtime_weapon_id(player)
	if skill != null:
		query.skill_id = StringName(String(skill.get("skill_id")))
		var definition: RefCounted = skill.get("definition") as RefCounted
		if definition != null:
			query.tags = _parse_string_name_array(definition.get("tags"))
	return query


static func for_damage(packet: Dictionary, attacker: Node = null) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = SCOPE_DAMAGE
	query.owner = attacker
	query.weapon_id = StringName(String(packet.get("source_weapon_id", _get_runtime_weapon_id(attacker))))
	query.skill_id = StringName(String(packet.get("source_skill_id", packet.get("skill_id", ""))))
	query.damage_origin = StringName(String(packet.get("damage_origin", "")))
	query.element = StringName(String(packet.get("element", "")))
	query.object_type = StringName(String(packet.get("source_type", packet.get("object_type", ""))))
	query.target_type = StringName(String(packet.get("target_type", "")))
	query.status_id = StringName(String(packet.get("status_id", "")))
	query.skill_instance = packet.get("skill_instance") as RefCounted
	return query


static func for_damage_any(packet_source: Variant, attacker: Node = null) -> ModifierQuery:
	var query: ModifierQuery = ModifierQuery.new()
	query.scope = SCOPE_DAMAGE
	query.owner = attacker
	query.weapon_id = StringName(String(_packet_value(packet_source, "source_weapon_id", _get_runtime_weapon_id(attacker))))
	query.skill_id = StringName(String(_packet_value(packet_source, "source_skill_id", _packet_value(packet_source, "skill_id", ""))))
	query.damage_origin = StringName(String(_packet_value(packet_source, "damage_origin", "")))
	query.element = StringName(String(_packet_value(packet_source, "element", "")))
	query.object_type = StringName(String(_packet_value(packet_source, "source_type", _packet_value(packet_source, "object_type", ""))))
	query.target_type = _resolve_target_type(packet_source)
	query.status_id = StringName(String(_packet_value(packet_source, "status_id", "")))
	query.skill_instance = _packet_value(packet_source, "skill_instance", null) as RefCounted
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


static func _get_runtime_weapon_id(player: Node) -> StringName:
	if player == null:
		return &""
	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	if runtime != null:
		return StringName(String(runtime.call("get_equipped_weapon_id")))
	var weapon_variant: Variant = player.get("selected_weapon_id")
	return StringName(String(weapon_variant)) if weapon_variant != null else &""


static func _parse_string_name_array(value: Variant) -> Array[StringName]:
	var parsed: Array[StringName] = []
	if not (value is Array):
		return parsed
	for item: Variant in value:
		var id: StringName = StringName(String(item))
		if id != &"":
			parsed.append(id)
	return parsed


static func _packet_value(packet_source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).get(key, fallback)
	if packet_source is RefCounted:
		if packet_source.has_method("packet_value"):
			return packet_source.call("packet_value", key, fallback)
		if packet_source.has_method("get_value"):
			return packet_source.call("get_value", key, fallback)
		var value: Variant = packet_source.get(String(key))
		return value if value != null else fallback
	return fallback


static func _resolve_target_type(packet_source: Variant) -> StringName:
	var configured: Variant = _packet_value(packet_source, "target_type", "")
	if String(configured) != "":
		return StringName(String(configured))
	var profile: RefCounted = _packet_value(packet_source, "target_profile", null) as RefCounted
	if profile != null:
		return StringName(String(profile.get("target_type")))
	return &""
