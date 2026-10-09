## 文件用途：连接技能订阅者、配置事件动作、拥有技能触发规则和火系被动运行时。
## 使用方式：subscribe 绑定外部监听器，emit_skill_event 提供 context；执行适配动作时保留特殊规则处理顺序。
extends Node
class_name SkillEventBus


const ConditionEvaluatorScript: Script = preload("res://scripts/skills/condition_evaluator.gd")
const HitEventResultScript: Script = preload("res://scripts/skills/hit_event_result.gd")
const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")
const SkillTriggerRuleAdapterScript: Script = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
const FireSkillRuntimeScript: Script = preload("res://scripts/skills/fire_skill_runtime.gd")
const SkillSpecialRuleExecutorScript: Script = preload("res://scripts/skills/skill_special_rule_executor.gd")
const DamageTraceContextScript: Script = preload("res://scripts/runtime/damage_trace_context.gd")
const EventContext: Script = preload("res://scripts/skills/skill_event_context.gd")
const ProcPolicy: Script = preload("res://scripts/skills/skill_proc_policy.gd")
const Clock: Script = preload("res://scripts/runtime/run_combat_clock.gd")

var _listeners: Dictionary = {}
var _action_executor: RefCounted = SkillActionExecutorScript.new()
var _special_rule_executor: RefCounted = SkillSpecialRuleExecutorScript.new()
var _clock: Node = Clock.new()
var _pending_events: Array[Dictionary] = []
var _dispatching: bool = false
var _budget_frame: int = -1
var _frame_events: int = 0
var _event_nonce: int = 0

func _ready() -> void:
	_clock.name = "RunCombatClock"
	add_child(_clock)

func _physics_process(_delta: float) -> void:
	process_pending_events()

func combat_seconds() -> float:
	return _clock.now_seconds()

func reset_run_state() -> void:
	_pending_events.clear()
	_clock.reset()
	_budget_frame = -1
	_frame_events = 0
	_event_nonce = 0

func process_pending_events() -> void:
	_refresh_budget()
	if _dispatching:
		return
	_dispatching = true
	while not _pending_events.is_empty() and _frame_events < 64:
		var item: Dictionary = _pending_events.pop_front()
		_frame_events += 1
		_dispatch_event(item.event_name, item.context)
	_dispatching = false

func _refresh_budget() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_frame_events = 0


## 作用：按事件名登记回调，已登记的同一 Callable 不重复添加。
## 使用：event_name 为统一技能事件名；listener 为订阅回调。
func subscribe(event_name: StringName, listener: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []

	var listeners: Array = _listeners[event_name]
	if not listeners.has(listener):
		listeners.append(listener)
		_listeners[event_name] = listeners


## 作用：仅把 on_cast 转为角色特性施法事件，其余技能事件忽略。
## 使用：event_name 为统一技能事件名。
func emit_skill_event(event_name: StringName, event_context: Dictionary = {}) -> Array:
	var context: Dictionary = EventContext.from_context(DamageTraceContextScript.normalize_event_context(event_context), event_name)
	_event_nonce += 1
	context["event_id"] = _event_nonce
	# Each new event uses its occurrence time; delayed objects retain ancestry,
	# but their creation timestamp must not freeze future listener cooldowns.
	context["combat_seconds"] = combat_seconds()
	_refresh_budget()
	if _dispatching or not _pending_events.is_empty() or _frame_events >= 64:
		_pending_events.append({"event_name": event_name, "context": context})
		return []
	_dispatching = true
	_frame_events += 1
	var results: Array = _dispatch_event(event_name, context)
	_dispatching = false
	process_pending_events()
	return results

func _dispatch_event(event_name: StringName, context: Dictionary) -> Array:
	EventContext.purge_invalid_references(context)
	context["event_name"] = event_name
	context["event_bus"] = self
	if event_name == &"on_cast":
		context["_cast_result"] = {"successful_outputs": 0}
		_prepare_cast_charge(context)
		_special_rule_executor.call("execute_event", event_name, context)
		if not bool(context.get("skip_fire_passive_runtime", false)):
			_execute_fire_passive_runtime(event_name, context)
		_execute_skill_events(event_name, context)
		if int(context["_cast_result"].successful_outputs) > 0:
			_commit_cast_charge(context)
			var succeeded: Dictionary = context.duplicate(true)
			succeeded["parent_event_id"] = int(context.event_id)
			emit_skill_event(&"skill_cast_succeeded", succeeded)
	else:
		_execute_skill_events(event_name, context)
		if not bool(context.get("skip_fire_passive_runtime", false)):
			_execute_fire_passive_runtime(event_name, context)
		_special_rule_executor.call("execute_event", event_name, context)

	var results: Array = []
	var listeners: Array = _listeners.get(event_name, [])
	for listener_variant: Variant in listeners:
		var listener: Callable = listener_variant
		if listener.is_valid():
			results.append(HitEventResultScript.from_value(listener.call(context)).to_dictionary())
	if event_name == &"on_player_damaged":
		var owner: Node = context.get("owner", context.get("caster")) as Node
		if owner != null:
			var current: float = float(owner.get("current_health"))
			var threshold: float = float(owner.get("max_health")) * 0.35
			var before: float = current + maxf(float(context.get("amount", 0.0)), 0.0)
			if before >= threshold and current < threshold:
				emit_skill_event(&"player_health_crossed_below", context)

	return results

func _prepare_cast_charge(context: Dictionary) -> void:
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	var caster: Node = context.get("caster") as Node
	if skill == null or String(skill.get("skill_type")) != "cast" or caster == null or bool(context.get("is_copy", false)):
		return
	var store: Node = caster.get_node_or_null("ModifierStore")
	if store != null:
		var snapshot: Dictionary = store.call("get_cast_charge_snapshot")
		context["cast_damage_multiplier"] = float(snapshot.multiplier)
		context["cast_charge_sources"] = snapshot.sources

func _commit_cast_charge(context: Dictionary) -> void:
	var caster: Node = context.get("caster") as Node
	var store: Node = caster.get_node_or_null("ModifierStore") if caster != null else null
	if store != null:
		store.call("consume_cast_charges", context.get("cast_charge_sources", []))


## 作用：从上下文或施法者解析技能管理器后运行拥有的火系被动。
## 使用：event_name 为统一技能事件名；context 携带 skill_manager/caster。
func _execute_fire_passive_runtime(event_name: StringName, context: Dictionary) -> void:
	var skill_manager: Node = context.get("skill_manager") as Node
	if skill_manager == null:
		var caster: Node = context.get("caster") as Node
		if caster != null:
			skill_manager = caster.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return
	FireSkillRuntimeScript.execute_passive_event(event_name, context, skill_manager, _action_executor)


## 作用：先执行来源技能的定义与运行事件，再检查其余拥有技能的触发规则。
## 使用：event_name 为统一技能事件名；context 携带 skill_instance。
func _execute_skill_events(event_name: StringName, context: Dictionary) -> void:
	var skill_instance: RefCounted = context.get("skill_instance") as RefCounted
	if skill_instance != null:
		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		if definition != null:
			_execute_event_list(event_name, context, skill_instance, _get_skill_events(skill_instance, definition))
	_execute_owned_trigger_rule_events(event_name, context, skill_instance)


## 作用：归一追踪上下文后执行已适配动作列表。
## 使用：actions 为依次执行的动作列表。
func execute_adapted_actions(actions: Array, event_context: Dictionary = {}) -> void:
	var context: Dictionary = DamageTraceContextScript.normalize_event_context(event_context, get_tree().root if get_tree() != null else null)
	context["event_bus"] = self
	_action_executor.call("execute_actions", actions, context)


## 作用：按事件名、条件、计数和冷却筛选事件动作并执行。
## 使用：event_name 为统一技能事件名；context 携带 source_id；skill_instance 为技能运行实例。
func _execute_event_list(event_name: StringName, context: Dictionary, skill_instance: RefCounted, events: Array) -> void:
	if skill_instance == null:
		return

	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue

		var event: Dictionary = event_variant
		if StringName(String(event.get("trigger", ""))) != event_name:
			continue
		var source_id: StringName = StringName(String(event.get("source_id", "")))
		if source_id != &"" and source_id != StringName(String(context.get("source_id", ""))):
			continue
		var event_context: Dictionary = context.duplicate(true)
		event_context["skill_instance"] = skill_instance
		event_context["skill_id"] = StringName(String(skill_instance.get("skill_id")))
		event_context["listener_skill_id"] = StringName(String(skill_instance.get("skill_id")))
		var source_cast: bool = event_name == &"on_cast" and event_context.listener_skill_id == context.get("origin_skill_id", &"")
		if event_name == &"on_cast" and not source_cast:
			continue
		if event_name == &"post_damage_hit" and context.has("damage_amount") and float(context.damage_amount) <= 0.0:
			continue
		var proc_id: StringName = &"status_reaction" if event_name == &"status_max_stack_reached" else event_context.listener_skill_id
		if not source_cast and not ProcPolicy.can_generate(context, proc_id):
			continue

		var conditions: Array = _get_array(event.get("conditions", []))
		if not ConditionEvaluatorScript.evaluate_all(conditions, event_context):
			continue
		if not SkillTriggerRuleAdapterScript.can_execute_rule_event(event, event_context, skill_instance):
			continue

		var actions: Array = _get_array(event.get("actions", []))
		if source_cast:
			event_context["_cast_result"] = context["_cast_result"]
			event_context["is_cast_source"] = true
		else:
			event_context = ProcPolicy.child_context(event_context, proc_id)
		_action_executor.call("execute_actions", actions, event_context)


## 作用：遍历拥有技能，把匹配当前事件的触发规则适配并执行。
## 使用：event_name 为统一技能事件名；context 携带 skill_manager/caster。
func _execute_owned_trigger_rule_events(event_name: StringName, context: Dictionary, skipped_skill_instance: RefCounted = null) -> void:
	var skill_manager: Node = context.get("skill_manager") as Node
	if skill_manager == null:
		var caster: Node = context.get("caster") as Node
		if caster != null:
			skill_manager = caster.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return
	for skill_variant: Variant in skill_manager.call("get_all_skills"):
		var skill_instance: RefCounted = skill_variant as RefCounted
		if skill_instance == null or skill_instance == skipped_skill_instance:
			continue
		var definition: RefCounted = skill_instance.get("definition") as RefCounted
		if definition == null:
			continue
		_execute_event_list(event_name, context, skill_instance, SkillTriggerRuleAdapterScript.to_events(skill_instance, definition))


## 作用：合并定义事件、实例运行事件和触发规则适配事件。
## 使用：skill_instance 为技能运行实例；definition 为技能定义。
func _get_skill_events(skill_instance: RefCounted, definition: RefCounted) -> Array:
	var events: Array = []
	var definition_events_variant: Variant = definition.get("events")
	if definition_events_variant is Array:
		events.append_array(definition_events_variant)

	var runtime_events_variant: Variant = skill_instance.get("runtime_events")
	if runtime_events_variant is Array:
		events.append_array(runtime_events_variant)
	events.append_array(SkillTriggerRuleAdapterScript.to_events(skill_instance, definition))

	return events


## 作用：仅接受 Array；直接返回原数组引用，其余类型返回空数组。
## 使用：由本文件 _execute_event_list 调用；无匹配项时返回空数组。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []

func clear_origin(skill_id: StringName) -> void:
	_pending_events = _pending_events.filter(func(item: Dictionary) -> bool:
		return StringName(String(item.context.get("origin_skill_id", ""))) != skill_id)
