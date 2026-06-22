extends RefCounted
class_name DamageSourceIdentity


static func for_projectile(cast_instance_id: String, projectile_index: int, source_id: Variant = "") -> String:
	var source_text: String = String(source_id)
	if source_text == "":
		return "%s:projectile:%d" % [cast_instance_id, projectile_index]
	return "%s:projectile:%s:%d" % [cast_instance_id, source_text, projectile_index]


static func for_area(cast_instance_id: String, source_type: String, source_id: Variant = "") -> String:
	var source_text: String = String(source_id)
	if source_text == "":
		return "%s:%s" % [cast_instance_id, source_type]
	return "%s:%s:%s" % [cast_instance_id, source_type, source_text]


static func for_orbit(owner: Node, skill_id: Variant, source_id: Variant = "") -> String:
	var owner_key: String = str(owner.get_instance_id()) if owner != null else "no_owner"
	var skill_text: String = String(skill_id)
	var source_text: String = String(source_id)
	if source_text == "":
		return "%s:orbit:%s" % [owner_key, skill_text]
	return "%s:orbit:%s:%s" % [owner_key, skill_text, source_text]


static func for_status_dot(target: Node, status_id: Variant, applier_source: Variant = "") -> String:
	var status_text: String = String(status_id)
	var target_key: String = str(target.get_instance_id()) if target != null else "no_target"
	var applier_text: String = String(applier_source)
	if applier_text == "":
		return "%s:%s" % [target_key, status_text]
	return "%s:%s:%s" % [target_key, status_text, applier_text]


static func for_reaction(base_source_instance_id: Variant, reaction_type: String, depth: int) -> String:
	var base_text: String = String(base_source_instance_id)
	if base_text == "":
		return "reaction:%s:%d" % [reaction_type, depth]
	return "%s:reaction:%s:%d" % [base_text, reaction_type, depth]
