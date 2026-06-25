extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const SkillComponentRunnerScript: Script = preload("res://scripts/skills/skill_component_runner.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const ModifierStoreScript: Script = preload("res://scripts/modifiers/modifier_store.gd")
const ModifierAggregatorScript: Script = preload("res://scripts/modifiers/modifier_aggregator.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageSystemScript: Script = preload("res://scripts/combat/damage_system.gd")
const SKILLS_DATA_PATH: String = "res://data/skills.json"


class SmokePlayer:
	extends Node2D

	var max_health: int = 160
	var current_health: int = 160
	var selected_character_id: StringName = &""

	func _init() -> void:
		add_to_group(&"player")

	func _ready() -> void:
		if get_node_or_null("ModifierStore") == null:
			var modifier_store: Node = ModifierStoreScript.new()
			modifier_store.name = "ModifierStore"
			add_child(modifier_store)

	func set_run_modifier_source(source_id: Variant, modifiers: Variant) -> void:
		var modifier_store: Node = get_node_or_null("ModifierStore")
		if modifier_store != null and modifier_store.has_method("set_source"):
			modifier_store.call("set_source", source_id, modifiers, _get_run_modifier_scopes(modifiers))

	func _get_run_modifier_scopes(modifiers: Variant) -> Array[StringName]:
		var scopes: Array[StringName] = [ModifierQueryScript.SCOPE_PLAYER]
		var flat_modifiers: Dictionary = ModifierSourceScript.flatten(modifiers)
		for key_variant: Variant in flat_modifiers.keys():
			var key: String = String(key_variant)
			if (key == "damage_multiplier" or key == "damage_multiplier_add" or key.ends_with("_damage_multiplier_add")) and key != "damage_taken_multiplier_add":
				if not scopes.has(ModifierQueryScript.SCOPE_DAMAGE):
					scopes.append(ModifierQueryScript.SCOPE_DAMAGE)
		return scopes


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

	func has_status(status_id: Variant) -> bool:
		return get_status_stack(status_id) > 0

	func consume_status_stack(status_id: Variant, stacks: int = 1) -> bool:
		var manager: Node = get_node_or_null("StatusEffectManager")
		return bool(manager.call("consume_status_stack", status_id, stacks)) if manager != null else false


var _failed: bool = false
var _player: SmokePlayer
var _enemy: SmokeEnemy
var _nearby_enemy: SmokeEnemy
var _far_enemy: SmokeEnemy
var _skill_manager: Node
var _event_bus: Node
var _enemy_status_manager: Node
var _area_tick_events: int = 0


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
	_expect_skill_modifier("primary_attack_damage_multiplier_add", 0.2, "fire_attack_searing applies primary attack modifier")
	_expect_skill_modifier("fire_damage_multiplier_add", 0.0, "fire_attack_searing does not also apply global fire damage")
	_expect_damage_modifier("primary_attack_damage_multiplier_add", 0.2, "fire_attack_searing exposes primary attack modifier to damage runtime")
	_expect_damage_modifier("fire_damage_multiplier_add", 0.0, "fire_attack_searing does not expose duplicate fire modifier to damage runtime")
	_expect_primary_attack_damage_multiplier(1.2, "fire_attack_searing increases primary fire attack damage by 20% once")
	_expect_skill_modifier("dot_damage_multiplier_add", 0.25, "fire_passive_burning_focus applies DOT damage modifier")
	_expect_skill_modifier("status_duration_multiplier_add", 0.2, "fire_passive_burning_focus applies status duration modifier")
	_expect_damage_modifier("dot_damage_multiplier_add", 0.25, "fire_passive_burning_focus exposes DOT modifier to damage runtime", {
		"damage_origin": &"status_dot",
		"element": &"fire",
		"status_id": &"burning",
		"source_skill_id": &"fire_passive_burning_focus"
	})

	var skill_instance: RefCounted = _skill_manager.call("get_skill", &"fire_attack_searing") as RefCounted
	_event_bus.call("subscribe", &"area_tick", Callable(self, "_on_area_tick"))
	_emit(&"attack_hit", skill_instance)
	_expect(_enemy.call("get_status_stack", &"burning") > 0, "fire_attack_searing attack_hit applies Burning", _enemy.call("get_status_stack", &"burning"))
	_enemy.damage_packets.clear()
	_enemy_status_manager.call("update_status_effects", 0.6)
	_expect(_enemy.damage_packets.size() > 0, "fire_attack_searing Burning ticks after skill-applied status", _enemy.damage_packets.size())
	_expect(_max_recorded_raw_damage() > 0.0, "fire_attack_searing Burning tick damage is positive", _enemy.damage_packets)
	_expect(_first_recorded_damage_origin() == &"status_dot", "fire_attack_searing Burning tick uses status_dot origin", _enemy.damage_packets)
	for _index in range(3):
		_emit(&"attack_hit", skill_instance)
	_expect(_count_area_effects(&"searing_fire_path") > 0, "fire_attack_searing creates a short fire path every 4 hits", _count_area_effects(&"searing_fire_path"))
	_emit(&"dash_start", _skill_manager.call("get_skill", &"fire_dash_blazing_run") as RefCounted)
	_expect(_count_area_effects(&"blazing_run_path") > 0, "fire_dash_blazing_run creates a dash fire path", _count_area_effects(&"blazing_run_path"))
	_emit(&"on_cast", _skill_manager.call("get_skill", &"fire_cast_meteor_rain") as RefCounted)
	_emit(&"on_enemy_killed", _skill_manager.call("get_skill", &"fire_power_combustion_chain") as RefCounted)
	_emit(&"on_projectile_hit", _skill_manager.call("get_skill", &"fusion_chaos_fire_riftfire_fork") as RefCounted)
	await process_frame
	await process_frame
	_expect(_area_tick_events > 0, "fire ground emits area_tick events for fire synergies", _area_tick_events)

	var component_runner: RefCounted = SkillComponentRunnerScript.new()
	var meteor_skill: RefCounted = _skill_manager.call("get_skill", &"fire_cast_meteor_rain") as RefCounted
	_expect(bool(component_runner.call("tick", meteor_skill, 999.0, _base_context(meteor_skill))), "fire_cast_meteor_rain auto-casts from trigger_rules", "tick=false")

	_enemy.call("apply_status", &"burning", {"stacks": 1, "duration": 4.0, "power": 16.0})
	_enemy.damage_packets.clear()
	_enemy_status_manager.call("update_status_effects", 0.6)
	_expect(_enemy.damage_packets.size() > 0, "burning tick produces a damage packet", _enemy.damage_packets.size())
	_expect(_max_recorded_raw_damage() > 0.0, "burning tick damage is positive", _enemy.damage_packets)
	_expect(_first_recorded_damage_origin() == &"status_dot", "burning tick uses status_dot origin", _enemy.damage_packets)

	for _index in range(7):
		_enemy.call("apply_status", &"chilled", {"stacks": 1, "duration": 6.0})
	_expect(_enemy.call("get_status_stack", &"frozen") > 0, "chilled max stack applies frozen", _enemy.call("get_status_stack", &"frozen"))

	var action_executor: RefCounted = SkillActionExecutorScript.new()
	_enemy.damage_packets.clear()
	_nearby_enemy.damage_packets.clear()
	_far_enemy.damage_packets.clear()
	action_executor.call("execute_action", {"type": "deal_damage", "params": {"amount": 11, "radius": 200.0}}, _base_context(skill_instance))
	_expect(_enemy.damage_packets.size() > 0, "radius damage hits primary target", _enemy.damage_packets.size())
	_expect(_nearby_enemy.damage_packets.size() > 0, "radius damage hits enemies within 200px", _nearby_enemy.damage_packets.size())
	_expect(_far_enemy.damage_packets.is_empty(), "radius damage ignores enemies outside 200px", _far_enemy.damage_packets.size())

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

	_nearby_enemy = SmokeEnemy.new()
	_nearby_enemy.name = "NearbySmokeEnemy"
	_nearby_enemy.global_position = _enemy.global_position + Vector2(190.0, 0.0)
	root.add_child(_nearby_enemy)

	_far_enemy = SmokeEnemy.new()
	_far_enemy.name = "FarSmokeEnemy"
	_far_enemy.global_position = _enemy.global_position + Vector2(240.0, 0.0)
	root.add_child(_far_enemy)


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
		"position": _enemy.global_position,
		"damage_packet": {
			"raw_amount": 16,
			"amount": 16,
			"damage_origin": &"primary_attack",
			"damage_type": &"direct_magical",
			"element": &"fire",
			"source_skill_id": &"fireball"
		}
	}


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _expect_skill_modifier(key: String, expected: float, label: String) -> void:
	var modifiers: Dictionary = ModifierSourceScript.flatten(_skill_manager.get("passive_modifiers"))
	var actual: float = float(modifiers.get(key, 0.0))
	_expect(absf(actual - expected) <= 0.0001, label, actual)


func _expect_damage_modifier(key: String, expected: float, label: String, packet: Dictionary = {}) -> void:
	if packet.is_empty():
		packet = {
		"damage_origin": &"primary_attack",
		"element": &"fire",
		"source_skill_id": &"fire_attack_searing"
		}
	var modifiers: Dictionary = ModifierAggregatorScript.collect(ModifierQueryScript.for_damage(packet, _player), _skill_manager)
	var actual: float = float(modifiers.get(key, 0.0))
	_expect(absf(actual - expected) <= 0.0001, label, actual)


func _expect_primary_attack_damage_multiplier(expected_multiplier: float, label: String) -> void:
	var packet: Dictionary = {
		"raw_amount": 100,
		"amount": 100,
		"damage_origin": &"primary_attack",
		"damage_type": &"direct_magical",
		"element": &"fire",
		"source_type": "projectile",
		"source_skill_id": &"fire_attack_searing",
		"attacker": _player,
		"can_crit": false,
		"uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false
	}
	var result: Dictionary = DamageSystemScript.calculate(packet, _enemy, &"", _player)
	var stages: Dictionary = result.get("stages", {})
	var actual: float = float(stages.get("origin_multiplier", 0.0)) * float(stages.get("element_multiplier", 0.0))
	_expect(absf(actual - expected_multiplier) <= 0.0001, label, stages)


func _count_area_effects(source_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if StringName(String(child.get_meta("source_id", ""))) == source_id:
			count += 1
	return count


func _on_area_tick(_context: Dictionary) -> void:
	_area_tick_events += 1


func _max_recorded_raw_damage() -> float:
	var result: float = 0.0
	for packet_variant: Variant in _enemy.damage_packets:
		if packet_variant is Dictionary:
			var packet: Dictionary = packet_variant
			result = maxf(result, float(packet.get("raw_amount", packet.get("amount", 0.0))))
	return result


func _first_recorded_damage_origin() -> StringName:
	for packet_variant: Variant in _enemy.damage_packets:
		if packet_variant is Dictionary:
			var packet: Dictionary = packet_variant
			return StringName(String(packet.get("damage_origin", "")))
	return &""


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_fire_skill_runtime_smoke] FAIL %s actual=%s" % [label, str(actual)])
