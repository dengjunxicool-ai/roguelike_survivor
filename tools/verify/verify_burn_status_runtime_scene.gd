extends SceneTree


const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")

var _failed: bool = false
var _lines: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)

	var normal: Node2D = _spawn_enemy(false)
	var boss: Node2D = _spawn_enemy(true)
	await process_frame

	_apply_burn_stacks(normal, 5, trace_id)
	_apply_burn_stacks(boss, 5, trace_id)
	normal.call("_update_status_effects", 0.51)
	boss.call("_update_status_effects", 0.51)
	await process_frame

	var records: Array = DebugCombatTraceScript.get_records(root)
	var normal_record: Dictionary = _first_burn_record_for(records, normal)
	var boss_record: Dictionary = _first_burn_record_for(records, boss)

	_expect(not normal_record.is_empty(), "records normal burn tick")
	_expect(not boss_record.is_empty(), "records Boss burn tick")
	if not normal_record.is_empty():
		_lines.append("normal_raw=%.2f normal_final=%d" % [float(normal_record.get("raw_amount", 0.0)), int(normal_record.get("final_amount", 0))])
		_expect(_approx(float(normal_record.get("raw_amount", 0.0)), 8.0), "5-stack normal burn raw tick is 8.0")
		_expect(int(normal_record.get("final_amount", 0)) == 8, "5-stack normal burn final tick is 8")
	if not boss_record.is_empty():
		_lines.append("boss_raw=%.2f boss_final=%d" % [float(boss_record.get("raw_amount", 0.0)), int(boss_record.get("final_amount", 0))])
		_expect(_approx(float(boss_record.get("raw_amount", 0.0)), 5.2), "5-stack Boss burn raw tick is 5.2")
		_expect(int(boss_record.get("final_amount", 0)) == 5, "5-stack Boss burn final tick is floored from 5.2")

	_write_result()
	quit(1 if _failed else 0)


func _spawn_enemy(is_boss: bool) -> Node2D:
	var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate() as Node2D
	enemy.set("enemy_id", &"small_slime")
	root.add_child(enemy)
	enemy.set_meta("is_boss", is_boss)
	if is_boss:
		enemy.add_to_group(&"bosses")
	enemy.set("max_health", 999)
	enemy.set("current_health", 999)
	return enemy


func _apply_burn_stacks(target: Node, stacks: int, trace_id: int) -> void:
	for _index: int in range(stacks):
		target.call("apply_status", &"burn", {
			"debug_attack_trace_id": trace_id
		})


func _first_burn_record_for(records: Array, target: Node) -> Dictionary:
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		if String(record.get("source_skill_id", "")) != "burn":
			continue
		if String(record.get("target_id", "")) == str(target.get_instance_id()):
			return record
	return {}


func _expect(condition: bool, message: String) -> void:
	var line: String = "[PASS] %s" % message if condition else "[FAIL] %s" % message
	_lines.append(line)
	if condition:
		return
	_failed = true


func _approx(actual: float, expected: float, epsilon: float = 0.001) -> bool:
	return absf(actual - expected) <= epsilon


func _write_result() -> void:
	var file: FileAccess = FileAccess.open("user://verify_burn_status_runtime_scene.out.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines))
	file.close()
