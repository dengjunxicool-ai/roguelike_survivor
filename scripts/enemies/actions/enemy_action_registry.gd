## 文件用途：按动作类型分派敌方投射物、区域、召唤和接触状态效果。
## 使用方式：execute(context) 按 action.type 分派；投射物和区域通过 CombatObjectFactory 创建，召唤、自爆等转交 owner，接触状态调用目标 apply_status。

extends RefCounted
class_name EnemyActionRegistry


const EnemyDamagePacketBuilderScript: Script = preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")
const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")


## 作用：按 action.type 分派投射物、伤害区域、召唤、核心、自爆、突进标记或接触状态动作。
## 使用：context 来自 EnemyActionContext，包含 owner/action/runtime_params；未知类型警告并返回 false。
func execute(context: Dictionary) -> bool:
	var action: Dictionary = _get_dictionary(context.get("action", {}))
	match String(action.get("type", "")):
		"projectile":
			return _execute_projectile(context)
		"damage_area":
			return _execute_damage_area(context)
		"summon":
			return _execute_summon(context)
		"ring_projectiles":
			return _execute_ring_projectiles(context)
		"delayed_area_blast", "shockwave", "corruption_gaze":
			return _execute_damage_area(context)
		"corrupted_cores":
			return _execute_corrupted_cores(context)
		"self_explode":
			return _execute_self_explode(context)
		"dash":
			return _execute_dash_marker(context)
		"contact_status":
			return _execute_contact_status(context)
		_:
			push_warning("[EnemyActionRegistry] Unsupported enemy action type: %s" % String(action.get("type", "")))
			return false


## 作用：从池取得敌方投射物，设置方向、弹道、目标组和严格伤害包。
## 使用：context 提供 owner 和动作参数；缺少场景、父节点或生成失败时返回 false，成功配置返回 true。
func _execute_projectile(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or owner.get("enemy_projectile_scene") == null or owner.get_parent() == null:
		return false

	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var skill: Dictionary = _get_dictionary(context.get("skill", {}))
	var skill_id: StringName = StringName(String(skill.get("id", "enemy_projectile")))
	var projectile_scene: PackedScene = owner.get("enemy_projectile_scene") as PackedScene
	var projectile: Node2D = CombatObjectFactoryScript._spawn_pooled_combat_node(projectile_scene, owner.get_parent(), &"enemy_projectile") as Node2D
	if projectile == null:
		return false

	var direction: Vector2 = _get_vector2(runtime.get("direction", Vector2.RIGHT), Vector2.RIGHT)
	var normalized_direction: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	var amount: int = _get_damage_amount(owner, params, "damage", int(owner.get("contact_damage")))
	projectile.add_to_group(&"enemy_projectiles")
	projectile.add_to_group(&"enemy_projectile")
	projectile.global_position = owner.global_position + normalized_direction * float(params.get("spawn_offset", params.get("projectile_spawn_offset", 20.0)))
	var setup_params: Dictionary = {
			"direction": normalized_direction,
			"damage": amount,
			"speed": float(params.get("speed", params.get("projectile_speed", 280.0))),
			"target_group": owner.get("target_group"),
			"pierce": int(params.get("pierce", params.get("projectile_pierce", 0))),
			"radius": float(params.get("radius", params.get("projectile_radius", 8.0))),
			"lifetime": float(params.get("lifetime", params.get("projectile_lifetime", 3.0))),
			"source_id": StringName(String(EnemyDamagePacketBuilderScript.source_id_for(owner, "projectile"))),
			"damage_packet": EnemyDamagePacketBuilderScript.build(owner, amount, "projectile", skill_id, params),
			"visual_color": params.get("visual_color", params.get("projectile_color", [1.0, 0.9, 0.08, 1.0])),
			"visual": _get_dictionary(params.get("visual", params.get("projectile_visual", {})))
		}
	if projectile.has_method("prepare_for_pool_spawn"):
		projectile.call(&"prepare_for_pool_spawn", setup_params)
	elif projectile.has_method("setup"):
		projectile.call(&"setup", setup_params)
	return true


## 作用：从池取得伤害区域，设置位置、周期、半径和严格伤害包。
## 使用：context 提供动作与运行参数；继承基础伤害且周期约为一秒的普通伤害池按现有规则倍增伤害；返回是否满足条件或执行成功。
func _execute_damage_area(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or owner.get("damage_area_scene") == null or owner.get_parent() == null:
		return false

	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var skill: Dictionary = _get_dictionary(context.get("skill", {}))
	var skill_id: StringName = StringName(String(skill.get("id", "enemy_area")))
	var damage_area_scene: PackedScene = owner.get("damage_area_scene") as PackedScene
	var damage_area: Node2D = CombatObjectFactoryScript._spawn_pooled_combat_node(damage_area_scene, owner.get_parent(), &"enemy_area") as Node2D
	if damage_area == null:
		return false

	var area_tick_interval: float = _get_area_tick_interval(action, params, runtime)
	var amount: int = _get_damage_amount(owner, params, "damage", int(runtime.get("damage", owner.get("contact_damage"))))
	if _should_scale_inherited_tick_damage(action, params, area_tick_interval):
		amount *= 2
	var area_position: Vector2 = _get_vector2(runtime.get("position", owner.global_position), owner.global_position)
	damage_area.global_position = area_position
	var setup_params: Dictionary = {
			"damage": amount,
			"duration": _get_area_duration(action, params, runtime),
			"tick_interval": area_tick_interval,
			"target_group": owner.get("target_group"),
			"area_radius": float(params.get("radius", params.get("area_radius", runtime.get("radius", 72.0)))),
			"visual_color": _get_color(params.get("visual_color", runtime.get("visual_color", Color(0.35, 0.95, 0.2, 0.32)))),
			"source_id": StringName(String(EnemyDamagePacketBuilderScript.source_id_for(owner, "area"))),
			"source_type": &"area",
			"damage_packet": EnemyDamagePacketBuilderScript.build(owner, amount, "area", skill_id, params)
		}
	if damage_area.has_method("prepare_for_pool_spawn"):
		damage_area.call(&"prepare_for_pool_spawn", setup_params)
	elif damage_area.has_method("setup"):
		damage_area.call(&"setup", setup_params)
	return true


## 作用：解析召唤 ID、数量、中心和半径并转发给敌人的环形生成入口。
## 使用：owner 必须提供 _spawn_enemies_around；返回 true 表示已发出请求，不逐一验证生成结果。
func _execute_summon(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or not owner.has_method("_spawn_enemies_around"):
		return false

	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var enemy_id: StringName = StringName(String(params.get("enemy_id", runtime.get("enemy_id", "small_slime"))))
	var count: int = int(params.get("count", runtime.get("count", 1)))
	var center: Vector2 = _get_vector2(runtime.get("center", owner.global_position), owner.global_position)
	var radius: float = float(params.get("radius", params.get("spawn_radius", runtime.get("radius", 72.0))))
	owner.call("_spawn_enemies_around", enemy_id, count, center, radius)
	return true


## 作用：按圆周等分方向生成投射物并跳过配置的安全缺口。
## 使用：count 至少为 1；每个方向使用独立上下文，返回是否至少成功生成一枚。
func _execute_ring_projectiles(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null:
		return false

	var params: Dictionary = _get_action_params(context)
	var count: int = maxi(int(params.get("projectile_count", params.get("count", 8))), 1)
	var safe_gap_count: int = maxi(int(params.get("safe_gap_count", 0)), 0)
	var safe_gap_start: int = maxi(int(params.get("safe_gap_start", 0)), 0)
	var executed: bool = false
	for projectile_index in range(count):
		if projectile_index >= safe_gap_start and projectile_index < safe_gap_start + safe_gap_count:
			continue
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(projectile_index) / float(count))
		var child_context: Dictionary = context.duplicate(true)
		var child_action: Dictionary = _get_dictionary(context.get("action", {})).duplicate(true)
		child_action["type"] = "projectile"
		var child_params: Dictionary = params.duplicate(true)
		child_params["speed"] = float(params.get("speed", 240.0))
		child_params["radius"] = float(params.get("radius", params.get("projectile_radius", 8.0)))
		child_params["pierce"] = int(params.get("pierce", 0))
		child_action["params"] = child_params
		var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {})).duplicate(true)
		runtime["direction"] = direction
		child_context["action"] = child_action
		child_context["runtime_params"] = runtime
		executed = _execute_projectile(child_context) or executed
	return executed


## 作用：把数量与血量交给 owner 的腐化核心生成入口。
## 使用：owner 必须提供 _spawn_corrupted_cores；返回该入口的执行结果。
func _execute_corrupted_cores(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or not owner.has_method("_spawn_corrupted_cores"):
		return false
	var params: Dictionary = _get_action_params(context)
	return bool(owner.call("_spawn_corrupted_cores", int(params.get("count", 2)), int(params.get("hp", 120))))


## 作用：转发给敌人统一自爆动作入口。
## 使用：owner 必须提供 _run_self_explosion_action；伤害和死亡处理由该入口负责；返回是否满足条件或执行成功。
func _execute_self_explode(context: Dictionary) -> bool:
	var owner: Node2D = context.get("owner") as Node2D
	if owner == null or not owner.has_method("_run_self_explosion_action"):
		return false
	return bool(owner.call("_run_self_explosion_action"))


## 作用：为突进动作返回已识别标记。
## 使用：_context 当前不用；固定返回 true，本方法不直接移动敌人。
func _execute_dash_marker(_context: Dictionary) -> bool:
	return true


## 作用：从动作配置合成状态参数并请求目标施加状态。
## 使用：目标优先取 runtime_params；必须有 apply_status 和非空 status_id，返回实际施加结果。
func _execute_contact_status(context: Dictionary) -> bool:
	var params: Dictionary = _get_action_params(context)
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var target: Object = runtime.get("target", params.get("target", null))
	if target == null or not target.has_method("apply_status"):
		return false

	var status_id: StringName = StringName(String(params.get("status_id", "")))
	if status_id == &"":
		return false

	var status_params: Dictionary = _get_dictionary(params.get("status_params", {}))
	if params.has("duration"):
		status_params["duration"] = float(params["duration"])
	if params.has("damage"):
		status_params["damage"] = int(params["damage"])
	if params.has("tick_interval"):
		status_params["tick_interval"] = float(params["tick_interval"])
	if params.has("stack"):
		status_params["stacks"] = int(params["stack"])
	if params.has("max_stacks"):
		status_params["max_stacks"] = int(params["max_stacks"])
	return bool(target.call("apply_status", status_id, status_params))


## 作用：对配置显式伤害应用 owner 的伤害倍率，缺少字段则直接使用回退伤害。
## 使用：owner/params/key 定位伤害字段，fallback 一般已来自敌人属性；返回非负整数。
func _get_damage_amount(owner: Node, params: Dictionary, key: String, fallback: int) -> int:
	if params.has(key):
		return maxi(roundi(float(params.get(key, fallback)) * float(owner.get("damage_multiplier"))), 0)
	return maxi(fallback, 0)


## 作用：深拷贝动作参数，先以 Boss 技能字段覆盖，再用运行参数填补缺项。
## 使用：忽略 type/skill_id/cooldown 等控制字段；返回可安全修改的新字典。
func _get_action_params(context: Dictionary) -> Dictionary:
	var action: Dictionary = _get_dictionary(context.get("action", {}))
	var params: Dictionary = _get_dictionary(action.get("params", {}))
	var runtime: Dictionary = _get_dictionary(context.get("runtime_params", {}))
	var boss_skill: Dictionary = _get_dictionary(runtime.get("boss_skill", {}))
	for key: Variant in boss_skill.keys():
		if key == "type" or key == "skill_id" or key == "cooldown":
			continue
		params[String(key)] = boss_skill[key]
	for key: Variant in runtime.keys():
		if key == "boss_skill" or key == "behavior" or key == "skill_ref":
			continue
		if not params.has(key):
			params[key] = runtime[key]
	return params


## 作用：解析区域持续时间，对延迟爆炸和冲击波按预警时间计算最小生命周期。
## 使用：显式 duration 优先，否则根据 action.type 或 runtime 的 duration 回退；返回计算或读取的数值。
func _get_area_duration(action: Dictionary, params: Dictionary, runtime: Dictionary) -> float:
	var action_type: String = String(action.get("type", "damage_area"))
	if params.has("duration"):
		return float(params["duration"])
	if action_type == "delayed_area_blast":
		return maxf(float(params.get("delay", runtime.get("delay", 1.0))) + 0.25, 0.3)
	if action_type == "shockwave":
		return maxf(float(params.get("warning_time", runtime.get("warning_time", 0.8))) + 0.2, 0.25)
	return float(runtime.get("duration", 3.0))


## 作用：解析区域伤害周期，对延迟爆炸和冲击波使用延迟或预警时间。
## 使用：显式 tick_interval 优先；特殊动作周期至少 0.05 秒；返回计算或读取的数值。
func _get_area_tick_interval(action: Dictionary, params: Dictionary, runtime: Dictionary) -> float:
	var action_type: String = String(action.get("type", "damage_area"))
	if params.has("tick_interval"):
		return float(params["tick_interval"])
	if action_type == "delayed_area_blast":
		return maxf(float(params.get("delay", runtime.get("delay", 1.0))), 0.05)
	if action_type == "shockwave":
		return maxf(float(params.get("warning_time", runtime.get("warning_time", 0.8))), 0.05)
	return float(runtime.get("tick_interval", 1.0))


## 作用：判断普通伤害池是否需倍增继承的基础伤害。
## 使用：显式 damage 或非 damage_area 类型返回 false；无显式伤害且周期至少 0.99 秒返回 true。
func _should_scale_inherited_tick_damage(action: Dictionary, params: Dictionary, tick_interval: float) -> bool:
	if params.has("damage"):
		return false
	var action_type: String = String(action.get("type", "damage_area"))
	if action_type != "damage_area":
		return false
	return tick_interval >= 0.99


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 execute、_execute_projectile、_execute_damage_area 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 作用：获取二维向量，供当前模块后续逻辑使用。
## 使用：本文件由 _execute_projectile、_execute_damage_area、_execute_summon 调用；输入 value（值）、fallback（回退）；返回 Vector2 对象/值。
func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


## 作用：获取颜色，供当前模块后续逻辑使用。
## 使用：本文件由 _execute_damage_area 调用；输入 value（值）；返回 Color 对象/值。
func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			return Color(float(items[0]), float(items[1]), float(items[2]), float(items[3]) if items.size() > 3 else 1.0)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return Color(0.35, 0.95, 0.2, 0.32)
