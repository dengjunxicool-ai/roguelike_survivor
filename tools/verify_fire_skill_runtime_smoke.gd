extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const SKILLS_DATA_PATH: String = "res://data/skills.json"


class SmokePlayer:
	extends Node2D

	var max_health: int = 160
	var current_health: int = 160
	var attack_power: float = 24.0
	var damage: float = 24.0
	var base_damage: float = 24.0
	var selected_character_id: StringName = &""

	func _init() -> void:
		add_to_group(&"player")


class SmokeEnemy:
	extends Node2D

	var max_health: int = 400
	var current_health: int = 400
	var damage_packets: Array = []

	func _init() -> void:
		add_to_group(&"enemies")

	func take_damage(packet: Variant, _damage_type: Variant = &"") -> void:
		damage_packets.append(packet)

	func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
		var manager: Node = get_node_or_null("StatusEffectManager")
		return bool(manager.call("apply_status", status_id, params)) if manager != null else false

	func get_status_stack(status_id: Variant) -> int:
		var manager: Node = get_node_or_null("StatusEffectManager")
		return int(manager.call("get_status_stack", status_id)) if manager != null else 0

	func consume_status_stack(status_id: Variant, stacks: int = 1) -> bool:
		var manager: Node = get_node_or_null("StatusEffectManager")
		return bool(manager.call("consume_status_stack", status_id, stacks)) if manager != null else false


var _failed: bool = false
var _player: SmokePlayer
var _enemy: SmokeEnemy
var _skill_manager: Node
var _event_bus: Node
var _enemy_status_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_nodes()
	var upgrade_pool: RefCounted = UpgradePoolScript.new()
	var generated_options: Array = upgrade_pool.call("generate_options", _player, 3)
	_expect(generated_options is Array, "UpgradePool handles null fire skill offer fields", typeof(generated_options))
	var skill_ids: Array[StringName] = _load_skill_ids()
	_expect(skill_ids.size() == 34, "loads all 34 first-version fire skills", skill_ids.size())
	for skill_id: StringName in skill_ids:
		_expect(bool(_skill_manager.call("add_skill", skill_id)), "learns %s" % String(skill_id), "add_skill=false")
	_expect(_skill_manager.call("get_all_skills").size() == 34, "SkillManager learned 34 skills", _skill_manager.call("get_all_skills").size())

	var skill_instance: RefCounted = _skill_manager.call("get_skill", &"fire_attack_searing") as RefCounted
	_emit(&"attack_hit", skill_instance)
	_emit(&"dash_start", _skill_manager.call("get_skill", &"fire_dash_blazing_run") as RefCounted)
	_emit(&"on_cast", _skill_manager.call("get_skill", &"fire_cast_meteor_rain") as RefCounted)
	_emit(&"on_enemy_killed", _skill_manager.call("get_skill", &"fire_power_combustion_chain") as RefCounted)
	_emit(&"on_projectile_hit", _skill_manager.call("get_skill", &"fusion_chaos_fire_riftfire_fork") as RefCounted)

	_enemy.call("apply_status", &"burning", {"stacks": 1, "duration": 4.0})
	_enemy_status_manager.call("update_status_effects", 0.6)
	_expect(_enemy.damage_packets.size() > 0, "burning tick produces a damage packet", _enemy.damage_packets.size())

	for _index in range(7):
		_enemy.call("apply_status", &"chilled", {"stacks": 1, "duration": 6.0})
	_expect(_enemy.call("get_status_stack", &"frozen") > 0, "chilled max stack applies frozen", _enemy.call("get_status_stack", &"frozen"))

	var action_executor: RefCounted = SkillActionExecutorScript.new()
	action_executor.call("execute_action", {"type": "grant_shield", "params": {"shield_type": "smoke", "max_health_ratio": 0.05}}, _base_context(skill_instance))
	_expect(int(_player.get_meta("fire_passive_shield", 0)) > 0, "grant_shield writes absorbable shield", _player.get_meta("fire_passive_shield", 0))

	await process_frame
	if not _failed:
		print("[verify_fire_skill_runtime_smoke] PASS")
	quit(1 if _failed else 0)


func _build_nodes() -> void:
	_player = SmokePlayer.new()
	_player.name = "SmokePlayer"
	root.add_child(_player)

	_skill_manager = SkillManagerScript.new()
	_skill_manager.name = "SkillManager"
	_player.add_child(_skill_manager)

	_event_bus = SkillEventBusScript.new()
	_event_bus.name = "SkillEventBus"
	_player.add_child(_event_bus)

	_enemy = SmokeEnemy.new()
	_enemy.name = "SmokeEnemy"
	_enemy.global_position = Vector2(140.0, 0.0)
	root.add_child(_enemy)

	_enemy_status_manager = StatusEffectManagerScript.new()
	_enemy_status_manager.name = "StatusEffectManager"
	_enemy.add_child(_enemy_status_manager)


func _load_skill_ids() -> Array[StringName]:
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
		if skill_variant is Dictionary:
			var id: StringName = StringName(String((skill_variant as Dictionary).get("id", "")))
			if id != &"":
				result.append(id)
	return result


func _emit(event_name: StringName, skill_instance: RefCounted) -> void:
	_event_bus.call("emit_skill_event", event_name, _base_context(skill_instance))


func _base_context(skill_instance: RefCounted) -> Dictionary:
	return {
		"caster": _player,
		"owner": _player,
		"player": _player,
		"target": _enemy,
		"enemy": _enemy,
		"skill_instance": skill_instance,
		"skill_id": StringName(String(skill_instance.get("skill_id"))) if skill_instance != null else &"",
		"skill_manager": _skill_manager,
		"event_bus": _event_bus,
		"parent": root,
		"target_group": &"enemies",
		"position": _enemy.global_position
	}


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_fire_skill_runtime_smoke] FAIL %s actual=%s" % [label, str(actual)])
