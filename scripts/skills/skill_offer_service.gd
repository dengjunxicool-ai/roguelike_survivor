extends RefCounted
class_name SkillOfferService


const KNOWN_EXCLUSIVE_GROUPS: Array[String] = [
	"attack_school",
	"dash_school",
	"core_school"
]


func is_skill_available(player: Node, skill: Dictionary) -> bool:
	var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null:
		return false
	if _has_learned(skill_manager, skill_id):
		return false
	if _is_blocked_by_capacity(skill_manager, skill):
		return false
	if _is_blocked_by_exclusive_group(skill_manager, skill):
		return false
	if _get_skill_type(skill) == "fusion" and _has_any_fusion(skill_manager):
		return false
	return _offer_rule_met(skill_manager, _get_dictionary(skill.get("offer_rule", {})))


func _is_blocked_by_capacity(skill_manager: Node, skill: Dictionary) -> bool:
	var category: String = _get_skill_category(skill)
	if category == "passive":
		return skill_manager.has_method("is_passive_skill_full") and bool(skill_manager.call("is_passive_skill_full"))
	if category == "active" and _is_capacity_counted_active_skill(skill):
		return skill_manager.has_method("is_active_skill_full") and bool(skill_manager.call("is_active_skill_full"))
	return false


func _is_capacity_counted_active_skill(skill: Dictionary) -> bool:
	var skill_type: String = _get_skill_type(skill)
	return (
		not bool(skill.get("is_starting_skill", false))
		and _string_or(skill.get("category", ""), "") != "starting_skill"
		and _string_or(skill.get("exclusive_group", ""), "") != "attack_school"
		and _string_or(skill.get("exclusive_group", ""), "") != "dash_school"
		and skill_type != "attack"
		and skill_type != "dash"
	)


func _offer_rule_met(skill_manager: Node, offer_rule: Dictionary) -> bool:
	for school_variant: Variant in _get_array(offer_rule.get("required_schools", [])):
		if _count_school(skill_manager, StringName(_string_or(school_variant, ""))) <= 0:
			return false
	for skill_variant: Variant in _get_array(offer_rule.get("required_skills", [])):
		if not _has_learned(skill_manager, StringName(_string_or(skill_variant, ""))):
			return false
	var min_counts: Dictionary = _get_dictionary(offer_rule.get("required_min_skill_count", {}))
	for school_variant: Variant in min_counts.keys():
		if _count_school(skill_manager, StringName(_string_or(school_variant, ""))) < int(min_counts[school_variant]):
			return false
	return true


func _is_blocked_by_exclusive_group(skill_manager: Node, skill: Dictionary) -> bool:
	var blocked_groups: Array = _get_array(_get_dictionary(skill.get("offer_rule", {})).get("blocked_by_exclusive_group", []))
	var own_group: String = _string_or(skill.get("exclusive_group", ""), "")
	if own_group != "" or KNOWN_EXCLUSIVE_GROUPS.has(own_group):
		blocked_groups.append(own_group)
	for group_variant: Variant in blocked_groups:
		if _has_exclusive_group(skill_manager, _string_or(group_variant, "")):
			return true
	return false


func _has_exclusive_group(skill_manager: Node, group: String) -> bool:
	if group == "":
		return false
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance != null and _string_or(skill_instance.get("exclusive_group"), "") == group:
			return true
	return false


func _has_any_fusion(skill_manager: Node) -> bool:
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance != null and _string_or(skill_instance.get("skill_type"), "") == "fusion":
			return true
	return false


func _count_school(skill_manager: Node, school: StringName) -> int:
	if school == &"":
		return 0
	var count: int = 0
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance == null:
			continue
		if _skill_instance_has_school(skill_instance, school):
			count += 1
	return count


func _skill_instance_has_school(skill_instance: RefCounted, school: StringName) -> bool:
	if StringName(_string_or(skill_instance.get("school"), "")) == school:
		return true
	if StringName(_string_or(skill_instance.get("fusion_school"), "")) == school:
		return true

	var definition: RefCounted = skill_instance.get("definition") as RefCounted
	if definition == null:
		return false
	if StringName(_string_or(definition.get("school"), "")) == school:
		return true
	if StringName(_string_or(definition.get("fusion_school"), "")) == school:
		return true

	var tags: Array = _get_array(definition.get("tags"))
	if tags.has(_string_or(school, "")):
		return true

	var base: Dictionary = _get_dictionary(definition.get("base"))
	return StringName(_string_or(base.get("element", ""), "")) == school


func _has_learned(skill_manager: Node, skill_id: StringName) -> bool:
	if skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
		return true
	if skill_manager.has_method("has_learned_skill") and bool(skill_manager.call("has_learned_skill", skill_id)):
		return true
	return false


func _get_all_skills(skill_manager: Node) -> Array:
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var value: Variant = skill_manager.call("get_all_skills")
		if value is Array:
			return value
	return []


func _get_skill_manager(player: Node) -> Node:
	if player == null:
		return null
	var manager: Node = player.get_node_or_null("SkillManager")
	if manager != null:
		return manager
	if player.has_method("get_skill_manager"):
		var value: Variant = player.call("get_skill_manager")
		if value is Node:
			return value
	return null


func _get_skill_type(skill: Dictionary) -> String:
	return _string_or(skill.get("skill_type", skill.get("type", skill.get("category", ""))), "")


func _get_skill_category(skill: Dictionary) -> String:
	var category: String = _string_or(skill.get("category", ""), "")
	if category == "active" or category == "passive":
		return category

	match _get_skill_type(skill):
		"passive":
			return "passive"
		"attack", "dash", "cast", "summon", "power", "core", "fusion":
			return "active"
		_:
			return category


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else String(value)
