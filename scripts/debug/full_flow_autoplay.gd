## 文件用途：装配真实 App 启动流程并自动驱动法师在废弃地牢战斗九十秒，记录状态后短暂停留退出。
## 使用方式：由 scenes/app/full_flow_autoplay.tscn 挂载并运行；通过 UIManager 完成标题、角色和地图入口，使用 Input 模拟移动，结束后保持八秒。
extends Node


const PLAY_SECONDS: float = 90.0
const POST_FINISH_HOLD_SECONDS: float = 8.0
const CHARACTER_ID: StringName = &"mage"
const MAP_ID: StringName = &"abandoned_dungeon"
const MAP_NAME: String = "废弃地牢"

var _main_scene: Node
var _ui: Node
var _player: Node2D
var _elapsed: float = 0.0
var _next_log_time: float = 0.0
var _movement_phase: float = 0.0
var _finished: bool = false


## 作用：实例化 app_bootstrap 场景，定位 UIManager 并完成菜单流程，取得玩家后打印开局状态；缺场景或玩家退出失败。
## 使用：由 Godot 在节点入树并完成子节点就绪后调用。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var packed_scene: PackedScene = load("res://scenes/app/app_bootstrap.tscn") as PackedScene
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
	print("[FullFlowAutoplay] combat_started state=%s character=%s map=%s" % [
		String(_ui.get("current_state")),
		String(CHARACTER_ID),
		MAP_NAME
	])
	_log_status(0.0)


## 作用：按 UI 状态累计战斗时间、驱动移动和定时日志，升级或诅咒时选择选项，终局或达到时限后结束。
## 使用：由 Godot 每处理帧调用，delta 参数以秒为单位。 入参：delta: float。
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
	elif state == "LEVEL_UP_MODAL" or state == "CURSE_CHOICE_MODAL":
		_release_all_movement()
		call_deferred("_choose_first_modal_option", state)
	elif state == "RESULT_DEFEAT" or state == "RESULT_VICTORY":
		_log_status(_elapsed)
		print("[FullFlowAutoplay] ended_early state=%s elapsed=%.1f" % [state, _elapsed])
		_finish(0)


## 作用：依次调用标题、角色选择、法师 loadout 确认与地图开局入口，等待处理和物理帧完成装配。
## 使用：由自动开局与战斗驱动流程调用。 直接调用时须 await 等待异步流程完成。
func _run_menu_flow() -> void:
	await get_tree().process_frame
	_ui.call("transition_to", "TITLE")
	await get_tree().process_frame
	print("[FullFlowAutoplay] reached_title state=%s" % String(_ui.get("current_state")))

	_ui.call("transition_to", "CHARACTER_SELECT")
	await get_tree().process_frame
	print("[FullFlowAutoplay] reached_character_select state=%s" % String(_ui.get("current_state")))

	_ui.call("_on_loadout_confirmed", CHARACTER_ID)
	await get_tree().process_frame
	print("[FullFlowAutoplay] confirmed_loadout state=%s" % String(_ui.get("current_state")))

	_ui.call("_start_run", MAP_ID)
	await get_tree().process_frame
	await get_tree().physics_frame


## 作用：累积移动相位，释放上一帧移动并按生存方向按下四方向输入，无方向时用旋转轨迹。
## 使用：由自动开局与战斗驱动流程调用。 入参：delta: float。
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


## 作用：合成敌人排斥、经验吸引、攻击间距与切向移动，返回归一化生存方向。
## 使用：由自动开局与战斗驱动流程调用。 返回 Vector2；具体值及空输入行为见作用说明。
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
	var attack_spacing: Vector2 = Vector2.ZERO
	if nearest_enemy != null:
		var to_enemy: Vector2 = nearest_enemy.global_position - _player.global_position
		var away_from_enemy: Vector2 = -to_enemy.normalized()
		var tangent: Vector2 = away_from_enemy.orthogonal()
		if nearest_enemy_distance < 48.0:
			attack_spacing = away_from_enemy * 3.0 + tangent * 0.8
		elif nearest_enemy_distance > 88.0 and nearest_enemy_distance < 240.0:
			attack_spacing = to_enemy.normalized() * 1.35 + tangent * 0.7
		else:
			attack_spacing = tangent * 1.4

	var desired: Vector2 = attack_spacing * 1.7 + repulsion * 1.2 + attraction * 0.8 + orbit_direction * 0.15
	if nearest_enemy_distance < 38.0:
		desired += repulsion * 2.0

	return desired.normalized() if desired != Vector2.ZERO else Vector2.ZERO


## 作用：仅在 UI 仍为指定弹窗状态时点击首个启用按钮，无选择则退回 RUNNING。
## 使用：由自动开局与战斗驱动流程调用。 入参：state: String。
func _choose_first_modal_option(state: String) -> void:
	if _ui == null or String(_ui.get("current_state")) != state:
		return

	var state_to_container: Dictionary = {
		"LEVEL_UP_MODAL": "_level_up_options",
		"CURSE_CHOICE_MODAL": "_curse_options"
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
		var buttons: Array[Button] = _collect_enabled_buttons(container)
		if not buttons.is_empty():
			var button: Button = buttons[0]
			print("[FullFlowAutoplay] choose_modal state=%s options=%d text=%s" % [state, buttons.size(), _describe_button(button)])
			button.emit_signal("pressed")
			return

	print("[FullFlowAutoplay] modal_no_choice state=%s, returning_to_running" % state)
	_ui.call("transition_to", "RUNNING")


## 作用：递归收集 root 下所有未禁用 Button，保持节点遍历顺序。
## 使用：由自动开局与战斗驱动流程调用。 入参：root: Node。 返回 Array[Button]；具体值及空输入行为见作用说明。
func _collect_enabled_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root == null:
		return buttons
	if root is Button and not (root as Button).disabled:
		buttons.append(root as Button)
	for child: Node in root.get_children():
		buttons.append_array(_collect_enabled_buttons(child))
	return buttons


## 作用：取得按钮直接文本或后代 Label 文本，用竖线分隔多行供日志展示。
## 使用：由自动开局与战斗驱动流程调用。 入参：button: Button。 返回 String；具体值及空输入行为见作用说明。
func _describe_button(button: Button) -> String:
	var direct_text: String = button.text.strip_edges()
	if direct_text != "":
		return direct_text.replace("\n", " | ")
	var labels: Array[String] = []
	_collect_label_text(button, labels)
	return " | ".join(labels)


## 作用：递归收集非空 Label 文本到 labels，换行替换成日志分隔符。
## 使用：由自动开局与战斗驱动流程调用。 入参：root: Node, labels: Array[String]。
func _collect_label_text(root: Node, labels: Array[String]) -> void:
	for child: Node in root.get_children():
		if child is Label:
			var label_text: String = (child as Label).text.strip_edges()
			if label_text != "":
				labels.append(label_text.replace("\n", " | "))
		_collect_label_text(child, labels)


## 作用：打印指定时间点的 UI 状态、玩家血量成长、击杀和场景实体数量。
## 使用：由自动开局与战斗驱动流程调用。 入参：time_value: float。
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
	var orbit_count: int = _count_player_orbit_objects(player)
	print("[FullFlowAutoplay] t=%.1f state=%s hp=%d/%d level=%d exp=%d/%d kills=%d enemies=%d enemy_projectiles=%d orbit_objects=%d" % [
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
		orbit_count
	])


## 作用：统计当前场景直属子节点中 owner_instance_id 匹配玩家的节点数量。
## 使用：由自动开局与战斗驱动流程调用。 入参：player: Node。 返回 int；具体值及空输入行为见作用说明。
func _count_player_orbit_objects(player: Node) -> int:
	if player == null or get_tree().current_scene == null:
		return 0

	var count: int = 0
	var owner_id: int = int(player.get_instance_id())
	for child: Node in get_tree().current_scene.get_children():
		if child.has_meta("owner_instance_id") and int(child.get_meta("owner_instance_id")) == owner_id:
			count += 1
	return count


## 作用：设置结束标记、释放输入并输出最后状态，等待八秒定时器后以 exit_code 退出。
## 使用：从自动流程 await 调用，传入退出码；释放模拟移动，等待 POST_FINISH_HOLD_SECONDS 后终止进程。
func _finish(exit_code: int) -> void:
	_finished = true
	_release_all_movement()
	_log_status(_elapsed)
	print("[FullFlowAutoplay] finished elapsed=%.1f" % _elapsed)
	await get_tree().create_timer(POST_FINISH_HOLD_SECONDS).timeout
	get_tree().quit(exit_code)


## 作用：释放四方向移动 Input 动作，避免自动流程结束后保持按键。
## 使用：由自动开局与战斗驱动流程调用。
func _release_all_movement() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
