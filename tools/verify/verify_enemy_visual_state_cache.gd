extends SceneTree

class CountingVisualController extends EnemyVisualController:
	var resolutions := 0
	func _first_available_state(states: Array[String]) -> String:
		resolutions += 1
		return super._first_available_state(states)

var _failed := false
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var controller := CountingVisualController.new()
	controller.setup(owner)
	controller.apply_enemy_config({"visual":{"states":{"idle":{},"move_right":{"flip_h":false},"move_left":{"flip_h":true}}}})
	var state := {"move_direction":Vector2.RIGHT}
	for index in range(100):
		_expect(controller._get_move_state(state)=="move_right","same direction retains real animation choice")
	_expect(controller.resolutions==1,"repeated direction resolves availability once per configuration")
	_expect(controller._get_move_state({"move_direction":Vector2.LEFT})=="move_left","different direction resolves independently")
	_expect(controller._get_move_state({"move_direction":Vector2.ZERO})=="move_left","stationary enemy retains last direction")
	var previous := controller.resolutions
	controller.apply_enemy_config({"visual":{"states":{"idle":{"flip_h":false}}}})
	_expect(controller._get_move_state(state)=="idle","configuration replacement invalidates the directional fallback")
	_expect(controller.resolutions==previous+1,"new configuration resolves again")
	owner.queue_free()
	await process_frame
	if not _failed: print("[verify_enemy_visual_state_cache] PASS")
	quit(1 if _failed else 0)
func _expect(condition: bool,label: String) -> void:
	if condition: return
	_failed=true
	push_error("[verify_enemy_visual_state_cache] FAIL "+label)
