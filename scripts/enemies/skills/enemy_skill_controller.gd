## 文件用途：整理敌方技能引用并按动作类型或技能 ID 显式执行动作。
## 使用方式：setup 注入 enemy 与配置；行为调用 execute_action_type，Boss 阶段调用 execute_skill_id；tick 当前为空接口。

extends RefCounted
class_name EnemySkillController


const EnemySkillRepositoryScript: Script = preload("res://scripts/enemies/skills/enemy_skill_repository.gd")
const EnemyActionContextScript: Script = preload("res://scripts/enemies/actions/enemy_action_context.gd")
const EnemyActionRegistryScript: Script = preload("res://scripts/enemies/actions/enemy_action_registry.gd")

var _owner: Node
var _behavior_config: Dictionary = {}
var _repository: RefCounted = EnemySkillRepositoryScript.new()
var _action_registry: RefCounted = EnemyActionRegistryScript.new()
var _skill_entries: Array[Dictionary] = []


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node, skill_refs: Array = [], behavior_config: Dictionary = {}) -> void:
	_owner = owner
	_behavior_config = behavior_config.duplicate(true)
	_skill_entries.clear()
	for ref_variant: Variant in skill_refs:
		var ref: Dictionary = _normalize_skill_ref(ref_variant)
		var skill_id: StringName = StringName(String(ref.get("skill_id", ref.get("id", ""))))
		if skill_id == &"":
			continue
		var definition: RefCounted = _repository.call("get_skill", skill_id) as RefCounted
		if definition == null:
			push_warning("[EnemySkillController] Missing enemy skill definition: %s" % String(skill_id))
			continue
		_skill_entries.append({
			"id": skill_id,
			"ref": ref,
			"definition": definition
		})


## 作用：保留敌方技能周期更新接口，当前实现为 pass。
## 使用：控制器调用此入口不会自动施法或推进冷却；动作由行为或 Boss 阶段显式请求。
func tick(_delta: float) -> void:
	pass


## 作用：寻找含指定动作类型的技能，执行其匹配动作并返回是否成功。
## 使用：action_type 为配置动作类型；runtime_params 为运行覆盖参数，首个成功技能后停止查找。
func execute_action_type(action_type: String, runtime_params: Dictionary = {}) -> bool:
	for entry: Dictionary in _skill_entries:
		var definition: RefCounted = entry.get("definition") as RefCounted
		if definition == null or not bool(definition.call("has_action_type", action_type)):
			continue
		var actions: Array = definition.call("get_actions_by_type", action_type)
		var executed: bool = false
		for action_variant: Variant in actions:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var context: Dictionary = EnemyActionContextScript.create(
				_owner,
				definition.call("to_dictionary"),
				action,
				_build_runtime_params(entry, runtime_params)
			)
			executed = bool(_action_registry.call("execute", context)) or executed
		if executed:
			_record_cast(entry,action_type)
			return true
	return false


## 作用：执行指定技能定义中的所有动作。
## 使用：skill_id 必须出现在当前敌人的已解析引用列表；返回是否至少一个动作执行成功。
func execute_skill_id(skill_id: Variant, runtime_params: Dictionary = {}) -> bool:
	var requested_id: StringName = StringName(String(skill_id))
	for entry: Dictionary in _skill_entries:
		if StringName(String(entry.get("id", ""))) != requested_id:
			continue
		var definition: RefCounted = entry.get("definition") as RefCounted
		if definition == null:
			return false
		var actions: Array = definition.get("actions")
		var executed: bool = false
		for action_variant: Variant in actions:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var context: Dictionary = EnemyActionContextScript.create(
				_owner,
				definition.call("to_dictionary"),
				action,
				_build_runtime_params(entry, runtime_params)
			)
			executed = bool(_action_registry.call("execute", context)) or executed
		if executed: _record_cast(entry,"cast")
		return executed
	return false

func _record_cast(entry: Dictionary,action_type: String) -> void:
	if _owner!=null and _owner.has_method("_record_attack_metric"):
		_owner.call("_record_attack_metric",StringName(String(entry.id)),StringName(action_type))

func get_skill_id_for_action(action_type: String, fallback: StringName) -> StringName:
	for entry: Dictionary in _skill_entries:
		if entry.definition.call("has_action_type",action_type): return StringName(entry.id)
	return fallback


## 作用：读取对应动作的引用冷却、定义冷却或回退值。
## 使用：action_type 为动作类型；返回值至少 0.1 秒，优先使用引用上的 cooldown。
func get_cooldown_for_action(action_type: String, fallback: float) -> float:
	for entry: Dictionary in _skill_entries:
		var definition: RefCounted = entry.get("definition") as RefCounted
		if definition == null or not bool(definition.call("has_action_type", action_type)):
			continue
		var ref: Dictionary = entry.get("ref", {})
		if ref.has("cooldown"):
			return maxf(float(ref.get("cooldown", fallback)), 0.1)
		var definition_cooldown: float = float(definition.get("cooldown"))
		if definition_cooldown > 0.0:
			return maxf(definition_cooldown, 0.1)
	return maxf(fallback, 0.1)


## 作用：构建运行时参数。
## 使用：本文件由 execute_action_type、execute_skill_id 调用；输入 entry（entry）、runtime_params（运行时参数）；返回结果字典。
func _build_runtime_params(entry: Dictionary, runtime_params: Dictionary) -> Dictionary:
	var params: Dictionary = runtime_params.duplicate(true)
	params["skill_ref"] = (entry.get("ref", {}) as Dictionary).duplicate(true)
	params["behavior"] = _behavior_config.duplicate(true)
	return params


## 作用：把技能配置引用统一为字典。
## 使用：value 是字典时返回深拷贝；否则转成字符串 skill_id，空字符串返回空字典。
func _normalize_skill_ref(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	if String(value) != "":
		return {"skill_id": String(value)}
	return {}
