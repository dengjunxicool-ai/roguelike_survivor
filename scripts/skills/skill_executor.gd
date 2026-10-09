## 文件用途：在玩家物理帧构建技能上下文并调度主动技能、事件总线和特殊规则。
## 使用方式：挂在玩家下并装配 SkillManager；物理更新调用组件 runner，调试入口可强制施放指定或全部技能。
extends Node
class_name SkillExecutor


const SkillStatServiceScript: Script = preload("res://scripts/skills/skill_stat_service.gd")
const SkillComponentRunnerScript: Script = preload("res://scripts/skills/skill_component_runner.gd")
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")

@export var skill_manager_path: NodePath = NodePath("../SkillManager")
@export var relic_manager_path: NodePath = NodePath("../RelicManager")
@export var event_bus_path: NodePath = NodePath("../SkillEventBus")
@export var target_group: StringName = &"enemies"

var _skill_manager: Node
var _relic_manager: Node
var _event_bus: Node
var _component_runner: RefCounted = SkillComponentRunnerScript.new()


## 作用：解析导出路径中的技能与遗物管理器，并取得或创建事件总线。
## 使用：挂在玩家下并装配 SkillManager；物理更新调用组件 runner，调试入口可强制施放指定或全部技能。
func _ready() -> void:
	_skill_manager = get_node_or_null(skill_manager_path)
	_relic_manager = get_node_or_null(relic_manager_path)
	_event_bus = _get_or_create_event_bus()


## 作用：包裹技能更新性能采样，将物理帧时长传给实际技能调度。
## 使用：delta 为本帧经过的秒数。
func _physics_process(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_physics_process_profiled(delta)
	HotPathProfilerScript.end(self, &"skill_update_total", hot_path_start)


## 作用：重取缺失管理器、清理环绕缓存，自动攻击允许时逐个 tick 主攻击与主动技能。
## 使用：delta 为本帧经过的秒数。
func _physics_process_profiled(delta: float) -> void:
	if _skill_manager == null:
		_skill_manager = get_node_or_null(skill_manager_path)
	if _skill_manager == null or not _skill_manager.has_method("get_all_skills"):
		return

	_cleanup_stale_orbit_objects()
	if _is_debug_control_mode() or _is_debug_player_attack_disabled():
		return

	var skills: Array = _skill_manager.call("get_active_skills") if _skill_manager.has_method("get_active_skills") else _skill_manager.call("get_all_skills")
	for skill_instance_variant: Variant in skills:
		var skill_instance: RefCounted = skill_instance_variant as RefCounted
		if skill_instance == null:
			continue

		_component_runner.call("tick", skill_instance, delta, _build_skill_context(skill_instance))


## 作用：在调试模式下尝试强制施放所有主动技能并汇总结果。
## 使用：挂在玩家下并装配 SkillManager；物理更新调用组件 runner，调试入口可强制施放指定或全部技能。
func debug_cast_all_skills(debug_attack_trace_id: int = 0) -> int:
	if _skill_manager == null:
		_skill_manager = get_node_or_null(skill_manager_path)
	if _skill_manager == null or not _skill_manager.has_method("get_all_skills"):
		return 0

	_cleanup_stale_orbit_objects()
	_advance_debug_attack_nonce()
	var cast_count: int = 0
	var skills: Array = _skill_manager.call("get_active_skills") if _skill_manager.has_method("get_active_skills") else _skill_manager.call("get_all_skills")
	for skill_instance_variant: Variant in skills:
		var skill_instance: RefCounted = skill_instance_variant as RefCounted
		if skill_instance == null:
			continue

		skill_instance.set("cooldown_remaining", 0.0)
		if bool(_component_runner.call("tick", skill_instance, 999.0, _build_skill_context(skill_instance, debug_attack_trace_id))):
			_allow_debug_orbit_pulse(skill_instance)
			cast_count += 1

	return cast_count


## 作用：按技能 ID 强制调试施放，重建上下文并保留追踪信息。
## 使用：skill_id 为标准技能 ID。
func debug_cast_skill(skill_id: Variant, debug_attack_trace_id: int = 0) -> int:
	if _skill_manager == null:
		_skill_manager = get_node_or_null(skill_manager_path)
	if _skill_manager == null or not _skill_manager.has_method("get_skill"):
		return 0

	var id: StringName = StringName(String(skill_id))
	var skill_instance: RefCounted = _skill_manager.call("get_skill", id) as RefCounted
	if skill_instance == null:
		return 0

	_cleanup_stale_orbit_objects()
	_advance_debug_attack_nonce()
	skill_instance.set("cooldown_remaining", 0.0)
	if bool(_component_runner.call("tick", skill_instance, 999.0, _build_skill_context(skill_instance, debug_attack_trace_id))):
		_allow_debug_orbit_pulse(skill_instance)
		return 1
	return 0


## 作用：为技能施放组装施法者、管理器、事件总线、目标组与对象父节点。
## 使用：skill_instance 为技能运行实例。
func _build_skill_context(skill_instance: RefCounted, debug_attack_trace_id: int = 0) -> Dictionary:
	var caster: Node2D = _get_caster()
	return {
		"caster": caster,
		"owner": caster,
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")),
		"source_origin_id": _get_source_origin_id(caster),
		"skill_manager": _skill_manager,
		"relic_manager": _relic_manager,
		"event_bus": _event_bus,
		"parent": _get_object_parent(),
		"target_group": target_group,
		"damage_type": _get_damage_type(skill_instance),
		"debug_attack_trace_id": debug_attack_trace_id
	}


## 作用：查找玩家技能总线，缺失时创建并挂载。
## 使用：由本文件 _ready 调用；无法解析或创建时返回 null。
func _get_or_create_event_bus() -> Node:
	var event_bus: Node = get_node_or_null(event_bus_path)
	if event_bus != null:
		return event_bus

	var caster: Node = get_parent()
	if caster == null:
		return null

	event_bus = SkillEventBusScript.new()
	event_bus.name = "SkillEventBus"
	caster.add_child(event_bus)
	return event_bus


## 作用：取得技能执行器父节点作为施法者。
## 使用：由本文件 _build_skill_context/_get_object_parent 调用。
func _get_caster() -> Node2D:
	return get_parent() as Node2D


## 作用：从角色或技能上下文解析伤害统计使用的稳定来源 ID。
## 使用：caster 为施法者节点。
func _get_source_origin_id(caster: Node) -> StringName:
	if caster == null:
		return &""
	var character_id: Variant = caster.get("selected_character_id")
	return StringName(String(character_id)) if character_id != null else &""


## 作用：确定生成战斗对象所挂载的场景父节点。
## 使用：由本文件 _build_skill_context/_cleanup_stale_orbit_objects 调用。
func _get_object_parent() -> Node:
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene

	var caster: Node2D = _get_caster()
	if caster != null and caster.get_parent() != null:
		return caster.get_parent()

	return self


## 作用：确定动作伤害分类，优先配置并按来源语义推断缺省类型。
## 使用：skill_instance 为技能运行实例。
func _get_damage_type(skill_instance: RefCounted) -> StringName:
	return SkillStatServiceScript.get_damage_type(skill_instance)


## 作用：从上下文读取并筛出当前仍有效的环绕对象引用。
## 使用：parent 为生成对象父节点；caster 为施法者节点；skill_id 为标准技能 ID。
func _get_orbit_objects(parent: Node, caster: Node2D, skill_id: StringName) -> Array[Node2D]:
	var objects: Array[Node2D] = []
	if parent == null or caster == null:
		return objects

	for child: Node in parent.get_children():
		var orbit_object: Node2D = child as Node2D
		if orbit_object == null or not orbit_object.has_meta("skill_id") or not orbit_object.has_meta("owner_instance_id"):
			continue
		if StringName(String(orbit_object.get_meta("skill_id"))) != skill_id:
			continue
		if int(orbit_object.get_meta("owner_instance_id")) != int(caster.get_instance_id()):
			continue

		objects.append(orbit_object)

	return objects


## 作用：从缓存中移除失效或等待释放的环绕对象。
## 使用：可能回收匹配节点。
func _cleanup_stale_orbit_objects() -> void:
	var caster: Node2D = _get_caster()
	var parent: Node = _get_object_parent()
	if caster == null or parent == null or _skill_manager == null or not _skill_manager.has_method("get_all_skills"):
		return

	var active_skill_ids: Dictionary = {}
	var active_skills: Array = _skill_manager.call("get_active_skills") if _skill_manager.has_method("get_active_skills") else _skill_manager.call("get_all_skills")
	for skill_instance_variant: Variant in active_skills:
		var skill_instance: RefCounted = skill_instance_variant as RefCounted
		if skill_instance != null:
			active_skill_ids[StringName(skill_instance.get("skill_id"))] = true

	for child: Node in parent.get_children():
		if not child.has_meta("skill_id") or not child.has_meta("owner_instance_id"):
			continue
		if int(child.get_meta("owner_instance_id")) != int(caster.get_instance_id()):
			continue

		var object_skill_id: StringName = StringName(String(child.get_meta("skill_id")))
		if not active_skill_ids.has(object_skill_id):
			child.queue_free()


## 作用：查询是否启用调试手动控制模式。
## 使用：由本文件 _physics_process_profiled 调用。
func _is_debug_control_mode() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_control_mode", false))


## 作用：查询调试设置是否禁止玩家自动攻击。
## 使用：由本文件 _physics_process_profiled 调用。
func _is_debug_player_attack_disabled() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.root != null and bool(tree.root.get_meta("debug_player_attack_disabled", false))


## 作用：推进调试攻击序号，给独立测试施放分配追踪身份。
## 使用：写入 debug_player_attack_nonce 元数据。
func _advance_debug_attack_nonce() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("debug_player_attack_nonce", int(tree.root.get_meta("debug_player_attack_nonce", 0)) + 1)


## 作用：按调试策略判断是否允许环绕对象产生本次脉冲。
## 使用：skill_instance 为技能运行实例。
func _allow_debug_orbit_pulse(skill_instance: RefCounted) -> void:
	var caster: Node2D = _get_caster()
	var parent: Node = _get_object_parent()
	if caster == null or parent == null or skill_instance == null:
		return

	var skill_id: StringName = StringName(String(skill_instance.get("skill_id")))
	for orbit_object: Node2D in _get_orbit_objects(parent, caster, skill_id):
		if orbit_object != null and orbit_object.has_method("debug_allow_current_nonce"):
			orbit_object.call("debug_allow_current_nonce")
