extends Node
class_name RunStatsTracker


signal event_recorded(event_name: StringName, payload: Dictionary)


var selected_character_id: StringName = &""
var selected_map_id: StringName = &""
var selected_map_name: String = ""

var run_seconds: float = 0.0
var boss_phase_started_at: float = -1.0
var boss_hp_at_30s: float = -1.0
var boss_damage_done: int = 0
var kill_count: int = 0
var elite_kill_count: int = 0
var boss_defeated: bool = false
var highest_alive_normal_enemies: int = 0
var seconds_near_alive_cap: float = 0.0

var damage_done_by_origin: Dictionary = {}
var damage_done_by_type: Dictionary = {}
var damage_done_by_element: Dictionary = {}
var damage_taken_by_source: Dictionary = {}
var last_damage_source: String = ""
var status_counts: Dictionary = {}
var reaction_counts: Dictionary = {}
var upgrade_counts: Dictionary = {}
var relics_gained: Array[StringName] = []
var elite_rewards_taken: int = 0
var boss_blessings_taken: int = 0
var poison_instances_taken: int = 0
var healing_used: int = 0
var lava_hits_taken: int = 0
var map_hazard_hits_taken: int = 0
var shield_break_kills: int = 0
var critical_kills: int = 0
var potion_zone_triggers: int = 0
var hunter_rhythm_seconds: float = 0.0
var overload_full_stack_boss_kill: bool = false
var boss_core_spawned_count: int = 0
var boss_core_destroyed_count: int = 0
var boss_core_total_lifetime: float = 0.0


func reset_run(character_id: Variant, map_id: Variant, map_name: String = "") -> void:
	selected_character_id = StringName(String(character_id))
	selected_map_id = StringName(String(map_id))
	selected_map_name = map_name
	run_seconds = 0.0
	boss_phase_started_at = -1.0
	boss_hp_at_30s = -1.0
	boss_damage_done = 0
	kill_count = 0
	elite_kill_count = 0
	boss_defeated = false
	highest_alive_normal_enemies = 0
	seconds_near_alive_cap = 0.0
	damage_done_by_origin.clear()
	damage_done_by_type.clear()
	damage_done_by_element.clear()
	damage_taken_by_source.clear()
	last_damage_source = ""
	status_counts.clear()
	reaction_counts.clear()
	upgrade_counts.clear()
	relics_gained.clear()
	elite_rewards_taken = 0
	boss_blessings_taken = 0
	poison_instances_taken = 0
	healing_used = 0
	lava_hits_taken = 0
	map_hazard_hits_taken = 0
	shield_break_kills = 0
	critical_kills = 0
	potion_zone_triggers = 0
	hunter_rhythm_seconds = 0.0
	overload_full_stack_boss_kill = false
	boss_core_spawned_count = 0
	boss_core_destroyed_count = 0
	boss_core_total_lifetime = 0.0


func set_run_time(seconds: float) -> void:
	run_seconds = maxf(seconds, 0.0)


func record_damage_done(target: Node, amount: int, result: Dictionary, packet: Variant = {}) -> void:
	if amount <= 0:
		return
	var origin: String = _extract_origin(packet, result)
	var damage_type: String = String(result.get("damage_type", "unknown"))
	var element: String = String(result.get("element", "unknown"))
	_add_number(damage_done_by_origin, origin, amount)
	_add_number(damage_done_by_type, damage_type, amount)
	_add_number(damage_done_by_element, element, amount)
	if _is_boss(target):
		boss_damage_done += amount
	event_recorded.emit(&"damage_done", {"target": target, "amount": amount, "origin": origin, "damage_type": damage_type, "element": element})


func record_damage_taken(amount: int, result: Dictionary, packet: Variant = {}) -> void:
	if amount <= 0:
		return
	var source: String = _extract_taken_source(packet, result)
	_add_number(damage_taken_by_source, source, amount)
	last_damage_source = source
	if source == "poison":
		poison_instances_taken += 1
	if source == "lava" or source == "map_lava":
		lava_hits_taken += 1
	if source.begins_with("map_"):
		map_hazard_hits_taken += 1
	event_recorded.emit(&"damage_taken", {"amount": amount, "source": source})


func record_status_applied(status_id: Variant, target: Node = null) -> void:
	var id: String = String(status_id)
	if id == "":
		return
	_add_number(status_counts, id, 1)
	if ["overload", "combustion", "shatter", "soul_burn", "shock"].has(id):
		_add_number(reaction_counts, id, 1)
		if id == "shock":
			event_recorded.emit(&"shock_triggered", {"status_id": id, "target": target})
	event_recorded.emit(&"status_applied", {"status_id": id, "target": target})
	event_recorded.emit(&"apply_status", {"status_id": id, "target": target})


func record_enemy_killed(enemy: Node) -> void:
	kill_count += 1
	var rank: String = _get_enemy_rank(enemy)
	if rank == "elite":
		elite_kill_count += 1
	if rank == "boss":
		boss_defeated = true
	if bool(enemy.get_meta("last_damage_was_critical", false)):
		critical_kills += 1
	if enemy != null and enemy.has_method("has_status"):
		if bool(enemy.call("has_status", &"armor_break")) or bool(enemy.call("has_status", &"holy_mark")) or bool(enemy.call("has_status", &"judgment")):
			shield_break_kills += 1
	event_recorded.emit(&"enemy_killed", {"enemy": enemy, "rank": rank})


func record_hunter_rhythm(delta: float) -> void:
	hunter_rhythm_seconds += maxf(delta, 0.0)


func record_potion_zone_triggered() -> void:
	potion_zone_triggers += 1
	event_recorded.emit(&"potion_zone_triggered", {})


func record_upgrade_applied(upgrade_id: Variant) -> void:
	_add_number(upgrade_counts, String(upgrade_id), 1)


func record_relic_gained(relic_id: Variant) -> void:
	var id: StringName = StringName(String(relic_id))
	if id != &"" and not relics_gained.has(id):
		relics_gained.append(id)
		event_recorded.emit(&"relic_gained", {"relic_id": id})


func record_reward_taken(kind: String) -> void:
	if kind == "elite":
		elite_rewards_taken += 1
	elif kind == "boss_blessing":
		boss_blessings_taken += 1
	event_recorded.emit(StringName("%s_reward" % kind), {"reward_kind": kind})


func record_healing(amount: int) -> void:
	if amount > 0:
		healing_used += amount


func record_map_hazard_hit(hazard_type: String) -> void:
	map_hazard_hits_taken += 1
	if hazard_type == "lava_fissure":
		lava_hits_taken += 1
	elif hazard_type == "toxic_fog":
		poison_instances_taken += 1
	event_recorded.emit(&"map_event", {"map_variable": hazard_type})


func record_map_event(map_variable: String) -> void:
	event_recorded.emit(&"map_event", {"map_variable": map_variable})


func record_boss_core_spawned(core: Node = null) -> void:
	boss_core_spawned_count += 1
	if core != null:
		core.set_meta("boss_core_spawn_run_seconds", run_seconds)
	event_recorded.emit(&"boss_core_spawned", {"core": core})


func record_boss_core_destroyed(core: Node = null) -> void:
	boss_core_destroyed_count += 1
	var lifetime: float = 0.0
	if core != null and core.has_meta("boss_core_spawn_run_seconds"):
		lifetime = maxf(run_seconds - float(core.get_meta("boss_core_spawn_run_seconds")), 0.0)
	boss_core_total_lifetime += lifetime
	event_recorded.emit(&"boss_core_destroyed", {"core": core, "lifetime": lifetime})


func update_wave_pressure(alive_count: int, max_alive: int, delta: float) -> void:
	highest_alive_normal_enemies = maxi(highest_alive_normal_enemies, alive_count)
	if max_alive > 0 and float(alive_count) >= float(max_alive) * 0.85:
		seconds_near_alive_cap += maxf(delta, 0.0)


func update_boss_snapshot(boss: Node) -> void:
	if boss == null:
		return
	if boss_phase_started_at < 0.0:
		boss_phase_started_at = run_seconds
	var elapsed_boss: float = run_seconds - boss_phase_started_at
	if boss_hp_at_30s < 0.0 and elapsed_boss >= 30.0:
		var max_hp: float = maxf(float(boss.get("max_health")), 1.0)
		boss_hp_at_30s = clampf(float(boss.get("current_health")) / max_hp, 0.0, 1.0)


func get_summary() -> Dictionary:
	var total_done: int = _sum_dictionary(damage_done_by_origin)
	var total_taken: int = _sum_dictionary(damage_taken_by_source)
	return {
		"selected_character_id": selected_character_id,
		"selected_map_id": selected_map_id,
		"selected_map_name": selected_map_name,
		"run_seconds": run_seconds,
		"boss_phase_started_at": boss_phase_started_at,
		"boss_hp_at_30s": boss_hp_at_30s,
		"boss_damage_done": boss_damage_done,
		"boss_dps": boss_damage_done / maxf(run_seconds - boss_phase_started_at, 1.0) if boss_phase_started_at >= 0.0 else 0.0,
		"kill_count": kill_count,
		"elite_kill_count": elite_kill_count,
		"boss_defeated": boss_defeated,
		"highest_alive_normal_enemies": highest_alive_normal_enemies,
		"seconds_near_alive_cap": seconds_near_alive_cap,
		"damage_done_by_origin": damage_done_by_origin.duplicate(true),
		"damage_done_by_type": damage_done_by_type.duplicate(true),
		"damage_done_by_element": damage_done_by_element.duplicate(true),
		"damage_done_total": total_done,
		"damage_taken_by_source": damage_taken_by_source.duplicate(true),
		"damage_taken_total": total_taken,
		"last_damage_source": last_damage_source,
		"status_counts": status_counts.duplicate(true),
		"reaction_counts": reaction_counts.duplicate(true),
		"upgrade_counts": upgrade_counts.duplicate(true),
		"relics_gained": relics_gained.duplicate(),
		"elite_rewards_taken": elite_rewards_taken,
		"boss_blessings_taken": boss_blessings_taken,
		"poison_instances_taken": poison_instances_taken,
		"healing_used": healing_used,
		"lava_hits_taken": lava_hits_taken,
		"map_hazard_hits_taken": map_hazard_hits_taken,
		"shield_break_kills": shield_break_kills,
		"critical_kills": critical_kills,
		"potion_zone_triggers": potion_zone_triggers,
		"hunter_rhythm_seconds": hunter_rhythm_seconds,
		"overload_full_stack_boss_kill": overload_full_stack_boss_kill,
		"boss_core_spawned_count": boss_core_spawned_count,
		"boss_core_destroyed_count": boss_core_destroyed_count,
		"boss_core_average_lifetime": boss_core_total_lifetime / maxf(float(boss_core_destroyed_count), 1.0) if boss_core_destroyed_count > 0 else 0.0
	}


static func get_active(tree: SceneTree = null) -> RunStatsTracker:
	var active_tree: SceneTree = tree if tree != null else Engine.get_main_loop() as SceneTree
	if active_tree == null:
		return null
	return active_tree.get_first_node_in_group(&"run_stats_tracker") as RunStatsTracker


func _ready() -> void:
	add_to_group(&"run_stats_tracker")


func _extract_origin(packet: Variant, result: Dictionary) -> String:
	if packet is Dictionary:
		var data: Dictionary = packet
		for key: String in ["damage_origin", "origin", "source_type"]:
			var value: String = String(data.get(key, ""))
			if value != "":
				return value
	var damage_type: String = String(result.get("damage_type", ""))
	if damage_type == "status_dot":
		return "status_dot"
	if damage_type == "reaction" or damage_type == "reaction_damage":
		return "reaction"
	if damage_type == "area_direct":
		return "field"
	return "primary_attack"


func _extract_taken_source(packet: Variant, result: Dictionary) -> String:
	if packet is Dictionary:
		var data: Dictionary = packet
		for key: String in ["source_id", "source", "source_type", "element"]:
			var value: String = String(data.get(key, ""))
			if value != "":
				return value
	return String(result.get("element", "contact"))


func _is_boss(node: Node) -> bool:
	return node != null and (node.is_in_group(&"bosses") or bool(node.get_meta("is_boss", false)) or String(node.get_meta("enemy_rank", "")) == "boss")


func _get_enemy_rank(enemy: Node) -> String:
	if enemy == null:
		return "unknown"
	return String(enemy.get_meta("enemy_rank", enemy.get_meta("enemy_type", "normal")))


func _add_number(dictionary: Dictionary, key: String, value: int) -> void:
	dictionary[key] = int(dictionary.get(key, 0)) + value


func _sum_dictionary(dictionary: Dictionary) -> int:
	var total: int = 0
	for value: Variant in dictionary.values():
		total += int(value)
	return total
