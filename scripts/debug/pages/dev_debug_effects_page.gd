## 文件用途：构建独立特效调试控件，预览火龙卷与火星飞弹，使用查询回调避免持有玩家敌人。
## 使用方式：实例化后先 setup 传入玩家和最近敌人查询 Callable，再 build；监听 log_requested，并由按钮触发单次或持续预览。
extends VBoxContainer
class_name DevDebugEffectsPage

signal log_requested(level: StringName, message: String)

const FIRE_TORNADO_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/fire_tornado_effect.tscn")
const MARS_SPARK_MISSILE_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/mars_spark_missile_effect.tscn")
const UIButtonSkinScript: Script = preload("res://scripts/ui/ui_button_skin.gd")

var _get_player_callback: Callable
var _get_nearest_enemy_callback: Callable
var _effect_option: OptionButton
var _built: bool = false


## 作用：保存玩家与最近敌人查询回调，供发射预览时解析当前实体。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：get_player: Callable, get_nearest_enemy: Callable。
func setup(get_player: Callable, get_nearest_enemy: Callable) -> void:
	_get_player_callback = get_player
	_get_nearest_enemy_callback = get_nearest_enemy


## 作用：幂等建立特效下拉框和持续、单次发射按钮，再填充选项。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func build() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 7)

	var option_row: HBoxContainer = _add_row()
	var label: Label = Label.new()
	label.text = "Effect"
	label.custom_minimum_size = Vector2(104, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	option_row.add_child(label)
	_effect_option = OptionButton.new()
	_effect_option.custom_minimum_size = Vector2(300, 30)
	_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_row.add_child(_effect_option)

	var actions_row: HBoxContainer = _add_row()
	_add_button(actions_row, "持续发射", Callable(self, "start_continuous_effect"), 116.0)
	_add_button(actions_row, "单次发射", Callable(self, "fire_single_effect"), 116.0)
	populate_options()


## 作用：确保页面已构建，重置火龙卷与火星飞弹下拉选项并选中首项。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func populate_options() -> void:
	if not _built:
		build()
	if _effect_option == null:
		return
	_effect_option.clear()
	_add_option_item("Fire Tornado", "fire_tornado")
	_add_option_item("火星飞弹", "mars_spark_missile")
	_effect_option.select(0)


## 作用：返回特效下拉控件引用，供宿主保留选项入口。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 OptionButton；具体值及空输入行为见作用说明。
func get_effect_option() -> OptionButton:
	return _effect_option


## 作用：用 continuous=true 转交当前选中特效；持续开关由火星飞弹预览消费。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func start_continuous_effect() -> void:
	trigger_selected_effect(true)


## 作用：用 continuous=false 转交当前选中特效，预览一次发射。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func fire_single_effect() -> void:
	trigger_selected_effect(false)


## 作用：按特效 ID 分派火龙卷或火星飞弹预览，空选项发出警告日志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：continuous: bool。
func trigger_selected_effect(continuous: bool) -> void:
	match _get_selected_effect_id():
		&"fire_tornado":
			spawn_fire_tornado_effect()
		&"mars_spark_missile":
			spawn_mars_spark_missile_effect(continuous)
		_:
			_emit_log(&"warning", "No effect selected.")


## 作用：实例化火龙卷场景，加入玩家场景父节点并放到目标方向 96 像素处；缺少父节点时释放实例。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。
func spawn_fire_tornado_effect() -> void:
	var player: Node2D = _resolve_player()
	if player == null:
		_emit_log(&"warning", "Cannot spawn Fire Tornado: player not found.")
		return
	if FIRE_TORNADO_EFFECT_SCENE == null:
		_emit_log(&"error", "Cannot spawn Fire Tornado: scene failed to load.")
		return

	var effect: Node2D = FIRE_TORNADO_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		_emit_log(&"error", "Cannot spawn Fire Tornado: scene root is not Node2D.")
		return

	var parent: Node = _resolve_spawn_parent(player)
	if parent == null:
		effect.queue_free()
		_emit_log(&"error", "Cannot spawn Fire Tornado: no scene parent available.")
		return

	parent.add_child(effect)
	effect.global_position = resolve_fire_tornado_spawn_position(player)
	_emit_log(&"info", "Spawned Fire Tornado VFX.")


## 作用：创建火星飞弹预览，配置起点和目标点以及 continuous 开关，加入场景并输出模式日志。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：continuous: bool。
func spawn_mars_spark_missile_effect(continuous: bool) -> void:
	var player: Node2D = _resolve_player()
	if player == null:
		_emit_log(&"warning", "Cannot spawn Mars Spark Missile: player not found.")
		return
	if MARS_SPARK_MISSILE_EFFECT_SCENE == null:
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: scene failed to load.")
		return

	var effect: Variant = MARS_SPARK_MISSILE_EFFECT_SCENE.instantiate()
	if not (effect is Node2D):
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: scene root is not MarsSparkMissileEffect.")
		return

	var parent: Node = _resolve_spawn_parent(player)
	if parent == null:
		(effect as Node).queue_free()
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: no scene parent available.")
		return

	parent.add_child(effect)
	var origin: Vector2 = resolve_mars_spark_missile_spawn_position(player)
	var target: Vector2 = resolve_mars_spark_missile_target_position(player, origin)
	effect.configure(origin, target, false)
	effect.set_continuous(continuous)
	_emit_log(&"info", "Spawned %s Mars Spark Missile VFX." % ("continuous" if continuous else "single"))


## 作用：返回玩家朝最近敌人方向 96 像素的世界坐标；无敌人使用右方向，无玩家返回零向量。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：player: Node2D。 返回 Vector2；具体值及空输入行为见作用说明。
func resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		var to_enemy: Vector2 = nearest_enemy.global_position - player.global_position
		if to_enemy.length_squared() > 0.0001:
			direction = to_enemy.normalized()
	return player.global_position + direction * 96.0


## 作用：返回玩家朝敌人方向 32 像素的飞弹起点；方向退化时用右方向。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：player: Node2D。 返回 Vector2；具体值及空输入行为见作用说明。
func resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		direction = player.global_position.direction_to(nearest_enemy.global_position)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return player.global_position + direction.normalized() * 32.0


## 作用：优先返回最近敌人世界坐标；无目标时沿发射方向向前延伸 360 像素。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：player: Node2D, origin: Vector2。 返回 Vector2；具体值及空输入行为见作用说明。
func resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		return nearest_enemy.global_position
	var direction: Vector2 = Vector2.RIGHT
	if player != null:
		direction = player.global_position.direction_to(origin)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return origin + direction.normalized() * 360.0


## 作用：创建带间隔的水平布局行，挂入本页并返回引用。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 HBoxContainer；具体值及空输入行为见作用说明。
func _add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	return row


## 作用：创建并应用按钮皮肤，绑定 action 回调后加入 parent，返回 Button。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：parent: HBoxContainer, text: String, action: Callable, width: float。 返回 Button；具体值及空输入行为见作用说明。
func _add_button(parent: HBoxContainer, text: String, action: Callable, width: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 30)
	UIButtonSkinScript.apply(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## 作用：添加下拉选项并用 StringName(id) 保存元数据。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：text: String, id: String。
func _add_option_item(text: String, id: String) -> void:
	var index: int = _effect_option.item_count
	_effect_option.add_item(text)
	_effect_option.set_item_metadata(index, StringName(id))


## 作用：调用玩家查询回调，仅返回存活 Node2D，否则返回 null。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 Node2D；具体值及空输入行为见作用说明。
func _resolve_player() -> Node2D:
	if not _get_player_callback.is_valid():
		return null
	var candidate: Variant = _get_player_callback.call()
	if candidate is Node2D and is_instance_valid(candidate):
		return candidate as Node2D
	return null


## 作用：调用最近敌人查询回调，仅返回存活 Node2D，否则返回 null。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 Node2D；具体值及空输入行为见作用说明。
func _resolve_nearest_enemy() -> Node2D:
	if not _get_nearest_enemy_callback.is_valid():
		return null
	var candidate: Variant = _get_nearest_enemy_callback.call()
	if candidate is Node2D and is_instance_valid(candidate):
		return candidate as Node2D
	return null


## 作用：优先取玩家父节点作为特效容器，否则使用当前场景，均不可用时返回 null。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：player: Node2D。 返回 Node；具体值及空输入行为见作用说明。
func _resolve_spawn_parent(player: Node2D) -> Node:
	if player != null and player.get_parent() != null:
		return player.get_parent()
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return null


## 作用：将选中下拉条目的元数据转为特效 ID；没有选项时返回空 StringName。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 返回 StringName；具体值及空输入行为见作用说明。
func _get_selected_effect_id() -> StringName:
	if _effect_option == null or _effect_option.item_count <= 0:
		return &""
	var selected_index: int = clampi(_effect_option.selected, 0, _effect_option.item_count - 1)
	return StringName(String(_effect_option.get_item_metadata(selected_index)))


## 作用：发射 log_requested(level, message)，将日志交由宿主显示。
## 使用：由 DevDebugPanel 对应页面入口或本页流程调用，宿主须仍有效。 入参：level: StringName, message: String。
func _emit_log(level: StringName, message: String) -> void:
	log_requested.emit(level, message)
