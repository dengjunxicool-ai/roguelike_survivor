extends SceneTree


const CharacterLoadoutServiceScript: Script = preload("res://scripts/characters/character_loadout_service.gd")
const WeaponBranchSystemScript: Script = preload("res://scripts/weapons/weapon_branch_system.gd")

var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	await process_frame
	await _check_developer_mode_button_flow()

	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	current_scene = main

	var ui_scene: PackedScene = load("res://scenes/ui/ui_prototype.tscn") as PackedScene
	if ui_scene != null:
		main.add_child(ui_scene.instantiate())

	await process_frame
	await process_frame

	var player: Node2D = main.get_node_or_null("Player") as Node2D
	await _check_dev_debug_control(main, player)

	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	var archer: Node2D = enemy_scene.instantiate() as Node2D
	archer.set("enemy_id", &"archer_skeleton")
	main.add_child(archer)
	archer.global_position = player.global_position + Vector2(520, 0)

	await process_frame
	await process_frame
	archer.call("_start_ranged_attack_warning", Vector2.LEFT)
	await process_frame

	_assert(archer.get_node_or_null("AttackTrajectoryLine") != null, "archer creates trajectory line")
	var line: Line2D = archer.get_node_or_null("AttackTrajectoryLine") as Line2D
	_assert(line != null and line.visible, "trajectory line is visible")
	_assert(line != null and line.width >= 7.0, "trajectory line is thick enough")
	await _check_enemy_status_damage_visual(archer)

	archer.call("_execute_enemy_skill_action", "projectile", {"direction": Vector2.LEFT})
	await process_frame

	var found_projectile: bool = false
	for node: Node in get_nodes_in_group(&"enemy_projectiles"):
		var projectile: Node2D = node as Node2D
		if projectile == null:
			continue
		found_projectile = true
		var sprite: Sprite2D = projectile.get_node_or_null("Sprite2D") as Sprite2D
		_assert(sprite != null and sprite.modulate.r >= 0.95 and sprite.modulate.g >= 0.8 and sprite.modulate.b <= 0.2, "enemy projectile is yellow")
		break
	_assert(found_projectile, "archer spawns enemy projectile")

	print("[VisualConfigCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)


func _check_developer_mode_button_flow() -> void:
	var app_scene: PackedScene = load("res://scenes/app_bootstrap.tscn") as PackedScene
	_assert(app_scene != null, "app bootstrap scene exists for developer mode flow")
	if app_scene == null:
		return

	var app: Node = app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame

	var ui_manager: Node = app.get_node_or_null("UIManager")
	_assert(ui_manager != null, "developer mode flow has UIManager")
	if ui_manager != null:
		ui_manager.call("transition_to", "DEVELOPER_MODE")
		await process_frame
		await process_frame
		_assert(String(ui_manager.get("current_state")) == "RUNNING", "developer mode enters running state from title")
		var run_scene: Node = app.get_node_or_null("Main")
		_assert(run_scene != null, "developer mode creates run scene from title")
		_assert(run_scene != null and bool(run_scene.get_meta("debug", false)), "developer mode marks run scene as debug")
		_assert(app.find_child("DevDebugPanel", true, false) != null, "developer mode creates dev debug panel from title")
		var player: Node = app.find_child("Player", true, false)
		if player != null:
			player.set("current_health", 0)
			player.emit_signal("died")
			await process_frame
			_assert(String(ui_manager.get("current_state")) == "RUNNING", "debug run ignores player death defeat transition")

	app.queue_free()
	current_scene = null
	root.set_meta("developer_mode_enabled", false)
	root.set_meta("debug_control_mode", false)
	root.set_meta("debug_manual_spawn_only", false)
	root.set_meta("developer_branch_id", "")
	await process_frame
	await process_frame


func _check_dev_debug_control(main: Node, player: Node2D) -> void:
	_assert(player != null, "player exists for dev debug control check")
	if player == null:
		return

	var ui_manager: CanvasLayer = main.get_node_or_null("UIManager") as CanvasLayer
	_assert(ui_manager != null, "main UI exists")
	var debug_panel: Node = main.get_node_or_null("DevDebugPanel")
	_assert(debug_panel == null, "main flow does not create dev debug panel by default")
	if ui_manager != null:
		root.set_meta("developer_mode_enabled", true)
		root.set_meta("debug_control_mode", true)
		root.set_meta("debug_manual_spawn_only", true)
		ui_manager.call("_open_developer_debug_panel")
		await process_frame
		debug_panel = main.get_node_or_null("DevDebugPanel")
	_assert(debug_panel != null, "developer mode creates dev debug panel")
	if debug_panel == null:
		return

	var debug_layer: CanvasLayer = debug_panel as CanvasLayer
	var left_toolbar: CanvasItem = debug_panel.get_node_or_null("DevDebugPanelRoot") as CanvasItem
	var ui_visible_before_debug: bool = ui_manager.visible if ui_manager != null else false
	var player_range_overlay: CanvasItem = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
	_assert(player_range_overlay == null or not player_range_overlay.visible, "player range overlay starts hidden in main flow")

	debug_panel.call("open_developer_mode")
	await process_frame
	_assert(debug_layer != null and debug_layer.visible, "developer mode opens debug panel")
	_assert(left_toolbar != null and left_toolbar.visible, "developer mode opens left toolbar")
	if ui_manager != null:
		_assert(ui_manager.visible == ui_visible_before_debug, "developer mode leaves main UI visible behind floating debug panel")
	var category_buttons: Dictionary = debug_panel.get("_category_buttons")
	var category_pages: Dictionary = debug_panel.get("_category_pages")
	_assert(not category_buttons.has("player_stats"), "dev debug removes Player Stats category button")
	_assert(not category_buttons.has("attack_stats"), "dev debug removes Primary Attack category button")
	_assert(not category_pages.has("player_stats"), "dev debug removes Player Stats page")
	_assert(not category_pages.has("attack_stats"), "dev debug removes Primary Attack page")
	var enemy_option: OptionButton = debug_panel.get("_enemy_option") as OptionButton
	_assert(enemy_option != null, "dev debug enemy spawn has enemy selector")
	if enemy_option != null:
		var has_normal_group: bool = false
		var has_elite_group: bool = false
		var has_boss_group: bool = false
		var selected_enemy_id: String = ""
		for item_index in range(enemy_option.item_count):
			var item_text: String = enemy_option.get_item_text(item_index)
			if item_text == "-- 普通 --":
				has_normal_group = true
				_assert(enemy_option.is_item_disabled(item_index), "dev debug enemy selector disables normal group header")
			elif item_text == "-- 精英 --":
				has_elite_group = true
				_assert(enemy_option.is_item_disabled(item_index), "dev debug enemy selector disables elite group header")
			elif item_text == "-- BOSS --":
				has_boss_group = true
				_assert(enemy_option.is_item_disabled(item_index), "dev debug enemy selector disables boss group header")
		if enemy_option.item_count > 0:
			selected_enemy_id = String(enemy_option.get_item_metadata(enemy_option.selected))
		_assert(has_normal_group, "dev debug enemy selector groups normal enemies")
		_assert(has_elite_group, "dev debug enemy selector groups elite enemies")
		_assert(has_boss_group, "dev debug enemy selector groups boss enemies")
		_assert(selected_enemy_id != "", "dev debug enemy selector defaults to a spawnable enemy")
	var status_option: OptionButton = debug_panel.get("_status_option") as OptionButton
	_assert(status_option != null, "dev debug status selector exists")
	_assert(debug_panel.has_method("_is_status_option_available"), "dev debug filters unavailable status options")
	if status_option != null and debug_panel.has_method("_is_status_option_available"):
		var status_options_are_valid: bool = true
		for status_index in range(status_option.item_count):
			var status_id: String = String(status_option.get_item_metadata(status_index))
			if status_id == "" or not bool(debug_panel.call("_is_status_option_available", status_id)):
				status_options_are_valid = false
				break
		_assert(status_options_are_valid, "dev debug status selector only lists available statuses")
		_assert(not bool(debug_panel.call("_is_status_option_available", "missing_debug_status")), "dev debug rejects missing status options")
	var enemy_armor_spin: SpinBox = debug_panel.get("_enemy_armor_spin") as SpinBox
	_assert(enemy_armor_spin != null, "dev debug enemy armor control exists")
	if enemy_armor_spin != null and debug_panel.has_method("_apply_enemy_panel_stats"):
		var skeleton_for_armor: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
		skeleton_for_armor.set("enemy_id", &"skeleton")
		main.add_child(skeleton_for_armor)
		skeleton_for_armor.global_position = player.global_position + Vector2(360.0, 96.0)
		await process_frame
		var default_skeleton_armor: int = int(skeleton_for_armor.get("armor"))
		enemy_armor_spin.value = 0.0
		debug_panel.call("_apply_enemy_panel_stats", skeleton_for_armor)
		_assert(default_skeleton_armor > 0 and int(skeleton_for_armor.get("armor")) == default_skeleton_armor, "dev debug enemy armor 0 keeps default armor")
		skeleton_for_armor.queue_free()
		await process_frame
	debug_panel.call("_refresh_runtime_upgrade_cards")
	await process_frame
	var runtime_upgrade_cards: Node = debug_panel.find_child("RuntimeUpgradeCards", true, false)
	var runtime_upgrade_cards_scroll: ScrollContainer = debug_panel.find_child("RuntimeUpgradeCardsScroll", true, false) as ScrollContainer
	var runtime_upgrade_options: Array = debug_panel.get("_runtime_upgrade_options")
	var character_runtime: Node = player.get_node_or_null("CharacterRuntime")
	var expected_branch_choice_count: int = 0
	if character_runtime != null and character_runtime.has_method("get_equipped_weapon_branch_ids"):
		expected_branch_choice_count = (character_runtime.call("get_equipped_weapon_branch_ids") as Array).size()
	_assert(runtime_upgrade_cards_scroll != null, "dev debug skill cards use a scroll container")
	_assert(runtime_upgrade_cards_scroll != null and runtime_upgrade_cards_scroll.custom_minimum_size.y >= 300.0, "dev debug skill cards scroll area has stable height")
	_assert(runtime_upgrade_cards_scroll != null and runtime_upgrade_cards != null and runtime_upgrade_cards.get_parent() == runtime_upgrade_cards_scroll, "dev debug skill cards list is inside scroll container")
	_assert(runtime_upgrade_cards != null and runtime_upgrade_cards.get_child_count() > 0, "dev debug lists runtime skill cards")
	_assert(not runtime_upgrade_options.is_empty(), "dev debug runtime skill card options are available")
	var branch_choice_count: int = 0
	var has_unselected_branch_level_card: bool = false
	for option_variant: Variant in runtime_upgrade_options:
		if option_variant is Dictionary:
			var option: Dictionary = option_variant
			var option_id_text: String = String(option.get("id", ""))
			if option_id_text.begins_with("branch_choice:"):
				branch_choice_count += 1
			if option_id_text.begins_with("skill_level_up:") and option_id_text.split(":").size() >= 4:
				has_unselected_branch_level_card = true
				break
	_assert(branch_choice_count == expected_branch_choice_count, "dev debug skill cards show all Lv2 branch choices before branch lock")
	_assert(not has_unselected_branch_level_card, "dev debug skill cards keep branch mutual exclusion before branch lock")
	if not runtime_upgrade_options.is_empty():
		var before_level: int = 0
		var current_skill: RefCounted = null
		var applied_branch_id: String = ""
		var first_option: Dictionary = runtime_upgrade_options[0] as Dictionary
		if first_option != null:
			var first_payload: Dictionary = first_option.get("payload", {}) as Dictionary
			applied_branch_id = String(first_payload.get("branch_id", ""))
		var skill_manager: Node = player.get_node_or_null("SkillManager")
		if skill_manager != null and skill_manager.has_method("get_all_skills"):
			var skills: Array = skill_manager.call("get_all_skills")
			if not skills.is_empty():
				current_skill = skills[0] as RefCounted
		if current_skill != null:
			before_level = int(current_skill.get("current_level"))
		debug_panel.call("_apply_runtime_upgrade_card", 0)
		await process_frame
		var comparison_rows: Array = debug_panel.get("_last_upgrade_comparison_rows")
		_assert(not comparison_rows.is_empty(), "dev debug draws runtime skill upgrade comparison chart")
		var after_level: int = int(current_skill.get("current_level")) if current_skill != null else before_level
		_assert(after_level >= before_level, "dev debug can apply a selected runtime skill card")
		var locked_branch_id: String = ""
		if character_runtime != null and character_runtime.has_method("get_selected_weapon_branch_id"):
			locked_branch_id = String(character_runtime.call("get_selected_weapon_branch_id"))
		_assert(locked_branch_id == applied_branch_id, "dev debug skill cards lock selected branch at Lv2")
		runtime_upgrade_options = debug_panel.get("_runtime_upgrade_options")
		var has_selected_branch_level_card: bool = false
		var has_other_branch_card: bool = false
		var selected_branch_level_card_index: int = -1
		var selected_branch_level_card_id: String = ""
		for refreshed_option_variant: Variant in runtime_upgrade_options:
			if not (refreshed_option_variant is Dictionary):
				continue
			var refreshed_option: Dictionary = refreshed_option_variant
			var refreshed_id_text: String = String(refreshed_option.get("id", ""))
			if refreshed_id_text.begins_with("branch_choice:"):
				has_other_branch_card = true
				break
			if refreshed_id_text.begins_with("skill_level_up:"):
				var refreshed_parts: PackedStringArray = refreshed_id_text.split(":")
				if refreshed_parts.size() >= 4:
					if String(refreshed_parts[3]) == applied_branch_id:
						has_selected_branch_level_card = true
						if selected_branch_level_card_index < 0:
							selected_branch_level_card_index = runtime_upgrade_options.find(refreshed_option_variant)
							selected_branch_level_card_id = refreshed_id_text
					else:
						has_other_branch_card = true
						break
		_assert(has_selected_branch_level_card, "dev debug skill cards show selected branch level cards after branch lock")
		_assert(not has_other_branch_card, "dev debug skill cards hide mutually exclusive branch cards after branch lock")
		if selected_branch_level_card_index >= 0:
			debug_panel.call("_apply_runtime_upgrade_card", selected_branch_level_card_index)
			await process_frame
			runtime_upgrade_options = debug_panel.get("_runtime_upgrade_options")
			var still_has_applied_level_card: bool = false
			for applied_option_variant: Variant in runtime_upgrade_options:
				if applied_option_variant is Dictionary and String((applied_option_variant as Dictionary).get("id", "")) == selected_branch_level_card_id:
					still_has_applied_level_card = true
					break
			_assert(not still_has_applied_level_card, "dev debug skill cards hide an already applied branch level card")
		debug_panel.call("_clear_skill_cards")
		await process_frame
		if skill_manager != null and skill_manager.has_method("get_all_skills"):
			var cleared_skills: Array = skill_manager.call("get_all_skills")
			_assert(cleared_skills.size() == 1, "dev debug clear skill cards keeps only character starting skill")
			if not cleared_skills.is_empty():
				_assert(String((cleared_skills[0] as RefCounted).get("skill_id")) == "fireball", "dev debug clear skill cards rebinds current weapon starting skill")
	debug_panel.call("_set_debug_visible", false)
	await process_frame
	_assert(bool(root.get_meta("debug_control_mode", false)), "F12 close keeps debug control mode enabled from developer mode")
	if ui_manager != null:
		_assert(ui_manager.visible == ui_visible_before_debug, "F12 close keeps main UI visibility unchanged from developer mode")
		ui_visible_before_debug = ui_manager.visible

	debug_panel.call("_set_debug_visible", true)
	await process_frame

	_assert(debug_layer != null and debug_layer.visible, "F12 debug mode can show panel")
	_assert(left_toolbar != null and left_toolbar.visible, "F12 debug mode can show left toolbar")
	_assert(bool(root.get_meta("debug_control_mode", false)), "debug control mode meta is enabled")
	if ui_manager != null:
		_assert(ui_manager.visible == ui_visible_before_debug, "F12 leaves main UI visibility unchanged while debug panel is visible")

	var spawner: Node = main.get_node_or_null("EnemySpawner")
	_assert(spawner != null, "enemy spawner exists for debug manual spawn check")
	if spawner != null:
		var before_auto_spawn_count: int = get_nodes_in_group(&"enemies").size()
		root.set_meta("debug_control_mode", false)
		spawner.call("_physics_process", 3.0)
		spawner.call("_physics_process", 3.0)
		await process_frame
		_assert(get_nodes_in_group(&"enemies").size() == before_auto_spawn_count, "developer debug mode disables automatic enemy spawning")
		root.set_meta("debug_control_mode", true)

	debug_panel.call("_spawn_enemies", 4)
	await process_frame
	var nearby_debug_enemies: int = 0
	var farthest_distance: float = 0.0
	for node: Node in get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not bool(enemy.get_meta("debug_spawned", false)):
			continue
		nearby_debug_enemies += 1
		farthest_distance = maxf(farthest_distance, player.global_position.distance_to(enemy.global_position))
	_assert(nearby_debug_enemies >= 4, "dev debug spawn creates enemies")
	_assert(farthest_distance <= 220.0, "dev debug enemies spawn inside player attack range")

	var overlap_debug_enemy: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
	overlap_debug_enemy.set("enemy_id", &"skeleton")
	main.add_child(overlap_debug_enemy)
	overlap_debug_enemy.global_position = player.global_position + Vector2(0, -46)
	var debug_blocker_position: Vector2 = overlap_debug_enemy.global_position
	(player as CharacterBody2D).velocity = Vector2.UP * 220.0
	await process_frame
	player.call("_limit_actor_motion", 0.2)
	var debug_player_blocked: bool = (player as CharacterBody2D).velocity.length() < 220.0
	(player as CharacterBody2D).velocity = Vector2.ZERO
	_assert(debug_player_blocked and overlap_debug_enemy.global_position == debug_blocker_position, "dev debug blocks player movement into enemy")
	overlap_debug_enemy.queue_free()
	await process_frame

	var first_enemy: Node2D = null
	for node: Node in get_nodes_in_group(&"enemies"):
		if bool(node.get_meta("debug_spawned", false)):
			first_enemy = node as Node2D
			break
	if first_enemy != null:
		debug_panel.call("_set_all_range_overlays_visible", true)
		player_range_overlay = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
		_assert(player_range_overlay != null and player_range_overlay.visible, "dev debug shows player range overlay")
		await _check_fireball_explosion_overlay_radius(main, player, player_range_overlay)
		await _check_attack_once_damage_trace(main, player, debug_panel)
		var range_overlay: CanvasItem = first_enemy.get_node_or_null("EnemyAttackRangeOverlay") as CanvasItem
		_assert(range_overlay != null and range_overlay.visible, "dev debug shows enemy attack range overlay")
		var bomber_enemy: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
		bomber_enemy.set("enemy_id", &"bomber")
		main.add_child(bomber_enemy)
		bomber_enemy.global_position = player.global_position + Vector2(24, 0)
		await process_frame
		debug_panel.call("_set_all_range_overlays_visible", true)
		var bomber_overlay: CanvasItem = bomber_enemy.get_node_or_null("EnemyAttackRangeOverlay") as CanvasItem
		_assert(bomber_overlay != null and bomber_overlay.visible, "dev debug shows bomber range overlay")
		var exploded: bool = bool(bomber_enemy.call("_execute_enemy_skill_action", "self_explode"))
		for frame_index: int in range(12):
			await process_frame
		debug_panel.call("_sync_enemy_attack_range_overlays", true)
		_assert(exploded and not is_instance_valid(bomber_enemy), "dev debug prunes bomber range overlay after self explode")
		var before_position: Vector2 = first_enemy.global_position
		first_enemy.call("_physics_process", 0.5)
		_assert(first_enemy.global_position.distance_to(before_position) <= 0.01, "dev debug mode stops enemy movement")
		debug_panel.call("_set_enemy_state_override", "idle")
		first_enemy.call("_physics_process", 0.2)
		_assert(String(first_enemy.call("get_runtime_state")) == "idle", "dev debug can force enemy idle state")
		debug_panel.call("_set_enemy_state_override", "chase")
		first_enemy.call("_physics_process", 0.2)
		_assert(String(first_enemy.call("get_runtime_state")) == "chase", "dev debug can force enemy chase state")
		debug_panel.call("_set_enemy_state_override", "attack")
		first_enemy.call("_physics_process", 0.2)
		_assert(String(first_enemy.call("get_runtime_state")) == "attack", "dev debug can force enemy attack state")
		debug_panel.call("_set_enemy_state_override", "")
		first_enemy.call("_physics_process", 0.2)
		_assert(String(root.get_meta("debug_enemy_forced_state", "")) == "", "dev debug can clear enemy forced state")
		debug_panel.call("_set_enemy_state_override", "hurt")
		debug_panel.call("_refresh_state")
		_assert(String(root.get_meta("debug_enemy_forced_state", "")) == "", "dev debug disables elite-only states for normal nearest enemy")
		root.set_meta("debug_enemy_forced_state", "hurt")
		first_enemy.call("_physics_process", 0.2)
		_assert(String(first_enemy.call("get_runtime_state")) != "hurt", "normal enemy ignores forced hurt state")
		root.set_meta("debug_enemy_forced_state", "dead")
		first_enemy.call("_physics_process", 0.2)
		_assert(String(first_enemy.call("get_runtime_state")) != "dead", "normal enemy ignores forced death state")
		root.set_meta("debug_enemy_forced_state", "")

		var elite_enemy: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
		elite_enemy.set("enemy_id", &"giant_slime")
		main.add_child(elite_enemy)
		elite_enemy.global_position = player.global_position + Vector2(16, 0)
		await process_frame
		debug_panel.call("_set_enemy_state_override", "hurt")
		elite_enemy.call("_physics_process", 0.2)
		_assert(String(elite_enemy.call("get_runtime_state")) == "hurt", "elite enemy can force hurt state")
		debug_panel.call("_set_enemy_state_override", "dead")
		elite_enemy.call("_physics_process", 0.2)
		_assert(String(elite_enemy.call("get_runtime_state")) == "dead", "elite enemy can force death state")
		debug_panel.call("_set_enemy_state_override", "")

	var before_spawn_all_count: int = get_nodes_in_group(&"enemies").size()
	var enemy_type_count: int = GameData.get_enemy_pool().size()
	debug_panel.call("_spawn_all_enemy_types")
	await process_frame
	var spawn_all_count: int = 0
	for node: Node in get_nodes_in_group(&"enemies"):
		if bool(node.get_meta("debug_spawn_all_types", false)):
			spawn_all_count += 1
	_assert(spawn_all_count >= enemy_type_count, "dev debug spawn all enemy types creates each enemy type")
	_assert(get_nodes_in_group(&"enemies").size() >= before_spawn_all_count + enemy_type_count, "dev debug spawn all enemy types increases enemy count")
	debug_panel.call("_set_debug_visible", false)
	await process_frame
	_assert(bool(root.get_meta("debug_control_mode", false)), "F12 close keeps spawned-all enemies frozen")
	debug_panel.call("_set_debug_visible", true)
	await process_frame

	var skill_executor: Node = player.get_node_or_null("SkillExecutor")
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_executor != null and skill_manager != null and skill_manager.has_method("get_all_skills"):
		var skills: Array = skill_manager.call("get_all_skills")
		if skills.is_empty():
			player.call("reset_for_loadout", CharacterLoadoutServiceScript.build_loadout(&"mage", &"fire_staff"))
			skills = skill_manager.call("get_all_skills")
		if not skills.is_empty():
			var skill: RefCounted = skills[0] as RefCounted
			skill.set("cooldown_remaining", 1.0)
			skill_executor.call("_physics_process", 0.5)
			_assert(is_equal_approx(float(skill.get("cooldown_remaining")), 1.0), "dev debug mode stops automatic player skill cooldown")
			var cast_count: int = int(skill_executor.call("debug_cast_all_skills"))
			_assert(cast_count >= 1, "dev debug tool can manually cast player skills")
			debug_panel.call("_set_debug_control_mode", false)
			debug_panel.call("_toggle_player_attack_disabled")
			skill.set("cooldown_remaining", 1.0)
			skill_executor.call("_physics_process", 0.5)
			_assert(is_equal_approx(float(skill.get("cooldown_remaining")), 1.0), "dev debug attack toggle stops automatic player skill cooldown")
			cast_count = int(skill_executor.call("debug_cast_all_skills"))
			_assert(cast_count >= 1, "manual player attack still works while auto attack is disabled")
			debug_panel.call("_toggle_player_attack_disabled")
			debug_panel.call("_set_debug_control_mode", true)

	debug_panel.call("_set_debug_visible", false)
	await process_frame
	_assert(bool(root.get_meta("debug_control_mode", false)), "F12 close preserves debug control mode after close")
	_assert(left_toolbar != null and not left_toolbar.visible, "left toolbar hidden after debug close")
	player_range_overlay = player.get_node_or_null("PlayerDebugOverlay") as CanvasItem
	_assert(player_range_overlay == null or not player_range_overlay.visible, "player range overlay hidden after debug close")
	if first_enemy != null and is_instance_valid(first_enemy):
		var closed_enemy_range_overlay: CanvasItem = first_enemy.get_node_or_null("EnemyAttackRangeOverlay") as CanvasItem
		_assert(closed_enemy_range_overlay == null or not closed_enemy_range_overlay.visible, "enemy range overlay hidden after debug close")
	if ui_manager != null:
		_assert(ui_manager.visible == ui_visible_before_debug, "F12 leaves main UI visibility unchanged after debug close")


func _check_enemy_status_damage_visual(enemy: Node2D) -> void:
	_assert(enemy != null, "enemy exists for status damage visual check")
	if enemy == null:
		return

	var before_hp: int = int(enemy.get("current_health"))
	var applied: bool = bool(enemy.call("apply_status", &"burn", {"duration": 1.2, "stacks": 1}))
	_assert(applied, "debug burn status applies to enemy")
	enemy.call("_update_status_effects", 0.6)
	enemy.call("_update_status_label")
	enemy.call("_update_debug_health_display")
	await process_frame

	var after_hp: int = int(enemy.get("current_health"))
	_assert(after_hp < before_hp, "debug burn status visibly reduces enemy HP")
	_assert(enemy.get_node_or_null("DebugHpBar") != null, "debug enemy HP bar exists")
	_assert(enemy.get_node_or_null("DebugHpLabel") == null, "debug enemy numeric HP label is replaced by visual bar")
	_assert(enemy.get_node_or_null("StatusLabel") != null and (enemy.get_node_or_null("StatusLabel") as Label).visible, "debug enemy status label is visible")


func _check_fireball_explosion_overlay_radius(main: Node, player: Node2D, player_range_overlay: CanvasItem) -> void:
	if player == null or player_range_overlay == null:
		return

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	_assert(skill_manager != null, "fireball explosion overlay check has skill manager")
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return

	var fireball_skill: RefCounted = skill_manager.call("get_skill", &"fireball") as RefCounted
	_assert(fireball_skill != null, "fireball explosion overlay check has fireball skill")
	if fireball_skill == null:
		return

	var branch_system: Node = WeaponBranchSystemScript.new()
	main.add_child(branch_system)
	var branch_applied: bool = bool(branch_system.call("apply_branch", player, &"fire_staff_branch_burst", true))
	var branch_level3_applied: bool = bool(branch_system.call("apply_selected_branch_level", player, 3, &"fire_staff_branch_burst", true))
	await process_frame
	_assert(branch_applied, "dev debug applies fireball burst branch for explosion trace check")
	_assert(branch_level3_applied, "dev debug applies fireball burst level 3 for multi-damage trace check")
	branch_system.queue_free()


func _check_attack_once_damage_trace(main: Node, player: Node2D, debug_panel: Node) -> void:
	_assert(debug_panel != null and debug_panel.has_method("_attack_once_player_skills"), "dev debug exposes attack once trace action")
	if debug_panel == null or not debug_panel.has_method("_attack_once_player_skills"):
		return

	var enemy_index: int = 0
	for node: Node in get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		enemy.global_position = player.global_position + Vector2(420.0 + float(enemy_index) * 40.0, 0.0)
		enemy_index += 1

	var trace_target: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
	trace_target.set("enemy_id", &"small_slime")
	main.add_child(trace_target)
	trace_target.global_position = player.global_position + Vector2(180.0, 0.0)
	await process_frame
	trace_target.set("max_health", 9999)
	trace_target.set("current_health", 9999)
	player.set("crit_chance", 0.0)

	debug_panel.call("_attack_once_player_skills")
	for frame_index: int in range(90):
		await physics_frame

	var trace_records: Array = root.get_meta("debug_combat_trace_records", [])
	_assert(not trace_records.is_empty(), "dev debug attack once records damage entries")
	var trace_damage_count: int = 0
	var explosion_trace: Dictionary = {}
	for trace_record_variant: Variant in trace_records:
		if not (trace_record_variant is Dictionary):
			continue
		var trace_record: Dictionary = trace_record_variant
		if String(trace_record.get("type", "")) == "damage":
			trace_damage_count += 1
		elif String(trace_record.get("type", "")) == "explosion":
			explosion_trace = trace_record
	_assert(trace_damage_count >= 2, "dev debug attack once records primary and explosion damage traces")
	_assert(not explosion_trace.is_empty(), "dev debug attack once records explosion trace entry")
	_assert(explosion_trace.has("damage_packet"), "dev debug explosion trace keeps damage packet")
	_assert(explosion_trace.has("raw_amount"), "dev debug explosion trace exposes raw amount")
	_assert(explosion_trace.has("damage_origin"), "dev debug explosion trace exposes damage origin")
	_assert(explosion_trace.has("damage_type"), "dev debug explosion trace exposes damage type")
	_assert(explosion_trace.has("element"), "dev debug explosion trace exposes element")
	_assert(explosion_trace.has("source_type"), "dev debug explosion trace exposes source type")
	_assert(explosion_trace.has("source_skill_id"), "dev debug explosion trace exposes source skill id")
	_assert(main.find_child("DebugExplosionSiteOverlay*", true, false) != null, "dev debug leaves explosion site overlay")
	_assert(String(debug_panel.get("_last_attack_damage_text")).find("Damage Breakdown") >= 0, "dev debug panel displays attack damage breakdown")
	var damage_card_scroll: ScrollContainer = debug_panel.find_child("AttackDamageCardScroll", true, false) as ScrollContainer
	_assert(damage_card_scroll != null, "dev debug damage panel uses single-card scroll container")
	_assert(damage_card_scroll != null and damage_card_scroll.custom_minimum_size.y >= 300.0, "dev debug damage card has stable scrollable height")
	var copy_record_button: Button = debug_panel.find_child("CopyDamageRecordButton", true, false) as Button
	_assert(copy_record_button != null, "dev debug damage panel exposes copy record button")
	_assert(debug_panel.has_method("_copy_current_attack_damage_record"), "dev debug exposes current record copy action")
	var damage_text: String = String(debug_panel.get("_last_attack_damage_text"))
	_assert(damage_text.find("敌人：small_slime") >= 0, "dev debug damage panel groups trace by enemy")
	_assert(damage_text.find("trace:") >= 0, "dev debug damage panel shows damage trace count by enemy")
	_assert(damage_text.find("构成：爆炸伤害+主攻击伤害") >= 0, "dev debug damage panel summarizes damage composition")
	_assert(damage_text.find("Card 1/%d" % trace_damage_count) >= 0, "dev debug damage panel cards are limited to damage records")
	_assert(damage_text.find("最终伤害：") < 0, "dev debug damage panel hides calculated damage detail")
	_assert(damage_text.find("基础伤害：") < 0, "dev debug damage panel hides base damage detail")
	_assert(damage_text.find("人物天赋倍率：") < 0, "dev debug damage panel hides multiplier detail")
	_assert(damage_text.find("record：") >= 0, "dev debug damage panel shows raw record dump")
	_assert(damage_text.find("type: damage") >= 0, "dev debug damage panel shows damage record dump")
	_assert(damage_text.find("type: explosion") < 0, "dev debug damage panel excludes explosion event record dump")
	_assert(damage_text.find("target_id:") >= 0, "dev debug damage panel includes raw target id")
	_assert(damage_text.find("source_instance_id:") >= 0, "dev debug damage panel includes raw source instance id")
	_assert(damage_text.find("stages:") >= 0, "dev debug damage panel includes raw nested stages")
	_assert(damage_text.find("  raw_amount:") >= 0, "dev debug damage panel includes indented raw stage fields")
	_assert(debug_panel.has_method("_show_next_attack_damage_card"), "dev debug exposes next damage record card action")
	if debug_panel.has_method("_show_next_attack_damage_card"):
		debug_panel.call("_show_next_attack_damage_card")
		await process_frame
		damage_text = String(debug_panel.get("_last_attack_damage_text"))
		_assert(damage_text.find("Card 2/") >= 0, "dev debug damage panel can switch to next record card")

	root.set_meta("debug_attack_trace_id", 987)
	root.set_meta("debug_combat_trace_records", [{
		"type": "damage",
		"trace_id": 987,
		"target": "copy_dummy",
		"target_id": "copy_target",
		"source_skill_id": "copy_skill",
		"source_type": "debug",
		"source_instance_id": "copy_source",
		"raw_amount": 12.0,
		"final_amount": 10,
		"multiplier": 1.0,
		"is_critical": false,
		"damage_origin": "test",
		"damage_type": "direct",
		"element": "fire",
		"stages": {
			"copy_stage": {
				"raw_amount": 12
			}
		}
	}])
	debug_panel.set("_attack_damage_card_index", 0)
	if debug_panel.has_method("_refresh_attack_damage_text"):
		debug_panel.call("_refresh_attack_damage_text")
	if debug_panel.has_method("_copy_current_attack_damage_record"):
		var copied_record: bool = bool(debug_panel.call("_copy_current_attack_damage_record"))
		var copied_text: String = String(debug_panel.get("_last_copied_attack_damage_record_text"))
		_assert(copied_record, "dev debug copies current damage record")
		_assert(copied_text.find("type: damage") >= 0 and copied_text.find("target: copy_dummy") >= 0, "dev debug copied text contains current record dump")

	var active_trace_id: int = int(root.get_meta("debug_attack_trace_id", 0))
	var status_applied: bool = bool(trace_target.call("apply_status", &"burn", {
		"damage": 5,
		"duration": 1.2,
		"tick_interval": 0.1,
		"debug_attack_trace_id": active_trace_id
	}))
	trace_target.call("_update_status_effects", 0.2)
	await process_frame
	debug_panel.call("_refresh_state")
	trace_records = root.get_meta("debug_combat_trace_records", [])
	var has_status_dot_trace: bool = false
	for status_trace_variant: Variant in trace_records:
		if not (status_trace_variant is Dictionary):
			continue
		var status_trace: Dictionary = status_trace_variant
		if String(status_trace.get("damage_origin", "")) == "status_dot" and String(status_trace.get("source_skill_id", "")) == "burn":
			has_status_dot_trace = true
			break
	_assert(status_applied, "dev debug applies traced burn status")
	_assert(has_status_dot_trace, "dev debug records traced burn tick damage")
	_assert(main.find_child("DebugElementDamageSiteOverlay*", true, false) != null, "dev debug leaves element damage site overlay")

	if debug_panel.has_method("_clear_attack_trace"):
		debug_panel.call("_clear_attack_trace")
		await process_frame
	var panel_status_target: Node2D = load("res://scenes/enemy.tscn").instantiate() as Node2D
	panel_status_target.set("enemy_id", &"small_slime")
	main.add_child(panel_status_target)
	panel_status_target.global_position = player.global_position + Vector2(90.0, 0.0)
	await process_frame
	panel_status_target.set("max_health", 9999)
	panel_status_target.set("current_health", 9999)

	var status_option: OptionButton = debug_panel.get("_status_option") as OptionButton
	var status_stack_spin: SpinBox = debug_panel.get("_status_stack_spin") as SpinBox
	var status_duration_spin: SpinBox = debug_panel.get("_status_duration_spin") as SpinBox
	var apply_to_all_enemies_check: BaseButton = debug_panel.get("_apply_to_all_enemies_check") as BaseButton
	var target_player_check: BaseButton = debug_panel.get("_target_player_check") as BaseButton
	_assert(status_option != null and status_stack_spin != null and status_duration_spin != null, "dev debug status controls exist for trace check")
	if status_option != null and status_stack_spin != null and status_duration_spin != null:
		debug_panel.call("_select_option_by_id", status_option, "burn")
		status_stack_spin.value = 1.0
		status_duration_spin.value = 1.2
		if apply_to_all_enemies_check != null:
			apply_to_all_enemies_check.button_pressed = false
		if target_player_check != null:
			target_player_check.button_pressed = false
		debug_panel.call("_apply_status_from_panel")
		panel_status_target.call("_update_status_effects", 0.6)
		await process_frame
		debug_panel.call("_refresh_state")
		trace_records = root.get_meta("debug_combat_trace_records", [])
		var has_panel_status_dot_trace: bool = false
		for panel_status_trace_variant: Variant in trace_records:
			if not (panel_status_trace_variant is Dictionary):
				continue
			var panel_status_trace: Dictionary = panel_status_trace_variant
			if String(panel_status_trace.get("damage_origin", "")) == "status_dot" and String(panel_status_trace.get("source_skill_id", "")) == "burn":
				has_panel_status_dot_trace = true
				break
		_assert(int(root.get_meta("debug_attack_trace_id", 0)) > 0, "dev debug status button starts a damage trace")
		_assert(has_panel_status_dot_trace, "dev debug status button records status tick damage")
		_assert(main.find_child("DebugElementDamageSiteOverlay*", true, false) != null, "dev debug status button leaves element damage site overlay")

	_assert(debug_panel.has_method("_clear_attack_trace"), "dev debug exposes clear attack trace action")
	if debug_panel.has_method("_clear_attack_trace"):
		debug_panel.call("_clear_attack_trace")
		await process_frame
		trace_records = root.get_meta("debug_combat_trace_records", [])
		_assert(trace_records.is_empty(), "dev debug clears attack trace records")
		_assert(main.find_child("DebugExplosionSiteOverlay*", true, false) == null, "dev debug clears explosion site overlays")
	trace_target.queue_free()
	panel_status_target.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[VisualConfigCheck] PASS %s" % message)
	else:
		_failed = true
		push_error("[VisualConfigCheck] FAIL %s" % message)
