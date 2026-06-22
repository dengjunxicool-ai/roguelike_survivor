extends SceneTree


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_assert(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return

	var main: Node2D = main_scene.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	_assert(main.get_node_or_null("ObliquePresentation") == null, "run scene has no oblique presentation layer")
	_assert(not bool(main.get("y_sort_enabled")), "run root does not use oblique y sorting")
	_assert(not ResourceLoader.exists("res://scripts/visual/oblique_visual_adapter.gd"), "oblique visual adapter is removed")

	var player: Node2D = main.get_node_or_null("Player") as Node2D
	_assert(player != null, "player exists")
	_assert(player != null and not bool(player.get_meta("oblique_visual_adapted", false)), "player has no oblique visual metadata")
	var weapon_visual: Node = player.get_node_or_null("WeaponVisual") if player != null else null
	_assert(weapon_visual != null, "weapon visual exists")
	_assert(weapon_visual != null and not weapon_visual.has_method("update_oblique_direction"), "weapon visual uses simple top-down display")
	_assert(weapon_visual != null and not bool(weapon_visual.get_meta("oblique_weapon_visual_adapted", false)), "weapon visual has no oblique metadata")

	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	enemy.set("enemy_id", &"small_slime")
	main.add_child(enemy)
	await process_frame
	_assert(not bool(enemy.get_meta("oblique_visual_adapted", false)), "enemy has no oblique visual metadata")

	var projectile_scene: PackedScene = load("res://scenes/fireball_projectile.tscn") as PackedScene
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	main.add_child(projectile)
	await process_frame
	_assert(not bool(projectile.get_meta("oblique_projectile_visual_adapted", false)), "projectile has no oblique visual metadata")

	var area_scene: PackedScene = load("res://scenes/area_effect.tscn") as PackedScene
	var area: Node = area_scene.instantiate()
	area.set("damage", 0)
	area.set("duration", 0.2)
	main.add_child(area)
	_assert(not area.has_method("_project_ground_point"), "area effect uses normal top-down drawing")

	var tornado_scene: PackedScene = load("res://scenes/effects/fire_tornado_effect.tscn") as PackedScene
	var tornado: Node = tornado_scene.instantiate()
	main.add_child(tornado)
	await process_frame
	_assert(not tornado.has_method("_project_ground"), "fire tornado uses normal top-down drawing")

	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[TopDownPresentationCheck] PASS %s" % message)
	else:
		_failed = true
		push_error("[TopDownPresentationCheck] FAIL %s" % message)


func _finish() -> void:
	print("[TopDownPresentationCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)
