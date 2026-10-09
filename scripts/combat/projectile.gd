## 文件用途：实现可池化的直线/弧线/追踪投射物，统一命中去重、穿透、事件与状态，并管理飞行/命中视觉。
## 使用方式：挂在Area2D投射物场景，由CombatObjectFactory.create_projectile传direction、伤害模板与技能上下文初始化。
extends Area2D
class_name Projectile


const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")
const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")
const PROJECTILE_RETARGET_INTERVAL: float = 0.1

@export_range(0, 10000, 1, "or_greater") var damage: int = 15
@export_range(1.0, 3000.0, 10.0, "or_greater") var speed: float = 520.0
@export var direction: Vector2 = Vector2.RIGHT
@export_range(0, 100, 1, "or_greater") var pierce: int = 0
@export var status_on_hit: StringName = &""
@export var statuses_on_hit: Array[StringName] = []
@export var status_params: Dictionary = {}
@export var damage_type: StringName = &""
@export var damage_packet: Dictionary = {}
@export_range(0.1, 20.0, 0.1, "or_greater") var lifetime: float = 2.0
@export var target_group: StringName = &"enemies"
@export var source_id: StringName = &""
@export var event_on_hit: StringName = &""
@export var homing_enabled: bool = false
@export_range(0.1, 40.0, 0.1, "or_greater") var homing_turn_rate: float = 8.0
@export_range(0.0, 5000.0, 10.0, "or_greater") var homing_seek_range: float = 0.0
@export var visual_effect_scene: String = ""

var _geometry_branch: int = -1
var _geometry_done: bool = false
var _return_once: bool = false
var _return_multiplier: float = 1.0
var _returned: bool = false
var spawn_generation: int = 0
var _age: float = 0.0
var _hits_remaining: int = 1
var _hit_bodies: Array[Object] = []
var event_bus: Node
var skill_instance: RefCounted
var caster: Node
var skill_manager: Node
var relic_manager: Node
var actions_on_hit: Array = []
var _apply_direct_damage_on_hit: bool = false
var _visual_config: Dictionary = {}
var _visual_mode: String = ""
var _visual_style: String = ""
var _visual_color: Color = Color(1.0, 0.45, 0.12, 0.9)
var _visual_ring_color: Color = Color(1.0, 0.9, 0.35, 0.95)
var _visual_seed: float = 0.0
var _is_destroying: bool = false
var _trajectory_mode: String = "linear"
var _curve_start_position: Vector2 = Vector2.ZERO
var _curve_target_position: Vector2 = Vector2.ZERO
var _curve_height: float = 0.0
var _curve_duration: float = 0.0
var _curve_elapsed: float = 0.0
var _visual_effect_node: Node2D
var _collision_radius: float = 12.0
var _homing_target: Node2D
var _homing_retarget_timer: float = 0.0


## 作用：连接命中信号、生成视觉相位并规范方向和穿透次数。
## 使用：节点入树自动调用，setup随后应用生成参数。
func _ready() -> void:
	_visual_seed = float(get_instance_id() % 997) / 997.0 * TAU
	if not body_entered.is_connected(Callable(self, "_on_body_entered")):
		body_entered.connect(Callable(self, "_on_body_entered"))
	_update_direction_state()
	_reset_pierce_counter()


## 作用：清旧元数据后依次配置核心、payload、上下文、视觉、轨迹与追踪，最后重置运行状态。
## 使用：池复用须传完整params，附加视觉场景在状态重置后创建。
func setup(params: Dictionary) -> void:
	spawn_generation += 1
	_clear_projectile_runtime_meta()
	_apply_projectile_core_params(params)
	_apply_projectile_payload_params(params)
	_apply_projectile_context_params(params)
	_apply_projectile_visual_params(params)
	_setup_trajectory(params)
	_apply_projectile_trace_meta(params)
	_apply_projectile_runtime_meta(params)
	_reset_projectile_runtime_state(params)
	_apply_visual_config(params)
	_attach_visual_effect_scene()
	queue_redraw()


## 作用：恢复显示与处理并调用setup重建本次spawn状态。
## 使用：params为对象完整生成参数，池复用时调用。
func prepare_for_pool_spawn(params: Dictionary) -> void:
	visible = true
	set_process(true)
	set_physics_process(true)
	setup(params)


## 作用：停止碰撞和动画、释放附加特效并清事件引用、命中列表与追踪目标。
## 使用：回池前隐藏节点，避免残留生命周期事件。
func prepare_for_pool_despawn() -> void:
	if event_bus != null: event_bus.clear_interaction_object(self)
	_is_destroying = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.stop()
	if _visual_effect_node != null and is_instance_valid(_visual_effect_node):
		_visual_effect_node.queue_free()
	_visual_effect_node = null
	event_bus = null
	skill_instance = null
	caster = null
	skill_manager = null
	relic_manager = null
	actions_on_hit.clear()
	_hit_bodies.clear()
	_homing_target = null
	_homing_retarget_timer = 0.0
	visible = false


## 作用：有有效runtime池元数据时清理并回池，否则queue_free释放。
## 使用：生命周期结束入口；池路径会调用prepare_for_pool_despawn。
func despawn_or_free() -> void:
	if has_meta(&"runtime_pool_owner") and has_meta(&"runtime_pool_key"):
		var pool_variant: Variant = get_meta(&"runtime_pool_owner")
		var key: StringName = StringName(String(get_meta(&"runtime_pool_key")))
		if pool_variant is Node and is_instance_valid(pool_variant) and (pool_variant as Node).has_method("despawn"):
			prepare_for_pool_despawn()
			(pool_variant as Node).call("despawn", key, self)
			return
	queue_free()


## 作用：读取伤害量、速度、方向、穿透、寿命、来源与追踪参数并裁剪边界。
## 使用：零方向稍后规范为向右，速度至少1。
func _apply_projectile_core_params(params: Dictionary) -> void:
	damage = maxi(int(params.get("damage", damage)), 0)
	speed = maxf(float(params.get("speed", speed)), 1.0)
	direction = _get_vector2(params.get("direction", direction), direction)
	pierce = maxi(int(params.get("pierce", pierce)), 0)
	lifetime = maxf(float(params.get("lifetime", lifetime)), 0.1)
	target_group = StringName(String(params.get("target_group", target_group)))
	source_id = StringName(String(params.get("source_id", source_id)))
	homing_enabled = bool(params.get("homing_enabled", homing_enabled))
	homing_turn_rate = maxf(float(params.get("homing_turn_rate", homing_turn_rate)), 0.1)
	homing_seek_range = maxf(float(params.get("homing_seek_range", homing_seek_range)), 0.0)


## 作用：读取状态、伤害模板、命中事件和action并补稳定来源。
## 使用：状态/动作配置使用副本，供每次命中使用。
func _apply_projectile_payload_params(params: Dictionary) -> void:
	status_on_hit = StringName(String(params.get("status_on_hit", status_on_hit)))
	statuses_on_hit = _get_status_array(params.get("statuses_on_hit", []), status_on_hit)
	status_params = _get_dictionary(params.get("status_params", status_params))
	damage_type = StringName(String(params.get("damage_type", damage_type)))
	damage_packet = _get_dictionary(params.get("damage_packet", damage_packet))
	_stabilize_damage_packet_source("projectile")
	event_on_hit = StringName(String(params.get("event_on_hit", event_on_hit)))
	actions_on_hit = _get_array(params.get("actions_on_hit", []))
	_apply_direct_damage_on_hit = bool(params.get("apply_direct_damage_on_hit", false))
	_geometry_branch = int(params.get("chaos_geometry_branch",-1))
	_geometry_done = false
	_return_once = bool(params.get("return_once",false)) or _geometry_branch == 1
	_return_multiplier = float(params.get("return_damage_multiplier",1.0))
	_returned = false


## 作用：绑定事件总线、技能实例、caster、技能及遗物管理器。
## 使用：供命中事件和action上下文使用。
func _apply_projectile_context_params(params: Dictionary) -> void:
	event_bus = params.get("event_bus") as Node
	skill_instance = params.get("skill_instance") as RefCounted
	caster = params.get("caster") as Node
	skill_manager = params.get("skill_manager") as Node
	relic_manager = params.get("relic_manager") as Node


## 作用：读取附加特效场景、视觉模式/风格及颜色。
## 使用：params缺失时保持当前值。
func _apply_projectile_visual_params(params: Dictionary) -> void:
	visual_effect_scene = String(params.get("visual_effect_scene", visual_effect_scene))
	_visual_mode = String(params.get("visual_mode", _visual_mode))
	_visual_style = String(params.get("visual_style", _visual_style))
	_visual_color = _get_color(params.get("visual_color", _visual_color), _visual_color)
	_visual_ring_color = _get_color(params.get("visual_ring_color", _visual_ring_color), _visual_ring_color)


## 作用：记录施放实例并把trace字段同步到节点及包。
## 使用：params含可选cast_instance_id和追踪上下文。
func _apply_projectile_trace_meta(params: Dictionary) -> void:
	if params.has("cast_instance_id"):
		set_meta("cast_instance_id", String(params["cast_instance_id"]))
	DamageTraceContextScript.apply_to_node_meta(self, params)
	damage_packet = DamageTraceContextScript.apply_to_packet(damage_packet, params)


## 作用：保存连射暴击、禁忌书页和奥术复制的特定元数据。
## 使用：仅在params含对应项时写入。
func _apply_projectile_runtime_meta(params: Dictionary) -> void:
	if params.has("hot_rapid_fire_crit"):
		set_meta("hot_rapid_fire_crit", bool(params["hot_rapid_fire_crit"]))
	if params.has("hot_rapid_fire_crit_chance_add"):
		set_meta("hot_rapid_fire_crit_chance_add", float(params["hot_rapid_fire_crit_chance_add"]))
	if params.has("forbidden_page"):
		set_meta("forbidden_page", bool(params["forbidden_page"]))
	if params.has("arcane_page_copy"):
		set_meta("arcane_page_copy", bool(params["arcane_page_copy"]))
	if params.has("arcane_page_hit_ids"):
		set_meta("arcane_page_hit_ids", params["arcane_page_hit_ids"])


## 作用：清理上次spawn的连射、书页与施放实例标记。
## 使用：必须在应用新params之前调用。
func _clear_projectile_runtime_meta() -> void:
	for key: StringName in [
		&"hot_rapid_fire_crit",
		&"hot_rapid_fire_crit_chance_add",
		&"forbidden_page",
		&"arcane_page_copy",
		&"arcane_page_hit_ids",
		&"cast_instance_id"
	]:
		if has_meta(key):
			remove_meta(key)


## 作用：清命中/销毁/年龄/追踪状态，启用碰撞并重设方向、穿透和半径。
## 使用：碰撞开关deferred写入，params可覆盖radius。
func _reset_projectile_runtime_state(params: Dictionary) -> void:
	_hit_bodies.clear()
	_is_destroying = false
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	_age = 0.0
	_homing_target = null
	_homing_retarget_timer = 0.0
	_update_direction_state()
	_reset_pierce_counter()
	_collision_radius = maxf(float(params.get("radius", params.get("area_radius", 12.0))), 1.0)
	_apply_area_radius(_collision_radius)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)


## 作用：以性能采样包装投射物生命周期与运动。
## 使用：引擎物理帧传delta。
func _physics_process(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_physics_process_profiled(delta)
	HotPathProfilerScript.end(self, &"projectile_update", hot_path_start)


## 作用：寿命到期结束，否则更新弧线或追踪直线并对追踪移动做扫掠命中。
## 使用：销毁中无动作，闪电球/陨石每帧请求重绘。
func _physics_process_profiled(delta: float) -> void:
	if _is_destroying:
		return

	var interaction_from: Vector2 = global_position
	_age += delta
	if _age >= lifetime:
		despawn_or_free()
		return

	if _return_once and not _returned and _age >= lifetime*0.5: _begin_return()
	if _trajectory_mode == "curve":
		_update_curve_trajectory(delta)
	else:
		_update_homing_direction(delta)
		var previous_position: Vector2 = global_position
		var next_position: Vector2 = global_position + direction * speed * delta
		if homing_enabled and _resolve_swept_homing_hit(previous_position, next_position):
			return
		global_position = next_position
	if event_bus != null: event_bus.observe_projectile(self,interaction_from,global_position,_collision_radius)
	if _visual_style == "lightning_orb" or _visual_style == "meteor":
		queue_redraw()


## 作用：过滤组和已命中目标，优先交给命中事件，否则直接typed受击和状态。
## 使用：每次有效命中消耗穿透，已命中目标不重复处理。
func _on_body_entered(body: Node) -> void:
	if _is_destroying or body == null or not body.is_in_group(target_group) or _hit_bodies.has(body):
		return

	_hit_bodies.append(body)
	if _emit_hit_event(body):
		_consume_pierce()
		return

	if body.has_method("take_damage"):
		body.call(&"take_damage", _get_damage_payload(body))
	_apply_status(body)
	_consume_pierce()


## 作用：构造规范上下文，deferred发送主攻击/配置命中事件并执行on_hit动作。
## 使用：返回true表示事件路径已接管伤害，调用方不再直接take_damage。
func _emit_hit_event(body: Node) -> bool:
	if event_bus == null or event_on_hit == &"" or not event_bus.has_method("emit_skill_event"):
		return false

	var event_context: Dictionary = DamageTraceContextScript.normalize_event_context({
		"caster": caster,
		"owner": caster,
		"target": body,
		"projectile": self,
		"source": self,
		"source_id": source_id,
		"source_origin_id": StringName(String(damage_packet.get("source_origin_id", ""))),
		"skill_instance": skill_instance,
		"skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else StringName(String(damage_packet.get("source_skill_id", ""))),
		"source_skill_id": StringName(skill_instance.get("skill_id")) if skill_instance != null else StringName(String(damage_packet.get("source_skill_id", ""))),
		"skill_manager": skill_manager,
		"relic_manager": relic_manager,
		"event_bus": event_bus,
		"parent": get_parent(),
		"target_group": target_group,
		"damage_packet": damage_packet,
		"milestone_returning":_returned,
		"milestone_hit_index":_hit_bodies.size()-1,
		"damage_type": damage_type,
		"hot_rapid_fire_crit": bool(get_meta("hot_rapid_fire_crit")) if has_meta("hot_rapid_fire_crit") else false,
		"hot_rapid_fire_crit_chance_add": float(get_meta("hot_rapid_fire_crit_chance_add")) if has_meta("hot_rapid_fire_crit_chance_add") else 0.0
	})
	var status_manager: Node = body.get_node_or_null("StatusEffectManager")
	if status_manager != null: event_context["target_statuses"] = status_manager.get_status_snapshot()
	if _apply_direct_damage_on_hit and damage > 0 and body.has_method("take_damage"):
		body.call(&"take_damage", _get_damage_payload(body))
	_emit_primary_attack_hit_event(event_context)
	event_bus.call_deferred("emit_skill_event", event_on_hit, event_context)
	_execute_adapted_actions(actions_on_hit, event_context)
	return true


## 作用：主攻击且专用事件不是attack_hit时额外deferred发送attack_hit。
## 使用：使用上下文副本，避免同名事件重复。
func _emit_primary_attack_hit_event(event_context: Dictionary) -> void:
	if String(damage_packet.get("damage_origin", "")) != "primary_attack":
		return
	if event_on_hit == &"attack_hit":
		return
	event_bus.call_deferred("emit_skill_event", &"attack_hit", event_context.duplicate(true))


## 作用：扣一次命中次数并同步pierce，耗尽时停止飞行播放命中视觉。
## 使用：剩余次数初始化为pierce+1。
func _consume_pierce() -> void:
	if _geometry_branch == 0 and not _geometry_done and event_bus != null:
		_geometry_done = true
		var c: Dictionary = {"caster":caster,"owner":caster,"target":_hit_bodies.back(),"parent":get_parent(),"skill_manager":skill_manager,"event_bus":event_bus,"origin_skill_id":damage_packet.get("origin_skill_id",source_id),"skill_id":damage_packet.get("origin_skill_id",source_id),"can_generate_secondary_proc":false,"proc_depth":1}
		event_bus.execute_adapted_actions([{"type":"spawn_projectile_burst","params":{"projectile_id":String(source_id),"count":2,"spread_angle":25,"damage":float(damage_packet.get("raw_amount",damage))*0.35,"damage_type":String(damage_type),"speed":speed,"range":speed*lifetime*0.4,"chaos_geometry_branch":-1}}],c)
	if _return_once and not _returned:
		_begin_return()
		return
	if _geometry_branch == 2 and not _geometry_done:
		_geometry_done = true
		var next: Node2D = null
		for candidate: Node2D in TargetingServiceScript.find_targets(caster,"nearest_enemy",{"range":speed*lifetime,"count":32}):
			if not _hit_bodies.has(candidate): next = candidate; break
		if next != null:
			direction = global_position.direction_to(next.global_position)
			homing_enabled = true
			return
	_hits_remaining -= 1
	pierce = maxi(_hits_remaining - 1, 0)
	if _hits_remaining <= 0:
		_play_hit_visual_then_free()


## 作用：幂等标记销毁、停运动和碰撞，再播放hit或直接结束。
## 使用：命中穿透耗尽时调用，不能继续命中。
func _play_hit_visual_then_free() -> void:
	if _is_destroying:
		return

	_is_destroying = true
	speed = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if not _has_visual_state("hit"):
		despawn_or_free()
		return

	_play_visual_state("hit", true)
	_free_when_hit_visual_finishes()


## 作用：验证命中动画存在且非循环，连接一次完成回调。
## 使用：无可用动画或循环动画立即回池/释放，循环情况输出警告。
func _free_when_hit_visual_finishes() -> void:
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		despawn_or_free()
		return

	var animation_name: StringName = animated_sprite.animation
	if animation_name == &"":
		animation_name = &"hit"
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		despawn_or_free()
		return
	if animated_sprite.sprite_frames.get_animation_loop(animation_name):
		push_warning("[Projectile] Hit animation must be non-looping to free on animation_finished: %s" % String(animation_name))
		despawn_or_free()
		return
	if not animated_sprite.animation_finished.is_connected(Callable(self, "_on_hit_visual_finished")):
		animated_sprite.animation_finished.connect(Callable(self, "_on_hit_visual_finished"), CONNECT_ONE_SHOT)


## 作用：命中动画完成后回池或释放。
## 使用：一次性动画信号回调。
func _on_hit_visual_finished() -> void:
	despawn_or_free()


## 作用：用模板、caster与命中目标构造typed投射物包。
## 使用：target可空，默认主攻击/物理直伤，保留稳定来源。
func _get_damage_payload(target: Node = null) -> DamagePacket:
	var template: Dictionary = damage_packet.duplicate(true)
	template["source_object_id"] = get_instance_id()
	template["source_generation"] = spawn_generation
	template["source_object_kind"] = "projectile"
	return DamagePacketBuilderScript.from_combat_object_hit_object({
		"template": template,
		"target": target,
		"owner": caster,
		"amount": damage,
		"source_type": "projectile",
		"source_id": source_id,
		"source_instance_id": str(get_instance_id()),
		"instance_id": get_instance_id(),
		"default_damage_origin": "primary_attack",
		"default_damage_type": damage_type if damage_type != &"" else &"direct_physical",
		"default_element": &"physical"
	})


## 作用：为非空模板补缺失的实例、来源类型与技能身份。
## 使用：保留显式来源，持续命中复用节点实例ID。
func _stabilize_damage_packet_source(default_source_type: String) -> void:
	if damage_packet.is_empty():
		return
	if not damage_packet.has("source_instance_id") or String(damage_packet.get("source_instance_id", "")) == "":
		damage_packet["source_instance_id"] = str(get_instance_id())
	if not damage_packet.has("source_type"):
		damage_packet["source_type"] = default_source_type
	if not damage_packet.has("source_id") and source_id != &"":
		damage_packet["source_id"] = source_id
	if not damage_packet.has("source_skill_id"):
		damage_packet["source_skill_id"] = StringName(String(source_id))
	if not damage_packet.has("source_origin_id"):
		damage_packet["source_origin_id"] = StringName("")


## 作用：对目标依次调用配置状态接口。
## 使用：优先apply_status带params，只有旧接口时用add_status_effect。
func _apply_status(body: Node) -> void:
	if statuses_on_hit.is_empty() and status_on_hit != &"":
		statuses_on_hit = [status_on_hit]
	if statuses_on_hit.is_empty():
		return

	for status_id: StringName in statuses_on_hit:
		if status_id == &"":
			continue

		if body.has_method("apply_status"):
			body.call(&"apply_status", status_id, status_params)
		elif body.has_method("add_status_effect"):
			body.call(&"add_status_effect", status_id)


## 作用：将零方向回退向右后归一化，并旋转节点指向运动方向。
## 使用：轨迹或追踪改变方向后调用。
func _update_direction_state() -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()


## 作用：把剩余命中次数设置为pierce+1。
## 使用：setup/ready调用，初始穿透0仍允许一次命中。
func _reset_pierce_counter() -> void:
	_hits_remaining = pierce + 1


## 作用：选择直线或弧线，弧线保存起终点、法向高度与由距离/速度得到的时长。
## 使用：curve模式设置当前位置和方向，时长不超过lifetime。
func _setup_trajectory(params: Dictionary) -> void:
	_trajectory_mode = String(params.get("trajectory_mode", "linear"))
	_curve_elapsed = 0.0
	if _trajectory_mode != "curve":
		return
	_curve_start_position = _get_vector2(params.get("curve_start_position", global_position), global_position)
	_curve_target_position = _get_vector2(params.get("curve_target_position", _curve_start_position + direction * speed * lifetime), _curve_start_position + direction * speed * lifetime)
	_curve_height = maxf(float(params.get("curve_height", 64.0)), 0.0)
	var distance: float = maxf(_curve_start_position.distance_to(_curve_target_position), 1.0)
	_curve_duration = clampf(distance / speed, 0.08, lifetime)
	global_position = _curve_start_position
	direction = _curve_start_position.direction_to(_curve_target_position)
	_update_direction_state()


## 作用：沿直线插值叠加sin弧高并更新朝向，终点到达结束。
## 使用：无有效时长回退直线；启用追踪时同时扫掠命中。
func _update_curve_trajectory(delta: float) -> void:
	if _curve_duration <= 0.0:
		var fallback_start: Vector2 = global_position
		var fallback_end: Vector2 = global_position + direction * speed * delta
		if homing_enabled and _resolve_swept_homing_hit(fallback_start, fallback_end):
			return
		global_position = fallback_end
		return
	_curve_elapsed += delta
	var t: float = clampf(_curve_elapsed / _curve_duration, 0.0, 1.0)
	var line_position: Vector2 = _curve_start_position.lerp(_curve_target_position, t)
	var chord: Vector2 = _curve_target_position - _curve_start_position
	var normal: Vector2 = Vector2(-chord.y, chord.x).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.UP
	var previous_position: Vector2 = global_position
	global_position = line_position + normal * sin(t * PI) * _curve_height
	var travel_direction: Vector2 = previous_position.direction_to(global_position)
	if travel_direction != Vector2.ZERO:
		direction = travel_direction
		_update_direction_state()
	if homing_enabled and _resolve_swept_homing_hit(previous_position, global_position):
		return
	if t >= 1.0:
		despawn_or_free()


## 作用：以性能采样包装追踪重选与转向。
## 使用：delta为物理帧秒数。
func _update_homing_direction(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_update_homing_direction_profiled(delta)
	HotPathProfilerScript.end(self, &"projectile_targeting", hot_path_start)


## 作用：追踪启用时每0.1秒或目标无效重选，并按turn_rate平滑转向。
## 使用：无有效目标保持当前方向。
func _update_homing_direction_profiled(delta: float) -> void:
	if not homing_enabled:
		return
	_homing_retarget_timer = maxf(_homing_retarget_timer - delta, 0.0)
	if not _is_valid_homing_target(_homing_target) or _homing_retarget_timer <= 0.0:
		_homing_target = _find_nearest_homing_target()
		_homing_retarget_timer = PROJECTILE_RETARGET_INTERVAL
	var target: Node2D = _homing_target
	if target == null:
		return
	var desired_direction: Vector2 = global_position.direction_to(target.global_position)
	if desired_direction == Vector2.ZERO:
		return
	direction = direction.lerp(desired_direction.normalized(), clampf(homing_turn_rate * delta, 0.0, 1.0)).normalized()
	_update_direction_state()


## 作用：查询seek_range内最近有效目标，未设范围用speed*lifetime。
## 使用：通过CombatTargetRegistry，返回目标或null。
func _find_nearest_homing_target() -> Node2D:
	var seek_range: float = homing_seek_range
	if seek_range <= 0.0:
		seek_range = maxf(speed * lifetime, 1.0)
	var nearest: Node2D = null
	var nearest_distance_squared: float = seek_range * seek_range
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	var candidates: Array = registry.call("get_targets_in_radius", global_position, seek_range, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in candidates:
		var target: Node2D = node as Node2D
		if not _is_valid_homing_target(target):
			continue
		var distance_squared: float = global_position.distance_squared_to(target.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = target
	return nearest


## 作用：以性能采样包装从旧位置到新位置的命中补偿。
## 使用：返回是否命中，调用方命中时不再正常移动。
func _resolve_swept_homing_hit(from_position: Vector2, to_position: Vector2) -> bool:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	var result: bool = _resolve_swept_homing_hit_profiled(from_position, to_position)
	HotPathProfilerScript.end(self, &"projectile_targeting", hot_path_start)
	return result


## 作用：查询线段周围候选，按沿线t选最早与双方半径相交的目标。
## 使用：移动到目标中心并走_on_body_entered，避免高速追踪穿过目标。
func _resolve_swept_homing_hit_profiled(from_position: Vector2, to_position: Vector2) -> bool:
	if from_position == to_position:
		return false

	var nearest_target: Node = null
	var nearest_t: float = INF
	var segment: Vector2 = to_position - from_position
	var segment_length_squared: float = segment.length_squared()
	var segment_length: float = sqrt(segment_length_squared)
	var query_origin: Vector2 = from_position.lerp(to_position, 0.5)
	var query_radius: float = segment_length * 0.5 + _collision_radius + 128.0
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	var candidates: Array = registry.call("get_targets_in_radius", query_origin, query_radius, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in candidates:
		var target: Node2D = node as Node2D
		if target == null or _hit_bodies.has(target) or not _is_valid_homing_target(target):
			continue
		var t: float = clampf((target.global_position - from_position).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_position: Vector2 = from_position.lerp(to_position, t)
		var hit_radius: float = _collision_radius + _get_target_hit_radius(target)
		if closest_position.distance_squared_to(target.global_position) > hit_radius * hit_radius:
			continue
		if t < nearest_t:
			nearest_t = t
			nearest_target = target

	if nearest_target == null:
		return false

	var impact_target: Node2D = nearest_target as Node2D
	global_position = impact_target.global_position
	_on_body_entered(impact_target)
	return true


## 作用：委托TargetingService验证可攻击目标。
## 使用：空、死亡或未显现目标由统一策略拒绝。
func _is_valid_homing_target(target: Node2D) -> bool:
	return TargetingServiceScript.is_valid_target(target)


## 作用：把圆、矩形、胶囊碰撞形状换算为保守命中半径。
## 使用：缺形状回退12像素，用于扫掠几何。
func _get_target_hit_radius(target: Node2D) -> float:
	var collision_shape: CollisionShape2D = target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 12.0
	var shape: Shape2D = collision_shape.shape
	if shape is CircleShape2D:
		return maxf((shape as CircleShape2D).radius, 1.0)
	if shape is RectangleShape2D:
		var size: Vector2 = (shape as RectangleShape2D).size
		return maxf(size.length() * 0.5, 1.0)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return maxf(maxf(capsule.radius, capsule.height * 0.5), 1.0)
	return 12.0


## 作用：将圆形碰撞半径更新为配置值。
## 使用：仅对现有CircleShape2D生效，节点或形状不符时无操作。
func _apply_area_radius(radius: float) -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is CircleShape2D):
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = maxf(radius, 1.0)


## 作用：程序化模式或无资源配置时隐藏sprite，其余播放fly状态。
## 使用：visual_color可补空配置的modulate。
func _apply_visual_config(params: Dictionary) -> void:
	if _visual_mode == "programmatic":
		_hide_sprite_nodes()
		return
	_visual_config = _get_dictionary(params.get("visual", {}))
	if _visual_config.is_empty() and params.has("visual_color"):
		_visual_config["modulate"] = params["visual_color"]
	if _visual_config.is_empty():
		_hide_sprite_nodes()
		return
	_play_visual_state("fly", true)


## 作用：加载并实例化附加特效为子节点，替换旧特效并关闭其自主处理。
## 使用：有set_continuous时设为false，位置与旋转归零跟随投射物。
func _attach_visual_effect_scene() -> void:
	if visual_effect_scene == "":
		return
	if _visual_effect_node != null and is_instance_valid(_visual_effect_node):
		_visual_effect_node.queue_free()
		_visual_effect_node = null
	var scene: PackedScene = load(visual_effect_scene) as PackedScene
	if scene == null:
		push_warning("[Projectile] Could not load visual_effect_scene: %s" % visual_effect_scene)
		return
	_visual_effect_node = scene.instantiate() as Node2D
	if _visual_effect_node == null:
		return
	add_child(_visual_effect_node)
	_visual_effect_node.position = Vector2.ZERO
	_visual_effect_node.rotation = 0.0
	if _visual_effect_node.has_method("set_continuous"):
		_visual_effect_node.call("set_continuous", false)
	_visual_effect_node.set_process(false)


## 作用：配置非空时交给VisualConfigApplier播放指定状态。
## 使用：force当前两个分支行为相同；fallback为idle。
func _play_visual_state(state: String, force: bool = false) -> void:
	if _visual_config.is_empty():
		return
	if force:
		VisualConfigApplierScript.play_state(self, _visual_config, state, "idle")
	else:
		VisualConfigApplierScript.play_state(self, _visual_config, state, "idle")


## 作用：查询配置是否提供指定状态视觉。
## 使用：返回布尔值，命中生命周期据此决定是否等待动画。
func _has_visual_state(state: String) -> bool:
	return VisualConfigApplierScript.has_state_visual(_visual_config, state)


## 作用：按投射物风格分派火球、冰雹、闪电、书页、刀箭、药瓶或陨石绘制。
## 使用：引擎绘图回调，不执行战斗动作。
func _draw() -> void:
	match _visual_style:
		"fireball_orb":
			_draw_fireball_orb()
		"hail_orb":
			_draw_hail_orb()
		"lightning_orb":
			_draw_lightning_orb()
		"arcane_page":
			_draw_arcane_page()
		"throwing_knife":
			_draw_throwing_knife()
		"hunter_arrow":
			_draw_hunter_arrow()
		"poison_bottle":
			_draw_poison_bottle()
		"oil_pot":
			_draw_oil_pot()
		"meteor":
			_draw_meteor()


## 作用：用配置颜色绘制发光火球、热核和短尾。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_fireball_orb() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.78))
	draw_circle(Vector2(-4.0, -2.0), 7.0, Color(1.0, 0.82, 0.24, 0.82))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 36, _visual_ring_color, 2.0, true)
	draw_line(Vector2(-22.0, 0.0), Vector2(-8.0, 0.0), Color(_visual_color.r, _visual_color.g, _visual_color.b, 0.38), 5.0, true)


## 作用：用配置颜色绘制五边冰雹及高光。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_hail_orb() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(12.0, -4.0),
		Vector2(8.0, 12.0),
		Vector2(-8.0, 12.0),
		Vector2(-12.0, -4.0)
	])
	draw_colored_polygon(points, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.78))
	draw_polyline(points + PackedVector2Array([points[0]]), _visual_ring_color, 2.0, true)
	draw_line(Vector2(-6.0, 0.0), Vector2(7.0, -6.0), Color(1.0, 1.0, 1.0, 0.65), 1.5, true)


## 作用：用配置颜色绘制脉动电球、旋转弧和闪电折线。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_lightning_orb() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 18.0 + _visual_seed)
	draw_circle(Vector2.ZERO, 12.0 + pulse * 2.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.62))
	draw_arc(Vector2.ZERO, 17.0, _age * 6.0, _age * 6.0 + TAU * 0.65, 28, _visual_ring_color, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(-14.0, -3.0), Vector2(-3.0, 4.0), Vector2(2.0, -5.0), Vector2(14.0, 2.0)]), Color(0.96, 1.0, 1.0, 0.9), 2.0, true)


## 作用：用配置颜色绘制倾斜书页轮廓及文字线。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_arcane_page() -> void:
	var page: PackedVector2Array = PackedVector2Array([
		Vector2(-11.0, -14.0),
		Vector2(10.0, -9.0),
		Vector2(11.0, 13.0),
		Vector2(-10.0, 9.0)
	])
	draw_colored_polygon(page, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.72))
	draw_polyline(page + PackedVector2Array([page[0]]), _visual_ring_color, 1.8, true)
	draw_line(Vector2(-5.0, -5.0), Vector2(6.0, -2.0), Color(1.0, 0.86, 1.0, 0.62), 1.2, true)
	draw_line(Vector2(-5.0, 1.0), Vector2(5.0, 4.0), Color(1.0, 0.86, 1.0, 0.50), 1.2, true)


## 作用：用配置颜色绘制刀刃线、刀尖和飞行尾迹。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_throwing_knife() -> void:
	draw_line(Vector2(-16.0, 0.0), Vector2(14.0, 0.0), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.92), 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(14.0, 0.0), Vector2(5.0, -5.0), Vector2(7.0, 0.0), Vector2(5.0, 5.0)]), _visual_color)
	draw_line(Vector2(-20.0, 0.0), Vector2(-9.0, 0.0), Color(0.65, 0.82, 1.0, 0.34), 2.0, true)


## 作用：用配置颜色绘制箭杆、箭头和尾羽。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_hunter_arrow() -> void:
	draw_line(Vector2(-26.0, 0.0), Vector2(18.0, 0.0), Color(_visual_color.r, _visual_color.g, _visual_color.b, 0.9), 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(22.0, 0.0), Vector2(10.0, -6.0), Vector2(13.0, 0.0), Vector2(10.0, 6.0)]), _visual_ring_color)
	draw_line(Vector2(-26.0, 0.0), Vector2(-34.0, -5.0), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.55), 1.5, true)
	draw_line(Vector2(-26.0, 0.0), Vector2(-34.0, 5.0), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.55), 1.5, true)


## 作用：用配置颜色绘制毒瓶圆身、瓶口和边环。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_poison_bottle() -> void:
	draw_circle(Vector2(2.0, 2.0), 11.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.66))
	draw_rect(Rect2(Vector2(-5.0, -14.0), Vector2(9.0, 9.0)), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.82), false, 2.0)
	draw_arc(Vector2(2.0, 2.0), 12.0, 0.0, TAU, 28, _visual_ring_color, 1.8, true)


## 作用：用配置颜色绘制火油罐体、瓶口及火焰尾迹。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_oil_pot() -> void:
	draw_circle(Vector2(1.0, 2.0), 12.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.70))
	draw_rect(Rect2(Vector2(-5.0, -15.0), Vector2(10.0, 9.0)), Color(_visual_ring_color.r, _visual_ring_color.g, _visual_ring_color.b, 0.86), false, 2.0)
	draw_line(Vector2(-13.0, 8.0), Vector2(-24.0, 14.0), Color(1.0, 0.28, 0.05, 0.42), 3.0, true)
	draw_arc(Vector2(1.0, 2.0), 13.0, 0.0, TAU, 28, _visual_ring_color, 2.0, true)


## 作用：用配置颜色绘制脉动尾焰与岩石多边形。
## 使用：由_draw按visual_style调用，使用节点本地坐标，绘图不改变命中逻辑。
func _draw_meteor() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 18.0 + _visual_seed)
	draw_line(Vector2(-38.0, -9.0), Vector2(-9.0, -3.0), Color(1.0, 0.2, 0.02, 0.32 + pulse * 0.16), 10.0, true)
	draw_line(Vector2(-34.0, 9.0), Vector2(-8.0, 3.0), Color(1.0, 0.72, 0.12, 0.28 + pulse * 0.12), 6.0, true)
	draw_circle(Vector2.ZERO, 18.0 + pulse * 2.0, Color(_visual_color.r, _visual_color.g, _visual_color.b, _visual_color.a * 0.58))
	draw_circle(Vector2(-4.0, -3.0), 11.0, Color(1.0, 0.72, 0.18, 0.78))
	draw_arc(Vector2.ZERO, 19.0 + pulse, 0.0, TAU, 40, _visual_ring_color, 2.2, true)
	var rock: PackedVector2Array = PackedVector2Array([
		Vector2(-11.0, -13.0),
		Vector2(7.0, -15.0),
		Vector2(16.0, -3.0),
		Vector2(10.0, 12.0),
		Vector2(-7.0, 15.0),
		Vector2(-17.0, 3.0)
	])
	draw_colored_polygon(rock, Color(0.26, 0.11, 0.07, 0.9))
	draw_polyline(rock + PackedVector2Array([rock[0]]), Color(1.0, 0.48, 0.08, 0.72), 1.6, true)


## 作用：隐藏静态和动画sprite，并停止动画。
## 使用：程序化视觉或无资源时调用。
func _hide_sprite_nodes() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.visible = false
	var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.visible = false
		animated_sprite.stop()


## 作用：将Vector2或至少两个成员的[x,y]数组解析为二维值。
## 使用：无法解析时返回fallback；不修改输入。
func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))

	return fallback


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回深复制，嵌套修改不会污染输入。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)

	return {}


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回深复制。
func _get_array(value: Variant) -> Array:
	if value is Array:
		var items: Array = value
		return items.duplicate(true)
	return []


## 作用：把on_hit动作列表与命中上下文交给技能总线。
## 使用：列表空或缺执行接口时无操作。
func _execute_adapted_actions(actions: Array, context: Dictionary) -> void:
	if actions.is_empty() or event_bus == null or not event_bus.has_method("execute_adapted_actions"):
		return
	event_bus.call("execute_adapted_actions", actions, context)


## 作用：解析Color、RGB/RGBA数组或HTML颜色字符串。
## 使用：无法解析时返回fallback；三成员RGB数组沿用fallback透明度。
func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			var alpha: float = float(items[3]) if items.size() > 3 else fallback.a
			return Color(float(items[0]), float(items[1]), float(items[2]), alpha)
	if value is String and String(value) != "":
		return Color.html(String(value))
	return fallback


## 作用：将状态数组转为去空去重的StringName列表，空列表可用单状态回退。
## 使用：fallback_status在没有有效数组成员时追加。
func _get_status_array(value: Variant, fallback_status: StringName = &"") -> Array[StringName]:
	var statuses: Array[StringName] = []
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			var status_id: StringName = StringName(String(item))
			if status_id != &"" and not statuses.has(status_id):
				statuses.append(status_id)

	if statuses.is_empty() and fallback_status != &"":
		statuses.append(fallback_status)

	return statuses

func _begin_return() -> void:
	if _returned: return
	_returned = true
	_geometry_done = true
	_trajectory_mode = "linear"
	homing_enabled = false
	direction = -direction
	_hit_bodies.clear()
	_hits_remaining = maxi(pierce+1,1)
	damage = roundi(float(damage)*_return_multiplier)
	for key: String in ["raw_amount","amount"]:
		if damage_packet.has(key): damage_packet[key] = float(damage_packet[key])*_return_multiplier
