extends CharacterTrait
class_name HpLostStackTrait


const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")


func get_modifiers(_query: RefCounted) -> Dictionary:
	var modifiers: Dictionary = {}
	var params: Dictionary = _get_params()
	SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("base_penalties", {})))
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
	var per_stack: Dictionary = _get_modifier_values(params.get("modifiers_per_stack", {}))
	for _stack_index in range(stack_count):
		SkillModifierCalculatorScript.merge_modifiers(modifiers, per_stack)
	return modifiers


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
