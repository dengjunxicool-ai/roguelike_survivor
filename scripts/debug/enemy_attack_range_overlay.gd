## 文件用途：显示单个敌人的攻击半径圆环和敌人 ID，供调试工具页检查敌人攻击距离。
## 使用方式：由 DevDebugUtilityPage 挂为敌人子节点，setup(enemy) 后切换 visible；绘制时读取敌人当前 attack_range。
extends Node2D
class_name EnemyAttackRangeOverlay


const RING_SEGMENTS: int = 96

@export var range_color: Color = Color(1.0, 0.28, 0.18, 0.72)

var _enemy: Node2D


## 作用：绑定敌人引用，设置暂停仍处理和高绘制层。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：enemy: Node2D。
func setup(enemy: Node2D) -> void:
	_enemy = enemy
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1000


## 作用：可见时每帧请求重绘，跟随敌人动态攻击范围。
## 使用：由 Godot 每处理帧调用，delta 参数以秒为单位。 入参：_delta: float。
func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## 作用：绘制有效攻击半径圆环与敌人 ID、范围值标签，非正半径不绘制。
## 使用：由 Godot 在 queue_redraw 后的绘制阶段调用，使用节点本地坐标。
func _draw() -> void:
	var attack_range: float = _get_attack_range()
	if attack_range <= 0.0:
		return

	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, RING_SEGMENTS, range_color, 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(attack_range + 8.0, -4.0), "%s atk %.0f" % [_get_enemy_label(), attack_range], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, range_color)


## 作用：从有效敌人读取 attack_range，敌人失效或属性为空返回零。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 返回 float；具体值及空输入行为见作用说明。
func _get_attack_range() -> float:
	if _enemy == null or not is_instance_valid(_enemy):
		return 0.0
	var value: Variant = _enemy.get("attack_range")
	return 0.0 if value == null else float(value)


## 作用：取得有效敌人 enemy_id 作为标签；引用失效时显示 enemy。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 返回 String；具体值及空输入行为见作用说明。
func _get_enemy_label() -> String:
	if _enemy == null or not is_instance_valid(_enemy):
		return "enemy"
	return String(_enemy.get("enemy_id"))
