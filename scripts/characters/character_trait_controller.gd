## 文件用途：创建注册的角色特性并统一分派计时、事件、属性查询和伤害吸收。
## 使用方式：initialize 绑定 CharacterRuntime 与玩家；每次处理后同步 trait_runtime_state，技能查询会适配初始技能专属属性。
extends RefCounted
class_name CharacterTraitController


const TraitRegistryScript: Script = preload("res://scripts/characters/traits/trait_registry.gd")
const CharacterTraitContextScript: Script = preload("res://scripts/characters/character_trait_context.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageAbsorbResultScript: Script = preload("res://scripts/characters/events/damage_absorb_result.gd")

var runtime: Node
var owner: Node
var trait_config: Dictionary = {}
var trait_type: String = ""
var _context: RefCounted
var _active_trait: RefCounted


## 作用：清空上一特性状态，创建上下文并按角色特性 type 实例化和 setup，最后同步运行状态。
## 使用：owning_node 为玩家聚合节点。
func initialize(character_runtime: Node, owning_node: Node) -> void:
	runtime = character_runtime
	owner = owning_node
	trait_config = {}
	trait_type = ""
	_context = CharacterTraitContextScript.new(owner, runtime)
	_active_trait = null

	if runtime == null:
		_sync_runtime_state()
		return

	trait_config = runtime.call("get_trait")
	trait_type = String(trait_config.get("type", ""))
	_active_trait = TraitRegistryScript.create(trait_type)
	if _active_trait != null and _active_trait.has_method("setup"):
		_active_trait.call("setup", trait_config, _context)
	_sync_runtime_state()


## 作用：推进当前特性计时后同步运行状态，即使缺特性也保持状态输出。
## 使用：delta 为本帧经过的秒数。
func process(delta: float) -> void:
	if _active_trait != null and _active_trait.has_method("process"):
		_active_trait.call("process", delta)
	_sync_runtime_state()


## 作用：把统一 CharacterEvent 转给当前特性，再同步运行状态。
## 使用：event 为当前事件或规则载荷。
func handle_event(event: RefCounted) -> void:
	if _active_trait != null and _active_trait.has_method("handle_event"):
		_active_trait.call("handle_event", event)
	_sync_runtime_state()


## 作用：收集当前特性属性，技能作用域下按初始技能归属转换专属属性键。
## 使用：query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
func collect_modifiers(query: RefCounted) -> Dictionary:
	if _active_trait == null or not _active_trait.has_method("get_modifiers"):
		return {}
	var raw_modifiers_variant: Variant = _active_trait.call("get_modifiers", query)
	if not (raw_modifiers_variant is Dictionary):
		return {}
	var raw_modifiers: Dictionary = raw_modifiers_variant
	if query != null and StringName(String(query.get("scope"))) == ModifierQueryScript.SCOPE_SKILL:
		return _adapt_skill_modifiers(raw_modifiers, query)
	return raw_modifiers


## 作用：请求当前特性吸收伤害并返回剩余伤害；缺特性时保留原值。
## 使用：amount 为本次伤害或动作数值；event 为当前事件或规则载荷。
func request_damage_absorb(amount: int, event: RefCounted) -> RefCounted:
	if _active_trait == null or not _active_trait.has_method("absorb_damage"):
		return DamageAbsorbResultScript.unchanged(amount)
	var result: RefCounted = _active_trait.call("absorb_damage", amount, event) as RefCounted
	if result == null:
		result = DamageAbsorbResultScript.unchanged(amount)
	_sync_runtime_state()
	return result


## 作用：返回当前特性运行状态，包括 trait_id、trait_type、cast_count、stack_count、moving_time，供运行时与调试查询。
## 使用：由本文件 _sync_runtime_state 调用。
func get_debug_state() -> Dictionary:
	var state: Dictionary = {
		"trait_id": trait_config.get("id", ""),
		"trait_type": trait_type,
		"cast_count": 0,
		"stack_count": 0,
		"moving_time": 0.0,
		"stopped_time": 0.0,
		"movement_penalty_remaining": 0.0,
		"shield_points": 0,
		"shield_remaining_seconds": 0.0,
		"shield_timer": 0.0
	}
	if _active_trait != null and _active_trait.has_method("get_debug_state"):
		var trait_state_variant: Variant = _active_trait.call("get_debug_state")
		if trait_state_variant is Dictionary:
			var trait_state: Dictionary = trait_state_variant
			for key: Variant in trait_state.keys():
				state[key] = trait_state[key]
	return state


## 作用：仅对角色初始技能保留 starting_skill_ 属性，并转换对应运行键。
## 使用：query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
func _adapt_skill_modifiers(raw_modifiers: Dictionary, query: RefCounted) -> Dictionary:
	if raw_modifiers.is_empty():
		return {}
	var applies_to_starting_skill: bool = _is_starting_skill(query.get("skill_id"))
	var modifiers: Dictionary = {}
	for key_variant: Variant in raw_modifiers.keys():
		var key: String = String(key_variant)
		if key.begins_with("starting_skill_"):
			if not applies_to_starting_skill:
				continue
			if key == "starting_skill_damage_add":
				modifiers[key] = raw_modifiers[key_variant]
			else:
				modifiers[key.trim_prefix("starting_skill_")] = raw_modifiers[key_variant]
		else:
			modifiers[key] = raw_modifiers[key_variant]
	return modifiers


## 作用：比较技能 ID 与上下文角色的初始技能 ID，缺角色上下文时不匹配。
## 使用：skill_id 为标准技能 ID；返回布尔判断或执行是否成功。
func _is_starting_skill(skill_id: Variant) -> bool:
	if runtime == null:
		return false
	return StringName(String(skill_id)) == StringName(String(runtime.call("get_starting_skill_id")))


## 作用：将控制器当前调试状态同步到角色运行时 trait_runtime_state。
## 使用：由本文件 initialize/process 调用。
func _sync_runtime_state() -> void:
	if runtime != null:
		runtime.set("trait_runtime_state", get_debug_state())
