## 文件用途：绘制玩家有效拾取半径以及投射物、区域、环绕技能的目标或命中范围。
## 使用方式：作为 PlayerDebugOverlay 挂到玩家节点，默认隐藏；由调试工具页开启 visible，半径经 SkillStatService 合并角色、技能和遗物修正。
extends Node2D
class_name PlayerDebugOverlay


const RING_SEGMENTS: int = 96
const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")

@export var enabled_in_debug_builds: bool = true
@export var pickup_color: Color = Color(0.25, 0.85, 1.0, 0.75)
@export var targeting_color: Color = Color(1.0, 0.72, 0.2, 0.75)
@export var orbit_color: Color = Color(0.95, 0.28, 0.22, 0.85)
@export var hitbox_color: Color = Color(1.0, 0.18, 0.18, 0.45)

var _player: Node


## 作用：缓存父玩家，默认隐藏，并设定暂停仍处理与高绘制层。
## 使用：由 Godot 在节点入树并完成子节点就绪后调用。
func _ready() -> void:
	_player = get_parent()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1000


## 作用：覆盖层可见时每帧请求重绘，反映实时属性变化。
## 使用：由 Godot 每处理帧调用，delta 参数以秒为单位。 入参：_delta: float。
func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## 作用：有玩家时绘制拾取半径与所有已拥有技能的范围。
## 使用：由 Godot 在 queue_redraw 后的绘制阶段调用，使用节点本地坐标。
func _draw() -> void:
	if _player == null:
		return

	_draw_pickup_radius()
	_draw_skill_ranges()


## 作用：查询有效拾取半径，绘制圆环与 pickup 数值标签。
## 使用：由本节点的绘制、初始化或内部运行流程调用。
func _draw_pickup_radius() -> void:
	var pickup_radius: float = _get_effective_pickup_radius()
	if pickup_radius <= 0.0:
		return

	_draw_ring(Vector2.ZERO, pickup_radius, pickup_color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(pickup_radius + 8.0, -4.0), "pickup %.0f" % pickup_radius, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, pickup_color)


## 作用：遍历 SkillManager 技能实例，按 projectile、orbit、area 标签分派范围绘制。
## 使用：由本节点的绘制、初始化或内部运行流程调用。
func _draw_skill_ranges() -> void:
	var skill_manager: Node = _player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return

	var skill_instances_variant: Variant = skill_manager.call("get_all_skills")
	if not (skill_instances_variant is Array):
		return

	for skill_instance_variant: Variant in skill_instances_variant:
		var skill_instance: RefCounted = skill_instance_variant as RefCounted
		if skill_instance == null:
			continue

		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		if definition == null:
			continue

		var skill_id: String = str(skill_instance.get("skill_id"))
		if _definition_has_tag(definition, "projectile"):
			_draw_projectile_skill_range(skill_instance, skill_id)
		elif _definition_has_tag(definition, "orbit"):
			_draw_orbit_skill_range(skill_instance, skill_id)
		elif _definition_has_tag(definition, "area"):
			_draw_area_skill_range(skill_instance, skill_id)


## 作用：绘制投射物技能目标 range 和额外 area_radius 命中圈，显示技能 ID 与距离。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：skill_instance: RefCounted, skill_id: String。
func _draw_projectile_skill_range(skill_instance: RefCounted, skill_id: String) -> void:
	var target_range: float = _get_skill_float(skill_instance, "range", 0.0)
	if target_range > 0.0:
		_draw_ring(Vector2.ZERO, target_range, targeting_color, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(target_range + 8.0, -18.0), "%s range %.0f" % [skill_id, target_range], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, targeting_color)

	var area_radius: float = _get_skill_float(skill_instance, "area_radius", 0.0)
	if area_radius > 0.0:
		_draw_ring(Vector2.ZERO, area_radius, hitbox_color, 1.0)


## 作用：绘制区域技能 area_radius 圈和范围标签，非正半径不绘制。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：skill_instance: RefCounted, skill_id: String。
func _draw_area_skill_range(skill_instance: RefCounted, skill_id: String) -> void:
	var area_radius: float = _get_skill_float(skill_instance, "area_radius", 0.0)
	if area_radius <= 0.0:
		return

	_draw_ring(Vector2.ZERO, area_radius, hitbox_color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(area_radius + 8.0, 14.0), "%s area %.0f" % [skill_id, area_radius], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, hitbox_color)


## 作用：绘制环绕中心半径和内外命中边缘，展示环绕半径与命中半径。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：skill_instance: RefCounted, skill_id: String。
func _draw_orbit_skill_range(skill_instance: RefCounted, skill_id: String) -> void:
	var orbit_radius: float = _get_skill_float(skill_instance, "orbit_radius", 0.0)
	var area_radius: float = _get_skill_float(skill_instance, "area_radius", 0.0)
	if orbit_radius <= 0.0:
		return

	_draw_ring(Vector2.ZERO, orbit_radius, orbit_color, 2.0)
	if area_radius > 0.0:
		_draw_ring(Vector2.ZERO, maxf(orbit_radius - area_radius, 1.0), hitbox_color, 1.0)
		_draw_ring(Vector2.ZERO, orbit_radius + area_radius, hitbox_color, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(orbit_radius + 8.0, 14.0), "%s orbit %.0f hit %.0f" % [skill_id, orbit_radius, area_radius], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, orbit_color)


## 作用：对正数 radius 绘制以 center 为中心的指定颜色、宽度圆环。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：center: Vector2, radius: float, color: Color, width: float。
func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 0.0:
		return

	draw_arc(center, radius, 0.0, TAU, RING_SEGMENTS, color, width, true)


## 作用：读取节点属性并转 float；字段为空时使用 default_value。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：node: Node, property_name: String, default_value: float。 返回 float；具体值及空输入行为见作用说明。
func _get_node_float(node: Node, property_name: String, default_value: float) -> float:
	var value: Variant = node.get(property_name)
	if value == null:
		return default_value

	return float(value)


## 作用：优先使用玩家有效拾取半径方法，缺少时读原始属性，无玩家返回零。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 返回 float；具体值及空输入行为见作用说明。
func _get_effective_pickup_radius() -> float:
	if _player == null:
		return 0.0
	if _player.has_method("get_effective_pickup_radius"):
		return float(_player.call("get_effective_pickup_radius"))
	return _get_node_float(_player, "pickup_radius", 0.0)


## 作用：调用 SkillStatService 合并技能、管理器、遗物和玩家修正，取得有效数值属性或默认值。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：skill_instance: RefCounted, stat_name: String, default_value: float。 返回 float；具体值及空输入行为见作用说明。
func _get_skill_float(skill_instance: RefCounted, stat_name: String, default_value: float) -> float:
	var skill_manager: Node = _player.get_node_or_null("SkillManager") if _player != null else null
	var relic_manager: Node = _player.get_node_or_null("RelicManager") if _player != null else null
	var value: Variant = SkillStatServiceScript.get_effective_stat(skill_instance, stat_name, default_value, skill_manager, relic_manager, _player)
	if value == null:
		return default_value

	return float(value)


## 作用：通过技能定义 has_tag 接口查询标签，定义为空或缺接口返回 false。
## 使用：由本节点的绘制、初始化或内部运行流程调用。 入参：definition: RefCounted, tag: String。 返回 bool；具体值及空输入行为见作用说明。
func _definition_has_tag(definition: RefCounted, tag: String) -> bool:
	return definition != null and definition.has_method("has_tag") and bool(definition.call("has_tag", tag))
