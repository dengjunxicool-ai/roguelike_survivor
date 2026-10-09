## 文件用途：绘制调试爆炸或状态伤害位置的圆环与标签，加入统一清理组。
## 使用方式：由 DebugCombatTrace 实例化并挂入战斗场景；调用 setup 指定半径和文本，通过 debug_explosion_site_overlays 组清理。
extends Node2D
class_name DebugExplosionSiteOverlay


const RING_SEGMENTS: int = 96

@export var radius: float = 1.0
@export var label_text: String = ""
@export var ring_color: Color = Color(1.0, 0.46, 0.08, 0.82)


## 作用：设为暂停时仍处理的高层节点，登记覆盖层组并请求首次重绘。
## 使用：由 Godot 在节点入树并完成子节点就绪后调用。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1200
	add_to_group(&"debug_explosion_site_overlays")
	queue_redraw()


## 作用：把半径约束到至少一像素，保存标签文本并请求重绘。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：new_radius: float, new_label_text: String = ""。
func setup(new_radius: float, new_label_text: String = "") -> void:
	radius = maxf(new_radius, 1.0)
	label_text = new_label_text
	queue_redraw()


## 作用：绘制设定颜色、半径的圆弧和非空标签，供爆炸位置诊断。
## 使用：由 Godot 在 queue_redraw 后的绘制阶段调用，使用节点本地坐标。
func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_SEGMENTS, ring_color, 2.5, true)
	if label_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(radius + 8.0, 4.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, ring_color)
