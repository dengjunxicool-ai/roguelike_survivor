## 文件用途：按玩家已损失生命比例计算叠层属性，并同时应用基础负面效果。
## 使用方式：由特性控制器查询 get_modifiers；层数每次根据玩家实时血量和 hp_step_percent 重算。
extends CharacterTrait
class_name HpLostStackTrait


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")


## 作用：先合并基础惩罚，再按玩家已失生命比例与每层步长重算有限叠层属性。
## 使用：由特性控制器查询 get_modifiers；层数每次根据玩家实时血量和 hp_step_percent 重算。
func get_modifiers(_query: RefCounted) -> Dictionary:
	var modifiers: Dictionary = {}
	var params: Dictionary = _get_params()
	SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("base_penalties", [])))
	var owner: Node = null
	if context != null:
		owner = context.get("owner") as Node
	if owner == null:
		return modifiers
	var max_health: float = maxf(float(owner.get("max_health")), 1.0)
	var current_health: float = clampf(float(owner.get("current_health")), 0.0, max_health)
	var lost_percent: float = 1.0 - current_health / max_health
	var step: float = maxf(float(params.get("hp_step_percent", 0.2)), 0.01)
	var stack_count: int = mini(floori(lost_percent / step), maxi(int(params.get("max_stacks", 5)), 0))
	var per_stack: Dictionary = _get_modifier_values(params.get("modifiers_per_stack", []))
	for _stack_index in range(stack_count):
		SkillModifierCalculatorScript.merge_modifiers(modifiers, per_stack)
	return modifiers


## 作用：返回当前特性运行状态，包括 stack_count，供运行时与调试查询。
## 使用：由特性控制器查询 get_modifiers；层数每次根据玩家实时血量和 hp_step_percent 重算。
func get_debug_state() -> Dictionary:
	var params: Dictionary = _get_params()
	var owner: Node = null
	if context != null:
		owner = context.get("owner") as Node
	if owner == null:
		return {"stack_count": 0}
	var max_health: float = maxf(float(owner.get("max_health")), 1.0)
	var current_health: float = clampf(float(owner.get("current_health")), 0.0, max_health)
	var lost_percent: float = 1.0 - current_health / max_health
	var step: float = maxf(float(params.get("hp_step_percent", 0.2)), 0.01)
	return {
		"stack_count": mini(floori(lost_percent / step), maxi(int(params.get("max_stacks", 5)), 0))
	}
