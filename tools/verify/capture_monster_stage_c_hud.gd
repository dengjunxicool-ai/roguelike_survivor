## 使用真实应用/HUD；强制波次与已用时间只用于画面检查，不计完整试玩。
extends "res://tools/verify/verify_performance_run.gd"
func _start_run() -> void:
	await super._start_run()
	while bool(_ui.get("_run_loading_active")): await process_frame
	var spawner: Node=get_first_node_in_group(&"enemy_spawner")
	spawner.set_physics_process(false)
	spawner.set("_elapsed_time",301.0)
	_ui.set("_run_seconds",301.0)
	_ui.call("_update_run_hud")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_report_dir.path_join("hud_actual_time_301.png"))
	spawner.call("_start_wave",7)
	spawner.call("_finish_normal_phase")
	_ui.call("_update_run_hud")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_report_dir.path_join("hud_boss_prepare.png"))
	RunEnvironment.cleanup_save(_environment)
	_finished=true
	quit(0)
