## 文件用途：在带状态的敌人死亡时按概率生成毒区域，并限制同来源冷却和活动区域数量。
## 使用方式：通过 ENEMY_KILLED 载荷提供敌人、位置、父节点及来源；成功区域记录到活动列表并写入单局统计。
extends CharacterTrait
class_name StatusKillRandomAreaTrait


const CharacterEventScript: Script = preload("res://scripts/characters/events/character_event.gd")
const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _source_cooldowns: Dictionary = {}
var _active_trait_zones: Array[Node] = []


## 作用：调用基类 setup 后随机化概率流，并清空来源冷却与活动区域记录。
## 使用：trait_config 为当前角色特性配置；trait_context 为角色和场景树上下文。
func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	super.setup(trait_config, trait_context)
	_rng.randomize()
	_source_cooldowns.clear()
	_active_trait_zones.clear()


## 作用：只响应敌人死亡事件，并把其载荷交给毒区触发逻辑。
## 使用：event 读取 type/payload。
func handle_event(event: RefCounted) -> void:
	if StringName(event.get("type")) == CharacterEventScript.ENEMY_KILLED:
		_on_enemy_killed(_get_dictionary(event.get("payload")))


## 作用：返回特性 base_modifiers 的聚合快照，不根据查询条件进一步筛选。
## 使用：通过 ENEMY_KILLED 载荷提供敌人、位置、父节点及来源；成功区域记录到活动列表并写入单局统计。
func get_modifiers(_query: RefCounted) -> Dictionary:
	return _get_modifier_values(_get_params().get("base_modifiers", []))


## 作用：先剔除无效区域，再返回当前活动特性毒区数量。
## 使用：通过 ENEMY_KILLED 载荷提供敌人、位置、父节点及来源；成功区域记录到活动列表并写入单局统计。
func get_debug_state() -> Dictionary:
	_prune_inactive_trait_zones()
	return {
		"active_trait_zones": _active_trait_zones.size()
	}


## 作用：带状态敌人死亡通过来源冷却、区域容量与概率检查后创建毒区，成功后记录冷却。
## 使用：event 读取 enemy/spawn_source_type/parent/position。
func _on_enemy_killed(event: Dictionary) -> void:
	if not _enemy_has_any_status(event.get("enemy")):
		return

	var params: Dictionary = _get_params()
	var chance: float = clampf(float(params.get("kill_chance", 0.0)), 0.0, 1.0)
	if String(event.get("spawn_source_type", "")) == "boss_minion":
		chance *= clampf(float(params.get("boss_minion_chance_multiplier", 1.0)), 0.0, 10.0)
	if not _can_trigger_same_source(event, params):
		return
	if not _can_create_trait_zone(params):
		return
	if _rng.randf() > chance:
		return

	var parent: Node = event.get("parent") as Node
	if parent == null and context != null:
		var tree: SceneTree = context.get("tree") as SceneTree
		parent = tree.current_scene if tree != null else null
	if parent == null:
		return

	var zone: Node2D = CombatObjectFactoryScript.create_area_effect({
		"parent": parent,
		"position": event.get("position", Vector2.ZERO),
		"damage": int(params.get("area_damage", 12)),
		"damage_type": &"status_dot",
		"element": &"poison",
		"damage_packet": {
			"damage_origin": "field",
			"damage_type": &"status_dot",
			"element": &"poison",
			"source_id": "character_trait_area",
			"source_skill_id": "character_trait_area",
			"can_crit": false,
			"can_trigger_reaction": false,
			"uses_skill_level_coefficient": false
		},
		"duration": float(params.get("area_duration", 2.5)),
		"tick_interval": float(params.get("area_tick_interval", 1.0)),
		"target_group": event.get("target_group", &"enemies"),
		"radius": float(params.get("area_radius", 56.0)),
		"visual_style": "poison_zone",
		"visual_color": Color(0.36, 0.95, 0.12, 0.34),
		"visual_ring_color": Color(0.78, 1.0, 0.22, 0.72)
	})
	if zone != null:
		_active_trait_zones.append(zone)
		_mark_same_source_triggered(event, params)
	var tree: SceneTree = null
	if context != null:
		tree = context.get("tree") as SceneTree
	var tracker: Node = RunStatsTrackerScript.get_active(tree)
	if tracker != null and tracker.has_method("record_potion_zone_triggered"):
		tracker.call("record_potion_zone_triggered")


## 作用：检查死亡敌人是否带燃烧、毒、冻结、减速、电击、流血或破甲状态。
## 使用：由本文件 _on_enemy_killed 调用；返回布尔判断或执行是否成功。
func _enemy_has_any_status(enemy_variant: Variant) -> bool:
	var enemy: Node = enemy_variant as Node
	if enemy == null:
		return false
	var status_manager: Node = enemy.get_node_or_null("StatusEffectManager")
	if status_manager == null or not status_manager.has_method("has_status"):
		return false
	for status_id: StringName in [&"burning", &"poison", &"freeze", &"slow", &"shock", &"bleed", &"armor_break"]:
		if bool(status_manager.call("has_status", status_id)):
			return true
	return false


## 作用：按事件来源身份查询下一次可触发时间，零冷却不限制。
## 使用：event 为当前事件或规则载荷；params 读取 same_source_cooldown。
func _can_trigger_same_source(event: Dictionary, params: Dictionary) -> bool:
	var cooldown: float = maxf(float(params.get("same_source_cooldown", 0.0)), 0.0)
	if cooldown <= 0.0:
		return true
	var source_key: String = _get_event_source_key(event)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	return now_seconds >= float(_source_cooldowns.get(source_key, 0.0))


## 作用：区域创建成功后记录该事件来源的冷却截止时间。
## 使用：event 为当前事件或规则载荷；params 读取 same_source_cooldown。
func _mark_same_source_triggered(event: Dictionary, params: Dictionary) -> void:
	var cooldown: float = maxf(float(params.get("same_source_cooldown", 0.0)), 0.0)
	if cooldown <= 0.0:
		return
	var source_key: String = _get_event_source_key(event)
	_source_cooldowns[source_key] = float(Time.get_ticks_msec()) / 1000.0 + cooldown


## 作用：优先使用有效 source_key，否则用敌人实例 ID 构造来源键。
## 使用：event 读取 source_key/enemy。
func _get_event_source_key(event: Dictionary) -> String:
	var source_key: String = String(event.get("source_key", ""))
	if source_key != "" and source_key != "unknown":
		return source_key
	var enemy: Node = event.get("enemy") as Node
	if enemy != null:
		return "enemy:%s" % str(enemy.get_instance_id())
	return "unknown"


## 作用：清理无效区域后检查最大活动区域数量，零上限表示不限制。
## 使用：params 读取 max_zones。
func _can_create_trait_zone(params: Dictionary) -> bool:
	var max_zones: int = maxi(int(params.get("max_zones", 0)), 0)
	if max_zones <= 0:
		return true
	_prune_inactive_trait_zones()
	return _active_trait_zones.size() < max_zones


## 作用：逆序移除已释放或等待删除的特性区域引用。
## 使用：由本文件 get_debug_state/_can_create_trait_zone 调用。
func _prune_inactive_trait_zones() -> void:
	for index: int in range(_active_trait_zones.size() - 1, -1, -1):
		var zone: Node = _active_trait_zones[index]
		if zone == null or not is_instance_valid(zone) or zone.is_queued_for_deletion():
			_active_trait_zones.remove_at(index)
