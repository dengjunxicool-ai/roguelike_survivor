extends RefCounted
class_name BossEncounterController


var _owner: Node


func setup(owner: Node) -> void:
	_owner = owner


func process_boss_event() -> void:
	if _owner == null:
		return
	if bool(_owner.get("_triggered_boss_event")):
		return
	if not bool(_owner.get("_normal_phase_complete")):
		return

	var boss_event: Dictionary = _owner.call("_get_config_dictionary", "boss_event")
	if boss_event.is_empty():
		return

	if bool(boss_event.get("clear_normal_enemies_on_spawn", false)):
		_owner.call("_clear_normal_enemies")

	var enemy_id: StringName = StringName(String(boss_event.get("boss_id", boss_event.get("enemy_id", "dungeon_heart"))))
	var boss: Node2D = _owner.call("_spawn_enemy", enemy_id, true, _owner.call("_get_boss_enemy_multipliers", boss_event), &"boss", &"boss") as Node2D
	_owner.set("_triggered_boss_event", true)
	_owner.set("_boss_active", boss != null)
	_owner.set("_boss_minion_spawn_cooldown", maxf(float(_owner.get("_normal_spawn_cooldown")), 0.0))
	if boss != null and boss.has_signal(&"died"):
		boss.connect(&"died", Callable(_owner, "_on_boss_died"))

	_owner.emit_signal(&"timeline_event_started", "boss:%s" % String(enemy_id), String(boss_event.get("announcement", "")))


func process_boss_minion_spawn(delta: float) -> void:
	if _owner == null:
		return

	var boss_event: Dictionary = _owner.call("_get_config_dictionary", "boss_event")
	var minion_spawn: Dictionary = _get_dictionary(boss_event.get("minion_spawn", {}))
	if minion_spawn.is_empty() or not bool(minion_spawn.get("enabled", false)):
		return
	if int(_owner.call("_get_alive_boss_minion_count")) >= int(minion_spawn.get("max_alive", 0)):
		return

	var cooldown: float = maxf(float(_owner.get("_boss_minion_spawn_cooldown")) - delta, 0.0)
	_owner.set("_boss_minion_spawn_cooldown", cooldown)
	if cooldown > 0.0:
		return

	var max_alive: int = maxi(int(minion_spawn.get("max_alive", 0)), 0)
	var available_slots: int = maxi(max_alive - int(_owner.call("_get_alive_boss_minion_count")), 0)
	var batch_limit: int = mini(int(_owner.get("_max_spawn_batch_size")), available_slots)
	if batch_limit > 0:
		_owner.call("_spawn_batch_from_source", minion_spawn, _get_dictionary(minion_spawn.get("enemy_multipliers", {})), &"boss_minion", batch_limit)

	_owner.set("_boss_minion_spawn_cooldown", float(_owner.get("_spawn_batch_interval")))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
