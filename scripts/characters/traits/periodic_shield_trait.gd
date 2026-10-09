## 文件用途：管理周期护盾的生成、持续时间、伤害减免和吸收结算。
## 使用方式：setup 先授予护盾，process 推进护盾或补充计时，伤害入口调用 absorb_damage 并使用返回的剩余伤害。
extends CharacterTrait
class_name PeriodicShieldTrait

const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var _shield_timer: float = 0.0
var _shield_points: int = 0
var _shield_remaining_seconds: float = 0.0


## 作用：调用基类 setup 后清空盾状态与计时，并立即授予初始周期护盾。
## 使用：trait_config 为当前角色特性配置；trait_context 为角色和场景树上下文。
func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	super.setup(trait_config, trait_context)
	_shield_timer = 0.0
	_shield_points = 0
	_shield_remaining_seconds = 0.0
	_grant_periodic_shield()


## 作用：推进护盾持续时间或下一次生成计时。
## 使用：delta 为本帧经过的秒数。
func process(delta: float) -> void:
	_update_periodic_shield(delta)


## 作用：合并基础属性，仅在护盾有效时追加盾激活属性。
## 使用：由本文件 absorb_damage 调用。
func get_modifiers(_query: RefCounted) -> Dictionary:
	var modifiers: Dictionary = {}
	var params: Dictionary = _get_params()
	SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("base_modifiers", [])))
	if _is_shield_active():
		SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("shield_active_modifiers", [])))
	return modifiers


## 作用：先按承伤倍率调整伤害，再消耗有效盾点；盾耗尽清零时长与补充计时，返回吸收结果。
## 使用：amount 为本次伤害或动作数值。
func absorb_damage(amount: int, _event: RefCounted) -> RefCounted:
	if amount <= 0:
		return DamageAbsorbResultScript.unchanged(amount)
	var adjusted_amount: int = amount
	var modifiers: Dictionary = get_modifiers(null)
	if modifiers.has("damage_taken_multiplier_add"):
		adjusted_amount = maxi(roundi(float(adjusted_amount) * maxf(1.0 + float(modifiers.get("damage_taken_multiplier_add", 0.0)), 0.05)), 0)
	if not _is_shield_active():
		return DamageAbsorbResultScript.new(adjusted_amount, maxi(amount - adjusted_amount, 0), {})

	var absorbed: int = mini(_shield_points, adjusted_amount)
	_shield_points -= absorbed
	if _shield_points <= 0:
		_shield_points = 0
		_shield_remaining_seconds = 0.0
		_shield_timer = 0.0
	return DamageAbsorbResultScript.new(maxi(adjusted_amount - absorbed, 0), absorbed + maxi(amount - adjusted_amount, 0), {"shield_points": _shield_points})


## 作用：返回当前特性运行状态，包括 shield_points、shield_remaining_seconds、shield_timer，供运行时与调试查询。
## 使用：setup 先授予护盾，process 推进护盾或补充计时，伤害入口调用 absorb_damage 并使用返回的剩余伤害。
func get_debug_state() -> Dictionary:
	return {
		"shield_points": _shield_points,
		"shield_remaining_seconds": _shield_remaining_seconds,
		"shield_timer": _shield_timer
	}


## 作用：先更新已有护盾持续时间，护盾失效后才累计下一次补充间隔。
## 使用：delta 为本帧经过的秒数。
func _update_periodic_shield(delta: float) -> void:
	var params: Dictionary = _get_params()
	if _is_shield_active():
		var duration: float = maxf(float(params.get("shield_duration", 0.0)), 0.0)
		if duration <= 0.0:
			return
		_shield_remaining_seconds = maxf(_shield_remaining_seconds - delta, 0.0)
		if _shield_remaining_seconds <= 0.0:
			_shield_points = 0
			_shield_timer = 0.0
		return

	var interval: float = maxf(float(params.get("shield_interval", 18.0)), 0.1)
	_shield_timer += delta
	if _shield_timer >= interval:
		_grant_periodic_shield()


## 作用：重置补盾计时并按配置补充护盾点数和持续时间。
## 使用：由本文件 setup/_update_periodic_shield 调用。
func _grant_periodic_shield() -> void:
	var params: Dictionary = _get_params()
	_shield_timer = 0.0
	_shield_points = maxi(_shield_points, int(params.get("shield_amount", 1)))
	_shield_remaining_seconds = maxf(float(params.get("shield_duration", 0.0)), 0.0)


## 作用：判断护盾点数和剩余时间是否有效，无时长护盾仅受点数限制。
## 使用：由本文件 get_modifiers/absorb_damage 调用；返回布尔判断或执行是否成功。
func _is_shield_active() -> bool:
	if _shield_points <= 0:
		return false
	var params: Dictionary = _get_params()
	var duration: float = maxf(float(params.get("shield_duration", 0.0)), 0.0)
	return duration <= 0.0 or _shield_remaining_seconds > 0.0
