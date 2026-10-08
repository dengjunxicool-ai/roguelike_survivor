extends RefCounted

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var _host_ref: WeakRef

func _init(host: CanvasLayer) -> void:
	_host_ref = weakref(host)


func _build_enemy_spawn_page(page_root: VBoxContainer) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var enemy_spawn_page: VBoxContainer = host._add_category_page(page_root, "enemy_spawn", "Enemy Spawn")
	host._enemy_option = host._add_option_row(enemy_spawn_page, "Enemy")
	host._spawn_count_spin = host._add_spin_row(enemy_spawn_page, "Count", 1.0, 200.0, 1.0, 8.0)
	host._enemy_health_spin = host._add_spin_row(enemy_spawn_page, "HP 0=default", 0.0, 100000.0, 10.0, 0.0)
	host._enemy_armor_spin = host._add_spin_row(enemy_spawn_page, "Armor 0=default", 0.0, 1000.0, 1.0, 0.0)
	host._enemy_resistance_spin = host._add_spin_row(enemy_spawn_page, "All Resist %", -75.0, 90.0, 5.0, 0.0)
	var enemy_row: HBoxContainer = host._add_row(enemy_spawn_page)
	host._add_button(enemy_row, "Spawn", Callable(host, "_spawn_configured_enemies"), 92)
	host._add_button(enemy_row, "Set Nearest", Callable(host, "_set_nearest_enemy_stats"), 116)
	host._add_button(enemy_row, "Clear Enemies", Callable(host, "_clear_enemies"), 124)
	var enemy_batch_row: HBoxContainer = host._add_row(enemy_spawn_page)
	host._add_button(enemy_batch_row, "Spawn All Types", Callable(host, "_spawn_all_enemy_types"), 148)
	host._enemy_state_option = host._add_option_row(enemy_spawn_page, "Enemy State")
	var enemy_state_row: HBoxContainer = host._add_row(enemy_spawn_page)
	host._add_button(enemy_state_row, "Set Enemy State", Callable(host, "_apply_enemy_state_override"), 140)
	host._add_button(enemy_state_row, "Clear Enemy State", Callable(host, "_clear_enemy_state_override"), 148)


func _populate_enemy_options() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._enemy_option.clear()
	var normal_enemies: Array[Dictionary] = []
	var elite_enemies: Array[Dictionary] = []
	var boss_enemies: Array[Dictionary] = []
	for enemy: Dictionary in GameData.get_enemy_pool():
		var id: String = String(enemy.get("id", ""))
		if id == "":
			continue
		match host._get_enemy_option_group(enemy):
			"boss":
				boss_enemies.append(enemy)
			"elite":
				elite_enemies.append(enemy)
			_:
				normal_enemies.append(enemy)
	host._add_enemy_group_options("普通", normal_enemies)
	host._add_enemy_group_options("精英", elite_enemies)
	host._add_enemy_group_options("BOSS", boss_enemies)
	host._select_first_enabled_option(host._enemy_option)


func _get_enemy_option_group(enemy: Dictionary) -> String:
	return String(enemy.get("enemy_rank", "normal"))


func _add_enemy_group_options(group_label: String, enemies: Array[Dictionary]) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if enemies.is_empty():
		return
	host._add_disabled_option_header(host._enemy_option, "-- %s --" % group_label)
	for enemy: Dictionary in enemies:
		var id: String = String(enemy.get("id", ""))
		if id != "":
			host._add_option_item(host._enemy_option, host._display_name(enemy, id), id)


func _populate_enemy_state_options() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._enemy_state_option == null:
		return
	host._enemy_state_option.clear()
	host._add_option_item(host._enemy_state_option, "Auto", "")
	host._add_option_item(host._enemy_state_option, "Idle", "idle")
	host._add_option_item(host._enemy_state_option, "Chase", "chase")
	host._add_option_item(host._enemy_state_option, "Attack", "attack")
	host._add_option_item(host._enemy_state_option, "Hurt", "hurt")
	host._add_option_item(host._enemy_state_option, "Death", "dead")
	host._select_option_by_id(host._enemy_state_option, host._get_enemy_state_override())
	host._refresh_enemy_state_option_availability()


func _apply_enemy_state_override() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var state: String = String(host._get_selected_id(host._enemy_state_option))
	state = host._normalize_enemy_forced_state(state)
	if not host._is_valid_enemy_forced_state(state) and state != "":
		host._log_warn("Unsupported enemy state: %s." % state)
		return
	if host._is_elite_only_enemy_state(state) and not host._can_apply_elite_enemy_state_to_nearest():
		host._select_option_by_id(host._enemy_state_option, "")
		host._log_warn("Hurt/Death enemy states are only enabled for elite enemies.")
		return
	host._set_enemy_state_override(state)
	host._log("Enemy forced state=%s." % ("auto" if state == "" else state))


func _clear_enemy_state_override() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	host._set_enemy_state_override("")
	host._select_option_by_id(host._enemy_state_option, "")
	host._log("Enemy forced state=auto.")


func _spawn_configured_enemies() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node2D = host._get_player() as Node2D
	if player == null or player.get_parent() == null:
		host._log_error("Player missing.")
		return

	var enemy_id: StringName = host._get_selected_id(host._enemy_option)
	var count: int = maxi(roundi(float(host._spawn_count_spin.value)), 1)
	var spawn_parent: Node = player.get_parent()
	var radius: float = host._get_debug_spawn_radius(player)
	var spawned: int = 0
	for spawn_index in range(count):
		var angle: float = TAU * float(spawn_index) / float(maxi(count, 1))
		var position: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * (radius + 12.0 * float(spawn_index % 4))
		var enemy: Node2D = host._spawn_debug_enemy(enemy_id, position, spawn_parent, true)
		if enemy == null:
			continue
		spawned += 1
	host._sync_enemy_attack_range_overlays(host._are_range_overlays_visible())
	host._log("Spawned %d x %s." % [spawned, String(enemy_id)])


func _spawn_all_enemy_types() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var player: Node2D = host._get_player() as Node2D
	if player == null or player.get_parent() == null:
		host._log_error("Player missing.")
		return

	var enemy_pool: Array[Dictionary] = GameData.get_enemy_pool()
	if enemy_pool.is_empty():
		host._log_warn("Enemy pool is empty.")
		return

	var spawn_parent: Node = player.get_parent()
	var count: int = enemy_pool.size()
	var base_radius: float = maxf(host._get_debug_spawn_radius(player), 150.0)
	var spawned: int = 0
	for index in range(count):
		var enemy_data: Dictionary = enemy_pool[index]
		var enemy_id: StringName = StringName(String(enemy_data.get("id", "")))
		if enemy_id == &"":
			continue
		var angle: float = TAU * float(index) / float(maxi(count, 1))
		var ring_offset: float = 34.0 * float(index / 12)
		var position: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * (base_radius + ring_offset)
		var enemy: Node2D = host._spawn_debug_enemy(enemy_id, position, spawn_parent, false)
		if enemy == null:
			continue
		enemy.set_meta("debug_spawn_all_types", true)
		spawned += 1

	host._sync_enemy_attack_range_overlays(host._are_range_overlays_visible())
	host._log("Spawned %d enemy type(s)." % spawned)


func _spawn_debug_enemy(enemy_id: StringName, position: Vector2, spawn_parent: Node, apply_panel_stats: bool) -> Node2D:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var enemy: Node2D = ENEMY_SCENE.instantiate() as Node2D
	if enemy == null:
		return null
	enemy.set("enemy_id", enemy_id)
	enemy.global_position = position
	enemy.set_meta("debug_spawned", true)
	spawn_parent.add_child(enemy)
	if apply_panel_stats:
		host._apply_enemy_panel_stats(enemy)
	return enemy


func _spawn_enemies(count: int) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._spawn_count_spin != null:
		host._spawn_count_spin.value = maxi(count, 1)
	host._spawn_configured_enemies()


func _set_nearest_enemy_stats() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var enemy: Node = host._get_nearest_enemy()
	if enemy == null:
		host._log_warn("No enemy found.")
		return
	host._apply_enemy_panel_stats(enemy)
	host._log("Applied enemy stats to %s." % enemy.name)


func _apply_enemy_panel_stats(enemy: Node) -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var hp: int = roundi(float(host._enemy_health_spin.value))
	if hp > 0:
		enemy.set("max_health", hp)
		enemy.set("current_health", hp)
	if enemy.get("armor") != null:
		var armor: int = roundi(float(host._enemy_armor_spin.value))
		if armor > 0:
			enemy.set("armor", armor)
	if enemy.get("resistances") != null:
		var resistance: float = clampf(float(host._enemy_resistance_spin.value) * 0.01, -0.75, 0.90)
		enemy.set("resistances", {
			"physical": resistance,
			"fire": resistance,
			"ice": resistance,
			"lightning": resistance,
			"poison": resistance,
			"acid": resistance,
			"holy": resistance,
			"arcane": resistance,
			"magic": resistance
		})
	if enemy.has_signal(&"health_changed"):
		enemy.emit_signal(&"health_changed", int(enemy.get("current_health")), int(enemy.get("max_health")))


func _clear_enemies() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var cleared: int = 0
	for enemy: Node in host.get_tree().get_nodes_in_group(&"enemies"):
		enemy.queue_free()
		cleared += 1
	host._enemy_range_overlays.clear()
	host._log("Cleared %d enemies." % cleared)


func _refresh_enemy_state_option_availability() -> void:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if host._enemy_state_option == null:
		return

	var allow_elite_states: bool = host._can_apply_elite_enemy_state_to_nearest()
	for index in range(host._enemy_state_option.item_count):
		var state: String = host._normalize_enemy_forced_state(String(host._enemy_state_option.get_item_metadata(index)))
		host._enemy_state_option.set_item_disabled(index, host._is_elite_only_enemy_state(state) and not allow_elite_states)

	var current_state: String = host._get_enemy_state_override()
	if host._is_elite_only_enemy_state(current_state) and not allow_elite_states:
		host._set_enemy_state_override("")
		host._select_option_by_id(host._enemy_state_option, "")


func _can_apply_elite_enemy_state_to_nearest() -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	var enemy: Node = host._get_nearest_enemy()
	return enemy != null and host._is_elite_state_debug_enemy(enemy)


func _is_elite_state_debug_enemy(enemy: Node) -> bool:
	var host: CanvasLayer = _host_ref.get_ref() as CanvasLayer
	if enemy == null:
		return false
	var rank: String = String(enemy.get_meta("enemy_rank", "normal"))
	return rank == "elite" or rank == "boss"
