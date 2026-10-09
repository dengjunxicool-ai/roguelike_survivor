## 文件用途：执行区域、爆炸、陷阱、环绕物、击退、牵引和区域转换类动作。
## 使用方式：由动作分派器调用；依共享上下文构建伤害包与工厂参数，维护活动区域上限、合并和元数据。
extends "res://scripts/skills/skill_action_support.gd"
class_name SkillActionAreaExecutor


## 作用：同步查询范围内目标并执行命中动作，返回本次命中集合，同时安排瞬时范围表现。
## 使用：params 读取 area_id/object_id/radius/area_radius；context 携带 target/target_group/skill_id；返回布尔判断或执行是否成功。
func _instant_area_hit(params: Dictionary, context: Dictionary) -> bool:
	context = _context_with_resolved_target(params, context)
	var target: Node = context.get("target") as Node
	if target == null:
		return false

	var parent: Node = _get_parent_node(context)
	var position: Vector2 = _resolve_position(params, context)
	var area_source_id: StringName = StringName(str(params.get("area_id", params.get("object_id", ""))))
	var radius: float = maxf(float(params.get("radius", params.get("area_radius", 48.0))), 1.0)
	var actions_on_apply: Array = _get_array(params.get("actions_on_apply", []))
	if actions_on_apply.is_empty():
		return false

	var targets: Array[Node] = [target]
	if bool(params.get("hit_all_targets", false)):
		targets = []
		var target_group: StringName = StringName(str(params.get("target_group", context.get("target_group", &"enemies"))))
		for candidate: Node2D in _find_targets_around(position, radius, target_group, null):
			targets.append(candidate)
	for hit_target: Node in targets:
		var target_context: Dictionary = context.duplicate(true)
		target_context["target"] = hit_target
		target_context["enemy"] = hit_target
		target_context["position"] = position
		target_context["source_id"] = area_source_id
		target_context["source_skill_id"] = StringName(str(context.get("skill_id", "")))
		execute_actions(actions_on_apply, target_context)
	_play_instant_area_hit_visual(parent, position, radius, params, area_source_id, context)
	return true


## 作用：根据配置创建或复用瞬时范围命中的视觉对象。
## 使用：parent 为生成对象父节点；position 为生成世界坐标；radius 为世界坐标半径；写入 source_id/source_skill_id 元数据。
func _play_instant_area_hit_visual(parent: Node, position: Vector2, radius: float, params: Dictionary, area_source_id: StringName, context: Dictionary) -> void:
	if parent == null:
		return
	var pool: Node = RuntimePoolRegistryScript.get_or_create(parent)
	if pool == null or not pool.has_method("spawn"):
		return
	var key: StringName = StringName("instant_area_hit_visual:%s" % String(area_source_id))
	var visual: Node2D = pool.call("spawn", key, Callable(self, "_create_instant_area_hit_visual"), parent) as Node2D
	if visual == null:
		return
	visual.global_position = position
	visual.set_meta("source_id", area_source_id)
	visual.set_meta("source_skill_id", StringName(str(context.get("skill_id", ""))))
	var visual_params: Dictionary = _instant_area_hit_visual_params(params, area_source_id, radius)
	if visual.has_method("setup"):
		visual.call("setup", visual_params)


## 作用：实例化瞬时范围表现节点并挂到指定父节点。
## 使用：由动作分派器调用；依共享上下文构建伤害包与工厂参数，维护活动区域上限、合并和元数据。
func _create_instant_area_hit_visual() -> Node:
	return InstantAreaHitVisualScript.new()


## 作用：构建瞬时范围表现使用的几何、颜色、位置与持续参数。
## 使用：params 为动作或状态参数；radius 为世界坐标半径。
func _instant_area_hit_visual_params(params: Dictionary, area_source_id: StringName, radius: float) -> Dictionary:
	return SkillActionAreaBuilderScript.build_instant_hit_visual_params(
		params,
		_get_combat_object_definition(area_source_id),
		radius
	)


## 作用：通过 GameData 查询指定战斗对象配置。
## 使用：由本文件 _instant_area_hit_visual_params 调用；无适用数据时返回空字典。
func _get_combat_object_definition(object_id: StringName) -> Dictionary:
	if object_id == &"":
		return {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	var data_manager: Node = tree.root.get_node_or_null("DataManager")
	if data_manager == null or not data_manager.has_method("get_combat_object_definition"):
		return {}
	var value: Variant = data_manager.call("get_combat_object_definition", object_id)
	return value.duplicate(true) if value is Dictionary else {}


## 作用：构造区域或爆炸伤害、几何与 tick 参数，处理油区合并及活动上限后创建对象。
## 使用：params 为动作或状态参数；context 为施放或命中上下文。
func _spawn_area(params: Dictionary, context: Dictionary, source_type: String = "area") -> bool:
	if String(params.get("position_mode", "")) != "event":
		context = _context_with_resolved_target(params, context)
	var parent: Node = _get_parent_node(context)
	var position: Vector2 = _resolve_position(params, context)
	var area_params: Dictionary = params.duplicate(true)
	var area_source_id: StringName = StringName(str(area_params.get("area_id", area_params.get("object_id", ""))))
	var special_rules: Dictionary = _get_runtime_special_rules(context)
	var radius: float = _prepare_area_radius_and_geometry_params(area_source_id, area_params, params, context, source_type, special_rules)
	var holy_field_capacity: Dictionary = {}
	if area_source_id == &"holy_field_area" and special_rules.has("cross_relic_field_capacity"):
		holy_field_capacity = _get_dictionary(special_rules.get("cross_relic_field_capacity", {}))
	var damage: int = _resolve_area_damage(area_source_id, params, context, source_type, special_rules, holy_field_capacity)

	var statuses_on_hit: Array[StringName] = _get_statuses_on_hit(params, context)
	var max_targets: int = _resolve_area_max_targets(area_source_id, area_params, context, source_type, special_rules)
	var max_active: int = _resolve_area_max_active(area_source_id, area_params, context, source_type, special_rules, holy_field_capacity)
	var debug_trace_id: int = _get_debug_attack_trace_id(context)
	var damage_packet: Dictionary = _prepare_area_damage_packet(area_params, context, source_type, area_source_id, damage)
	if max_active > 0:
		_enforce_max_active_areas(parent, source_type, area_source_id, max_active)

	var duration: float = _resolve_area_duration(area_source_id, area_params, context, special_rules)
	if _try_merge_fire_oil_area(area_source_id, special_rules, parent, position, radius, duration, damage):
		return true

	var area_effect_params: Dictionary = _build_area_effect_spawn_params(
		area_params,
		context,
		source_type,
		parent,
		area_source_id,
		position,
		damage,
		damage_packet,
		duration,
		radius,
		max_targets,
		statuses_on_hit,
		special_rules
	)
	var area_effect: Node2D = CombatObjectFactoryScript.create_area_effect(area_effect_params)
	if area_effect != null:
		_register_area_effect_runtime_metadata(area_effect, area_source_id, area_params, source_type, radius)
	if area_effect != null and source_type == "explosion":
		_record_area_explosion_trace(parent, position, radius, area_params, context, debug_trace_id, damage_packet)
		if debug_trace_id > 0 and area_effect.has_method("apply_immediate_tick_once"):
			area_effect.call("apply_immediate_tick_once")
	return area_effect != null


## 作用：构建区域来源伤害包并补充对象类型与规则数值。
## 使用：context 为施放或命中上下文；会原地更新 area_params.source_instance_id。
func _prepare_area_damage_packet(area_params: Dictionary, context: Dictionary, source_type: String, area_source_id: StringName, damage: int) -> Dictionary:
	if not area_params.has("source_instance_id"):
		var cast_instance_id: String = _cast_instance_id_for_area(context)
		area_params["source_instance_id"] = DamageSourceIdentityScript.for_area(cast_instance_id, source_type, area_source_id)
	return _build_damage_packet(area_params, context, damage, source_type)


## 作用：识别可合并的火油区域并尝试把新效果并入既有区域。
## 使用：parent 为生成对象父节点；position 为生成世界坐标；radius 为世界坐标半径；返回布尔判断或执行是否成功。
func _try_merge_fire_oil_area(area_source_id: StringName, special_rules: Dictionary, parent: Node, position: Vector2, radius: float, duration: float, damage: int) -> bool:
	if area_source_id != &"fire_oil_area" or not special_rules.has("fire_oil_merge_zones"):
		return false
	var fire_oil_merge: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_zones", {}))
	return bool(fire_oil_merge.get("enabled", false)) and _merge_existing_fire_oil_area(parent, position, radius, duration, damage, fire_oil_merge)


## 作用：为区域或爆炸生成记录技能攻击追踪信息。
## 使用：parent 为生成对象父节点；position 为生成世界坐标；radius 为世界坐标半径。
func _record_area_explosion_trace(parent: Node, position: Vector2, radius: float, area_params: Dictionary, context: Dictionary, debug_trace_id: int, damage_packet: Dictionary) -> void:
	DebugCombatTraceScript.record_explosion(
		_get_root_node(),
		parent,
		position,
		radius,
		str(context.get("skill_id", area_params.get("source_id", ""))),
		str(area_params.get("source_instance_id", "")),
		debug_trace_id,
		damage_packet
	)


## 作用：把技能、来源、类型与后续事件所需信息写入区域运行元数据。
## 使用：radius 为世界坐标半径；写入 source_type/source_id/source_instance_id 元数据。
func _register_area_effect_runtime_metadata(area_effect: Node2D, area_source_id: StringName, area_params: Dictionary, source_type: String, radius: float) -> void:
	area_effect.set_meta("source_type", source_type)
	area_effect.set_meta("source_id", area_source_id)
	area_effect.set_meta("source_instance_id", str(area_params.get("source_instance_id", "")))
	area_effect.add_to_group(&"areas")
	area_effect.add_to_group(&"area_effects")
	if source_type == "trap":
		area_effect.add_to_group(&"traps")
	if area_source_id == &"holy_field_area":
		area_effect.set_meta("cross_relic_field", true)
	if area_source_id == &"poison_cloud_area":
		area_effect.set_meta("toxic_vial_poison_cloud", true)
		area_effect.set_meta("toxic_vial_poison_cloud_radius", radius)
	if area_source_id == &"fire_oil_area":
		area_effect.set_meta("fire_oil_area", true)
		area_effect.set_meta("fire_oil_radius", radius)
	if area_source_id == &"acid_spray_cone_area":
		area_effect.set_meta("acid_spray_cone_area", true)
		area_effect.set_meta("acid_spray_radius", radius)
	if area_source_id == &"smoke_cloud_area":
		area_effect.set_meta("fire_oil_smoke_cloud", true)
		area_effect.set_meta("fire_oil_smoke_radius", radius)


## 作用：解析区域范围成长、形状、扇形方向与移动几何参数。
## 使用：params 读取 radius/collision_radius；context 为施放或命中上下文；会原地更新 area_params.max_targets/boss_damage_multiplier_add/cone_width_degrees。
func _prepare_area_radius_and_geometry_params(area_source_id: StringName, area_params: Dictionary, params: Dictionary, context: Dictionary, source_type: String, special_rules: Dictionary) -> float:
	var radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("radius", params.get("collision_radius", 48.0)))), 1.0)
	if source_type == "explosion":
		radius = maxf(float(ModifierResolverScript.resolve_value(context, "explosion_radius", radius)), 1.0)
	if source_type == "trap":
		if special_rules.has("trap_radius_upgrade"):
			var trap_radius_rule: Dictionary = _get_dictionary(special_rules.get("trap_radius_upgrade", {}))
			radius *= maxf(1.0 + float(trap_radius_rule.get("radius_multiplier_add", 0.0)), 0.05)
	var storm_rule: Dictionary = _get_storm_hail_rule_for_context(context)
	if not storm_rule.is_empty():
		radius *= maxf(1.0 + float(storm_rule.get("area_radius_multiplier_add", 0.0)), 0.05)
		area_params["max_targets"] = int(area_params.get("max_targets", 0)) + int(storm_rule.get("max_targets_add", 0))
		area_params["boss_damage_multiplier_add"] = float(area_params.get("boss_damage_multiplier_add", 0.0)) + float(storm_rule.get("boss_damage_multiplier", 0.8)) - 1.0
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_upgrade"):
		var fire_oil_upgrade: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_upgrade", {}))
		radius *= maxf(1.0 + float(fire_oil_upgrade.get("radius_multiplier_add", 0.0)), 0.05)
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_range_width"):
		var acid_range_rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_range_width", {}))
		radius += float(acid_range_rule.get("range_add", 0.0))
		area_params["cone_width_degrees"] = float(area_params.get("cone_width_degrees", 70.0)) + float(acid_range_rule.get("cone_width_degrees_add", 0.0))
	return radius


## 作用：从动作和技能属性中取得区域伤害，并应用配置缩放。
## 使用：params 读取 damage_multiplier/damage；context 为施放或命中上下文。
func _resolve_area_damage(area_source_id: StringName, params: Dictionary, context: Dictionary, source_type: String, special_rules: Dictionary, holy_field_capacity: Dictionary) -> int:
	var damage_multiplier: float = float(params.get("damage_multiplier", 1.0))
	if not holy_field_capacity.is_empty():
		damage_multiplier *= maxf(1.0 + float(holy_field_capacity.get("field_damage_multiplier_add", 0.0)), 0.0)
	var damage: int = maxi(roundi(float(ModifierResolverScript.get_stat(context, "damage", 0)) * damage_multiplier), 0)
	if params.has("damage"):
		damage = maxi(roundi(_resolve_scaled_amount(params["damage"], context, "damage")), 0)
		if not holy_field_capacity.is_empty():
			damage = maxi(roundi(float(damage) * maxf(1.0 + float(holy_field_capacity.get("field_damage_multiplier_add", 0.0)), 0.0)), 0)
		if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_upgrade"):
			var fire_oil_damage_upgrade: Dictionary = _get_dictionary(special_rules.get("fire_oil_merge_upgrade", {}))
			damage = maxi(roundi(float(damage) * maxf(1.0 + float(fire_oil_damage_upgrade.get("tick_damage_multiplier_add", 0.0)), 0.0)), 0)
		if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_duration_damage"):
			var acid_damage_rule: Dictionary = _get_dictionary(special_rules.get("acid_pressure_duration_damage", {}))
			damage = maxi(roundi(float(damage) * maxf(1.0 + float(acid_damage_rule.get("tick_damage_multiplier_add", 0.0)), 0.0)), 0)
	if source_type == "explosion":
		damage = maxi(roundi(float(ModifierResolverScript.resolve_value(context, "explosion_damage", damage))), 0)
	return damage


## 作用：解析区域每次命中的目标数量上限。
## 使用：context 携带 skill_instance；写入 acid_pressure_next_cast 元数据。
func _resolve_area_max_targets(area_source_id: StringName, area_params: Dictionary, context: Dictionary, source_type: String, special_rules: Dictionary) -> int:
	var max_targets_stat: String = "%s_max_targets" % source_type
	var max_targets: int = maxi(int(ModifierResolverScript.resolve_value(context, max_targets_stat, area_params.get("max_targets", 0))), 0)
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if area_source_id == &"acid_spray_cone_area" and skill_instance != null and bool(skill_instance.get_meta("acid_pressure_next_cast", false)):
		max_targets = maxi(max_targets, int(_get_dictionary(special_rules.get("acid_pressure_every_n_casts", {})).get("max_targets", 8)))
		skill_instance.set_meta("acid_pressure_next_cast", false)
	return max_targets


## 作用：解析同类技能区域的活动数量上限。
## 使用：context 为施放或命中上下文。
func _resolve_area_max_active(area_source_id: StringName, area_params: Dictionary, context: Dictionary, source_type: String, special_rules: Dictionary, holy_field_capacity: Dictionary) -> int:
	if source_type == "trap":
		return maxi(int(ModifierResolverScript.resolve_value(context, "max_active_traps", area_params.get("max_active", 0))), 0)
	if area_source_id == &"holy_field_area":
		return maxi(int(ModifierResolverScript.resolve_value(context, "max_active_fields", area_params.get("max_active", 0))) + int(holy_field_capacity.get("max_active_add", 0)), 0)
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_merge_zones"):
		return maxi(int(_get_dictionary(special_rules.get("fire_oil_merge_zones", {})).get("max_active", area_params.get("max_active", 0))), 0)
	return maxi(int(area_params.get("max_active", 0)), 0)


## 作用：通过技能成长和属性修饰求得区域存续秒数。
## 使用：context 为施放或命中上下文。
func _resolve_area_duration(area_source_id: StringName, area_params: Dictionary, context: Dictionary, special_rules: Dictionary) -> float:
	var duration: float = maxf(float(ModifierResolverScript.resolve_value(context, "duration", area_params.get("duration", 0.12))), 0.05)
	if area_source_id == &"fire_oil_area" and special_rules.has("fire_oil_duration_tuning"):
		duration += float(_get_dictionary(special_rules.get("fire_oil_duration_tuning", {})).get("duration_add", 0.0))
	if area_source_id == &"acid_spray_cone_area" and special_rules.has("acid_pressure_duration_damage"):
		duration += float(_get_dictionary(special_rules.get("acid_pressure_duration_damage", {})).get("duration_add", 0.0))
	return duration


## 作用：把已解析的运行数值委托区域构建器生成工厂参数。
## 使用：context 为施放或命中上下文；parent 为生成对象父节点；position 为生成世界坐标。
func _build_area_effect_spawn_params(area_params: Dictionary, context: Dictionary, source_type: String, parent: Node, area_source_id: StringName, position: Vector2, damage: int, damage_packet: Dictionary, duration: float, radius: float, max_targets: int, statuses_on_hit: Array[StringName], special_rules: Dictionary) -> Dictionary:
	return SkillActionAreaBuilderScript.build_effect_spawn_params({
		"area_params": area_params,
		"context": context,
		"parent": parent,
		"area_source_id": area_source_id,
		"position": position,
		"damage": damage,
		"damage_type": _get_damage_type(area_params, context, source_type, _get_damage_origin(area_params, context, source_type)),
		"damage_packet": damage_packet,
		"duration": duration,
		"tick_interval": _resolve_area_tick_interval(area_source_id, area_params, special_rules),
		"radius": radius,
		"max_targets": max_targets,
		"statuses_on_hit": statuses_on_hit,
		"status_params": _get_status_params(area_params, context),
		"cone_direction": _resolve_cone_direction(area_params, context, position),
		"move_direction": _resolve_area_move_direction(area_params, context, position)
	})


## 作用：为陷阱动作补充陷阱对象语义后走区域创建路径。
## 使用：params 为动作或状态参数；context 为施放或命中上下文。
func _spawn_trap(params: Dictionary, context: Dictionary) -> bool:
	var trap_params: Dictionary = params.duplicate(true)
	if not trap_params.has("damage_origin"):
		trap_params["damage_origin"] = "trap"
	if not trap_params.has("damage_type"):
		trap_params["damage_type"] = "trap_damage"
	if not trap_params.has("duration"):
		trap_params["duration"] = 4.0
	if not trap_params.has("tick_interval"):
		trap_params["tick_interval"] = 0.25
	if not trap_params.has("position_mode"):
		trap_params["position_mode"] = "target"
	return _spawn_area(trap_params, context, "trap")


## 作用：按活动区域上限查找同来源对象并清理超额旧对象。
## 使用：parent 为生成对象父节点；source_id 为稳定效果来源 ID；可能回收匹配节点。
func _enforce_max_active_areas(parent: Node, source_type: String, source_id: StringName, max_active: int) -> void:
	if parent == null or max_active <= 0:
		return
	var matches: Array[Node] = []
	for child: Node in parent.get_children():
		if child == null or not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if str(child.get_meta("source_type", "")) != source_type:
			continue
		if StringName(str(child.get_meta("source_id", ""))) != source_id:
			continue
		matches.append(child)
	while matches.size() >= max_active:
		var oldest: Node = matches.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()


## 作用：更新命中的既有火油区域几何、时长及合并元数据。
## 使用：parent 为生成对象父节点；position 为生成世界坐标；radius 为世界坐标半径；写入 fire_oil_radius/fire_oil_merged_area 元数据；返回布尔判断或执行是否成功。
func _merge_existing_fire_oil_area(parent: Node, position: Vector2, radius: float, duration: float, damage: int, rule: Dictionary) -> bool:
	if parent == null:
		return false
	var merge_radius: float = maxf(float(rule.get("merge_radius", 120.0)), 1.0)
	for child: Node in parent.get_children():
		var area: Node2D = child as Node2D
		if area == null or not bool(area.get_meta("fire_oil_area", false)) or area.is_queued_for_deletion():
			continue
		if area.global_position.distance_squared_to(position) > merge_radius * merge_radius:
			continue
		if area.has_method("extend_duration"):
			area.call("extend_duration", duration, duration + float(rule.get("duration_add", 1.0)))
		if area.has_method("set_effect_radius"):
			var merged_radius: float = maxf(float(area.get("radius")), radius)
			area.call("set_effect_radius", merged_radius)
			area.set_meta("fire_oil_radius", merged_radius)
		area.set_meta("fire_oil_merged_area", true)
		if int(area.get("damage")) < damage:
			area.set("damage", damage)
		return true
	return false


## 作用：创建单个环绕战斗对象并登记来源技能与环绕轨道。
## 使用：params 读取 count/orbit_radius/collision_radius/object_id；context 携带 caster/skill_id；写入 owner_instance_id/skill_id/source_id 元数据；返回布尔判断或执行是否成功。
func _spawn_orbit_object(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node2D = context.get("caster") as Node2D
	if caster == null:
		return false

	var count: int = maxi(int(ModifierResolverScript.resolve_value(context, "orbit_object_count", params.get("count", 1))), 1)
	var orbit_radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "orbit_radius", params.get("orbit_radius", 72.0))), 1.0)
	var area_radius: float = maxf(float(ModifierResolverScript.resolve_value(context, "area_radius", params.get("collision_radius", 18.0))), 1.0)
	var source_id: StringName = StringName(str(params.get("object_id", params.get("source_id", ""))))
	var parent: Node = _get_parent_node(context)
	var existing_objects: Array[Node2D] = _get_orbit_objects(parent, caster, StringName(str(context.get("skill_id", ""))), source_id)
	if existing_objects.size() != count:
		for existing_object: Node2D in existing_objects:
			if is_instance_valid(existing_object):
				existing_object.queue_free()
		existing_objects.clear()
	else:
		for existing_object: Node2D in existing_objects:
			if existing_object != null and existing_object.has_method("setup"):
				existing_object.call("setup", _build_orbit_params(params, context, caster, orbit_radius, area_radius, source_id, float(existing_object.get("angle"))))
		return true

	for object_index in range(count):
		var angle: float = TAU * float(object_index) / float(count)
		var orbit_params: Dictionary = _build_orbit_params(params, context, caster, orbit_radius, area_radius, source_id, angle)
		orbit_params["parent"] = parent
		orbit_params["position"] = caster.global_position + Vector2.RIGHT.rotated(angle) * orbit_radius
		var orbit_object: Node2D = CombatObjectFactoryScript.create_orbit_object(orbit_params)
		if orbit_object != null:
			orbit_object.set_meta("owner_instance_id", caster.get_instance_id())
			orbit_object.set_meta("skill_id", StringName(str(context.get("skill_id", ""))))
			orbit_object.set_meta("source_id", source_id)

	return true


## 作用：按数量、角度和轨道配置生成一组环绕对象。
## 使用：params 为动作或状态参数；context 为施放或命中上下文。
func _spawn_orbitals(params: Dictionary, context: Dictionary) -> bool:
	var orbit_params: Dictionary = params.duplicate(true)
	if not orbit_params.has("object_id"):
		orbit_params["object_id"] = str(orbit_params.get("orbital_id", orbit_params.get("source_id", "")))
	if not orbit_params.has("orbit_radius"):
		orbit_params["orbit_radius"] = float(orbit_params.get("radius", 72.0))
	return _spawn_orbit_object(orbit_params, context)


## 作用：根据施法者、区域中心或配置方向给命中目标施加击退。
## 使用：params 读取 force；context 携带 target/caster；返回布尔判断或执行是否成功。
func _knockback(params: Dictionary, context: Dictionary) -> bool:
	var target: Node2D = context.get("target") as Node2D
	var caster: Node2D = context.get("caster") as Node2D
	if target == null or caster == null:
		return false

	var direction: Vector2 = caster.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		return false

	target.global_position += direction.normalized() * float(params.get("force", 10.0))
	return true


## 作用：把有效目标沿指定中心方向牵引。
## 使用：params 读取 distance/strength/radius；context 携带 target/source/caster；返回布尔判断或执行是否成功。
func _pull(params: Dictionary, context: Dictionary) -> bool:
	var target: Node2D = context.get("target") as Node2D
	if target == null:
		return false
	var origin_node: Node2D = context.get("source") as Node2D
	if origin_node == null:
		origin_node = context.get("caster") as Node2D
	if origin_node == null:
		return false

	var direction: Vector2 = target.global_position.direction_to(origin_node.global_position)
	if direction == Vector2.ZERO:
		return false
	var distance: float = maxf(float(params.get("distance", 0.0)), 0.0)
	if distance <= 0.0:
		distance = maxf(float(params.get("strength", 0.2)) * maxf(float(params.get("radius", 64.0)), 1.0), 1.0)
	if target.has_method("apply_pull"):
		target.call("apply_pull", direction, distance)
	else:
		target.global_position += direction.normalized() * distance
	return true


## 作用：按动作策略解析目标并交换对应位置。
## 使用：params 读取 targeting/count/target_range/detect_range；context 携带 caster；返回布尔判断或执行是否成功。
func _swap_targets(params: Dictionary, context: Dictionary) -> bool:
	var caster: Node = context.get("caster") as Node
	var targeting: String = str(params.get("targeting", "instability_stack_highest"))
	var target_params: Dictionary = params.duplicate(true)
	target_params["count"] = maxi(int(params.get("count", 2)), 2)
	if not params.has("target_range") and not params.has("detect_range") and not params.has("range"):
		target_params.erase("radius")
	elif params.has("target_range"):
		target_params["range"] = float(params.get("target_range"))
	elif params.has("detect_range"):
		target_params["range"] = float(params.get("detect_range"))
	if not target_params.has("origin") and caster is Node2D:
		target_params["origin"] = caster
	var targets: Array = TargetingServiceScript.find_targets(caster, targeting, target_params)
	var first: Node2D = null
	var second: Node2D = null
	for target_variant: Variant in targets:
		var candidate: Node2D = target_variant as Node2D
		if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if candidate.has_method("is_dead") and bool(candidate.call("is_dead")):
			continue
		if first == null:
			first = candidate
		elif second == null and candidate != first:
			second = candidate
			break
	if first == null or second == null:
		return false

	var first_position: Vector2 = first.global_position
	var second_position: Vector2 = second.global_position
	first.global_position = second_position
	second.global_position = first_position

	if params.has("area_id"):
		var area_params: Dictionary = {
			"area_id": str(params.get("area_id")),
			"position": (first_position + second_position) * 0.5,
			"radius": maxf(float(params.get("radius", 0.0)), first_position.distance_to(second_position) * 0.5),
			"duration": maxf(float(params.get("duration", 0.18)), 0.05),
			"effects_on_apply": [
				{
					"type": "damage",
					"damage_type": str(params.get("damage_type", "chaos")),
					"source_type": "power",
					"power_scale": float(params.get("power_scale", 0.0))
				}
			]
		}
		for key_variant: Variant in params.keys():
			var key: String = str(key_variant)
			if not area_params.has(key) and key not in ["targeting", "count", "power_scale", "damage_type"]:
				area_params[key] = params[key_variant]
		var area_context: Dictionary = context.duplicate(true)
		area_context["position"] = area_params["position"]
		area_context["target"] = first
		_spawn_area(area_params, area_context, "area")
	return true


## 作用：查找符合条件的现有区域并改造为新区域效果。
## 使用：params 读取 area_id/object_id/remove_source_area；context 携带 area；返回布尔判断或执行是否成功。
func _transform_area(params: Dictionary, context: Dictionary) -> bool:
	var area: Node = context.get("area") as Node
	if area == null:
		push_warning("[SkillActionExecutor] transform_area has no source area.")
		return false
	if params.has("area_id") or params.has("object_id"):
		var area_params: Dictionary = params.duplicate(true)
		if not area_params.has("position") and area is Node2D:
			area_params["position"] = (area as Node2D).global_position
		var spawned: bool = _spawn_area(area_params, context, "area")
		if spawned and bool(params.get("remove_source_area", false)) and area.has_method("queue_free"):
			area.call("queue_free")
		return spawned
	for key_variant: Variant in params.keys():
		var key: String = str(key_variant)
		if key == "type":
			continue
		area.set_meta(key, params[key_variant])
	return true


## 作用：补齐区域 ID 与持续时间，把路径重复动作转换为单个带 tick 动作的区域创建请求。
## 使用：params 读取 source_area_tag/duration；context 为施放或命中上下文。
func _repeat_area_path(params: Dictionary, context: Dictionary) -> bool:
	var area_params: Dictionary = _prepare_area_tick_action_params(params)
	if not area_params.has("area_id"):
		area_params["area_id"] = str(params.get("source_area_tag", "repeated_area_path"))
	if not area_params.has("duration"):
		area_params["duration"] = float(params.get("duration", 2.0))
	return _spawn_area(area_params, context, "area")


## 作用：读取既有区域位置和参数，为派生区域补齐上下文后创建。
## 使用：params 为动作或状态参数；context 携带 area/source。
func _spawn_area_from_existing_area(params: Dictionary, context: Dictionary) -> bool:
	var source_area: Node2D = context.get("area") as Node2D
	if source_area == null:
		source_area = context.get("source") as Node2D
	var area_params: Dictionary = _prepare_area_tick_action_params(params)
	if source_area != null and not area_params.has("position"):
		area_params["position"] = source_area.global_position
	if not area_params.has("radius") and source_area != null:
		area_params["radius"] = float(source_area.get("radius")) if _has_property(source_area, "radius") else 48.0
	return _spawn_area(area_params, context, "area")


## 作用：把区域 tick 的配置效果适配为运行命中动作参数。
## 使用：params 为动作或状态参数。
func _prepare_area_tick_action_params(params: Dictionary) -> Dictionary:
	var area_params: Dictionary = params.duplicate(true)
	if area_params.has("effects_on_tick") and not area_params.has("actions_on_tick"):
		area_params["actions_on_tick"] = _effects_to_actions(_get_array(area_params.get("effects_on_tick", [])))
	return area_params
