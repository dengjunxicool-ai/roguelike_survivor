extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")
const SKILLS_DATA_PATH: String = "res://data/skills/skills.json"


class SmokePlayer:
	extends Node2D

	var attack_power: float = 24.0
	var max_health: int = 240
	var current_health: int = 240

	func _init() -> void:
		add_to_group(&"player")

	func set_run_modifier_source(_source_id: Variant, _modifiers: Variant) -> void:
		pass


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
var _nearby_enemy: SmokeEnemy
var _skill_manager: Node
var _event_bus: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_nodes()
	var fusion_ids: Array[StringName] = _load_fusion_skill_ids()
	_expect(fusion_ids.size() == 60, "loads all 60 fusion skills", fusion_ids.size())
	for skill_id: StringName in fusion_ids:
		_expect(bool(_skill_manager.call("add_skill", skill_id)), "learns %s" % str(skill_id), "add_skill=false")
	_expect(_skill_manager.call("get_all_skills").size() == 60, "SkillManager learned 60 fusion skills", _skill_manager.call("get_all_skills").size())

	_enemy.call("apply_status", &"burning", {"stacks": 1, "duration": 4.0, "power": 24.0})
	_emit(&"area_tick", _skill_manager.call("get_skill", &"fusion_fire_frost_steam_mist") as RefCounted, {"target": _enemy, "source_id": &"frost_field"})
	await process_frame
	_expect(_count_area_effects(&"fusion_fire_frost_steam_mist_area") > 0, "fire frost steam mist reacts to area_tick", _count_area_effects(&"fusion_fire_frost_steam_mist_area"))
	_expect(_close(_area_float(&"fusion_fire_frost_steam_mist_area", "radius"), 168.0), "steam mist runtime radius uses R2.0", _area_float(&"fusion_fire_frost_steam_mist_area", "radius"))
	_expect(_close(_area_float(&"fusion_fire_frost_steam_mist_area", "duration"), 3.0), "steam mist runtime duration is 3s", _area_float(&"fusion_fire_frost_steam_mist_area", "duration"))
	_expect(_close(_area_float(&"fusion_fire_frost_steam_mist_area", "tick_interval"), 0.5), "steam mist runtime tick is 0.5s", _area_float(&"fusion_fire_frost_steam_mist_area", "tick_interval"))

	_enemy.call("apply_status", &"frozen", {"stacks": 1, "duration": 1.2, "power": 24.0})
	_emit(&"post_damage_hit", _skill_manager.call("get_skill", &"fusion_frost_thunder_lightning_ice_pillar") as RefCounted, {"target": _enemy, "damage_packet": _packet(&"lightning")})
	await process_frame
	_expect(_count_area_effects(&"fusion_frost_thunder_lightning_ice_pillar_area") > 0, "frost thunder lightning ice pillar has runtime output", _count_area_effects(&"fusion_frost_thunder_lightning_ice_pillar_area"))
	_expect(_close(_area_float(&"fusion_frost_thunder_lightning_ice_pillar_area", "radius"), 58.8), "lightning ice pillar runtime radius uses R0.7", _area_float(&"fusion_frost_thunder_lightning_ice_pillar_area", "radius"))
	_expect(_close(_area_float(&"fusion_frost_thunder_lightning_ice_pillar_area", "duration"), 3.0), "lightning ice pillar runtime duration is 3s", _area_float(&"fusion_frost_thunder_lightning_ice_pillar_area", "duration"))
	_expect(_close(_area_float(&"fusion_frost_thunder_lightning_ice_pillar_area", "tick_interval"), 1.0), "lightning ice pillar runtime tick is 1s", _area_float(&"fusion_frost_thunder_lightning_ice_pillar_area", "tick_interval"))

	_enemy.call("apply_status", &"conductive", {"stacks": 1, "duration": 5.0, "power": 24.0})
	_emit(&"shield_gained", _skill_manager.call("get_skill", &"fusion_thunder_holy_shield_capacitor") as RefCounted, {"target": _enemy})
	await process_frame
	_expect(_count_area_effects(&"fusion_thunder_holy_shield_capacitor_area") > 0 or _count_projectiles(&"fusion_thunder_holy_shield_capacitor_projectile") > 0, "thunder holy shield capacitor reacts to shield_gained", _count_area_effects(&"fusion_thunder_holy_shield_capacitor_area"))

	_enemy.call("apply_status", &"cursed", {"stacks": 1, "duration": 3.0, "power": 24.0})
	_emit(&"status_max_stack_reached", _skill_manager.call("get_skill", &"fusion_curse_chaos_paradox_curse_mark") as RefCounted, {"target": _enemy, "status_id": &"instability"})
	await process_frame
	_expect(_count_projectiles(&"fusion_curse_chaos_paradox_curse_mark_projectile") > 0 or _count_area_effects(&"fusion_curse_chaos_paradox_curse_mark_area") > 0, "curse chaos paradox mark reacts to Instability fission", _count_projectiles(&"fusion_curse_chaos_paradox_curse_mark_projectile"))

	_enemy.call("apply_status", &"instability", {"stacks": 1, "duration": 6.0, "power": 24.0})
	_emit(&"status_max_stack_reached", _skill_manager.call("get_skill", &"fusion_holy_chaos_judgment_echo") as RefCounted, {"target": _enemy, "status_id": &"judgment"})
	await process_frame
	_expect(_count_area_effects(&"fusion_holy_chaos_judgment_echo_area") > 0, "holy chaos judgment echo reacts to Judgment punishment", _count_area_effects(&"fusion_holy_chaos_judgment_echo_area"))

	if not _failed:
		print("[verify_fusion_skill_runtime_smoke] PASS")
	quit(1 if _failed else 0)


func _build_nodes() -> void:
	_player = SmokePlayer.new()
	_player.name = "FusionSmokePlayer"
	root.add_child(_player)

	_skill_manager = SkillManagerScript.new()
	_skill_manager.name = "SkillManager"
	_player.add_child(_skill_manager)

	_event_bus = SkillEventBusScript.new()
	_event_bus.name = "SkillEventBus"
	_player.add_child(_event_bus)

	_enemy = _create_enemy("FusionSmokeEnemy", Vector2(160.0, 0.0))
	_nearby_enemy = _create_enemy("NearbyFusionSmokeEnemy", Vector2(220.0, 0.0))


func _create_enemy(enemy_name: String, position: Vector2) -> SmokeEnemy:
	var enemy: SmokeEnemy = SmokeEnemy.new()
	enemy.name = enemy_name
	enemy.global_position = position
	root.add_child(enemy)
	var status_manager: Node = StatusEffectManagerScript.new()
	status_manager.name = "StatusEffectManager"
	enemy.add_child(status_manager)
	return enemy


func _load_fusion_skill_ids() -> Array[StringName]:
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
		if str(skill.get("type", "")) != "fusion":
			continue
		var id: StringName = StringName(str(skill.get("id", "")))
		if id != &"":
			result.append(id)
	return result


func _emit(event_name: StringName, skill_instance: RefCounted, overrides: Dictionary = {}) -> void:
	var context: Dictionary = _base_context(skill_instance)
	for key: Variant in overrides.keys():
		context[key] = overrides[key]
	if context.has("target"):
		var target_node: Node2D = context.get("target") as Node2D
		if target_node != null:
			context["enemy"] = target_node
			context["position"] = target_node.global_position
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
		"damage_packet": _packet(&"arcane")
	}


func _packet(element: StringName) -> Dictionary:
	return {
		"raw_amount": 24,
		"amount": 24,
		"damage_origin": &"primary_attack",
		"damage_type": &"direct_magical",
		"element": element
	}


func _count_area_effects(source_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			count += 1
	return count


func _area_float(source_id: StringName, property_name: String) -> float:
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			return snappedf(float(child.get(property_name)), 0.001)
	return -1.0


func _count_projectiles(source_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		var projectile_source_id: StringName = StringName(str(child.get("source_id"))) if child.get("source_id") != null else StringName(str(child.get_meta("source_id", "")))
		if projectile_source_id == source_id:
			count += 1
	return count


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _close(actual: float, expected: float, epsilon: float = 0.01) -> bool:
	return absf(actual - expected) <= epsilon


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_fusion_skill_runtime_smoke] FAIL %s actual=%s" % [label, str(actual)])
