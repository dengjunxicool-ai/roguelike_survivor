extends Node


const PLAY_SECONDS: float = 90.0
const POST_FINISH_HOLD_SECONDS: float = 8.0
const CHARACTER_ID: StringName = &"mage"
const WEAPON_ID: StringName = &"fire_staff"
const MAP_ID: StringName = &"abandoned_dungeon"
const MAP_NAME: String = "废弃地牢"

var _main_scene: Node
var _ui: Node
var _player: Node2D
var _elapsed: float = 0.0
var _next_log_time: float = 0.0
var _movement_phase: float = 0.0
var _finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed_scene: PackedScene = load("res://scenes/app_bootstrap.tscn") as PackedScene
	if packed_scene == null:
		push_error("[FullFlowAutoplay] Could not load main.tscn.")
		get_tree().quit(1)
		return

	_main_scene = packed_scene.instantiate()
	add_child(_main_scene)
	await get_tree().process_frame

	_ui = _main_scene.get_node_or_null("UIManager")
	if _ui == null:
		push_error("[FullFlowAutoplay] Missing UIManager or Player.")
		get_tree().quit(1)
		return

	await _run_menu_flow()
	_player = _main_scene.find_child("Player", true, false) as Node2D
	if _player == null:
		push_error("[FullFlowAutoplay] Missing Player after starting run.")
		get_tree().quit(1)
		return
	print("[FullFlowAutoplay] combat_started state=%s character=%s weapon=%s map=%s" % [
		String(_ui.get("current_state")),
		String(CHARACTER_ID),
		String(WEAPON_ID),
		MAP_NAME
	])
	_log_status(0.0)


func _process(delta: float) -> void:
	if _finished or _ui == null:
		return

	var state: String = String(_ui.get("current_state"))
	if state == "RUNNING":
		_elapsed += delta
		_drive_player(delta)
		if _elapsed >= _next_log_time:
			_log_status(_elapsed)
			_next_log_time += 15.0
		if _elapsed >= PLAY_SECONDS:
			_finish(0)
	elif state == "LEVEL_UP_MODAL" or state == "CURSE_CHOICE_MODAL" or state == "EVOLUTION_MODAL":
		_release_all_movement()
		call_deferred("_choose_first_modal_option", state)
	elif state == "RESULT_DEFEAT" or state == "RESULT_VICTORY":
		_log_status(_elapsed)
		print("[FullFlowAutoplay] ended_early state=%s elapsed=%.1f" % [state, _elapsed])
		_finish(0)


func _run_menu_flow() -> void:
	await get_tree().process_frame
	_ui.call("transition_to", "TITLE")
	await get_tree().process_frame
	print("[FullFlowAutoplay] reached_title state=%s" % String(_ui.get("current_state")))

	_ui.call("transition_to", "CHARACTER_SELECT")
	await get_tree().process_frame
	print("[FullFlowAutoplay] reached_character_select state=%s" % String(_ui.get("current_state")))

	_ui.call("_on_loadout_confirmed", CHARACTER_ID, WEAPON_ID)
	await get_tree().process_frame
	print("[FullFlowAutoplay] confirmed_loadout state=%s" % String(_ui.get("current_state")))

	_ui.call("_start_run", MAP_ID)
	await get_tree().process_frame
	await get_tree().physics_frame


func _drive_player(delta: float) -> void:
	_movement_phase += delta
	_release_all_movement()
	var desired_direction: Vector2 = _get_survival_direction()
	if desired_direction == Vector2.ZERO:
		desired_direction = Vector2.RIGHT.rotated(_movement_phase * 1.7)

	if desired_direction.x > 0.25:
		Input.action_press("move_right")
	elif desired_direction.x < -0.25:
		Input.action_press("move_left")

	if desired_direction.y > 0.25:
		Input.action_press("move_down")
	elif desired_direction.y < -0.25:
		Input.action_press("move_up")


func _get_survival_direction() -> Vector2:
	if _player == null:
		return Vector2.ZERO

	var repulsion: Vector2 = Vector2.ZERO
	var attraction: Vector2 = Vector2.ZERO
	var nearest_enemy: Node2D = null
	var nearest_enemy_distance: float = INF
	for enemy_variant: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue

		var offset: Vector2 = _player.global_position - enemy.global_position
		var distance: float = maxf(offset.length(), 1.0)
		if distance < nearest_enemy_distance:
			nearest_enemy_distance = distance
			nearest_enemy = enemy
		if distance < 180.0:
			repulsion += offset.normalized() * ((180.0 - distance) / 180.0)
		if distance < 105.0:
			repulsion += offset.normalized() * 1.2

	for gem_variant: Node in get_tree().get_nodes_in_group(&"experience_crystal"):
		var gem: Node2D = gem_variant as Node2D
		if gem == null or not is_instance_valid(gem):
			continue

		var to_gem: Vector2 = gem.global_position - _player.global_position
		var gem_distance: float = to_gem.length()
		if gem_distance < 260.0:
			attraction += to_gem.normalized() * ((260.0 - gem_distance) / 260.0)

	var orbit_direction: Vector2 = Vector2.RIGHT.rotated(_movement_phase * 1.1)
	var weapon_spacing: Vector2 = Vector2.ZERO
	if nearest_enemy != null:
		var to_enemy: Vector2 = nearest_enemy.global_position - _player.global_position
		var away_from_enemy: Vector2 = -to_enemy.normalized()
		var tangent: Vector2 = away_from_enemy.orthogonal()
		if nearest_enemy_distance < 48.0:
			weapon_spacing = away_from_enemy * 3.0 + tangent * 0.8
		elif nearest_enemy_distance > 88.0 and nearest_enemy_distance < 240.0:
			weapon_spacing = to_enemy.normalized() * 1.35 + tangent * 0.7
		else:
			weapon_spacing = tangent * 1.4

	var desired: Vector2 = weapon_spacing * 1.7 + repulsion * 1.2 + attraction * 0.8 + orbit_direction * 0.15
	if nearest_enemy_distance < 38.0:
		desired += repulsion * 2.0

	return desired.normalized() if desired != Vector2.ZERO else Vector2.ZERO


func _choose_first_modal_option(state: String) -> void:
	if _ui == null or String(_ui.get("current_state")) != state:
		return

	var state_to_container: Dictionary = {
		"LEVEL_UP_MODAL": "_level_up_options",
		"CURSE_CHOICE_MODAL": "_curse_options",
		"EVOLUTION_MODAL": "_evolution_options"
	}
	var key: String = String(state_to_container.get(state, ""))
	var container: Node = null
	if key.begins_with("_"):
		container = _ui.get(key) as Node
	else:
		var screens: Dictionary = _ui.get("_screens")
		var screen: Node = screens.get(state, null) as Node
		container = screen.find_child(key, true, false) if screen != null else null

	if container != null:
		var option_count: int = 0
		for child: Node in container.get_children():
			if child is Button and not (child as Button).disabled:
				option_count += 1
		for child: Node in container.get_children():
			if child is Button and not (child as Button).disabled:
				print("[FullFlowAutoplay] choose_modal state=%s options=%d text=%s" % [state, option_count, (child as Button).text.replace("\n", " | ")])
				(child as Button).emit_signal("pressed")
				return

	print("[FullFlowAutoplay] modal_no_choice state=%s, returning_to_running" % state)
	_ui.call("transition_to", "RUNNING")


func _log_status(time_value: float) -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var enemy_count: int = get_tree().get_nodes_in_group(&"enemy").size()
	var projectile_count: int = get_tree().get_nodes_in_group(&"enemy_projectile").size()
	var state: String = String(_ui.get("current_state")) if _ui != null else "UNKNOWN"
	var hp: int = int(player.get("current_health")) if player != null else -1
	var max_hp: int = int(player.get("max_health")) if player != null else -1
	var level: int = int(player.get("level")) if player != null else -1
	var exp_current: int = int(player.get("current_experience")) if player != null else -1
	var exp_next: int = int(player.get("experience_to_next_level")) if player != null else -1
	var kills: int = int(_ui.get("_kill_count")) if _ui != null else -1
	var weapon_visual: Node = player.get_node_or_null("WeaponVisual") if player != null else null
	var weapon_visual_visible: bool = weapon_visual != null and bool(weapon_visual.get("visible"))
	var orbit_count: int = _count_player_orbit_objects(player)
	print("[FullFlowAutoplay] t=%.1f state=%s hp=%d/%d level=%d exp=%d/%d kills=%d enemies=%d enemy_projectiles=%d weapon_visual=%s orbit_objects=%d" % [
		time_value,
		state,
		hp,
		max_hp,
		level,
		exp_current,
		exp_next,
		kills,
		enemy_count,
		projectile_count,
		str(weapon_visual_visible),
		orbit_count
	])


func _count_player_orbit_objects(player: Node) -> int:
	if player == null or get_tree().current_scene == null:
		return 0

	var count: int = 0
	var owner_id: int = int(player.get_instance_id())
	for child: Node in get_tree().current_scene.get_children():
		if child.has_meta("owner_instance_id") and int(child.get_meta("owner_instance_id")) == owner_id:
			count += 1
	return count


func _finish(exit_code: int) -> void:
	_finished = true
	_release_all_movement()
	_log_status(_elapsed)
	print("[FullFlowAutoplay] finished elapsed=%.1f" % _elapsed)
	await get_tree().create_timer(POST_FINISH_HOLD_SECONDS).timeout
	get_tree().quit(exit_code)


func _release_all_movement() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
