extends CharacterTrait
class_name PeriodicShieldTrait

const SkillModifierCalculatorScript: Script = preload("res://scripts/skills/skill_modifier.gd")

var _shield_timer: float = 0.0
var _shield_points: int = 0
var _shield_remaining_seconds: float = 0.0


func setup(trait_config: Dictionary, trait_context: RefCounted) -> void:
	super.setup(trait_config, trait_context)
	_shield_timer = 0.0
	_shield_points = 0
	_shield_remaining_seconds = 0.0
	_grant_periodic_shield()


func process(delta: float) -> void:
	_update_periodic_shield(delta)


func get_modifiers(_query: RefCounted) -> Dictionary:
	var modifiers: Dictionary = {}
	var params: Dictionary = _get_params()
	SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("base_modifiers", {})))
	if _is_shield_active():
		SkillModifierCalculatorScript.merge_modifiers(modifiers, _get_modifier_values(params.get("shield_active_modifiers", {})))
	return modifiers


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


func get_debug_state() -> Dictionary:
	return {
		"shield_points": _shield_points,
		"shield_remaining_seconds": _shield_remaining_seconds,
		"shield_timer": _shield_timer
	}


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


func _grant_periodic_shield() -> void:
	var params: Dictionary = _get_params()
	_shield_timer = 0.0
	_shield_points = maxi(_shield_points, int(params.get("shield_amount", 1)))
	_shield_remaining_seconds = maxf(float(params.get("shield_duration", 0.0)), 0.0)


func _is_shield_active() -> bool:
	if _shield_points <= 0:
		return false
	var params: Dictionary = _get_params()
	var duration: float = maxf(float(params.get("shield_duration", 0.0)), 0.0)
	return duration <= 0.0 or _shield_remaining_seconds > 0.0
