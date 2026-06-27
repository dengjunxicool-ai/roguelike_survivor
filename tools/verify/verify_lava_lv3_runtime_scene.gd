extends SceneTree


const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")


var _failed: bool = false
var _lines: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent: Node = root
	var caster: Node2D = Node2D.new()
	caster.global_position = Vector2(24, 24)
	parent.add_child(caster)
	var target: Node2D = Node2D.new()
	target.global_position = Vector2(72, 24)
	parent.add_child(target)
	await process_frame

	var rules: Dictionary = {
		"player_lava_on_nearby_fireball_hit": {
			"spawn_position": "player",
			"near_player_radius": 160,
			"duration": 2.0,
			"tick_interval": 0.5,
			"damage_from_fireball_base": 0.2,
			"same_source_cooldown": 3.0
		},
		"lava_slow": {
			"status_id": "slow",
			"slow_percent": 0.30,
			"boss_slow_percent": 0.15,
			"duration": 0.5
		}
	}
	var context: Dictionary = {
		"parent": parent,
		"caster": caster,
		"target": target,
		"target_group": &"enemies",
		"skill_id": "fireball"
	}
	var area: Node2D = SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava(rules, context, 16)
	_expect(area != null, "Lava Lv3 creates player lava when target is nearby")
	if area != null:
		_expect(area.global_position.distance_to(caster.global_position) < 0.01, "Lava Lv3 spawns at player position")
		_expect(_approx(float(area.get("duration")), 2.0), "Lava Lv3 duration is 2s")
		_expect(_approx(float(area.get("tick_interval")), 0.5), "Lava Lv3 tick interval is 0.5s")
		_expect(int(area.get("damage")) == 3, "Lava Lv3 damage is 20% of 16 fireball damage")
		var packet: Dictionary = area.get("damage_packet")
		_expect(String(packet.get("source_type", "")) == "area", "Lava Lv3 damage packet has source_type")
		var status_params: Dictionary = area.get("status_params")
		_expect(String(area.get("status_on_hit")) == "slow", "Lava Lv4 lava applies slow status")
		_expect(_approx(float(status_params.get("slow_percent", 0.0)), 0.30), "Lava Lv4 lava slow is 30%")
		_expect(_approx(float(status_params.get("boss_slow_percent", 0.0)), 0.15), "Lava Lv4 Boss slow is 15%")
		_expect(bool(area.get_meta("fireball_lava_zone", false)), "Lava Lv3 area is marked as fireball lava")

	var blocked: Node2D = SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava(rules, context, 16)
	_expect(blocked == null, "Lava Lv3 same-source cooldown blocks immediate second lava")

	var different_source_context: Dictionary = context.duplicate()
	different_source_context["skill_id"] = "fireball_debug_attack_once"
	var blocked_different_source: Node2D = SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava(rules, different_source_context, 16)
	_expect(blocked_different_source == null, "Lava Lv3 effect cooldown blocks a different source within 3s")

	var far_caster: Node2D = Node2D.new()
	far_caster.global_position = Vector2(24, 24)
	parent.add_child(far_caster)
	var far_target: Node2D = Node2D.new()
	far_target.global_position = Vector2(400, 24)
	parent.add_child(far_target)
	var far_context: Dictionary = context.duplicate()
	far_context["caster"] = far_caster
	far_context["target"] = far_target
	far_context["skill_id"] = "fireball_far_target"
	var far_area: Node2D = SpecialDamageRuleHandlerScript.spawn_ground_fire_or_lava(rules, far_context, 16)
	_expect(far_area == null, "Lava Lv3 does not spawn when hit target is outside player radius")

	_write_result()
	quit(1 if _failed else 0)


func _approx(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if condition:
		_lines.append("[PASS] " + message)
	else:
		_failed = true
		_lines.append("[FAIL] " + message)


func _write_result() -> void:
	var output: String = "\n".join(_lines)
	print(output)
	var file: FileAccess = FileAccess.open("res://tools/verify/verify_lava_lv3_runtime_scene.out.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
