extends SceneTree


const SkillActionAreaBuilderScript: Script = preload("res://scripts/skills/skill_action_area_builder.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var radial: Dictionary = SkillActionAreaBuilderScript.build_effect_spawn_params({
		"params": {"radius": 80.0},
		"context": {"dash_path_start": Vector2.ZERO, "dash_path_end": Vector2.RIGHT * 120.0}
	})
	_expect(not bool(radial.get("dash_path_filter", false)), "radial dash area does not inherit path filtering", radial)

	var path_area: Dictionary = SkillActionAreaBuilderScript.build_effect_spawn_params({
		"params": {"radius": 80.0, "dash_path_filter": true},
		"context": {"dash_path_start": Vector2.ZERO, "dash_path_end": Vector2.RIGHT * 120.0}
	})
	_expect(bool(path_area.get("dash_path_filter", false)), "explicit path filtering is preserved", path_area)

	if not _failed:
		print("[verify_dash_area_path_filter] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_dash_area_path_filter] FAIL %s actual=%s" % [label, str(actual)])
