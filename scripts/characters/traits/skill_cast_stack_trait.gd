## 文件用途：统计角色初始技能施放次数以叠层，并在玩家受伤时扣减叠层。
## 使用方式：通过 SKILL_CAST 和 PLAYER_DAMAGED 事件更新；get_modifiers 合并每层属性与满层额外属性。
extends CharacterTrait
class_name SkillCastStackTrait


const CharacterEventScript: Script = preload("res://scripts/characters/events/character_event.gd")
const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var _cast_count: int = 0
var _stack_count: int = 0


## 作用：调用基类 setup 后清零施放次数与叠层数。
## 使用：trait_config 为当前角色特性配置；trait_context 为角色和场景树上下文。
func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	super.setup(trait_config, trait_context)
	_cast_count = 0
	_stack_count = 0


## 作用：按初始技能施放或玩家受伤事件更新施放叠层。
## 使用：event 读取 type/payload。
func handle_event(event: RefCounted) -> void:
	match StringName(event.get("type")):
		CharacterEventScript.SKILL_CAST:
			_on_skill_cast(_get_dictionary(event.get("payload")))
		CharacterEventScript.PLAYER_DAMAGED:
			_on_player_damaged()


## 作用：按当前施法叠层数反复合并每层属性，达到满层时再合并满层属性。
## 使用：通过 SKILL_CAST 和 PLAYER_DAMAGED 事件更新；get_modifiers 合并每层属性与满层额外属性。
func get_modifiers(_query: RefCounted) -> Dictionary:
	var modifiers: Dictionary = {}
	var params: Dictionary = _get_params()
	var per_stack: Dictionary = _get_modifier_values(params.get("modifiers_per_stack", []))
	for _stack_index in range(_stack_count):
		SkillModifierCalculatorScript.merge_modifiers(modifiers, per_stack)
	var max_stack: int = int(params.get("max_stacks", 0))
	if max_stack > 0 and _stack_count >= max_stack:
		SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("full_stack_modifiers", [])))
	return modifiers


## 作用：返回当前特性运行状态，包括 cast_count、stack_count，供运行时与调试查询。
## 使用：通过 SKILL_CAST 和 PLAYER_DAMAGED 事件更新；get_modifiers 合并每层属性与满层额外属性。
func get_debug_state() -> Dictionary:
	return {
		"cast_count": _cast_count,
		"stack_count": _stack_count
	}


## 作用：只统计角色初始技能施放，累计次数到门槛后清零并增加有限叠层。
## 使用：event 读取 skill_id。
func _on_skill_cast(event: Dictionary) -> void:
	if not _is_starting_skill(event.get("skill_id", "")):
		return
	var params: Dictionary = _get_params()
	var casts_per_stack: int = maxi(int(params.get("casts_per_stack", 3)), 1)
	var max_stack: int = maxi(int(params.get("max_stacks", 1)), 0)
	_cast_count += 1
	if _cast_count < casts_per_stack:
		return
	_cast_count = 0
	_stack_count = mini(_stack_count + 1, max_stack)


## 作用：按受击配置比例与最低损失扣减施法叠层，低于清零门槛时清空。
## 使用：由本文件 handle_event 调用。
func _on_player_damaged() -> void:
	var params: Dictionary = _get_params()
	var damaged: Dictionary = _get_dictionary(params.get("on_damaged", {}))
	var lose_percent: float = clampf(float(damaged.get("lose_stack_percent", 0.0)), 0.0, 1.0)
	if lose_percent <= 0.0:
		return
	var stack_loss: int = maxi(ceili(float(_stack_count) * lose_percent), int(damaged.get("minimum_stack_loss", 2)))
	_stack_count = maxi(_stack_count - stack_loss, 0)
	if _stack_count < int(damaged.get("clear_below_stack", 2)):
		_stack_count = 0
