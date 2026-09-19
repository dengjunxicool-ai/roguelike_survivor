extends SceneTree


const ProjectileBuilderScript: Script = preload("res://scripts/skills/skill_action_projectile_builder.gd")
const AreaBuilderScript: Script = preload("res://scripts/skills/skill_action_area_builder.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_projectile_helpers()
	_verify_area_visual_params()
	if not _failed:
		print("[verify_skill_action_builder_pure_data] PASS")
	quit(1 if _failed else 0)


func _verify_projectile_helpers() -> void:
	for method_name: StringName in [
		&"resolve_same_target_spawn_delay",
		&"build_same_target_hit_params",
		&"filter_damage_actions",
		&"normalize_status_ids",
		&"build_runtime_data",
	]:
		if not _script_has_method(ProjectileBuilderScript, method_name):
			_expect(false, "projectile builder exposes %s" % method_name)
			return
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": 0.15}, -1), 0.0, "negative hit index has no delay")
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": 0.15}, 0), 0.0, "first hit has no delay")
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": 0.15}, 2), 0.3, "later hit delay scales by index")
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": -0.25}, 3), 0.0, "negative configured delay clamps to zero")

	var unchanged: Dictionary = {"same_target_repeat_damage_only": false, "actions_on_hit": [{"type": "apply_status"}]}
	var unchanged_result: Dictionary = ProjectileBuilderScript.build_same_target_hit_params(unchanged, 2)
	_expect(is_same(unchanged_result, unchanged), "disabled filtering preserves the original dictionary")
	_expect(is_same(ProjectileBuilderScript.build_same_target_hit_params(unchanged, -1), unchanged), "negative index preserves the original dictionary")

	var source: Dictionary = {
		"same_target_repeat_damage_only": true,
		"actions_on_hit": [
			{"type": "deal_damage", "params": {"damage": 12}},
			{"type": "apply_status", "params": {"status_id": "burning"}},
			"invalid",
			{"type": "deal_damage", "params": {"damage": 7}},
		]
	}
	var filtered: Dictionary = ProjectileBuilderScript.build_same_target_hit_params(source, 1)
	var filtered_actions: Array = filtered.get("actions_on_hit", [])
	_expect(not is_same(filtered, source), "enabled filtering returns a new dictionary")
	_expect(filtered_actions.size() == 2, "enabled filtering keeps only damage actions", filtered_actions)
	_expect(str((filtered_actions[0] as Dictionary).get("type", "")) == "deal_damage", "first retained action is damage", filtered_actions)
	_expect(str((filtered_actions[1] as Dictionary).get("type", "")) == "deal_damage", "second retained action is damage", filtered_actions)
	var returned_damage_action: Dictionary = filtered_actions[0] as Dictionary
	var returned_damage_params: Dictionary = returned_damage_action.get("params", {}) as Dictionary
	returned_damage_params["damage"] = 99
	_expect(int(((source["actions_on_hit"][0] as Dictionary)["params"] as Dictionary)["damage"]) == 12, "filtered actions are deep copies", source)
	_expect((source["actions_on_hit"] as Array).size() == 4, "filtering does not mutate the source array", source)

	var statuses: Array[StringName] = ProjectileBuilderScript.normalize_status_ids(["burning", &"frozen", "burning"])
	_expect(statuses == [&"burning", &"frozen", &"burning"], "status normalization preserves order and duplicates", statuses)
	_expect(statuses.get_typed_builtin() == TYPE_STRING_NAME, "status normalization returns a typed StringName array", statuses.get_typed_builtin())
	var empty_statuses: Array[StringName] = ProjectileBuilderScript.normalize_status_ids([])
	_expect(empty_statuses.is_empty(), "empty status normalization remains empty", empty_statuses)
	_expect(empty_statuses.get_typed_builtin() == TYPE_STRING_NAME, "empty status normalization remains typed", empty_statuses.get_typed_builtin())

	var parent: Node = Node.new()
	var runtime_data: Dictionary = ProjectileBuilderScript.build_runtime_data({
		"speed": 510.0,
		"pierce": 3,
		"radius": 14.0,
		"lifetime": 4.5,
		"damage": 27,
		"source_id": &"test_projectile",
		"statuses_on_hit": ["burning", &"frozen"],
		"parent": parent,
		"cast_instance_id": "cast-17",
	})
	_expect(runtime_data.size() == 9, "runtime data exposes exactly nine fields", runtime_data)
	_expect_close(float(runtime_data.get("speed", 0.0)), 510.0, "runtime speed is preserved")
	_expect(int(runtime_data.get("pierce", -1)) == 3, "runtime pierce is preserved", runtime_data)
	_expect_close(float(runtime_data.get("radius", 0.0)), 14.0, "runtime radius is preserved")
	_expect_close(float(runtime_data.get("lifetime", 0.0)), 4.5, "runtime lifetime is preserved")
	_expect(int(runtime_data.get("damage", -1)) == 27, "runtime damage is preserved", runtime_data)
	_expect(runtime_data.get("source_id") is StringName and runtime_data.get("source_id") == &"test_projectile", "runtime source id is a StringName", runtime_data)
	_expect(runtime_data.get("parent") == parent, "runtime parent is preserved", runtime_data)
	_expect(str(runtime_data.get("cast_instance_id", "")) == "cast-17", "runtime cast id is preserved", runtime_data)
	var runtime_statuses: Array = runtime_data.get("statuses_on_hit", [])
	_expect(runtime_statuses == [&"burning", &"frozen"], "runtime statuses are normalized", runtime_statuses)

	var defaults: Dictionary = ProjectileBuilderScript.build_runtime_data({})
	_expect(defaults.size() == 9, "runtime defaults expose exactly nine fields", defaults)
	_expect_close(float(defaults.get("speed", 0.0)), 420.0, "default speed is unchanged")
	_expect(int(defaults.get("pierce", -1)) == 0, "default pierce is unchanged", defaults)
	_expect_close(float(defaults.get("radius", 0.0)), 10.0, "default radius is unchanged")
	_expect_close(float(defaults.get("lifetime", 0.0)), 2.0, "default lifetime is unchanged")
	_expect(int(defaults.get("damage", -1)) == 0, "default damage is unchanged", defaults)
	_expect(defaults.get("source_id") is StringName and defaults.get("source_id") == &"", "default source id is an empty StringName", defaults)
	_expect(defaults.get("parent") == null, "default parent is null", defaults)
	_expect(str(defaults.get("cast_instance_id", "missing")) == "", "default cast id is empty", defaults)
	var default_statuses: Array = defaults.get("statuses_on_hit", [])
	_expect(default_statuses.is_empty() and default_statuses.get_typed_builtin() == TYPE_STRING_NAME, "default statuses are an empty typed array", default_statuses)
	parent.free()


func _verify_area_visual_params() -> void:
	if not _script_has_method(AreaBuilderScript, &"build_instant_hit_visual_params"):
		_expect(false, "area builder exposes build_instant_hit_visual_params")
		return
	var explicit_params: Dictionary = {
		"visual_duration": 0.35,
		"duration": 9.0,
		"visual_color": Color(0.9, 0.2, 0.1, 0.8),
	}
	var definition: Dictionary = {
		"visual_color": Color(0.1, 0.2, 0.9, 0.5),
		"visual_ring_color": Color(0.3, 0.8, 1.0, 0.9),
	}
	var explicit_params_before: Dictionary = explicit_params.duplicate(true)
	var definition_before: Dictionary = definition.duplicate(true)
	var explicit_result: Dictionary = AreaBuilderScript.build_instant_hit_visual_params(explicit_params, definition, 72.0)
	_expect_close(float(explicit_result.get("radius", 0.0)), 72.0, "instant visual radius is preserved")
	_expect_close(float(explicit_result.get("duration", 0.0)), 0.35, "visual_duration takes precedence over duration")
	_expect(explicit_result.get("visual_color") == Color(0.9, 0.2, 0.1, 0.8), "explicit visual color wins", explicit_result)
	_expect(explicit_result.get("visual_ring_color") == Color(0.3, 0.8, 1.0, 0.9), "definition supplies missing ring color", explicit_result)
	_expect(explicit_params == explicit_params_before and definition == definition_before, "visual merge does not mutate either input", [explicit_params, definition])

	var fallback_result: Dictionary = AreaBuilderScript.build_instant_hit_visual_params({"duration": 0.6}, definition, 48.0)
	_expect_close(float(fallback_result.get("duration", 0.0)), 0.6, "duration is the visual-duration fallback")
	_expect(fallback_result.get("visual_color") == Color(0.1, 0.2, 0.9, 0.5), "definition supplies visual color", fallback_result)

	var minimal_result: Dictionary = AreaBuilderScript.build_instant_hit_visual_params({}, {}, 36.0)
	_expect(minimal_result.size() == 2, "missing optional colors remain absent", minimal_result)
	_expect_close(float(minimal_result.get("duration", 0.0)), 0.12, "default visual duration is unchanged")
	_expect(not minimal_result.has("visual_color") and not minimal_result.has("visual_ring_color"), "minimal result does not invent color keys", minimal_result)


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(is_equal_approx(actual, expected), label, actual)


func _script_has_method(script: Script, method_name: StringName) -> bool:
	for method_data: Dictionary in script.get_script_method_list():
		if StringName(str(method_data.get("name", ""))) == method_name:
			return true
	return false


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_action_builder_pure_data] FAIL %s actual=%s" % [label, str(actual)])
