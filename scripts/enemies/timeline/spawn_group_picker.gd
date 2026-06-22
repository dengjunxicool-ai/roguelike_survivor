extends RefCounted
class_name SpawnGroupPicker


var _rng: RandomNumberGenerator


func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng


func pick_enemy_group(source: Dictionary) -> Dictionary:
	var groups: Array = _get_array(source.get("groups", []))
	var total_weight: float = 0.0
	for group_variant: Variant in groups:
		if group_variant is Dictionary:
			var group: Dictionary = group_variant
			total_weight += maxf(float(group.get("weight", 0.0)), 0.0)

	if total_weight <= 0.0:
		return {}

	var rng: RandomNumberGenerator = _get_rng()
	var roll: float = rng.randf_range(0.0, total_weight)
	var accumulated_weight: float = 0.0
	for group_variant: Variant in groups:
		if not (group_variant is Dictionary):
			continue

		var group: Dictionary = group_variant
		accumulated_weight += maxf(float(group.get("weight", 0.0)), 0.0)
		if roll <= accumulated_weight:
			return group

	return {}


func pick_enemy_id_from_group(group_config: Dictionary) -> StringName:
	var enemy_ids: Array = _get_array(group_config.get("enemy_ids", []))
	if not enemy_ids.is_empty():
		return StringName(String(enemy_ids[_get_rng().randi_range(0, enemy_ids.size() - 1)]))
	return StringName(String(group_config.get("enemy_id", "small_slime")))


func weighted_average_group_count(source: Dictionary) -> float:
	var groups: Array = _get_array(source.get("groups", []))
	var total_weight: float = 0.0
	var weighted_count: float = 0.0
	for group_variant: Variant in groups:
		if not (group_variant is Dictionary):
			continue
		var group: Dictionary = group_variant
		var weight: float = maxf(float(group.get("weight", 0.0)), 0.0)
		if weight <= 0.0:
			continue
		var count_min: float = float(group.get("count_min", 1))
		var count_max: float = float(group.get("count_max", count_min))
		weighted_count += weight * ((count_min + count_max) * 0.5)
		total_weight += weight
	if total_weight <= 0.0:
		return 1.0
	return maxf(weighted_count / total_weight, 1.0)


func _get_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
