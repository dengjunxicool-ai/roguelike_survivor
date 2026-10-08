extends SceneTree

const RelicManagerScript: Script = preload("res://scripts/relics/relic_manager.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var definition: Dictionary = GameData.get_relic(&"corrosion_nameplate")
	var manager: Node = RelicManagerScript.new()
	var condition: Dictionary = definition.get("trigger_condition", {})
	_expect(condition.get("status_id") == "acid_mark", "corrosion relic references canonical acid status")
	_expect(not GameData.get_status(&"acid_mark").is_empty(), "acid status definition exists")
	_expect(bool(manager.call("_can_trigger_relic", &"corrosion_nameplate", definition, "apply_status", {"status_id": "acid_mark"})), "acid mark event triggers relic")
	_expect(not bool(manager.call("_can_trigger_relic", &"corrosion_nameplate", definition, "apply_status", {"status_id": "poison"})), "other statuses do not trigger acid relic")
	manager.free()
	if not failed:
		print("[verify_relic_acid_status_trigger] PASS")
	quit(1 if failed else 0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("[verify_relic_acid_status_trigger] FAIL " + label)
