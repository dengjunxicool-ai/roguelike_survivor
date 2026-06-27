extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")
const ModifierStoreScript: Script = preload("res://scripts/modifiers/modifier_store.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const SKILLS_DATA_PATH: String = "res://data/skills/skills.json"


class SmokePlayer:
	extends Node2D

	var attack_power: float = 24.0
	var max_health: int = 160
	var current_health: int = 160

	func _init() -> void:
		add_to_group(&"player")

	func _ready() -> void:
		var modifier_store: Node = ModifierStoreScript.new()
		modifier_store.name = "ModifierStore"
		add_child(modifier_store)

	func set_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
		var modifier_store: Node = get_node_or_null("ModifierStore")
		if modifier_store != null and modifier_store.has_method("set_source"):
			modifier_store.call("set_source", source_id, modifiers, [ModifierQueryScript.SCOPE_PLAYER, ModifierQueryScript.SCOPE_DAMAGE])


class SmokeEnemy:
	extends Node2D

	var max_health: int = 500
	var current_health: int = 500
	var damage_packets: Array = []

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet)
		var amount: int = int(packet.get("amount", packet.get("raw_amount", 0))) if packet is Dictionary else int(packet)
		current_health = maxi(current_health - amount, 0)

	func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
		var manager: Node = get_node_or_null("StatusEffectManager")
		return bool(manager.call("apply_status", status_id, params)) if manager != null else false

	func get_status_stack(status_id: Variant) -> int:
		var manager: Node = get_node_or_null("StatusEffectManager")
		return int(manager.call("get_status_stack", status_id)) if manager != null else 0

	func has_status(status_id: Variant) -> bool:
		return get_status_stack(status_id) > 0

	func is_dead() -> bool:
		return current_health <= 0


var _failed: bool = false
var _player: SmokePlayer
var _enemy: SmokeEnemy
var _conductive_enemy: SmokeEnemy
var _cluster_enemy: SmokeEnemy
var _skill_manager: Node
var _event_bus: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_nodes()
	var skill_ids: Array[StringName] = _load_thunder_skill_ids()
	_expect(skill_ids.size() == 14, "loads all 14 first-version thunder skills", skill_ids.size())
	for skill_id: StringName in skill_ids:
		_expect(bool(_skill_manager.call("add_skill", skill_id)), "learns %s" % str(skill_id), "add_skill=false")
	_expect(_skill_manager.call("get_all_skills").size() == 14, "SkillManager learned 14 thunder skills", _skill_manager.call("get_all_skills").size())
	_expect_skill_modifier("primary_attack_damage_multiplier_add", 0.15, "thunder attack applies one primary attack modifier")

	var thunder_attack: RefCounted = _skill_manager.call("get_skill", &"thunder_attack_thundering") as RefCounted
	_emit(&"attack_hit", thunder_attack)
	_expect(_enemy.call("get_status_stack", &"conductive") > 0, "thunder attack_hit applies Conductive", _enemy.call("get_status_stack", &"conductive"))

	_emit_without_target(&"dash_start", _skill_manager.call("get_skill", &"thunder_dash_ball_lightning") as RefCounted)
	await process_frame
	_expect(_count_area_effects(&"ball_lightning_path") > 0, "ball lightning dash creates a visible path area", _count_area_effects(&"ball_lightning_path"))
	_emit_without_target(&"dash_end", _skill_manager.call("get_skill", &"thunder_dash_ball_lightning") as RefCounted)
	await process_frame
	_expect(_count_area_effects(&"ball_lightning_orb") > 0, "ball lightning leaves a discharge orb on dash_end", _count_area_effects(&"ball_lightning_orb"))

	_emit_without_target(&"on_cast", _skill_manager.call("get_skill", &"thunder_cast_chain_lightning") as RefCounted)
	await process_frame
	_expect(_count_projectiles(&"chain_lightning_bolt") > 0, "chain lightning spawns a projectile without explicit target", _count_projectiles(&"chain_lightning_bolt"))
	_expect(_projectile_damage_for(&"chain_lightning_bolt") > 0, "chain lightning projectile carries nonzero damage", _projectile_damage_for(&"chain_lightning_bolt"))

	_free_area_effects(&"thunderstorm_cloud")
	await process_frame
	_clear_statuses(_enemy)
	_conductive_enemy.call("apply_status", &"conductive", {"stacks": 1, "duration": 5.0})
	_expect(_conductive_enemy.call("get_status_stack", &"conductive") > 0, "left cluster enemy has Conductive before storm targeting", _conductive_enemy.call("get_status_stack", &"conductive"))
	var storm_skill: RefCounted = _skill_manager.call("get_skill", &"thunder_cast_storm_circle") as RefCounted
	storm_skill.set_meta("trigger_cd_on_cast_global", 0.0)
	_emit_without_target(&"on_cast", storm_skill)
	await process_frame
	_expect(_count_area_effects(&"thunderstorm_cloud") > 0, "thunderstorm creates a visible cloud", _count_area_effects(&"thunderstorm_cloud"))
	_expect(_area_position_near(&"thunderstorm_cloud", _conductive_enemy.global_position, 8.0), "thunderstorm prioritizes Conductive cluster target", _area_position_for(&"thunderstorm_cloud"))

	_emit_without_target(&"on_cast", _skill_manager.call("get_skill", &"thunder_cast_emp_ring") as RefCounted)
	await process_frame
	_expect(_count_area_effects(&"emp_ring") > 0, "EMP creates a visible ring", _count_area_effects(&"emp_ring"))

	for _index in range(5):
		_enemy.call("apply_status", &"conductive", {"stacks": 1, "duration": 5.0, "power": 24.0})
	await process_frame
	_expect(_count_area_effects(&"overload_burst") > 0, "Conductive max stack triggers overload burst", _count_area_effects(&"overload_burst"))

	_emit(&"on_cast", _skill_manager.call("get_skill", &"thunder_summon_storm_lynx") as RefCounted)
	_emit(&"on_cast", _skill_manager.call("get_skill", &"thunder_summon_storm_crow") as RefCounted)
	await process_frame
	_expect(_count_summons(&"storm_lynx") > 0, "storm lynx spawns through Summon system", _count_summons(&"storm_lynx"))
	_expect(_count_summons(&"storm_crow") > 0, "storm crow spawns through Summon system", _count_summons(&"storm_crow"))

	if not _failed:
		print("[verify_thunder_skill_runtime_smoke] PASS")
	quit(1 if _failed else 0)


func _build_nodes() -> void:
	_player = SmokePlayer.new()
	_player.name = "ThunderSmokePlayer"
	root.add_child(_player)

	_skill_manager = SkillManagerScript.new()
	_skill_manager.name = "SkillManager"
	_player.add_child(_skill_manager)

	_event_bus = SkillEventBusScript.new()
	_event_bus.name = "SkillEventBus"
	_player.add_child(_event_bus)

	_enemy = _create_enemy("ThunderSmokeEnemy", Vector2(140.0, 0.0))
	_conductive_enemy = _create_enemy("ConductiveThunderSmokeEnemy", Vector2(-220.0, 0.0))
	_cluster_enemy = _create_enemy("ClusterThunderSmokeEnemy", Vector2(-245.0, 22.0))


func _create_enemy(enemy_name: String, position: Vector2) -> SmokeEnemy:
	var enemy: SmokeEnemy = SmokeEnemy.new()
	enemy.name = enemy_name
	enemy.global_position = position
	root.add_child(enemy)
	var status_manager: Node = StatusEffectManagerScript.new()
	status_manager.name = "StatusEffectManager"
	enemy.add_child(status_manager)
	return enemy


func _load_thunder_skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var file: FileAccess = FileAccess.open(SKILLS_DATA_PATH, FileAccess.READ)
	if file == null:
		_fail("opens skills.json", error_string(FileAccess.get_open_error()))
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("skills.json root is dictionary", typeof(parsed))
		return result
	for skill_variant: Variant in (parsed as Dictionary).get("skills", []):
		if not (skill_variant is Dictionary):
			continue
		var skill: Dictionary = skill_variant as Dictionary
		if str(skill.get("school", "")) != "thunder" or skill.get("fusion_school", null) != null:
			continue
		var id: StringName = StringName(str(skill.get("id", "")))
		if id != &"":
			result.append(id)
	return result


func _emit(event_name: StringName, skill_instance: RefCounted) -> void:
	_event_bus.call("emit_skill_event", event_name, _base_context(skill_instance))


func _emit_without_target(event_name: StringName, skill_instance: RefCounted) -> void:
	var context: Dictionary = _base_context(skill_instance)
	context.erase("target")
	context.erase("enemy")
	context.erase("position")
	_event_bus.call("emit_skill_event", event_name, context)


func _base_context(skill_instance: RefCounted) -> Dictionary:
	return {
		"caster": _player,
		"owner": _player,
		"player": _player,
		"target": _enemy,
		"enemy": _enemy,
		"skill_instance": skill_instance,
		"skill_id": StringName(str(skill_instance.get("skill_id"))) if skill_instance != null else &"",
		"skill_manager": _skill_manager,
		"event_bus": _event_bus,
		"parent": root,
		"target_group": &"enemies",
		"position": _enemy.global_position,
		"power": 24.0,
		"damage_packet": {
			"raw_amount": 24,
			"amount": 24,
			"damage_origin": &"primary_attack",
			"damage_type": &"direct_magical",
			"element": &"lightning",
			"source_skill_id": &"thunder_attack_thundering"
		}
	}


func _expect_skill_modifier(key: String, expected: float, label: String) -> void:
	var modifiers: Dictionary = ModifierSourceScript.flatten(_skill_manager.get("passive_modifiers"))
	var actual: float = float(modifiers.get(key, 0.0))
	_expect(absf(actual - expected) <= 0.0001, label, actual)


func _count_area_effects(source_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			count += 1
	return count


func _free_area_effects(source_id: StringName) -> void:
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			child.queue_free()


func _count_projectiles(source_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		var projectile_source_id: StringName = StringName(str(child.get("source_id"))) if child.get("source_id") != null else StringName(str(child.get_meta("source_id", "")))
		if projectile_source_id == source_id:
			count += 1
	return count


func _projectile_damage_for(source_id: StringName) -> int:
	for child: Node in root.get_children():
		var projectile_source_id: StringName = StringName(str(child.get("source_id"))) if child.get("source_id") != null else StringName(str(child.get_meta("source_id", "")))
		if projectile_source_id == source_id:
			return int(child.get("damage"))
	return 0


func _area_position_near(source_id: StringName, position: Vector2, tolerance: float) -> bool:
	return _area_position_for(source_id).distance_to(position) <= tolerance


func _area_position_for(source_id: StringName) -> Vector2:
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			var area: Node2D = child as Node2D
			return area.global_position if area != null else Vector2.INF
	return Vector2.INF


func _clear_statuses(enemy: Node) -> void:
	var manager: Node = enemy.get_node_or_null("StatusEffectManager") if enemy != null else null
	if manager != null and manager.has_method("clear_statuses"):
		manager.call("clear_statuses")


func _count_summons(definition_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child.has_meta("summon_definition_id") and StringName(str(child.get_meta("summon_definition_id", ""))) == definition_id:
			count += 1
		for grandchild: Node in child.get_children():
			if grandchild.has_meta("summon_definition_id") and StringName(str(grandchild.get_meta("summon_definition_id", ""))) == definition_id:
				count += 1
	return count


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_thunder_skill_runtime_smoke] FAIL %s actual=%s" % [label, str(actual)])
