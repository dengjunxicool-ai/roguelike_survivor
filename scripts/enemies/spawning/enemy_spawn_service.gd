## 文件用途：统一实例化敌人、应用生成倍率、选位和显形预警。
## 使用方式：先 setup 注入场景/owner/RNG，再 spawn；预警中的实体保留在场并暂时关闭行为和碰撞。

extends RefCounted
class_name EnemySpawnService


const EnemySpawnMultipliersScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_multipliers.gd")
const EnemySpawnWarningScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_warning.gd")
const EnemyMapBoundaryScript: Script = preload("res://scripts/enemies/enemy_map_boundary.gd")
signal spawn_created(request: Dictionary, enemy: Node2D)
signal spawn_activated(request: Dictionary, enemy: Node2D)
signal spawn_cancelled(request: Dictionary, reason: StringName)
var _pending: Dictionary = {}
var _completed: Dictionary = {}
var _reveals: Dictionary = {}
var _request_sequence := 0
var _run_generation := 0
var _wave_id := ""
var _retry_cooldown := 0.0
var _pump_ref: WeakRef
var _side_sequence := 0
var statistics: Dictionary = {"created":0,"activated":0,"queued":0,"retry_attempts":0,"relocated":0,"cancelled":0,"reasons":{}}

var _owner: Node
var _enemy_scene: PackedScene
var _boss_scene: PackedScene
var _target_group: StringName = &"player"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_radius_min: float = 520.0
var _spawn_radius_max: float = 760.0
var _spawn_clearance: float = 56.0
var _visible_spawn_enabled: bool = false
var _visible_spawn_margin: float = 64.0
var _player_safe_radius: float = 120.0
var _spawn_warning_duration: float = 1.5


## 作用：绑定生成 owner、普通/Boss 场景、目标组和随机流。
## 使用：首次生成前调用；若未提供 rng，则随机化本服务独立随机流。
func setup(
	owner: Node,
	enemy_scene: PackedScene,
	boss_scene: PackedScene = null,
	target_group: StringName = &"player",
	rng: RandomNumberGenerator = null
) -> void:
	_owner = owner
	if not spawn_cancelled.is_connected(Callable(self,"_record_cancellation")):
		spawn_cancelled.connect(Callable(self,"_record_cancellation"))
	_enemy_scene = enemy_scene
	_boss_scene = boss_scene
	_target_group = target_group
	if rng != null:
		_rng = rng
	else:
		_rng.randomize()

func _ensure_pump() -> void:
	var current: Node = _pump_ref.get_ref() as Node if _pump_ref != null else null
	if is_instance_valid(_owner) and _owner.is_inside_tree() and (not is_instance_valid(current) or current.is_queued_for_deletion()):
		var pump := preload("res://scripts/enemies/spawning/enemy_spawn_pump.gd").new()
		pump.service = self
		_owner.add_child(pump)
		_pump_ref = weakref(pump)


## 作用：设置生成半径范围。
## 使用：供本模块调用者使用；输入 min_radius（下限半径）、max_radius（上限半径）。
func set_spawn_radius_range(min_radius: float, max_radius: float) -> void:
	_spawn_radius_min = maxf(min_radius, 1.0)
	_spawn_radius_max = maxf(max_radius, _spawn_radius_min)


## 作用：设置可见生成规则。
## 使用：供本模块调用者使用；输入 enabled（启用）、viewport_margin（视口边距）、player_safe_radius（玩家safe半径）、warning_duration（预警持续时间）。
func set_visible_spawn_rules(enabled: bool, viewport_margin: float, player_safe_radius: float, warning_duration: float) -> void:
	_visible_spawn_enabled = enabled
	_visible_spawn_margin = maxf(viewport_margin, 0.0)
	_player_safe_radius = maxf(player_safe_radius, 0.0)
	_spawn_warning_duration = maxf(warning_duration, 0.0)


## 作用：实例化敌人并按入树前属性、选位、入树后属性和显形顺序完成生成。
## 使用：request 为生成请求；失败返回 null，成功返回 Node2D；预警中实体已入树并占场。
func spawn(request: Dictionary) -> Node2D:
	request = request.duplicate(true)
	if not request.has("spawn_request_id"):
		_request_sequence += 1
		request["spawn_request_id"] = _request_sequence
	else:
		_request_sequence = maxi(_request_sequence,int(request.spawn_request_id))
	request["run_generation"] = request.get("run_generation",_run_generation)
	request["wave_id"] = request.get("wave_id",_wave_id)
	var key := _request_key(request)
	if _completed.has(key) or _pending.has(key):
		return null
	if String(request.get("spawn_pattern",""))=="alternating_sides" and not request.has("spawn_side"):
		request["spawn_side"]=_side_sequence%2
		_side_sequence+=1
	return _spawn_request(request)

func allocate_request_id() -> int:
	_request_sequence+=1
	return _request_sequence

func _spawn_request(request: Dictionary) -> Node2D:
	if _is_source_expired(request):
		statistics.cancelled+=1
		_record_reason(&"source_or_context_expired")
		spawn_cancelled.emit(request,&"source_or_context_expired")
		return null
	if not _is_request_current(request):
		_record_reason(&"stale_context")
		return null
	var enemy_id: StringName = StringName(String(request.get("enemy_id", "")))
	if enemy_id == &"":
		return null

	var scene_to_spawn: PackedScene = _get_scene(request)
	if scene_to_spawn == null:
		return null

	var enemy: Node2D = scene_to_spawn.instantiate() as Node2D
	if enemy == null:
		return null

	var parent_node: Node = _get_parent_node(request)
	if parent_node == null:
		enemy.free()
		return null

	_apply_pre_ready_values(enemy, enemy_id, request)
	var definition: Dictionary = GameData.get_enemy(enemy_id)
	if enemy.has_method("_apply_collision_radius"):
		enemy.call("_apply_collision_radius",float(definition.get("base_stats",{}).get("collision_radius",24.0)))
	var placement := try_find_spawn_position(request, enemy)
	if not bool(placement.ok):
		enemy.free()
		_queue_request(request,StringName(placement.reason))
		return null
	_prepare_spawn_reveal(enemy)
	parent_node.add_child(enemy)
	enemy.global_position = placement.position
	_apply_post_ready_values(enemy, request)
	enemy.set_meta("spawn_request",request)
	_completed[_request_key(request)] = true
	_begin_spawn_reveal(enemy, _warning_duration(request))
	statistics.created += 1
	_record_lifecycle(enemy,&"created",request)
	if String(request.get("source_type",""))=="boss_core":
		var tracker: Node = RunStatsTracker.get_active(_owner.get_tree())
		if tracker != null:
			tracker.call("record_boss_core_spawned",enemy)
	if String(request.get("source_type",""))=="summon":
		var source_ref: WeakRef = request.get("source_owner")
		var source: Node = source_ref.get_ref() as Node if source_ref != null else null
		if is_instance_valid(source) and source.get("_is_dead") != true:
			source.set("_summon_cooldown",source.call("_get_enemy_skill_cooldown","summon",5.0))
	spawn_created.emit(request,enemy)
	return enemy


## 作用：获取场景，供当前模块后续逻辑使用。
## 使用：本文件由 spawn 调用；输入 request（请求）；返回 PackedScene 对象/值。
func _get_scene(request: Dictionary) -> PackedScene:
	var scene_override: Variant = request.get("scene", null)
	if scene_override is PackedScene:
		return scene_override
	if bool(request.get("use_boss_scene", false)) and _boss_scene != null:
		return _boss_scene
	if _enemy_scene != null:
		return _enemy_scene
	return load("res://scenes/enemies/enemy.tscn") as PackedScene


## 作用：获取父节点节点，供当前模块后续逻辑使用。
## 使用：本文件由 spawn 调用；输入 request（请求）；返回 Node 对象/值。
func _get_parent_node(request: Dictionary) -> Node:
	var parent_override: Node = request.get("parent", null) as Node
	if parent_override != null:
		return parent_override
	if _owner != null and _owner.get_tree() != null and _owner.get_tree().current_scene != null:
		return _owner.get_tree().current_scene
	return _owner.get_parent() if _owner != null else null


## 作用：在入树前设置 enemy_id、属性倍率、等阶、来源和奖励策略。
## 使用：add_child 前调用，保证 EnemyBase._ready 使用正确初始配置。
func _apply_pre_ready_values(enemy: Node2D, enemy_id: StringName, request: Dictionary) -> void:
	var multipliers: Dictionary = EnemySpawnMultipliersScript.normalize(request.get("multipliers", {}))
	enemy.set("enemy_id", enemy_id)
	enemy.set("health_multiplier", multipliers["hp"])
	enemy.set("damage_multiplier", multipliers["damage"])
	if enemy.get("move_speed_multiplier") != null:
		enemy.set("move_speed_multiplier", multipliers["move_speed"])
	if enemy.get("experience_multiplier") != null:
		enemy.set("experience_multiplier", multipliers["exp"])
	if int(multipliers.get("defense_add", 0)) != 0:
		enemy.set_meta("defense_add", int(multipliers["defense_add"]))

	if request.has("enemy_rank"):
		enemy.set_meta("enemy_rank", String(request["enemy_rank"]))

	enemy.set_meta("spawn_source_type", String(request.get("source_type", "unknown")))
	enemy.set_meta("spawn_source_id", String(request.get("source_id", "")))
	enemy.set_meta("spawn_role",String(request.get("spawn_role","")))
	if request.has("treasure_lifetime"):
		enemy.set_meta("treasure_lifetime",float(request.treasure_lifetime))
	if request.has("summoner_instance_id"):
		enemy.set_meta("summoner_instance_id", int(request.summoner_instance_id))
	var reward_policy: Dictionary = _get_dictionary(request.get("reward_policy", {}))
	if not reward_policy.is_empty():
		enemy.set_meta("reward_policy", reward_policy)


## 作用：在敌人入树初始化后应用请求中的覆盖属性。
## 使用：post_ready_properties 含血量时补发 health_changed；不会重建配置。
func _apply_post_ready_values(enemy: Node2D, request: Dictionary) -> void:
	var post_ready_properties: Dictionary = _get_dictionary(request.get("post_ready_properties", {}))
	for key: Variant in post_ready_properties.keys():
		enemy.set(String(key), post_ready_properties[key])
	if post_ready_properties.has("current_health") and enemy.has_signal(&"health_changed"):
		enemy.emit_signal(&"health_changed", int(enemy.get("current_health")), int(enemy.get("max_health")))


## 显式选位结果；失败位置不用于创建。显形前复检与首次创建共用此入口。
func try_find_spawn_position(request: Dictionary, spawned_enemy: Node2D = null) -> Dictionary:
	if not is_instance_valid(_owner) or _owner.get_tree() == null:
		return {"ok":false,"position":Vector2.ZERO,"reason":&"owner_unavailable"}
	var target: Node2D = _owner.get_tree().get_first_node_in_group(_target_group) as Node2D
	var specified: Variant = request.get("position")
	var around := specified is Vector2
	var origin: Vector2 = specified if around else (target.global_position if target != null else Vector2.ZERO)
	if not origin.is_finite():
		return {"ok":false,"position":Vector2.ZERO,"reason":&"invalid_position"}
	var attempts := maxi(int(request.get("spawn_position_attempts",24)),1)
	var clearance := maxf(float(request.get("spawn_clearance",_spawn_clearance)),0.0)
	var radius := _collision_radius(spawned_enemy,24.0)
	for attempt in range(attempts):
		var candidate: Vector2 = origin if around and attempt==0 else _candidate_position(origin,request,around,attempt)
		if not candidate.is_finite() or not _inside_spawn_bounds(candidate,request,radius):
			continue
		if target != null and candidate.distance_to(target.global_position) < maxf(_player_safe_radius, radius + _collision_radius(target,24.0) + 2.0):
			continue
		if clearance > 0.0 and not _is_position_clear(candidate,clearance,spawned_enemy):
			continue
		if bool(request.get("avoid_map_hazards",false)) and _is_hazard_blocked(candidate,radius): continue
		return {"ok":true,"position":candidate,"reason":&"available"}
	return {"ok":false,"position":Vector2.ZERO,"reason":&"no_safe_position"}

func _is_hazard_blocked(position: Vector2,radius: float) -> bool:
	for hazard: Node in _owner.get_tree().get_nodes_in_group(&"map_hazard"):
		if not is_instance_valid(hazard) or hazard.is_queued_for_deletion() or not hazard is Node2D: continue
		if hazard.get("_attack_finished")==true or hazard.get("_is_despawned")==true: continue
		var area_radius: Variant = hazard.get("area_radius")
		if area_radius==null: area_radius=hazard.get("radius")
		if area_radius!=null and position.distance_to(hazard.global_position)<float(area_radius)+radius: return true
	return false

func _inside_spawn_bounds(position: Vector2,request: Dictionary,radius: float = 24.0) -> bool:
	var bounds: Variant = request.get("spawn_bounds")
	if bounds is Rect2 and not bounds.has_point(position):
		return false
	var bounds_rect: Rect2 = EnemyMapBoundaryScript.get_bounds(_owner)
	if bounds_rect.size.x>0.0 and bounds_rect.size.y>0.0:
		var map_rect: Rect2 = bounds_rect.grow(-radius)
		if map_rect.size.x<=0.0 or map_rect.size.y<=0.0 or not map_rect.has_point(position):
			return false
	if _visible_spawn_enabled:
		var viewport := _owner.get_viewport()
		var rect := viewport.get_visible_rect().grow(-_visible_spawn_margin)
		return rect.size.x > 0.0 and rect.size.y > 0.0 and rect.has_point(viewport.get_canvas_transform()*position)
	return true

func _collision_radius(node: Node2D,fallback: float) -> float:
	if node == null:
		return fallback
	var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return fallback
	var circle: CircleShape2D = shape_node.shape
	var scale_factor := maxf(absf(shape_node.global_scale.x),absf(shape_node.global_scale.y))
	if bool(node.get_meta("spawn_reveal_pending",false)):
		scale_factor /= 0.72
	return circle.radius * scale_factor


## 作用：候选位置。
## 使用：本文件由 _find_clear_position 调用；输入 origin（来源）、request（请求）、around_origin（周围来源）、attempt（attempt）；返回 Vector2 对象/值。
func _candidate_position(origin: Vector2, request: Dictionary, around_origin: bool, attempt: int) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	if _visible_spawn_enabled and (not around_origin or attempt >= 12):
		return _visible_spawn_candidate(origin,request)
	if around_origin:
		var radius: float = float(request.get("spawn_position_retry_radius", 220.0)) * (float(attempt + 1) / maxf(float(request.get("spawn_position_attempts", 24)), 1.0))
		return origin + Vector2.RIGHT.rotated(angle) * radius
	if _visible_spawn_enabled and bool(request.get("visible_spawn_warning", false)):
		return _visible_spawn_candidate(origin,request)
	var radius: float = _rng.randf_range(_spawn_radius_min, _spawn_radius_max)
	return origin + Vector2.RIGHT.rotated(angle) * radius


## 作用：在当前视口内抽样，并优先选择距玩家安全半径外的位置。
## 使用：把屏幕点经逆画布变换为世界坐标；无可用视口时返回 fallback。
func _visible_spawn_candidate(fallback: Vector2,request: Dictionary = {}) -> Vector2:
	var viewport: Viewport = _owner.get_viewport() if _owner != null and _owner.is_inside_tree() else null
	if viewport == null:
		return fallback
	var screen_rect: Rect2 = viewport.get_visible_rect().grow(-_visible_spawn_margin)
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		return fallback
	if String(request.get("spawn_pattern",""))=="alternating_sides":
		var viewport_width := viewport.get_visible_rect().size.x
		var right := int(request.get("spawn_side",0))==1
		var left_x := viewport_width*0.75 if right else screen_rect.position.x
		var right_x := screen_rect.end.x if right else viewport_width*0.25
		screen_rect=Rect2(Vector2(left_x,screen_rect.position.y),Vector2(maxf(right_x-left_x,0),screen_rect.size.y))
	var inverse_canvas: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var target: Node2D = viewport.get_tree().get_first_node_in_group(_target_group) as Node2D
	var best_candidate: Vector2 = fallback
	var best_distance_squared: float = -1.0
	for _index: int in range(8):
		var screen_position := Vector2(
			_rng.randf_range(screen_rect.position.x, screen_rect.end.x),
			_rng.randf_range(screen_rect.position.y, screen_rect.end.y)
		)
		var candidate: Vector2 = inverse_canvas * screen_position
		if target == null:
			return candidate
		var distance_squared: float = candidate.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			best_candidate = candidate
			best_distance_squared = distance_squared
		if distance_squared >= _player_safe_radius * _player_safe_radius:
			return candidate
	return best_candidate


## 作用：保存处理模式、碰撞和颜色，关闭行为碰撞并隐藏待显形敌人。
## 使用：敌人入树前调用；设置 spawn_reveal_pending，避免预警阶段攻击。
func _prepare_spawn_reveal(enemy: Node2D) -> void:
	enemy.set_meta("spawn_reveal_pending", true)
	enemy.set_meta("spawn_reveal_process_mode", enemy.process_mode)
	enemy.set_meta("spawn_reveal_collision_layer", enemy.collision_layer)
	enemy.set_meta("spawn_reveal_collision_mask", enemy.collision_mask)
	enemy.set_meta("spawn_reveal_modulate", enemy.modulate)
	enemy.set_meta("spawn_reveal_scale", enemy.scale)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	var hidden_color: Color = enemy.modulate
	hidden_color.a = 0.0
	enemy.modulate = hidden_color
	enemy.scale *= 0.72


## 作用：创建地面预警并用并行 Tween 渐显敌人。
## 使用：duration 为秒；零时长或无父节点时直接激活。
func _begin_spawn_reveal(enemy: Node2D, duration: float) -> void:
	var parent: Node = enemy.get_parent()
	if parent == null:
		_activate_spawned_enemy(enemy)
		return
	if not is_instance_valid(_owner):
		_owner=parent
	_ensure_pump()
	var warning: Node2D = EnemySpawnWarningScript.new()
	warning.z_index = enemy.z_index + 1
	parent.add_child(warning)
	warning.global_position = enemy.global_position
	warning.call("configure", _spawn_clearance * 0.72)
	enemy.set_meta("spawn_warning_node",weakref(warning))
	enemy.set_meta("spawn_warning_duration",duration)
	if duration <= 0.0:
		warning.queue_free()
		_activate_spawned_enemy(enemy)
		return
	var target_color: Color = enemy.get_meta("spawn_reveal_modulate", Color.WHITE)
	var target_scale: Vector2 = enemy.get_meta("spawn_reveal_scale",enemy.scale/0.72)
	var tween: Tween = parent.create_tween()
	tween.bind_node(warning)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "modulate", target_color, duration)
	tween.tween_property(enemy, "scale", target_scale, duration)
	tween.tween_method(Callable(warning, "set_progress"), 0.0, 1.0, duration)
	tween.chain().tween_callback(Callable(self, "_finish_spawn_reveal").bind(weakref(enemy), weakref(warning)))
	_reveals[enemy.get_instance_id()] = {"enemy":weakref(enemy),"warning":weakref(warning),"tween":tween,"request":enemy.get_meta("spawn_request",{}),"duration":duration}


## 作用：通过弱引用清理预警并激活仍有效的敌人。
## 使用：显形 Tween 完成回调；已释放或等待删除的敌人不会再次激活。
func _finish_spawn_reveal(enemy_ref: WeakRef, warning_ref: WeakRef) -> void:
	var warning: Node2D = warning_ref.get_ref() as Node2D
	var enemy: Node2D = enemy_ref.get_ref() as Node2D
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		if is_instance_valid(warning):
			warning.queue_free()
		for id: Variant in _reveals.keys():
			if _reveals[id].enemy == enemy_ref or _reveals[id].warning.get_ref() == warning:
				_cancel_reveal(id,&"reveal_removed",false)
		return
	var current_ref: WeakRef = enemy.get_meta("spawn_warning_node",null)
	if current_ref != null and current_ref.get_ref() != warning:
		return
	var record: Dictionary = _reveals.get(enemy.get_instance_id(),{})
	var tween: Tween = record.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	if is_instance_valid(warning):
		warning.queue_free()
	var target: Node2D = _owner.get_tree().get_first_node_in_group(_target_group) as Node2D if is_instance_valid(_owner) and _owner.is_inside_tree() else null
	var radius := _collision_radius(enemy,24.0)+_collision_radius(target,24.0)+2.0
	if target != null and enemy.global_position.distance_squared_to(target.global_position) <= radius*radius:
		var request: Dictionary = record.get("request",{}).duplicate(true)
		request["position"] = enemy.global_position
		var placement := try_find_spawn_position(request,enemy)
		if bool(placement.ok):
			enemy.global_position = placement.position
			statistics.relocated += 1
		else:
			_record_reason(&"activation_blocked")
		# 即使没有新位置也保持禁用并重播完整预警，不强制激活。
		var hidden_color: Color = enemy.get_meta("spawn_reveal_modulate",Color.WHITE)
		hidden_color.a=0.0
		enemy.modulate=hidden_color
		enemy.scale=enemy.get_meta("spawn_reveal_scale",Vector2.ONE)*0.72
		_begin_spawn_reveal(enemy,float(record.get("duration",_spawn_warning_duration)))
		return
	_reveals.erase(enemy.get_instance_id())
	_activate_spawned_enemy(enemy)


## 作用：恢复显形前保存的处理模式、碰撞与颜色并解除待显形标记。
## 使用：仅在预警完成或无需预警时调用。
func _activate_spawned_enemy(enemy: Node2D) -> void:
	enemy.process_mode = int(enemy.get_meta("spawn_reveal_process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
	enemy.collision_layer = int(enemy.get_meta("spawn_reveal_collision_layer", 1))
	enemy.collision_mask = int(enemy.get_meta("spawn_reveal_collision_mask", 0))
	enemy.modulate = enemy.get_meta("spawn_reveal_modulate", Color.WHITE)
	enemy.scale = enemy.get_meta("spawn_reveal_scale",enemy.scale)
	enemy.set_meta("spawn_reveal_pending", false)
	statistics.activated += 1
	_record_lifecycle(enemy,&"activated",enemy.get_meta("spawn_request",{}))
	spawn_activated.emit(enemy.get_meta("spawn_request",{}),enemy)

func _record_lifecycle(enemy: Node, phase: StringName,request: Dictionary) -> void:
	var tracker := RunStatsTracker.get_active(_owner.get_tree()) if is_instance_valid(_owner) and _owner.is_inside_tree() else null
	if tracker!=null: tracker.record_monster_lifecycle(enemy,phase,request)

func _record_cancellation(request: Dictionary,_reason: StringName) -> void:
	if _reason==&"run_reset": return
	_record_lifecycle(null,&"cancelled",request)


## 作用：判断位置清除，返回布尔判断结果。
## 使用：本文件由 _find_clear_position 调用；输入 position（位置）、clearance（clearance）、spawned_enemy（已生成敌人）。
func _is_position_clear(position: Vector2, clearance: float, spawned_enemy: Node2D) -> bool:
	var tree: SceneTree = _owner.get_tree() if _owner != null else null
	if tree == null:
		return true
	var clearance_squared: float = clearance * clearance
	for node: Node in tree.get_nodes_in_group(&"enemy"):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy == spawned_enemy or enemy.is_queued_for_deletion() or enemy.get("_is_dead")==true:
			continue
		var contact_clearance := maxf(clearance,_collision_radius(enemy,24.0)+_collision_radius(spawned_enemy,24.0)+2.0)
		if enemy.global_position.distance_squared_to(position) < maxf(clearance_squared,contact_clearance*contact_clearance):
			return false
	return true

func _request_key(request: Dictionary) -> String:
	return "%s:%s:%s" % [request.get("run_generation",0),request.get("wave_id",""),request.get("spawn_request_id",0)]

func _is_request_current(request: Dictionary) -> bool:
	return int(request.get("run_generation",_run_generation)) == _run_generation and (not bool(request.get("wave_bound",String(request.get("source_type",""))=="wave")) or String(request.get("wave_id","")) == _wave_id)

func get_reveal_count(source_type: String = "",wave_id: String = "") -> int:
	var count := 0
	for record: Dictionary in _reveals.values():
		if (source_type=="" or String(record.request.get("source_type",""))==source_type) and (wave_id=="" or String(record.request.get("wave_id",""))==wave_id): count+=1
	return count

func get_pending_role_count(role: String) -> int:
	var count := 0
	for request: Dictionary in _pending.values():
		if String(request.get("spawn_role",""))==role: count+=1
	return count

func _warning_duration(request: Dictionary) -> float:
	var source := String(request.get("source_type",""))
	var rank := String(request.get("enemy_rank",GameData.get_enemy(request.get("enemy_id",&"")).get("enemy_rank","normal")))
	var duration := 0.6 if source in ["summon","death_split","boss_core"] else (0.8 if rank=="elite" or source=="elite_event" else _spawn_warning_duration)
	return maxf(float(request.get("spawn_warning_duration",duration)),0.01)

func _queue_request(request: Dictionary,reason: StringName) -> void:
	_ensure_pump()
	var key := _request_key(request)
	if not _pending.has(key):
		_pending[key]=request
		statistics.queued += 1
	_record_reason(reason)

func _record_reason(reason: StringName) -> void:
	statistics.reasons[reason] = int(statistics.reasons.get(reason,0))+1

func get_pending_count(source_type: String = "") -> int:
	var count := 0
	for request: Dictionary in _pending.values():
		if source_type=="" or request.get("source_type","")==source_type:
			count+=1
	return count

func retry_pending(delta: float) -> void:
	# 外部清理预警/实体时显式退回请求，避免无行为且无预警的幽灵实体。
	for id: Variant in _reveals.keys():
		var record: Dictionary = _reveals[id]
		var enemy: Node2D = record.enemy.get_ref() as Node2D
		var warning: Node2D = record.warning.get_ref() as Node2D
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not is_instance_valid(warning) or warning.is_queued_for_deletion():
			var reason: StringName = enemy.get_meta("spawn_recycle_reason",&"reveal_removed") if is_instance_valid(enemy) else &"reveal_removed"
			_cancel_reveal(id,reason,reason==&"reveal_removed" and record.request.get("source_type","")=="wave")
	_retry_cooldown = maxf(_retry_cooldown-delta,0.0)
	if _retry_cooldown>0.0:
		return
	_retry_cooldown=0.2
	var processed := 0
	for key: Variant in _pending.keys():
		if processed>=4:
			break
		var request: Dictionary = _pending[key]
		_pending.erase(key)
		processed+=1
		statistics.retry_attempts+=1
		if not is_instance_valid(_owner) or not _owner.is_inside_tree() or _is_source_expired(request) or not _is_request_current(request):
			statistics.cancelled+=1
			_record_reason(&"source_or_context_expired")
			spawn_cancelled.emit(request,&"source_or_context_expired")
			continue
		_spawn_request(request)

func _is_source_expired(request: Dictionary) -> bool:
	if String(request.get("source_type","")) not in ["summon","boss_core"]:
		return false
	var source_ref: WeakRef = request.get("source_owner")
	if source_ref == null:
		return false
	var source: Node = source_ref.get_ref() as Node
	return not is_instance_valid(source) or source.is_queued_for_deletion() or source.get("_is_dead")==true

func has_work() -> bool:
	return not _pending.is_empty() or not _reveals.is_empty()

func set_context(run_generation: int,wave_id: String) -> void:
	if run_generation != _run_generation:
		cancel_all(&"run_reset",true)
		_completed.clear()
		_side_sequence=0
		_retry_cooldown=0.0
		statistics={"created":0,"activated":0,"queued":0,"retry_attempts":0,"relocated":0,"cancelled":0,"reasons":{}}
	_run_generation=run_generation
	_wave_id=wave_id
	for key: Variant in _pending.keys():
		var request: Dictionary = _pending[key]
		if not _is_request_current(request):
			_pending.erase(key)
			statistics.cancelled+=1
			_record_reason(&"wave_changed")
			spawn_cancelled.emit(request,&"wave_changed")

func cancel_all(reason: StringName,include_reveals: bool = false) -> void:
	for request: Dictionary in _pending.values():
		statistics.cancelled+=1
		_record_reason(reason)
		spawn_cancelled.emit(request,reason)
	_pending.clear()
	if include_reveals:
		for id: Variant in _reveals.keys():
			_cancel_reveal(id,reason,false)

func _cancel_reveal(id: int,reason: StringName,requeue: bool) -> void:
	var record: Dictionary = _reveals[id]
	_reveals.erase(id)
	var tween: Tween = record.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	for ref: WeakRef in [record.enemy,record.warning]:
		var node: Node = ref.get_ref() as Node
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	statistics.cancelled+=1
	_record_reason(reason)
	var request: Dictionary = record.request
	spawn_cancelled.emit(request,reason)
	if requeue and not request.is_empty() and _is_request_current(request):
		_completed.erase(_request_key(request))
		_queue_request(request,reason)


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _apply_pre_ready_values、_apply_post_ready_values 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}
