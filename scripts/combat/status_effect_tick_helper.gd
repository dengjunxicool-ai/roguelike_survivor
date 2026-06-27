extends RefCounted
class_name StatusEffectTickHelper


static func advance_duration(status: Dictionary, delta: float) -> void:
	status["duration_remaining"] = float(status.get("duration_remaining", 0.0)) - delta


static func is_status_expired(status: Dictionary) -> bool:
	return int(status.get("stacks", 1)) <= 0 or float(status.get("duration_remaining", 0.0)) <= 0.0


static func has_status_tick_work(status: Dictionary) -> bool:
	return float(status.get("tick_damage", 0.0)) > 0.0 or not _get_array(status.get("on_tick_effects", [])).is_empty()


static func should_consume_stack_on_tick(status: Dictionary) -> bool:
	if status.has("consume_stack_on_tick"):
		return bool(status.get("consume_stack_on_tick", false))
	var definition: Dictionary = _get_dictionary(status.get("definition", {}))
	return bool(definition.get("consume_stack_on_tick", false))


static func tick_damage_total(status: Dictionary) -> float:
	var stacks: float = float(maxi(int(status.get("stacks", 1)), 1))
	var total: float = float(status.get("tick_damage", 0.0)) * stacks
	var power: float = float(status.get("power", 0.0))
	for effect_variant: Variant in _get_array(status.get("on_tick_effects", [])):
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		if str(effect.get("type", "")) != "damage":
			continue
		if effect.has("power_scale"):
			total += power * float(effect.get("power_scale", 0.0))
		elif effect.has("power_scale_per_stack"):
			total += power * float(effect.get("power_scale_per_stack", 0.0)) * stacks
	return total


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
