## 文件用途：按敌人组权重选择组和具体敌人并估算组规模。
## 使用方式：setup 注入生成器的 RandomNumberGenerator；选择函数消费该随机流，不绑定 owner 节点。

extends RefCounted
class_name SpawnGroupPicker


var _rng: RandomNumberGenerator


## 作用：保存生成器的随机流供组权重选择和敌人选择共用。
## 使用：rng 为 RandomNumberGenerator；不注入 owner 节点。
func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng


## 作用：累加正权重并按随机抽样选中敌人组。
## 使用：source 中 enemy_groups 提供组配置；无有效权重时返回空字典。
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


## 作用：选择敌人ID来源分组，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 group_config（分组配置）；返回 StringName 文本/标识。
func pick_enemy_id_from_group(group_config: Dictionary) -> StringName:
	var enemy_ids: Array = _get_array(group_config.get("enemy_ids", []))
	if not enemy_ids.is_empty():
		return StringName(String(enemy_ids[_get_rng().randi_range(0, enemy_ids.size() - 1)]))
	return StringName(String(group_config.get("enemy_id", "small_slime")))


## 作用：用组权重计算各组最小/最大数量中点的加权平均。
## 使用：source 为生成来源配置；无有效权重返回 1，结果至少为 1。
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


## 作用：获取随机流，供当前模块后续逻辑使用。
## 使用：本文件由 pick_enemy_group、pick_enemy_id_from_group 调用；返回 RandomNumberGenerator 对象/值。
func _get_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 pick_enemy_group、pick_enemy_id_from_group、weighted_average_group_count 调用；输入 value（值）。
func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
