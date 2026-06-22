extends SceneTree


const SKILLS_DATA_PATH: String = "res://data/skills.json"
const CARD_SKILL_ID: StringName = &"mars_spark_missile"
const PROJECTILE_SOURCE_ID: StringName = &"mars_spark_missile_projectile"
const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillExecutorScript: Script = preload("res://scripts/skills/skill_executor.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")


class SmokeEnemy:
	extends Node2D

	var damage_packets: Array = []
	var statuses: Dictionary = {}

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, damage_type: Variant = &"") -> void:
		damage_packets.append({
			"packet": packet,
			"damage_type": damage_type
		})

	func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
		statuses[StringName(String(status_id))] = params.duplicate(true)
		return true

	func is_dead() -> bool:
		return false


var _failed: bool = false
var _selected_skill: Dictionary = {}
var _player: Node2D
var _skill_manager: Node
var _skill_executor: Node
var _event_bus: Node
var _target: SmokeEnemy


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_selected_skill = _load_skill_from_data_file(CARD_SKILL_ID)
	if _selected_skill.is_empty():
		_fail("card selected: missing %s in %s" % [String(CARD_SKILL_ID), SKILLS_DATA_PATH])
		_finish()
		return

	_expect(String(_selected_skill.get("god_id", "")) == "fire", "card selected")
	_expect(bool(_selected_skill.get("offer_in_upgrade_pool", false)), "card selected from upgrade pool")

	await process_frame
	var data_manager: Node = _get_data_manager()
	if data_manager == null:
		_fail("DataManager autoload missing at /root/DataManager")
		_finish()
		return
	if not data_manager.has_method("get_skill_definition"):
		_fail("DataManager missing get_skill_definition(skill_id)")
		_finish()
		return

	var runtime_definition_variant: Variant = data_manager.call("get_skill_definition", CARD_SKILL_ID)
	var runtime_definition: Dictionary = runtime_definition_variant if runtime_definition_variant is Dictionary else {}
	_expect(not runtime_definition.is_empty(), "runtime skill definition found for selected card")
	_expect(_runtime_definition_matches_selected_contract(runtime_definition), "DataManager exposes data/skills.json contract for selected card")

	_build_runtime_nodes()
	await process_frame
	if _player == null or _skill_manager == null or _skill_executor == null or _event_bus == null:
		_finish()
		return

	_try_grant_skill()
	await _try_trigger_attack()
	await _try_trigger_hit_feedback()
	_finish()


func _load_skill_from_data_file(skill_id: StringName) -> Dictionary:
	if not FileAccess.file_exists(SKILLS_DATA_PATH):
		return {}

	var file: FileAccess = FileAccess.open(SKILLS_DATA_PATH, FileAccess.READ)
	if file == null:
		_fail("could not open %s: %s" % [SKILLS_DATA_PATH, error_string(FileAccess.get_open_error())])
		return {}

	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK:
		_fail("could not parse %s line %d: %s" % [SKILLS_DATA_PATH, json.get_error_line(), json.get_error_message()])
		return {}

	if not (json.data is Dictionary):
		_fail("%s root must be a Dictionary" % SKILLS_DATA_PATH)
		return {}

	var document: Dictionary = json.data
	for section_name: String in ["skills", "starting_skills"]:
		var section: Array = document.get(section_name, [])
		for item_variant: Variant in section:
			if item_variant is Dictionary:
				var item: Dictionary = item_variant
				if StringName(String(item.get("id", ""))) == skill_id:
					return item.duplicate(true)

	return {}


func _get_data_manager() -> Node:
	return root.get_node_or_null("DataManager")


func _runtime_definition_matches_selected_contract(runtime_definition: Dictionary) -> bool:
	if runtime_definition.is_empty():
		return false
	var keys_to_match: Array[String] = [
		"god_id",
		"runtime_family",
		"offer_in_upgrade_pool",
		"particle"
	]
	for key: String in keys_to_match:
		if not runtime_definition.has(key):
			_fail("DataManager.get_skill_definition(%s) missing data/skills.json field '%s'; runtime still appears to use the legacy loader" % [String(CARD_SKILL_ID), key])
			return false
		if str(runtime_definition.get(key)) != str(_selected_skill.get(key)):
			_fail("DataManager.get_skill_definition(%s) field '%s' differs from data/skills.json" % [String(CARD_SKILL_ID), key])
			return false
	return true


func _build_runtime_nodes() -> void:
	_player = Node2D.new()
	_player.name = "SmokePlayer"
	_player.global_position = Vector2.ZERO
	root.add_child(_player)

	_skill_manager = SkillManagerScript.new()
	_skill_manager.name = "SkillManager"
	_player.add_child(_skill_manager)

	_event_bus = SkillEventBusScript.new()
	_event_bus.name = "SkillEventBus"
	_player.add_child(_event_bus)

	_skill_executor = SkillExecutorScript.new()
	_skill_executor.name = "SkillExecutor"
	_skill_executor.set("skill_manager_path", NodePath("../SkillManager"))
	_skill_executor.set("event_bus_path", NodePath("../SkillEventBus"))
	_skill_executor.set("target_group", &"enemies")
	_player.add_child(_skill_executor)

	_target = SmokeEnemy.new()
	_target.name = "SmokeEnemy"
	_target.global_position = Vector2(180.0, 0.0)
	root.add_child(_target)

	_expect(_skill_manager.has_method("add_skill"), "SkillManager.add_skill available")
	_expect(_skill_executor.has_method("debug_cast_all_skills"), "SkillExecutor.debug_cast_all_skills available")
	_expect(_event_bus.has_method("emit_skill_event"), "SkillEventBus.emit_skill_event available")


func _try_grant_skill() -> void:
	if _skill_manager == null or not _skill_manager.has_method("add_skill"):
		_fail("cannot grant skill: SkillManager.add_skill missing")
		return

	var granted: bool = bool(_skill_manager.call("add_skill", CARD_SKILL_ID))
	_expect(granted, "skill granted to player")
	if not granted:
		_fail("SkillManager.add_skill(%s) returned false; selected data/skills.json card is not wired into runtime learning yet" % String(CARD_SKILL_ID))
		return

	_expect(bool(_skill_manager.call("has_skill", CARD_SKILL_ID)), "selected fire skill is active on player")


func _try_trigger_attack() -> void:
	if _skill_executor == null or not _skill_executor.has_method("debug_cast_all_skills"):
		_fail("cannot trigger attack: SkillExecutor.debug_cast_all_skills missing")
		return

	var before_projectiles: int = _count_projectile_feedback_nodes()
	var cast_count: int = int(_skill_executor.call("debug_cast_all_skills", 1001))
	await process_frame
	await process_frame
	var after_projectiles: int = _count_projectile_feedback_nodes()
	_expect(cast_count > 0, "attack triggered")
	_expect(after_projectiles > before_projectiles, "projectile or particle feedback observed")


func _try_trigger_hit_feedback() -> void:
	var skill_instance: RefCounted = null
	if _skill_manager != null and _skill_manager.has_method("get_skill"):
		skill_instance = _skill_manager.call("get_skill", CARD_SKILL_ID) as RefCounted
	if skill_instance == null:
		_fail("cannot trigger hit feedback: SkillManager.get_skill(%s) returned null" % String(CARD_SKILL_ID))
		return

	var before_damage: int = _target.damage_packets.size()
	_event_bus.call("emit_skill_event", &"on_projectile_hit", {
		"caster": _player,
		"owner": _player,
		"target": _target,
		"source_id": PROJECTILE_SOURCE_ID,
		"source_skill_id": CARD_SKILL_ID,
		"skill_id": CARD_SKILL_ID,
		"skill_instance": skill_instance,
		"skill_manager": _skill_manager,
		"event_bus": _event_bus,
		"parent": root,
		"target_group": &"enemies",
		"debug_attack_trace_id": 1002
	})
	await process_frame

	var expected_status_or_runtime: bool = _skill_expects_status_or_runtime_feedback(_selected_skill)
	var has_status_or_runtime: bool = not _target.statuses.is_empty() or _skill_has_runtime_effect_trace(skill_instance)
	_expect((not expected_status_or_runtime) or has_status_or_runtime, "status or runtime effect observed when expected")

	var has_damage: bool = _target.damage_packets.size() > before_damage
	_expect(has_damage, "damage popup or damage trace observed")
	_expect(has_damage and _last_damage_packet_uses_formula_chain(), "damage formula chain used")


func _count_projectile_feedback_nodes() -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child is Area2D:
			count += 1
		if child.has_meta("source_id") or child.has_meta("source_skill_id"):
			count += 1
		count += _count_particle_nodes(child)
	return count


func _count_particle_nodes(node: Node) -> int:
	var count: int = 0
	if node is GPUParticles2D:
		count += 1
	for child: Node in node.get_children():
		count += _count_particle_nodes(child)
	return count


func _skill_expects_status_or_runtime_feedback(skill: Dictionary) -> bool:
	if skill.has("runtime_rules") and skill.get("runtime_rules") is Dictionary and not (skill.get("runtime_rules") as Dictionary).is_empty():
		return true
	for event_variant: Variant in skill.get("events", []):
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		for action_variant: Variant in event.get("actions", []):
			if action_variant is Dictionary:
				var action: Dictionary = action_variant
				var action_type: String = String(action.get("type", ""))
				if action_type == "apply_status" or action_type == "spawn_particles":
					return true
	return false


func _skill_has_runtime_effect_trace(skill_instance: RefCounted) -> bool:
	if skill_instance == null:
		return false
	var runtime_rules: Variant = skill_instance.get("runtime_special_rules")
	if runtime_rules is Dictionary and not (runtime_rules as Dictionary).is_empty():
		return true
	var runtime_events: Variant = skill_instance.get("runtime_events")
	return runtime_events is Array and not (runtime_events as Array).is_empty()


func _last_damage_packet_uses_formula_chain() -> bool:
	if _target.damage_packets.is_empty():
		return false
	var last_record: Dictionary = _target.damage_packets[_target.damage_packets.size() - 1]
	var packet_variant: Variant = last_record.get("packet")
	var packet: Dictionary = packet_variant if packet_variant is Dictionary else {}
	if packet.is_empty():
		return false
	return packet.has("damage_origin") and packet.has("damage_type") and packet.has("source_skill_id") and packet.has("source_instance_id")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL %s" % message)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("[verify_fire_skill_card_selection_runtime] PASS")
	quit(0)
