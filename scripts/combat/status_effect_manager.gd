## 文件用途：管理宿主状态的叠层、时限、DOT、满层反应、移动/易伤查询及视觉事件。
## 使用方式：作为角色/敌人子节点使用；宿主按should_update_status_effects积累时间再调用update_status_effects，伤害走typed包。
extends Node
class_name StatusEffectManager


const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")
const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const DamagePacketBuilderScript: Script = preload("res://scripts/combat/damage_packet_builder.gd")
const DamageSourceIdentityScript: Script = preload("res://scripts/combat/damage_source_identity.gd")
const VisualConfigApplierScript: Script = preload("res://scripts/visual/visual_config_applier.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")
const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")
const StatusEffectQueryScript: Script = preload("res://scripts/combat/status_effect_query.gd")
const StatusEffectTickHelperScript: Script = preload("res://scripts/combat/status_effect_tick_helper.gd")
const StatusTickSchedulerScript: Script = preload("res://scripts/combat/status_tick_scheduler.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")
const DOT_STATUS_IDS: Array[StringName] = [&"burning", &"poison", &"bleed"]
const MOVEMENT_LOCK_STATUS_IDS: Array[StringName] = [&"freeze", &"frozen", &"stun", &"paralyze"]
const STATUS_VISUAL_NODE_NAME: String = "StatusVisualOverlay"

var _statuses: Dictionary = {}
var _status_visual_overlay: Node2D
var _status_visual_key: String = ""
var _status_visual_priority: float = -INF
var _status_visual_refresh_queued: bool = false
var _status_display_dirty: bool = true
var _status_tick_scheduler: RefCounted = StatusTickSchedulerScript.new()
var _reaction_queue: Array[Dictionary] = []
var _processing_reaction_queue: bool = false
var _pending_status_update_delta: float = 0.0
var _freeze_immunity_remaining: float = 0.0
var _resolution_nonce: int = 0
var _boss_frost_weak_until: float = 0.0
var _boss_frost_weak_ready: float = 0.0
var _freeze_immunity_ready_at: float = 0.0
var _status_elapsed_seconds: float = 0.0

func _status_time_seconds() -> float:
	var bus: Node = _get_skill_event_bus()
	return maxf(_status_elapsed_seconds, float(bus.call("combat_seconds"))) if bus != null and bus.has_method("combat_seconds") else _status_elapsed_seconds

static var _status_definition_cache: Dictionary = {}
static var _apply_coalesce_frame: int = -1
static var _apply_coalesce_keys: Dictionary = {}


## 作用：规范状态ID并合并同物理帧重复施加，否则计时执行完整施加。
## 使用：params含层数、时长、tick与来源覆盖；返回是否成功。
func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"":
		return false
	_freeze_immunity_remaining = maxf(_freeze_immunity_ready_at - _status_time_seconds(), 0.0)
	if id == &"frozen" and _is_boss() and _status_time_seconds() >= _boss_frost_weak_ready:
		_boss_frost_weak_until = _status_time_seconds() + 0.5
		_boss_frost_weak_ready = _status_time_seconds() + 2.0
	if id == &"frozen" and (_freeze_immunity_remaining > 0.0 or has_status(&"frozen")):
		_emit_status_skill_event(&"freeze_attempted", id, {"id": id, "stacks": 0, "resisted": true})
		return false
	if _should_coalesce_status_apply(id):
		return _merge_coalesced_status_apply(id, params)
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	var result: bool = _apply_status_profiled(id, params)
	HotPathProfilerScript.end(self, &"status_apply", hot_path_start)
	return result


## 作用：解析配置和阶级转换、构建叠层数据并登记tick，再通知施加和满层反应。
## 使用：未知/免疫状态返回false；状态入表后才发送事件。
func _apply_status_profiled(status_id: Variant, params: Dictionary = {}) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"":
		return false

	var definition: Dictionary = _get_status_definition(id)
	if definition.is_empty():
		push_warning("[StatusEffectManager] Unknown status_id: %s" % String(id))
		return false

	definition = _apply_enemy_tier_rules(id, definition)
	if definition.is_empty():
		return false

	var converted_status_id: StringName = StringName(String(definition.get("convert_to_status", "")))
	if converted_status_id != &"" and converted_status_id != id:
		var converted_params: Dictionary = params.duplicate(true)
		for key: Variant in definition.keys():
			if key != "convert_to_status" and not converted_params.has(key):
				converted_params[key] = definition[key]
		return apply_status(converted_status_id, converted_params)

	var stack_data: Dictionary = _resolve_status_stack_data(id, definition, params)
	var status: Dictionary = _build_status_runtime_data(id, definition, params, stack_data)
	var current_stacks: int = int(stack_data.get("current_stacks", 0))
	var new_stacks: int = int(stack_data.get("new_stacks", 0))
	var max_stacks: int = int(stack_data.get("max_stacks", 1))

	var next_tick_interval: float = float(status["tick_interval"])
	status["tick_timer"] = minf(float(status.get("tick_timer", next_tick_interval)), next_tick_interval)
	_statuses[id] = status
	_sync_status_tick_scheduler(id, status)
	_pending_status_update_delta = 0.0
	_mark_status_display_dirty()
	if _status_visual_refresh_needed_after_apply(id, definition):
		_queue_status_visual_refresh()

	_notify_status_applied(id, status)
	if new_stacks >= max_stacks and (current_stacks < max_stacks or (id == &"chilled" and _freeze_immunity_remaining <= 0.0 and not has_status(&"frozen"))):
		_handle_max_stack_reached(id, status)
	_apply_poison_slow_synergy()
	return true


## 作用：按宿主实例和状态ID记录本物理帧首次施加。
## 使用：同帧后续返回true，跨帧清共享去重表。
func _should_coalesce_status_apply(status_id: StringName) -> bool:
	if status_id == &"":
		return false
	var target: Node = get_parent()
	if target == null:
		return false
	var frame: int = int(Engine.get_physics_frames())
	if _apply_coalesce_frame != frame:
		_apply_coalesce_frame = frame
		_apply_coalesce_keys.clear()
	var key: String = "%d|%s" % [int(target.get_instance_id()), String(status_id)]
	if _apply_coalesce_keys.has(key):
		return true
	_apply_coalesce_keys[key] = true
	return false


## 作用：合并同帧重复施加的层数/时限，保留满层和协同但省略施加通知。
## 使用：支持转换状态，仍更新tick调度与显示脏标记。
func _merge_coalesced_status_apply(id: StringName, params: Dictionary) -> bool:
	if id == &"":
		return false
	var definition: Dictionary = _get_status_definition(id)
	if definition.is_empty():
		return false
	definition = _apply_enemy_tier_rules(id, definition)
	if definition.is_empty():
		return true
	var converted_status_id: StringName = StringName(String(definition.get("convert_to_status", "")))
	if converted_status_id != &"" and converted_status_id != id:
		var converted_params: Dictionary = params.duplicate(true)
		for key: Variant in definition.keys():
			if key != "convert_to_status" and not converted_params.has(key):
				converted_params[key] = definition[key]
		return _merge_coalesced_status_apply(converted_status_id, converted_params)
	var stack_data: Dictionary = _resolve_status_stack_data(id, definition, params)
	var current_stacks: int = int(stack_data.get("current_stacks", 0))
	var status: Dictionary = _build_status_runtime_data(id, definition, params, stack_data)
	var new_stacks: int = int(stack_data.get("new_stacks", 0))
	var max_stacks: int = int(stack_data.get("max_stacks", 1))
	var next_tick_interval: float = float(status["tick_interval"])
	status["tick_timer"] = minf(float(status.get("tick_timer", next_tick_interval)), next_tick_interval)
	_statuses[id] = status
	_sync_status_tick_scheduler(id, status)
	_pending_status_update_delta = 0.0
	_mark_status_display_dirty()
	if _status_visual_refresh_needed_after_apply(id, definition):
		_queue_status_visual_refresh()
	if new_stacks >= max_stacks and (current_stacks < max_stacks or (id == &"chilled" and _freeze_immunity_remaining <= 0.0 and not has_status(&"frozen"))):
		_handle_max_stack_reached(id, status)
	_apply_poison_slow_synergy()
	return true


## 作用：复制已有状态并计算加层上限和本次持续时间。
## 使用：stacks至少加1，max_stacks至少1，时长至少0.05秒。
func _resolve_status_stack_data(id: StringName, definition: Dictionary, params: Dictionary) -> Dictionary:
	var status: Dictionary = _statuses.get(id, {}).duplicate(true)
	var stacks_to_add: int = maxi(int(params.get("stacks", params.get("stack", 1))), 1)
	var max_stacks: int = maxi(int(params.get("max_stacks", definition.get("max_stacks", 1))), 1)
	if id == &"chilled":
		var player: Node = _get_player()
		var query: RefCounted = preload("res://scripts/modifiers/modifier_query.gd").for_skill(null, player)
		var values: Dictionary = preload("res://scripts/modifiers/modifier_aggregator.gd").collect(query)
		max_stacks = maxi(int(values.get("chilled_freeze_threshold_override", max_stacks)), 1)
	var current_stacks: int = int(status.get("stacks", 0))
	var duration: float = float(definition.get("duration", 3.0)) if String(definition.get("refresh_rule", "")) == "keep_first_deadline" else maxf(float(params.get("duration", definition.get("duration", 1.0))), 0.0)
	if id == &"frozen" and params.has("duration"):
		duration *= 0.125 if _is_boss() else (0.5 / 1.2 if _is_elite() else 1.0)
	if id in [&"chilled", &"frozen"]:
		var query: RefCounted = preload("res://scripts/modifiers/modifier_query.gd").for_skill(null, _get_player())
		var values: Dictionary = preload("res://scripts/modifiers/modifier_aggregator.gd").collect(query)
		duration *= maxf(1.0 + float(values.get("%s_duration_multiplier_add" % id, 0.0)), 0.05)
	return {
		"status": status,
		"current_stacks": current_stacks,
		"new_stacks": mini(current_stacks + stacks_to_add, max_stacks),
		"max_stacks": max_stacks,
		"duration": duration
	}


## 作用：合并定义与参数生成包含tick、来源追踪、减速及易伤的运行状态。
## 使用：续时取较长剩余时间；返回字典待写入状态表。
func _build_status_runtime_data(id: StringName, definition: Dictionary, params: Dictionary, stack_data: Dictionary) -> Dictionary:
	var status: Dictionary = stack_data.get("status", {}).duplicate(true)
	var max_stacks: int = int(stack_data.get("max_stacks", 1))
	status["id"] = id
	status["definition"] = definition
	status["stacks"] = int(stack_data.get("new_stacks", 0))
	var duration: float = float(stack_data.get("duration", 1.0))
	var refresh_rule: String = String(definition.get("refresh_rule", "refresh_duration"))
	if refresh_rule == "keep_first_deadline" and status.has("duration_remaining"):
		pass
	elif refresh_rule == "strongest_only":
		status["duration_remaining"] = maxf(float(status.get("duration_remaining", 0.0)), duration)
	else:
		status["duration_remaining"] = duration
	status["tick_interval"] = maxf(float(params.get("tick_interval", definition.get("tick_interval", 1.0))), 0.05)
	var configured_tick_damage: float = maxf(float(params.get("tick_damage", params.get("damage", definition.get("damage", 0.0)))), 0.0)
	configured_tick_damage = maxf(configured_tick_damage * maxf(1.0 + float(params.get("damage_multiplier_add", 0.0)), 0.0), 0.0)
	status["tick_damage"] = configured_tick_damage
	status["damage_type"] = StringName(String(params.get("damage_type", definition.get("damage_type", id))))
	status["element"] = StringName(String(params.get("element", definition.get("element", id))))
	if params.has("power"):
		status["power"] = maxf(float(params.get("power", 0.0)), 0.0)
	status["on_tick_effects"] = _get_array(definition.get("on_tick_effects", definition.get("on_tick", [])))
	status["on_expire_effects"] = _get_array(definition.get("on_expire", definition.get("on_expire_effects", [])))
	status = DamageTraceContextScript.apply_to_status_params(status, params)
	status["slow_percent"] = clampf(float(params.get("slow_percent", definition.get("slow_percent", _get_effect_value(definition, "slow_percent", 0.0)))), 0.0, 0.95)
	if _is_boss() and params.has("boss_slow_percent"):
		status["slow_percent"] = clampf(float(params.get("boss_slow_percent", status["slow_percent"])), 0.0, 0.95)
	status["armor_break_multiplier_add"] = maxf(
		float(params.get("armor_break_multiplier_add", definition.get("armor_break_multiplier_add", _get_effect_value(definition, "physical_damage_taken_multiplier_add_per_stack", 0.0)))),
		0.0
	)
	if params.has("direct_damage_multiplier_add_per_stack"):
		status["direct_damage_multiplier_add_per_stack"] = float(params.get("direct_damage_multiplier_add_per_stack", 0.0))
	for vulnerability_key: String in [
		"all_damage_taken_multiplier_add_per_stack",
		"fire_damage_taken_multiplier_add_per_stack",
		"direct_magical_damage_taken_multiplier_add_per_stack",
		"direct_damage_taken_multiplier_add_per_stack",
	]:
		if params.has(vulnerability_key):
			status[vulnerability_key] = float(params.get(vulnerability_key, 0.0))
	if params.has("full_stack_explosion_damage_taken_multiplier_add"):
		status["full_stack_explosion_damage_taken_multiplier_add"] = float(params.get("full_stack_explosion_damage_taken_multiplier_add", 0.0))
		status["full_stack_required_stacks"] = int(params.get("full_stack_required_stacks", max_stacks))
	return status


## 作用：状态非空时以性能采样包装推进全部状态。
## 使用：delta为待消费的累计秒数。
func update_status_effects(delta: float) -> void:
	var owner: Node = get_parent()
	if owner != null and (owner.is_queued_for_deletion() or (owner.get("current_health") != null and float(owner.get("current_health")) <= 0.0)):
		clear_statuses()
		return
	_status_elapsed_seconds += maxf(delta, 0.0)
	_freeze_immunity_remaining = maxf(_freeze_immunity_ready_at - _status_time_seconds(), 0.0)
	if _statuses.is_empty():
		return
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_update_status_effects_profiled(delta)
	HotPathProfilerScript.end(self, &"status_update_total", hot_path_start)


## 作用：推进状态tick后收集过期快照，统一移除与发事件再刷新协同。
## 使用：避免遍历时删除键；层数变化会标记显示脏。
func _update_status_effects_profiled(delta: float) -> void:
	if delta <= 0.0 or _statuses.is_empty():
		return

	var expired_statuses: Array[StringName] = []
	var expired_snapshots: Dictionary = {}
	var frozen_duration: float = float(_statuses.get(&"frozen", {}).get("duration_remaining", 0.0))
	for id_variant: Variant in _statuses.keys():
		var id: StringName = StringName(String(id_variant))
		if not _statuses.has(id):
			continue
		var status: Dictionary = _statuses[id]
		var previous_stacks: int = int(status.get("stacks", 0))
		var effective_delta: float = delta
		if not _get_dictionary(status.get("pause_sources", {})).is_empty():
			effective_delta = 0.0
		elif id == &"cursed" and frozen_duration > 0.0:
			effective_delta = maxf(delta - frozen_duration, 0.0)
		_advance_status_tick(status, effective_delta)
		if int(status.get("stacks", 0)) != previous_stacks:
			_mark_status_display_dirty()

		if _is_status_expired(status):
			expired_statuses.append(id)
			expired_snapshots[id] = status.duplicate(true)
		else:
			_statuses[id] = status
			_sync_status_tick_scheduler(id, status)

	_expire_statuses(expired_statuses, expired_snapshots)
	if not expired_statuses.is_empty():
		_queue_status_visual_refresh()
	_apply_poison_slow_synergy()


## 作用：先扣持续时间，再为DOT推进调度并在到期时处理伤害。
## 使用：status原地更新；调度已扣delta，因此执行tick时传0。
func _advance_status_tick(status: Dictionary, delta: float) -> void:
	var active_delta: float = minf(maxf(delta, 0.0), maxf(float(status.get("duration_remaining", 0.0)), 0.0))
	if _is_dot_status(status):
		var status_id: StringName = StringName(String(status.get("id", "")))
		if _status_tick_scheduler != null and _status_tick_scheduler.call("advance_and_is_due", self, status_id, status, active_delta):
			_update_damage_over_time(status, 0.0)
	StatusEffectTickHelperScript.advance_duration(status, delta)


## 作用：判断层数用尽或剩余时间非正。
## 使用：返回布尔值，移除和过期效果由管理器负责。 本入口委托StatusEffectTickHelperScript.is_status_expired执行。
func _is_status_expired(status: Dictionary) -> bool:
	return StatusEffectTickHelperScript.is_status_expired(status)


## 作用：移除过期状态并注销tick，执行过期效果与事件。
## 使用：expired_snapshots保存移除前内容；结束标记显示脏。
func _expire_statuses(expired_statuses: Array[StringName], expired_snapshots: Dictionary) -> void:
	for id: StringName in expired_statuses:
		if id == &"cursed":
			resolve_cursed(&"natural")
			continue
		_statuses.erase(id)
		_unregister_status_tick(id)
		var expired_status: Dictionary = _get_dictionary(expired_snapshots.get(id, {}))
		if id == &"frozen":
			_begin_freeze_immunity(maxf(-float(expired_status.get("duration_remaining", 0.0)), 0.0))
		_execute_status_effects(expired_status, "on_expire_effects")
		_emit_status_skill_event(&"status_expired", id, expired_status)
		_emit_profiler_status_event(&"status_expired", id, expired_status)
	if not expired_statuses.is_empty():
		_mark_status_display_dirty()

func _begin_freeze_immunity(elapsed_after_ending: float = 0.0) -> void:
	var duration: float = 2.0 if _is_boss() else (1.5 if _is_elite() else 0.8)
	_freeze_immunity_remaining = maxf(duration - elapsed_after_ending, 0.0)
	_freeze_immunity_ready_at = _status_time_seconds() + _freeze_immunity_remaining


## 作用：查询宿主运行表是否存在指定状态。
## 使用：status_id转换为StringName后查键；过期清理由更新时间处理。
func has_status(status_id: Variant) -> bool:
	return StatusEffectQueryScript.has_status(_statuses, status_id)

## 先删除待结算诅咒，再执行输出及通知；重入/死亡均不重复结算。
func resolve_cursed(reason: StringName) -> bool:
	if not _statuses.has(&"cursed"):
		return false
	var status: Dictionary = _statuses[&"cursed"].duplicate(true)
	_statuses.erase(&"cursed")
	_unregister_status_tick(&"cursed")
	_mark_status_display_dirty()
	var target: Node = get_parent()
	if target == null or target.is_queued_for_deletion() or (target.get("current_health") != null and float(target.get("current_health")) <= 0.0):
		return false
	_resolution_nonce += 1
	var before: float = float(target.get("current_health")) if target.get("current_health") != null else 0.0
	if before > 0.0 and before <= float(target.get("max_health")) * 0.4:
		var query: RefCounted = preload("res://scripts/modifiers/modifier_query.gd").for_skill(null, _get_player())
		var values: Dictionary = preload("res://scripts/modifiers/modifier_aggregator.gd").collect(query)
		var bonus: float = clampf(float(values.get("cursed_low_hp_damage_multiplier_add", 0.0)), 0.0, 0.4)
		if _is_boss(): bonus *= 0.3
		status["power"] = float(status.get("power", 0.0)) * (1.0+bonus)
	_execute_status_effects(status, "on_expire_effects")
	var after: float = float(target.get("current_health")) if is_instance_valid(target) and target.get("current_health") != null else 0.0
	var context: Dictionary = _build_status_event_context(&"cursed", status)
	context["resolution_id"] = "%d:%d" % [get_instance_id(), _resolution_nonce]
	context["resolution_reason"] = reason
	context["stacks"] = int(status.get("stacks", 0))
	context["resolved_damage"] = maxf(before - after, 0.0)
	var bus: Node = _get_skill_event_bus()
	if bus != null:
		bus.call("emit_skill_event", &"cursed_resolved", context)
	_emit_status_skill_event(&"status_expired", &"cursed", status)
	_emit_profiler_status_event(&"status_expired", &"cursed", status)
	_queue_status_visual_refresh()
	return true

func pause_status(status_id: StringName, source_id: StringName) -> void:
	if not _statuses.has(status_id) or source_id == &"":
		return
	var status: Dictionary = _statuses[status_id]
	var sources: Dictionary = status.get("pause_sources", {})
	sources[source_id] = true
	status["pause_sources"] = sources

func resume_status(status_id: StringName, source_id: StringName) -> void:
	if _statuses.has(status_id):
		var status: Dictionary = _statuses[status_id]
		var sources: Dictionary = status.get("pause_sources", {})
		sources.erase(source_id)


## 作用：读取宿主指定状态的叠层数。
## 使用：status_id为状态标识，缺失返回0；委托StatusEffectQuery查询。
func get_status_stack(status_id: Variant) -> int:
	return StatusEffectQueryScript.get_status_stack(_statuses, status_id)


## 作用：更新已有运行状态的可扩展字段并按需续时。
## 使用：禁止改id/definition/stacks，更新后重同步tick和显示。
func merge_status_fields(status_id: Variant, fields: Dictionary, duration: float = 0.0) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"" or not _statuses.has(id):
		return false

	var status: Dictionary = _statuses[id]
	for key_variant: Variant in fields.keys():
		var key: String = String(key_variant)
		if key == "" or key == "id" or key == "definition" or key == "stacks":
			continue
		status[key] = fields[key_variant]
	if duration > 0.0:
		status["duration_remaining"] = maxf(float(status.get("duration_remaining", 0.0)), duration)
	_statuses[id] = status
	_sync_status_tick_scheduler(id, status)
	_mark_status_display_dirty()
	return true


## 作用：通过通用叠层消费入口移除一层shock。
## 使用：返回状态是否存在并完成消费。
func consume_shock_stack() -> bool:
	return consume_status_stack(&"shock", 1)


## 作用：扣至少一层，耗尽则移除并注销tick。
## 使用：不会执行过期效果；标记显示和视觉刷新。
func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"" or not _statuses.has(id):
		return false

	var status: Dictionary = _statuses[id]
	var stacks: int = int(status.get("stacks", 0)) - maxi(stack_count, 1)
	if stacks <= 0:
		_statuses.erase(id)
		_unregister_status_tick(id)
		if id == &"frozen": _begin_freeze_immunity()
	else:
		status["stacks"] = stacks
		_statuses[id] = status

	_mark_status_display_dirty()
	_queue_status_visual_refresh()
	return true


## 作用：扣指定非负时长，耗尽时执行过期效果和事件。
## 使用：状态缺失返回false，结束后更新显示视觉与毒协同。
func consume_status_duration(status_id: Variant, seconds: float) -> bool:
	var id: StringName = StringName(String(status_id))
	if id == &"" or not _statuses.has(id):
		return false

	var status: Dictionary = _statuses[id]
	status["duration_remaining"] = float(status.get("duration_remaining", 0.0)) - maxf(seconds, 0.0)
	if float(status.get("duration_remaining", 0.0)) <= 0.0:
		if id == &"cursed":
			return resolve_cursed(&"forced")
		_statuses.erase(id)
		_unregister_status_tick(id)
		if id == &"frozen": _begin_freeze_immunity()
		_execute_status_effects(status, "on_expire_effects")
		_emit_status_skill_event(&"status_expired", id, status)
		_emit_profiler_status_event(&"status_expired", id, status)
	else:
		_statuses[id] = status

	_mark_status_display_dirty()
	_queue_status_visual_refresh()
	_apply_poison_slow_synergy()
	return true


## 作用：导出宿主各状态ID、层数、时限和tick/元素信息。
## 使用：返回独立简化快照数组，供显示与事件读取。
func get_status_snapshot() -> Array[Dictionary]:
	return StatusEffectQueryScript.get_status_snapshot(_statuses)


## 作用：累计非负delta并与最近状态到期/tick时机比较。
## 使用：空表清累计返回false，true后宿主应消费累计值。
func should_update_status_effects(delta: float) -> bool:
	if _statuses.is_empty():
		_pending_status_update_delta = 0.0
		return false
	_pending_status_update_delta += maxf(delta, 0.0)
	return _pending_status_update_delta >= _next_status_update_delay()


## 作用：取出累计更新时间并清零。
## 使用：should_update返回true后交给update_status_effects，避免丢失间隔。
func consume_pending_status_update_delta() -> float:
	var pending_delta: float = _pending_status_update_delta
	_pending_status_update_delta = 0.0
	return pending_delta


## 作用：检查当前状态表是否非空。
## 使用：用于宿主决定是否推进状态。
func has_active_statuses() -> bool:
	return not _statuses.is_empty()


## 作用：读取并清除显示脏标记。
## 使用：显示层只在true时重建状态文本。
func consume_status_display_dirty() -> bool:
	var dirty: bool = _status_display_dirty
	_status_display_dirty = false
	return dirty


## 作用：清空状态并注销所有tick，取消视觉刷新标记并立刻隐藏/刷新视觉。
## 使用：重置或清状态时调用，不执行逐个过期效果。
func clear_statuses() -> void:
	_statuses.clear()
	_reaction_queue.clear()
	_freeze_immunity_remaining = 0.0
	_freeze_immunity_ready_at = 0.0
	_status_elapsed_seconds = 0.0
	_pending_status_update_delta = 0.0
	if _status_tick_scheduler != null:
		_status_tick_scheduler.call("unregister_all_for_owner", self)
	_status_visual_refresh_queued = false
	_mark_status_display_dirty()
	_refresh_status_visual()


## 作用：检查固定冻结、冰冻、眩晕、麻痹状态是否存在。
## 使用：返回移动锁定标志。
func is_movement_frozen() -> bool:
	for status_id: StringName in MOVEMENT_LOCK_STATUS_IDS:
		if has_status(status_id):
			return true
	return false


## 作用：按状态查询减速系数并应用Boss/精英上限。
## 使用：不修改状态；冻结应由is_movement_frozen先判断。
func get_move_speed_multiplier() -> float:
	return StatusEffectQueryScript.movement_speed_multiplier(_statuses, MOVEMENT_LOCK_STATUS_IDS, _is_boss(), _is_elite())


## 作用：将易伤加法总量转换为1+总量承伤倍率。
## 使用：damage_type实际用于元素键、category用于伤害类型键。
func get_damage_taken_multiplier(damage_type: Variant = &"", category: Variant = &"") -> float:
	return 1.0 + get_vulnerability_total(damage_type, category, {})


## 作用：委托状态查询合并易伤并传入宿主阶级。
## 使用：packet区分下一击和爆炸易伤资格，返回加法总量。
func get_vulnerability_total(damage_type: Variant = &"", category: Variant = &"", packet: Variant = {}) -> float:
	var bonus: float = 0.1 if _is_boss() and _status_time_seconds() < _boss_frost_weak_until and (String(damage_type) == "frost" or String(category) == "frost") else 0.0
	return StatusEffectQueryScript.vulnerability_total(_statuses, damage_type, category, packet, _is_boss(), _is_elite()) + bonus


## 作用：以性能采样包装单个状态的DOT处理。
## 使用：status原地更新tick计时器与可消耗层数。
func _update_damage_over_time(status: Dictionary, delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_update_damage_over_time_profiled(status, delta)
	HotPathProfilerScript.end(self, &"status_tick", hot_path_start)


## 作用：执行到期tick、伤害、效果与事件，必要时消耗叠层并推进计时器。
## 使用：满足纯Power burning条件可合并多次tick，普通路径逐次循环。
func _update_damage_over_time_profiled(status: Dictionary, delta: float) -> void:
	var tick_interval: float = maxf(
		float(status.get("tick_interval", 1.0)) * float(status.get("tick_interval_multiplier", 1.0)),
		0.05
	)
	var tick_timer: float = float(status.get("tick_timer", tick_interval)) - delta
	var tick_damage: float = float(status.get("tick_damage", 0.0))
	var stacks: int = int(status.get("stacks", 1))
	var status_id: StringName = StringName(String(status.get("id", "")))
	var coalesced_tick_count: int = _coalesced_dot_tick_count(status, tick_timer, tick_interval, stacks)
	if coalesced_tick_count > 1:
		_apply_coalesced_damage_over_time(status, status_id, tick_damage, tick_interval, coalesced_tick_count)
		if _should_consume_stack_on_tick(status):
			stacks = maxi(stacks - coalesced_tick_count, 0)
			status["stacks"] = stacks
		tick_timer += tick_interval * coalesced_tick_count
		status["tick_timer"] = tick_timer
		return

	while tick_timer <= 0.0 and _has_status_tick_work(status) and float(status.get("duration_remaining", 0.0)) > 0.0:
		_emit_profiler_status_event(&"status_tick_due", status_id, status, {"tick_interval": tick_interval})
		if tick_damage > 0:
			_apply_tick_damage(_get_tier_scaled_dot_damage(status, tick_damage * stacks), status)
		_execute_status_effects(status, "on_tick_effects")
		_emit_status_skill_event(&"status_tick", status_id, status)
		_emit_profiler_status_event(&"status_tick_applied", status_id, status, {
			"tick_damage": tick_damage,
			"tick_interval": tick_interval
		})
		if _should_consume_stack_on_tick(status):
			stacks = maxi(stacks - 1, 0)
			status["stacks"] = stacks
			if stacks <= 0:
				break
		tick_timer += tick_interval

	status["tick_timer"] = tick_timer


## 作用：计算可合并的积压tick数，消耗叠层时不超过当前层数。
## 使用：不能合并/未到期/已过期返回1。
func _coalesced_dot_tick_count(status: Dictionary, tick_timer: float, tick_interval: float, stacks: int) -> int:
	if tick_timer > 0.0 or not _can_coalesce_dot_ticks(status) or not _has_status_tick_work(status):
		return 1
	if float(status.get("duration_remaining", 0.0)) <= 0.0:
		return 1

	var due_ticks: int = int(floor(-tick_timer / tick_interval)) + 1
	if _should_consume_stack_on_tick(status):
		due_ticks = mini(due_ticks, maxi(stacks, 0))
	return maxi(due_ticks, 1)


## 作用：仅允许没有固定tick_damage且全部为纯Power damage效果的burning合并。
## 使用：禁止带逐层Power或显式伤害量，避免改变状态效果语义。
func _can_coalesce_dot_ticks(status: Dictionary) -> bool:
	if StringName(String(status.get("id", ""))) != &"burning":
		return false
	if float(status.get("tick_damage", 0.0)) > 0.0:
		return false

	var effects: Array = _get_array(status.get("on_tick_effects", []))
	if effects.is_empty():
		return false
	for effect_variant: Variant in effects:
		if not (effect_variant is Dictionary):
			return false
		var effect: Dictionary = effect_variant
		if String(effect.get("type", "")) != "damage":
			return false
		if not effect.has("power_scale") or effect.has("power_scale_per_stack") or effect.has("amount") or effect.has("amount_per_stack"):
			return false
	return true


## 作用：复制状态并放大tick效果，一次执行并携带有效tick数量事件。
## 使用：tick_count为积压数量，原始状态计时/层数由调用方更新。
func _apply_coalesced_damage_over_time(status: Dictionary, status_id: StringName, tick_damage: float, tick_interval: float, tick_count: int) -> void:
	var coalesced_status: Dictionary = status.duplicate(true)
	coalesced_status["coalesced_tick_count"] = tick_count
	coalesced_status["effective_tick_count"] = tick_count
	coalesced_status["on_tick_effects"] = _coalesced_status_tick_effects(_get_array(status.get("on_tick_effects", [])), tick_count)
	_emit_profiler_status_event(&"status_tick_due", status_id, coalesced_status, {
		"coalesced_tick_count": tick_count,
		"tick_interval": tick_interval
	})
	_execute_status_effects(coalesced_status, "on_tick_effects")
	_emit_status_skill_event(&"status_tick", status_id, coalesced_status)
	_emit_profiler_status_event(&"status_tick_applied", status_id, coalesced_status, {
		"coalesced_tick_count": tick_count,
		"tick_damage": tick_damage,
		"tick_interval": tick_interval
	})


## 作用：复制每项damage效果并乘以合并tick数的power_scale。
## 使用：仅在纯Power效果已验证可合并后调用。
func _coalesced_status_tick_effects(effects: Array, tick_count: int) -> Array:
	var coalesced_effects: Array = []
	for effect_variant: Variant in effects:
		var effect: Dictionary = (effect_variant as Dictionary).duplicate(true)
		effect["power_scale"] = float(effect.get("power_scale", 0.0)) * float(tick_count)
		coalesced_effects.append(effect)
	return coalesced_effects


## 作用：为宿主构造状态DOT严格包并调用take_damage。
## 使用：amount为阶级缩放后小数值，强目标设置忽略重复来源阶级倍率。
func _apply_tick_damage(amount: float, status: Dictionary = {}) -> void:
	var owning_node: Node = get_parent()
	if owning_node == null or amount <= 0:
		return

	var tick_packet_args: Dictionary = {
		"target": owning_node,
		"status": status,
		"amount": amount,
		"element": StringName(String(status.get("element", status.get("id", "status")))),
		"damage_type": StringName(String(status.get("damage_type", &"status_dot"))),
		"ignore_target_class_origin_modifier": _is_boss() or _is_elite()
	}
	if owning_node.has_method("take_damage"):
		owning_node.call(&"take_damage", DamagePacketBuilderScript.from_status_dot_object(tick_packet_args))


## 作用：按DOT性质和tick工作登记或注销状态。
## 使用：运行状态变化后调用，scheduler为空时无操作。
func _sync_status_tick_scheduler(status_id: StringName, status: Dictionary) -> void:
	if _status_tick_scheduler == null:
		return
	if _is_dot_status(status) and _has_status_tick_work(status):
		_status_tick_scheduler.call("register_status", self, status_id, status)
	else:
		_status_tick_scheduler.call("unregister_status", self, status_id)


## 作用：移除一个状态的tick登记。
## 使用：状态移除/耗尽时调用。
func _unregister_status_tick(status_id: StringName) -> void:
	if _status_tick_scheduler != null:
		_status_tick_scheduler.call("unregister_status", self, status_id)


## 作用：取剩余时限和DOT计时器中的最早更新延迟。
## 使用：无有效项返回0.1，返回值限制非负。
func _next_status_update_delay() -> float:
	var next_delay: float = INF
	for status_variant: Variant in _statuses.values():
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		next_delay = minf(next_delay, maxf(float(status.get("duration_remaining", 0.0)), 0.0))
		if _is_dot_status(status) and _has_status_tick_work(status):
			var tick_interval: float = maxf(
				float(status.get("tick_interval", 1.0)) * float(status.get("tick_interval_multiplier", 1.0)),
				0.05
			)
			next_delay = minf(next_delay, maxf(float(status.get("tick_timer", tick_interval)), 0.0))
	if next_delay == INF:
		return 0.1
	return maxf(next_delay, 0.0)


## 作用：判断状态有正tick_damage或非空on_tick_effects。
## 使用：用于避免没有tick工作的调度。 本入口委托StatusEffectTickHelperScript.has_status_tick_work执行。
func _has_status_tick_work(status: Dictionary) -> bool:
	return StatusEffectTickHelperScript.has_status_tick_work(status)


## 作用：优先读运行状态开关，否则读定义默认开关。
## 使用：返回每次tick是否消耗一层。 本入口委托StatusEffectTickHelperScript.should_consume_stack_on_tick执行。
func _should_consume_stack_on_tick(status: Dictionary) -> bool:
	return StatusEffectTickHelperScript.should_consume_stack_on_tick(status)


## 作用：计算固定tick伤害乘层数及damage效果的Power缩放总值。
## 使用：只计damage效果，不应用阶级减伤和取整。 本入口委托StatusEffectTickHelperScript.tick_damage_total执行。
func _get_status_tick_damage_total(status: Dictionary) -> float:
	return StatusEffectTickHelperScript.tick_damage_total(status)


## 作用：以性能采样包装满层反应入队处理。
## 使用：仅首次跨越层数上限调用，避免每次刷新重复反应。
func _handle_max_stack_reached(status_id: StringName, status: Dictionary) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_handle_max_stack_reached_profiled(status_id, status)
	HotPathProfilerScript.end(self, &"status_reaction", hot_path_start)


## 作用：将满层状态入队并尝试处理队列。
## 使用：重入期间只入队，由外层循环继续消费。
func _handle_max_stack_reached_profiled(status_id: StringName, status: Dictionary) -> void:
	_enqueue_status_reaction(status_id, status)
	_process_status_reaction_queue()


## 作用：深复制满层状态并保存反应队列项。
## 使用：空status_id不入队。
func _enqueue_status_reaction(status_id: StringName, status: Dictionary) -> void:
	if status_id == &"":
		return
	_reaction_queue.append({
		"status_id": status_id,
		"status": status.duplicate(true)
	})


## 作用：用重入标志串行消费全部反应项。
## 使用：反应内再次施加状态可继续入队，避免递归处理嵌套。
func _process_status_reaction_queue() -> void:
	if _processing_reaction_queue:
		return
	_processing_reaction_queue = true
	while not _reaction_queue.is_empty():
		var item: Dictionary = _reaction_queue.pop_front()
		_execute_status_reaction(StringName(String(item.get("status_id", ""))), _get_dictionary(item.get("status", {})))
	_processing_reaction_queue = false


## 作用：先发满层事件，再施加配置转换状态并发送配置专用事件。
## 使用：status为入队快照，事件使用当前宿主上下文。
func _execute_status_reaction(status_id: StringName, status: Dictionary) -> void:
	if status_id == &"chilled":
		_emit_status_skill_event(&"freeze_attempted", status_id, status)
		if _freeze_immunity_remaining > 0.0 or has_status(&"frozen"):
			return
		consume_status_stack(&"chilled", maxi(get_status_stack(&"chilled"), 1))
	_emit_status_skill_event(&"status_max_stack_reached", status_id, status)
	_emit_profiler_status_event(&"status_reaction_triggered", status_id, status, {"trigger": &"status_max_stack_reached"})
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	var max_stack_status: StringName = StringName(String(definition.get("max_stack_status", "")))
	if max_stack_status != &"" and max_stack_status != status_id:
		var conversion_params: Dictionary = DamageTraceContextScript.apply_to_status_params({}, status)
		apply_status(max_stack_status, conversion_params)
	var max_stack_event: StringName = StringName(String(definition.get("max_stack_event", "")))
	if max_stack_event != &"":
		var event_context: Dictionary = _build_status_event_context(status_id, status)
		event_context["max_stack_event"] = max_stack_event
		var event_bus: Node = _get_skill_event_bus()
		if event_bus != null and event_bus.has_method("emit_skill_event"):
			event_bus.call("emit_skill_event", max_stack_event, event_context)


## 作用：读取tick/expire效果并适配为action交由技能总线执行。
## 使用：effects_key指定运行列表；缺总线或空效果无操作。
func _execute_status_effects(status: Dictionary, effects_key: String) -> void:
	var effects: Array = _get_array(status.get(effects_key, []))
	if effects.is_empty():
		return
	var event_bus: Node = _get_skill_event_bus()
	if event_bus == null or not event_bus.has_method("execute_adapted_actions"):
		return
	var status_id: StringName = StringName(String(status.get("id", "")))
	var output_status: Dictionary = status
	if status_id == &"burning" and effects_key == "on_tick_effects" and preload("res://scripts/skills/fire_ground_policy.gd").burning_bonus(get_parent() as Node2D, _get_player()) > 0.0:
		output_status = status.duplicate(true)
		output_status["power"] = float(status.get("power", 0.0)) * (1.0+preload("res://scripts/skills/fire_ground_policy.gd").burning_bonus(get_parent() as Node2D, _get_player()))
	var actions: Array = SkillEffectAdapterScript.to_actions(_prepare_status_effects(effects, output_status))
	event_bus.call("execute_adapted_actions", actions, _build_status_event_context(status_id, output_status))


## 作用：复制效果并将逐层Power系数换算为当前叠层的power_scale。
## 使用：不改定义列表，已有power_scale优先。
func _prepare_status_effects(effects: Array, status: Dictionary) -> Array:
	var prepared: Array = []
	var stacks: float = float(maxi(int(status.get("stacks", 1)), 1))
	for effect_variant: Variant in effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = (effect_variant as Dictionary).duplicate(true)
		if String(effect.get("type", "")) == "damage":
			effect["uses_character_damage_multiplier"] = false
		if effect.has("power_scale_per_stack") and not effect.has("power_scale"):
			effect["power_scale"] = float(effect.get("power_scale_per_stack", 0.0)) * stacks
		prepared.append(effect)
	return prepared


## 作用：向可用技能总线发送状态事件和完整来源上下文。
## 使用：event_name、status_id及状态快照描述事件。
func _emit_status_skill_event(event_name: StringName, status_id: StringName, status: Dictionary) -> void:
	var event_bus: Node = _get_skill_event_bus()
	if event_bus != null and event_bus.has_method("emit_skill_event"):
		event_bus.call("emit_skill_event", event_name, _build_status_event_context(status_id, status))


## 作用：构造目标、玩家、来源、Power、位置和技能/遗物服务引用。
## 使用：缺来源实例时用目标/状态/攻击者生成稳定ID；状态深复制。
func _build_status_event_context(status_id: StringName, status: Dictionary) -> Dictionary:
	var target: Node = get_parent()
	var position: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	var player: Node = _get_player()
	var source_skill_id: StringName = StringName(String(status.get("source_skill_id", status_id)))
	if source_skill_id == &"":
		source_skill_id = status_id
	var source_instance_id: String = String(status.get("source_instance_id", ""))
	if source_instance_id == "":
		source_instance_id = DamageSourceIdentityScript.for_status_dot(target, status_id, status.get("attacker_id", ""))
	return {
		"target": target,
		"enemy": target,
		"caster": player,
		"owner": player,
		"status_id": status_id,
		"status": status.duplicate(true),
		"skill_id": source_skill_id,
		"source_id": source_skill_id,
		"source_origin_id": StringName(String(status.get("source_origin_id", ""))),
		"source_skill_id": source_skill_id,
		"source_instance_id": source_instance_id,
		"power": float(status.get("power", status.get("tick_damage", 0.0))),
		"status_power_snapshot": true,
		"origin_skill_id": status.get("origin_skill_id", source_skill_id),
		"parent_event_id": int(status.get("event_id", 0)),
		"proc_depth": int(status.get("proc_depth", 0)),
		"is_copy": bool(status.get("is_copy", false)),
		"can_generate_secondary_proc": bool(status.get("can_generate_secondary_proc", true)),
		"position": position,
		"parent": target.get_parent() if target != null else null,
		"event_bus": _get_skill_event_bus(),
		"skill_manager": player.get_node_or_null("SkillManager") if player != null else null,
		"relic_manager": player.get_node_or_null("RelicManager") if player != null else null,
		"target_group": &"enemies"
	}


## 作用：优先返回宿主本地总线，否则查询玩家总线。
## 使用：找不到玩家或总线返回null。
func _get_skill_event_bus() -> Node:
	var owner: Node = get_parent()
	if owner != null:
		var local_bus: Node = owner.get_node_or_null("SkillEventBus")
		if local_bus != null:
			return local_bus
	var player: Node = _get_player()
	return player.get_node_or_null("SkillEventBus") if player != null else null


## 作用：查询player组首节点，否则用带技能总线的宿主。
## 使用：场景树缺失返回null。
func _get_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group(&"player")
	if player != null:
		return player
	var owner: Node = get_parent()
	if owner != null and owner.has_node("SkillEventBus"):
		return owner
	return null


## 作用：以性能采样包装状态叠加视觉刷新。
## 使用：由清空或deferred刷新调用。
func _refresh_status_visual() -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_refresh_status_visual_profiled()
	HotPathProfilerScript.end(self, &"status_visual_update", hot_path_start)


## 作用：选最高优先级视觉并播放状态，视觉身份相同则省略重复应用。
## 使用：无视觉隐藏overlay，设置z_index和当前优先级。
func _refresh_status_visual_profiled() -> void:
	var visual: Dictionary = _get_active_status_visual()
	if visual.is_empty():
		_hide_status_visual()
		return

	var overlay: Node2D = _get_or_create_status_visual_overlay()
	if overlay == null:
		return

	var state: String = String(visual.get("state", visual.get("animation", visual.get("status_id", "idle"))))
	var visual_key: String = _status_visual_identity(visual, state)
	if overlay.visible and visual_key == _status_visual_key:
		return

	overlay.visible = true
	overlay.z_index = int(visual.get("overlay_z_index", 20))
	_status_visual_key = visual_key
	_status_visual_priority = float(visual.get("priority", 0.0))
	VisualConfigApplierScript.play_state(overlay, visual, state, "idle")
	_emit_profiler_status_event(&"status_visual_update", StringName(String(visual.get("status_id", ""))), {}, {
		"visual_key": visual_key,
		"state": state
	})


## 作用：合并视觉刷新请求并deferred调用一次刷新。
## 使用：避免同帧多次施加重建视觉。
func _queue_status_visual_refresh() -> void:
	if _status_visual_refresh_queued:
		return
	_status_visual_refresh_queued = true
	call_deferred("_flush_status_visual_refresh")


## 作用：标记状态文本快照需要刷新。
## 使用：宿主通过consume_status_display_dirty消费。
func _mark_status_display_dirty() -> void:
	_status_display_dirty = true


## 作用：消费待刷新标记并执行视觉刷新。
## 使用：deferred回调，标记已取消时无操作。
func _flush_status_visual_refresh() -> void:
	if not _status_visual_refresh_queued:
		return
	_status_visual_refresh_queued = false
	_refresh_status_visual()


## 作用：判断新状态资源和优先级是否值得刷新当前overlay。
## 使用：同身份不刷新，低于当前优先级不抢占。
func _status_visual_refresh_needed_after_apply(status_id: StringName, definition: Dictionary) -> bool:
	var visual: Dictionary = _get_dictionary(definition.get("visual", {}))
	if not _has_visual_resource(visual):
		return false

	visual = visual.duplicate(true)
	visual["status_id"] = status_id
	var state: String = String(visual.get("state", visual.get("animation", visual.get("status_id", "idle"))))
	var visual_key: String = _status_visual_identity(visual, state)
	if _status_visual_overlay == null or not is_instance_valid(_status_visual_overlay) or not _status_visual_overlay.visible:
		return true
	if visual_key == _status_visual_key:
		return false
	return float(visual.get("priority", 0.0)) >= _status_visual_priority


## 作用：遍历状态选择最高优先级且有可用资源的visual。
## 使用：返回深复制并补status_id，相同优先级保留先出现项。
func _get_active_status_visual() -> Dictionary:
	var best_visual: Dictionary = {}
	var best_priority: float = -INF
	for status_variant: Variant in _statuses.values():
		if not (status_variant is Dictionary):
			continue
		var status: Dictionary = status_variant
		var definition: Dictionary = _get_dictionary(status.get("definition", {}))
		var visual: Dictionary = _get_dictionary(definition.get("visual", {}))
		if not _has_visual_resource(visual):
			continue
		var priority: float = float(visual.get("priority", 0.0))
		if priority <= best_priority:
			continue
		best_priority = priority
		best_visual = visual.duplicate(true)
		best_visual["status_id"] = StringName(String(status.get("id", "")))
	return best_visual


## 作用：检查texture、sprite_frames或sprite_sheet资源配置是否存在。
## 使用：仅检测字段，不加载资源。
func _has_visual_resource(visual: Dictionary) -> bool:
	return String(visual.get("texture", "")) != "" or String(visual.get("sprite_frames", "")) != "" or visual.has("sprite_sheet")


## 作用：复用有效overlay或在二维宿主创建隐藏状态视觉节点。
## 使用：宿主非Node2D返回null；创建时发可选性能事件。
func _get_or_create_status_visual_overlay() -> Node2D:
	if _status_visual_overlay != null and is_instance_valid(_status_visual_overlay):
		return _status_visual_overlay

	var owning_node: Node2D = get_parent() as Node2D
	if owning_node == null:
		return null

	var existing_overlay: Node2D = owning_node.get_node_or_null(STATUS_VISUAL_NODE_NAME) as Node2D
	if existing_overlay != null and not existing_overlay.is_queued_for_deletion():
		_status_visual_overlay = existing_overlay
		return _status_visual_overlay

	_status_visual_overlay = Node2D.new()
	_status_visual_overlay.name = STATUS_VISUAL_NODE_NAME
	_status_visual_overlay.visible = false
	owning_node.add_child(_status_visual_overlay)
	_emit_profiler_status_event(&"status_visual_spawn", &"", {}, {"owner": owning_node})
	return _status_visual_overlay


## 作用：隐藏overlay并清当前身份和优先级。
## 使用：无有效overlay时无操作。
func _hide_status_visual() -> void:
	if _status_visual_overlay == null or not is_instance_valid(_status_visual_overlay):
		return
	_status_visual_overlay.visible = false
	_status_visual_key = ""
	_status_visual_priority = -INF


## 作用：组合状态ID、贴图、帧资源和播放状态为缓存身份。
## 使用：用于跳过重复视觉应用。
func _status_visual_identity(visual: Dictionary, state: String) -> String:
	return "%s|%s|%s|%s" % [
		String(visual.get("status_id", "")),
		String(visual.get("texture", "")),
		String(visual.get("sprite_frames", "")),
		state
	]


## 作用：按定义effect.dot或预设燃烧/毒/流血ID判定DOT。
## 使用：用于tick调度，不检查实际伤害伤害量。
func _is_dot_status(status: Dictionary) -> bool:
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	if _get_effect_bool(definition, "dot", false):
		return true
	return DOT_STATUS_IDS.has(StringName(String(status.get("id", ""))))


## 作用：按精英/Boss定义缩放DOT并应用未过期火油燃烧加成。
## 使用：返回非负伤害，Boss火油倍率与普通加法规则不同。
func _get_tier_scaled_dot_damage(status: Dictionary, amount: float) -> float:
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	var multiplier: float = 1.0
	if _is_boss():
		multiplier = float(_get_dictionary(definition.get("boss_modifiers", {})).get("dot_damage_multiplier", 0.65))
	elif _is_elite():
		multiplier = float(_get_dictionary(definition.get("elite_modifiers", {})).get("dot_damage_multiplier", 0.8))
	if StringName(String(status.get("id", ""))) == &"burning":
		var owner: Node = get_parent()
		if owner != null and float(owner.get_meta("fire_oil_burn_damage_until", 0.0)) > float(Time.get_ticks_msec()) / 1000.0:
			if _is_boss():
				multiplier *= maxf(float(owner.get_meta("fire_oil_boss_burn_damage_multiplier", 0.7)), 0.0)
			else:
				multiplier *= maxf(1.0 + float(owner.get_meta("fire_oil_burn_damage_multiplier_add", 0.0)), 0.0)
	if StringName(String(status.get("id", ""))) == &"burning": multiplier *= 1.0+preload("res://scripts/skills/fire_ground_policy.gd").burning_bonus(get_parent() as Node2D, _get_player())
	return maxf(float(amount) * multiplier, 0.0)


## 作用：复制状态定义，转换Boss控制并合并阶级持续时间、层数、减速和下一击易伤规则。
## 使用：duration_multiplier非正表示免疫，返回空字典。
func _apply_enemy_tier_rules(_status_id: StringName, definition: Dictionary) -> Dictionary:
	var result: Dictionary = definition.duplicate(true)
	if _status_id == &"frozen":
		if _is_boss():
			result["duration"] = float(definition.get("boss_duration", 0.15))
		elif _is_elite():
			result["duration"] = float(definition.get("elite_duration", 0.5))
		return result
	var boss_control_conversion: Dictionary = ReactionLimiterScript.apply_boss_control_conversion(get_parent(), _status_id)
	if not boss_control_conversion.is_empty():
		for key: Variant in boss_control_conversion.keys():
			result[key] = boss_control_conversion[key]

	var modifiers: Dictionary = {}
	if _is_boss():
		modifiers = _get_dictionary(definition.get("boss_modifiers", {}))
	elif _is_elite():
		modifiers = _get_dictionary(definition.get("elite_modifiers", {}))

	if modifiers.is_empty():
		return result

	if float(modifiers.get("duration_multiplier", 1.0)) <= 0.0:
		return {}
	if modifiers.has("convert_to_status"):
		result["convert_to_status"] = modifiers["convert_to_status"]
	if modifiers.has("duration"):
		result["duration"] = modifiers["duration"]
	elif modifiers.has("duration_multiplier"):
		result["duration"] = float(result.get("duration", 1.0)) * float(modifiers["duration_multiplier"])
	if modifiers.has("max_stacks"):
		result["max_stacks"] = modifiers["max_stacks"]
	if modifiers.has("slow_percent"):
		result["slow_percent"] = modifiers["slow_percent"]
	if modifiers.has("next_damage_taken_multiplier_add"):
		var effect: Dictionary = _get_dictionary(result.get("effect", {}))
		effect["next_damage_taken_multiplier_add"] = modifiers["next_damage_taken_multiplier_add"]
		result["effect"] = effect
	return result


## 作用：判断伤害是否可使用下一击承伤加成，排除DOT、场地与minor反应。
## 使用：空字典视为允许，支持typed包和上下文。 本入口委托StatusEffectQueryScript.can_consume_next_damage_taken执行。
func _can_consume_next_damage_taken(packet: Variant) -> bool:
	return StatusEffectQueryScript.can_consume_next_damage_taken(packet)


## 作用：检查满层阈值与反应/爆炸来源是否同时符合。
## 使用：status含required_stacks与加成，返回布尔值。 本入口委托StatusEffectQueryScript.is_full_stack_explosion_vulnerability_active执行。
func _is_full_stack_explosion_vulnerability_active(status: Dictionary, packet: Variant) -> bool:
	return StatusEffectQueryScript.is_full_stack_explosion_vulnerability_active(status, packet)


## 作用：从伤害输入读取字段值。
## 使用：key 为伤害字段名，fallback 为字段缺失时的默认值。
func _damage_packet_value(packet: Variant, key: Variant, fallback: Variant = null) -> Variant:
	return StatusEffectQueryScript.damage_packet_value(packet, key, fallback)


## 作用：从静态定义缓存或GameData查询状态并深复制隔离。
## 使用：未知ID返回空字典，不读JSON文件。
func _get_status_definition(status_id: StringName) -> Dictionary:
	var cache_key: String = String(status_id)
	if _status_definition_cache.has(cache_key):
		var cached_definition: Dictionary = _get_dictionary(_status_definition_cache.get(cache_key, {}))
		return cached_definition.duplicate(true)
	var status_data: Dictionary = GameData.get_status(status_id)
	if not status_data.is_empty():
		_status_definition_cache[cache_key] = status_data.duplicate(true)
		return status_data
	return {}


## 作用：读取状态定义 effect 下的浮点参数。
## 使用：key 为效果字段，字段缺失或 effect 非字典时返回 fallback。
func _get_effect_value(definition: Dictionary, key: String, fallback: float) -> float:
	var effect: Dictionary = _get_dictionary(definition.get("effect", {}))
	return float(effect.get(key, fallback))


## 作用：读取状态定义 effect 下的布尔参数。
## 使用：key 为效果开关，字段缺失时使用 fallback。
func _get_effect_bool(definition: Dictionary, key: String, fallback: bool) -> bool:
	var effect: Dictionary = _get_dictionary(definition.get("effect", {}))
	return bool(effect.get(key, fallback))


## 作用：发送技能事件、记录局内状态统计，再通知遗物协同管理器。
## 使用：状态已入表后调用，传给协同的状态为副本。
func _notify_status_applied(status_id: StringName, status: Dictionary) -> void:
	_emit_status_skill_event(&"status_applied", status_id, status)

	var tracker: Node = RunStatsTrackerScript.get_active(get_tree())
	if tracker != null and tracker.has_method("record_status_applied"):
		tracker.call("record_status_applied", status_id, get_parent())

	var synergy_manager: Node = _get_synergy_manager()
	if synergy_manager == null or not synergy_manager.has_method("on_status_applied"):
		return

	synergy_manager.call("on_status_applied", {
		"target": get_parent(),
		"status_id": status_id,
		"status": status.duplicate(true)
	})


## 作用：若存在有效性能回调，拼接状态来源、层数与附加数据并发送。
## 使用：仅开发采样副作用，不依赖debug页面。
func _emit_profiler_status_event(event_name: StringName, status_id: StringName, status: Dictionary, extra: Dictionary = {}) -> void:
	var profiler_callback: Callable = _real_full_run_profiler_status_callback()
	if not profiler_callback.is_valid():
		return
	var payload: Dictionary = {
		"status_id": status_id,
		"source_id": StringName(String(status.get("source_id", status.get("source_skill_id", status_id)))),
		"source_skill_id": StringName(String(status.get("source_skill_id", status_id))),
		"source_instance_id": String(status.get("source_instance_id", "")),
		"target": get_parent(),
		"stacks": int(status.get("stacks", 0)),
		"duration_remaining": float(status.get("duration_remaining", 0.0))
	}
	for key_variant: Variant in extra.keys():
		payload[key_variant] = extra[key_variant]
	profiler_callback.call(event_name, payload)


## 作用：从根元数据读取已启用的性能采样Callable。
## 使用：未开启或缺失返回无效Callable。
func _real_full_run_profiler_status_callback() -> Callable:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return Callable()
	if not tree.root.has_meta(&"real_full_run_profiler_enabled") or not bool(tree.root.get_meta(&"real_full_run_profiler_enabled")):
		return Callable()
	if not tree.root.has_meta(&"real_full_run_profiler_status_event"):
		return Callable()
	var callback: Variant = tree.root.get_meta(&"real_full_run_profiler_status_event")
	return callback if callback is Callable else Callable()


## 作用：读取协同的毒tick间隔倍率并缩短计时器至新间隔。
## 使用：毒不存在则无操作，不影响其他状态。
func _apply_poison_slow_synergy() -> void:
	if not _statuses.has(&"poison"):
		return

	var synergy_manager: Node = _get_synergy_manager()
	var multiplier: float = 1.0
	if synergy_manager != null and synergy_manager.has_method("get_status_tick_interval_multiplier"):
		multiplier = float(synergy_manager.call("get_status_tick_interval_multiplier", get_parent(), &"poison"))

	var poison: Dictionary = _statuses[&"poison"]
	poison["tick_interval_multiplier"] = multiplier
	var adjusted_interval: float = maxf(float(poison.get("tick_interval", 1.0)) * multiplier, 0.05)
	poison["tick_timer"] = minf(float(poison.get("tick_timer", adjusted_interval)), adjusted_interval)
	_statuses[&"poison"] = poison


## 作用：检查宿主enemy_rank是否为boss。
## 使用：宿主为空返回false。
func _is_boss() -> bool:
	var owning_node: Node = get_parent()
	return owning_node != null and String(owning_node.get_meta("enemy_rank", "normal")) == "boss"


## 作用：检查宿主enemy_rank是否为elite。
## 使用：宿主为空返回false。
func _is_elite() -> bool:
	var owning_node: Node = get_parent()
	return owning_node != null and String(owning_node.get_meta("enemy_rank", "normal")) == "elite"


## 作用：返回player组首节点的SynergyManager子节点。
## 使用：场景树/玩家缺失返回null。
func _get_synergy_manager() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		return null

	return player.get_node_or_null("SynergyManager")


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回输入字典本身，调用方写入会影响原值。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


## 作用：读取数组配置，非数组输入返回空数组。
## 使用：value为待检查配置；返回深复制。
func _get_array(value: Variant) -> Array:
	if value is Array:
		var array: Array = value
		return array.duplicate(true)
	return []

func clear_origin(skill_id: StringName) -> void:
	for id: Variant in _statuses.keys():
		if StringName(String(_statuses[id].get("source_skill_id", ""))) == skill_id:
			consume_status_stack(id, get_status_stack(id))
