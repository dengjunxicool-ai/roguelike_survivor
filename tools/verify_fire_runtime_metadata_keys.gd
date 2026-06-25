extends SceneTree

const FireSkillRuntimeScript: Script = preload("res://scripts/skills/fire_skill_runtime.gd")


class SkillStub:
	extends RefCounted
	var skill_id: StringName = &"fireball"
	var runtime_modifiers: Dictionary = {}
	var definition: RefCounted = null


class DefinitionStub:
	extends RefCounted
	var category: String = "active"
	var tags: Array[String] = ["fire"]


class SkillManagerStub:
	extends Node
	var skills: Array[RefCounted] = []

	func get_all_skills() -> Array[RefCounted]:
		return skills


func _init() -> void:
	var skill: SkillStub = SkillStub.new()
	FireSkillRuntimeScript._set_runtime_modifier(
		skill,
		"high_health_bonus:heart_scorch_weakness",
		"damage_multiplier_add",
		0.12
	)

	var invalid_keys: Array[String] = []
	for key: StringName in skill.get_meta_list():
		if not String(key).is_valid_ascii_identifier():
			invalid_keys.append(String(key))
	if not invalid_keys.is_empty():
		push_error("Fire runtime metadata keys must be valid identifiers: %s" % ", ".join(invalid_keys))
		quit(1)
		return
	if not skill.has_meta("high_health_bonus_heart_scorch_weakness_runtime_originals"):
		push_error("Fire runtime must store originals under a sanitized high-health metadata key.")
		quit(1)
		return

	var passive_skill: SkillStub = SkillStub.new()
	passive_skill.skill_id = &"furnace_granted_seal"
	FireSkillRuntimeScript._apply_charge_empower({
		"charges_required": 2,
		"damage_multiplier_add": 0.18
	}, {
		"passive_skill_instance": passive_skill,
		"skill_instance": skill
	})
	invalid_keys.clear()
	for key: StringName in passive_skill.get_meta_list():
		if not String(key).is_valid_ascii_identifier():
			invalid_keys.append(String(key))
	if not invalid_keys.is_empty():
		push_error("Fire charge metadata keys must be valid identifiers: %s" % ", ".join(invalid_keys))
		quit(1)
		return
	if not passive_skill.has_meta("fire_runtime_charge_furnace_granted_seal"):
		push_error("Fire charge runtime must store charges under a sanitized metadata key.")
		quit(1)
		return

	passive_skill.skill_id = &"kill_trigger:fire"
	skill.definition = DefinitionStub.new()
	var skill_manager: SkillManagerStub = SkillManagerStub.new()
	skill_manager.skills = [skill]
	FireSkillRuntimeScript._apply_kill_trigger({
		"chance": 1.0,
		"effect": "empower",
		"damage_multiplier_add": 0.05,
		"max_stacks": 3,
		"damage": 0
	}, {
		"passive_skill_instance": passive_skill
	}, skill_manager, null)
	invalid_keys.clear()
	for key: StringName in passive_skill.get_meta_list():
		if not String(key).is_valid_ascii_identifier():
			invalid_keys.append(String(key))
	if not invalid_keys.is_empty():
		push_error("Fire kill-trigger metadata keys must be valid identifiers: %s" % ", ".join(invalid_keys))
		quit(1)
		return
	if not passive_skill.has_meta("kill_trigger_stack_count_kill_trigger_fire"):
		push_error("Fire kill-trigger stack count must use a sanitized metadata key.")
		quit(1)
		return

	var target: Node = Node.new()
	FireSkillRuntimeScript._apply_stack_mark({
		"stack_id": "soul:ember",
		"max_stacks": 4,
		"stacks_required": 4,
		"damage": 0
	}, {
		"target": target
	}, null)
	invalid_keys.clear()
	for key: StringName in target.get_meta_list():
		if not String(key).is_valid_ascii_identifier():
			invalid_keys.append(String(key))
	if not invalid_keys.is_empty():
		push_error("Fire stack-mark metadata keys must be valid identifiers: %s" % ", ".join(invalid_keys))
		quit(1)
		return
	if not target.has_meta("soul_ember"):
		push_error("Fire stack-mark rules must sanitize data-driven stack ids.")
		quit(1)
		return
	target.free()
	skill_manager.free()
	print("verify_fire_runtime_metadata_keys: PASS")
	quit(0)
