extends SceneTree


const ResultUnlockServiceScript: Script = preload("res://scripts/ui/result_unlock_service.gd")
const ResultScreenControllerScript: Script = preload("res://scripts/ui/screens/result_screen_controller.gd")
const RESULT_STATE: String = "RESULT_DEFEAT"
const MAP_ID: StringName = &"abandoned_dungeon"
const RESULT_KEY: String = "RESULT_DEFEAT:abandoned_dungeon:10"
const PREVIOUS_UNLOCK: String = "previous run unlock"

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_service_lifetime()
	_verify_controller_lifetime()
	await _verify_start_run_lifetime()
	print("[ResultUnlockCacheLifetime] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _verify_service_lifetime() -> void:
	var service: RefCounted = ResultUnlockServiceScript.new()
	_seed_previous_result(service)
	var first: Array = service.call("apply_result_unlocks", RESULT_STATE, 10.0, MAP_ID, "Dungeon")
	_expect(first == [PREVIOUS_UNLOCK], "same-run cached unlock is returned")
	first.append("caller modification")
	var repeated: Array = service.call("apply_result_unlocks", RESULT_STATE, 10.5, MAP_ID, "Dungeon")
	_expect(repeated == [PREVIOUS_UNLOCK], "same-run repeat remains idempotent and isolated from caller changes")
	_reset_if_available(service, "service")
	_expect(not _cache(service).has(RESULT_KEY), "service reset removes the previous run key")
	var next_run: Array = service.call("apply_result_unlocks", RESULT_STATE, 10.0, MAP_ID, "Dungeon")
	_expect(next_run.is_empty(), "same key in a new run computes fresh unlocks")


func _verify_controller_lifetime() -> void:
	var controller: RefCounted = ResultScreenControllerScript.new()
	var service: RefCounted = controller.get("_result_unlock_service") as RefCounted
	_seed_previous_result(service)
	var body := VBoxContainer.new()
	root.add_child(body)
	controller.call("build", body, RESULT_STATE)
	var run_state: Dictionary = {"selected_map_id": MAP_ID, "selected_map_name": "Dungeon", "run_seconds": 10.0}
	controller.call("refresh", RESULT_STATE, run_state)
	controller.call("refresh", RESULT_STATE, run_state)
	var labels_by_state: Dictionary = controller.get("_labels_by_state")
	var labels: Dictionary = labels_by_state[RESULT_STATE]
	var unlock_label: Label = labels["unlock"] as Label
	_expect(unlock_label.text.contains(PREVIOUS_UNLOCK), "repeated result refresh retains same-run unlock text")
	_reset_if_available(controller, "controller")
	_expect(not _cache(service).has(RESULT_KEY), "controller reset clears its real service cache")
	controller.call("refresh", RESULT_STATE, run_state)
	_expect(not unlock_label.text.contains(PREVIOUS_UNLOCK), "next-run result refresh excludes previous unlock text")
	body.free()


func _verify_start_run_lifetime() -> void:
	var packed_scene: PackedScene = load("res://scenes/app/app_bootstrap.tscn") as PackedScene
	var app: Node = packed_scene.instantiate()
	root.add_child(app)
	for _index: int in range(4):
		await process_frame
	var ui: Node = app.get_node("UIManager")
	var controller: RefCounted = ui.get("_result_controller") as RefCounted
	var service: RefCounted = controller.get("_result_unlock_service") as RefCounted
	_seed_previous_result(service)
	ui.call("transition_to", "CHARACTER_SELECT")
	ui.call("_on_loadout_confirmed", &"mage")
	_expect(_cache(service).has(RESULT_KEY), "menu navigation preserves current result cache")
	ui.call("_start_run", MAP_ID)
	for _index: int in range(120):
		await process_frame
		if String(ui.get("current_state")) == "RUNNING":
			break
	_expect(String(ui.get("current_state")) == "RUNNING", "real run initialization reaches RUNNING")
	_expect(not _cache(service).has(RESULT_KEY), "real run initialization clears the previous result cache")
	var unlocks: Array = service.call("apply_result_unlocks", RESULT_STATE, 10.0, MAP_ID, "Dungeon")
	_expect(unlocks.is_empty(), "newly started run cannot reuse previous unlocks at the same second")
	app.queue_free()
	await process_frame


func _seed_previous_result(service: RefCounted) -> void:
	_cache(service)[RESULT_KEY] = [PREVIOUS_UNLOCK]


func _cache(service: RefCounted) -> Dictionary:
	return service.get("_unlocks_by_result_key")


func _reset_if_available(target: RefCounted, label: String) -> void:
	_expect(target.has_method("reset_for_new_run"), "%s exposes reset_for_new_run" % label)
	if target.has_method("reset_for_new_run"):
		target.call("reset_for_new_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[ResultUnlockCacheLifetime] PASS %s" % message)
	else:
		_failed = true
		push_error("[ResultUnlockCacheLifetime] FAIL %s" % message)
