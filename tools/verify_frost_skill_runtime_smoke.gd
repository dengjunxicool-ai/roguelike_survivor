extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")
const ModifierStoreScript: Script = preload("res://scripts/modifiers/modifier_store.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const SKILLS_DATA_PATH: String = "res://data/skills.json"


class SmokePlayer:
	extends Node2D

	var selected_character_id: StringName = &""
	var attack_power: float = 24.0
	var max_health: int = 160
	var current_health: int = 160

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
			modifier_store.call("set_source", source_id, modifiers, [ModifierQueryScript.SCOPE_PLAYER, ModifierQueryScript.SCOPE_DAMAGE])


class SmokeEnemy:
	extends Node2D

	var max_health: int = 400
	var current_health: int = 400
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
var _dense_enemy_a: SmokeEnemy
var _dense_enemy_b: SmokeEnemy
var _skill_manager: Node
var _event_bus: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_nodes()
	var skill_ids: Array[StringName] = _load_frost_skill_ids()
	_expect(skill_ids.size() == 14, "loads all 14 first-version frost skills", skill_ids.size())
	for skill_id: StringName in skill_ids:
		_expect(bool(_skill_manager.call("add_skill", skill_id)), "learns %s" % str(skill_id), "add_skill=false")
	_expect(_skill_manager.call("get_all_skills").size() == 14, "SkillManager learned 14 frost skills", _skill_manager.call("get_all_skills").size())
	_expect_skill_modifier("primary_attack_damage_multiplier_add", 0.18, "frost attack applies one primary attack modifier")

	var frost_attack: RefCounted = _skill_manager.call("get_skill", &"frost_attack_frostbite") as RefCounted
	_emit(&"attack_hit", frost_attack)
	_expect(_enemy.call("get_status_stack", &"chilled") > 0, "frost attack_hit applies Chilled", _enemy.call("get_status_stack", &"chilled"))

	for _index in range(7):
		_enemy.call("apply_status", &"chilled", {"stacks": 1, "duration": 6.0})
	_expect(_enemy.call("get_status_stack", &"frozen") > 0, "Chilled max stack applies Frozen", _enemy.call("get_status_stack", &"frozen"))

	_emit_without_target(&"dash_start", _skill_manager.call("get_skill", &"frost_dash_ice_shard_assault") as RefCounted)
	await process_frame
	_expect(_count_projectiles(&"ice_shard_projectile") >= 6, "frost dash spawns ice shards without explicit target", _count_projectiles(&"ice_shard_projectile"))

	_emit_without_target(&"on_cast", _skill_manager.call("get_skill", &"frost_cast_frost_field") as RefCounted)
	_expect(_count_area_effects(&"frost_field") > 0, "frost field creates area runtime", _count_area_effects(&"frost_field"))
	_expect(_area_position_near(&"frost_field", _enemy.global_position, 8.0), "frost field spawns under a target instead of the player", _area_position_for(&"frost_field"))
	_shorten_area_duration(&"frost_field", 0.001)
	for _frame in range(8):
		await physics_frame
	_expect(_count_area_effects(&"frost_path") > 0, "frost field creates a frost path on expire", _count_area_effects(&"frost_path"))
	_expect(_area_position_near(&"frost_path", _enemy.global_position, 8.0), "frost path stays at the field target position on expire", _area_position_for(&"frost_path"))

	_emit_without_target(&"on_cast", _skill_manager.call("get_skill", &"frost_cast_glacial_lance") as RefCounted)
	await process_frame
	_expect(_count_projectiles(&"glacial_lance_projectile") > 0, "glacial lance spawns a damaging projectile without explicit target", _count_projectiles(&"glacial_lance_projectile"))
	_expect(_projectile_damage_for(&"glacial_lance_projectile") > 0, "glacial lance projectile carries nonzero damage", _projectile_damage_for(&"glacial_lance_projectile"))

	_emit_without_target(&"on_cast", _skill_manager.call("get_skill", &"frost_cast_blizzard_cloud") as RefCounted)
	await process_frame
	_expect(_area_move_direction_left(&"blizzard_cloud"), "blizzard cloud moves toward the densest enemy cluster", _area_move_direction_for(&"blizzard_cloud"))

	var shatter_execute: RefCounted = _skill_manager.call("get_skill", &"frost_power_shatter_execute") as RefCounted
	_enemy.max_health = 400
	_enemy.current_health = 40
	_enemy.call("apply_status", &"chilled", {"stacks": 1, "duration": 6.0})
	_emit(&"post_damage_hit", shatter_execute)
	_expect(_enemy.current_health == 0, "frost shatter execute kills Chilled enemies at 10% HP", _enemy.current_health)

	_enemy.max_health = 400
	_enemy.current_health = 44
	_enemy.call("apply_status", &"chilled", {"stacks": 1, "duration": 6.0})
	_emit(&"post_damage_hit", shatter_execute)
	_expect(_enemy.current_health == 44, "frost shatter execute does not add damage above 10% HP", _enemy.current_health)

	_enemy.max_health = 80
	_enemy.current_health = 8
	_enemy.call("apply_status", &"chilled", {"stacks": 1, "duration": 6.0})
	_emit(&"post_damage_hit", frost_attack)
	_expect(_enemy.current_health == 0, "frost shatter execute kills Chilled enemies after primary attack leaves them at 10% HP", _enemy.current_health)

	_emit(&"on_cast", _skill_manager.call("get_skill", &"frost_summon_frost_wolf") as RefCounted)
	_emit(&"on_cast", _skill_manager.call("get_skill", &"frost_summon_ice_crystal_guard") as RefCounted)
	await process_frame
	_expect(_count_summons(&"summon_frost_wolf") > 0, "frost wolf spawns through Summon system", _count_summons(&"summon_frost_wolf"))
	_expect(_summon_has_visual(&"summon_frost_wolf"), "frost wolf has visible summon art config", _count_summons(&"summon_frost_wolf"))
	_expect(_count_summons(&"ice_crystal_guard") > 0, "ice crystal guard spawns through Summon system", _count_summons(&"ice_crystal_guard"))
	var ice_guard: Node2D = _first_summon(&"ice_crystal_guard")
	if ice_guard != null:
		_enemy.global_position = ice_guard.global_position + Vector2(48.0, 0.0)
	for _frame in range(6):
		await physics_frame
	_expect(_count_area_effects(&"frost_ring") > 0, "ice crystal guard releases a visible frost pulse", _count_area_effects(&"frost_ring"))
	for _frame in range(18):
		await physics_frame
	_expect(_enemy.call("get_status_stack", &"chilled") > 0, "ice crystal guard pulse applies Chilled", _enemy.call("get_status_stack", &"chilled"))
	_free_summons(&"summon_frost_wolf")
	await process_frame
	_emit(&"on_cast", _skill_manager.call("get_skill", &"frost_summon_frost_wolf") as RefCounted)
	await process_frame
	_expect(_count_summons(&"summon_frost_wolf") > 0, "frost wolf can respawn after a previous summon was freed", _count_summons(&"summon_frost_wolf"))

	if not _failed:
		print("[verify_frost_skill_runtime_smoke] PASS")
	quit(1 if _failed else 0)


func _build_nodes() -> void:
	_player = SmokePlayer.new()
	_player.name = "FrostSmokePlayer"
	root.add_child(_player)

	_skill_manager = SkillManagerScript.new()
	_skill_manager.name = "SkillManager"
	_player.add_child(_skill_manager)

	_event_bus = SkillEventBusScript.new()
	_event_bus.name = "SkillEventBus"
	_player.add_child(_event_bus)

	_enemy = SmokeEnemy.new()
	_enemy.name = "FrostSmokeEnemy"
	_enemy.global_position = Vector2(140.0, 0.0)
	root.add_child(_enemy)

	var enemy_status_manager: Node = StatusEffectManagerScript.new()
	enemy_status_manager.name = "StatusEffectManager"
	_enemy.add_child(enemy_status_manager)

	_dense_enemy_a = SmokeEnemy.new()
	_dense_enemy_a.name = "DenseFrostSmokeEnemyA"
	_dense_enemy_a.global_position = Vector2(-240.0, -24.0)
	root.add_child(_dense_enemy_a)

	_dense_enemy_b = SmokeEnemy.new()
	_dense_enemy_b.name = "DenseFrostSmokeEnemyB"
	_dense_enemy_b.global_position = Vector2(-260.0, 22.0)
	root.add_child(_dense_enemy_b)


func _load_frost_skill_ids() -> Array[StringName]:
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
		if str(skill.get("school", "")) != "frost" or skill.get("fusion_school", null) != null:
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
			"element": &"frost",
			"source_skill_id": &"frost_attack_frostbite"
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
	var actual: Vector2 = _area_position_for(source_id)
	return actual.distance_to(position) <= tolerance


func _area_position_for(source_id: StringName) -> Vector2:
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			var area: Node2D = child as Node2D
			return area.global_position if area != null else Vector2.INF
	return Vector2.INF


func _area_move_direction_left(source_id: StringName) -> bool:
	var direction: Vector2 = _area_move_direction_for(source_id)
	return direction.x < -0.5 and absf(direction.y) < 0.35


func _area_move_direction_for(source_id: StringName) -> Vector2:
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			return child.get("move_direction")
	return Vector2.ZERO


func _shorten_area_duration(source_id: StringName, duration: float) -> void:
	for child: Node in root.get_children():
		if StringName(str(child.get_meta("source_id", ""))) == source_id:
			child.set("duration", duration)


func _count_summons(definition_id: StringName) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child.has_meta("summon_definition_id") and StringName(str(child.get_meta("summon_definition_id", ""))) == definition_id:
			count += 1
		for grandchild: Node in child.get_children():
			if grandchild.has_meta("summon_definition_id") and StringName(str(grandchild.get_meta("summon_definition_id", ""))) == definition_id:
				count += 1
	return count


func _summon_has_visual(definition_id: StringName) -> bool:
	for child: Node in root.get_children():
		if not child.has_meta("summon_definition_id") or StringName(str(child.get_meta("summon_definition_id", ""))) != definition_id:
			continue
		if child.get_node_or_null("SummonVisual") != null:
			return true
		if child.get_node_or_null("AnimatedSprite2D") != null:
			return true
	return false


func _first_summon(definition_id: StringName) -> Node2D:
	for child: Node in root.get_children():
		if child.has_meta("summon_definition_id") and StringName(str(child.get_meta("summon_definition_id", ""))) == definition_id:
			return child as Node2D
	return null


func _free_summons(definition_id: StringName) -> void:
	for child: Node in root.get_children():
		if child.has_meta("summon_definition_id") and StringName(str(child.get_meta("summon_definition_id", ""))) == definition_id:
			child.queue_free()


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_fail(label, actual)


func _fail(label: String, actual: Variant = "") -> void:
	_failed = true
	push_error("[verify_frost_skill_runtime_smoke] FAIL %s actual=%s" % [label, str(actual)])
