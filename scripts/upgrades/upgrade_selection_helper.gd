extends RefCounted
class_name UpgradeSelectionHelper


static func fill_from_weighted_pool(selected_options: Array, option_pool: Array, requested_count: int, rng: RandomNumberGenerator, rarity_weights: Dictionary) -> void:
	shuffle_options(option_pool, rng)
	while selected_options.size() < requested_count and not option_pool.is_empty():
		var option_index: int = pick_weighted_option_index(option_pool, rng, rarity_weights)
		var option: RefCounted = option_pool[option_index]
		option_pool.remove_at(option_index)
		add_unique_options(selected_options, [option], requested_count)


static func add_unique_options(target: Array, source: Array, max_count: int) -> void:
	var existing_ids: Dictionary = {}
	var existing_learn_skill_ids: Dictionary = {}
	for option_variant: Variant in target:
		var option: RefCounted = option_variant as RefCounted
		if option != null:
			existing_ids[_string_or(option.get("id"), "")] = true
			var learn_skill_id: StringName = get_option_learn_skill_id(option)
			if learn_skill_id != &"":
				existing_learn_skill_ids[learn_skill_id] = true

	for option_variant: Variant in source:
		if target.size() >= max_count:
			return
		var option: RefCounted = option_variant as RefCounted
		if option == null:
			continue
		var option_id: String = _string_or(option.get("id"), "")
		if existing_ids.has(option_id):
			continue
		var learn_skill_id: StringName = get_option_learn_skill_id(option)
		if learn_skill_id != &"" and existing_learn_skill_ids.has(learn_skill_id):
			continue
		target.append(option)
		existing_ids[option_id] = true
		if learn_skill_id != &"":
			existing_learn_skill_ids[learn_skill_id] = true


static func take_options(options: Array, count: int) -> Array:
	var taken_options: Array = []
	var take_count: int = mini(maxi(count, 0), options.size())
	for option_index in range(take_count):
		taken_options.append(options[option_index])
	return taken_options


static func shuffle_options(options: Array, rng: RandomNumberGenerator) -> void:
	for option_index in range(options.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, option_index)
		var value: Variant = options[option_index]
		options[option_index] = options[swap_index]
		options[swap_index] = value


static func pick_weighted_option_index(options: Array, rng: RandomNumberGenerator, rarity_weights: Dictionary) -> int:
	if options.is_empty():
		return 0

	var total_weight: float = 0.0
	for option_variant: Variant in options:
		total_weight += get_option_weight(option_variant as RefCounted, rarity_weights)
	if total_weight <= 0.0:
		return rng.randi_range(0, options.size() - 1)

	var roll: float = rng.randf_range(0.0, total_weight)
	var accumulated: float = 0.0
	for option_index in range(options.size()):
		accumulated += get_option_weight(options[option_index] as RefCounted, rarity_weights)
		if roll <= accumulated:
			return option_index
	return options.size() - 1


static func get_option_weight(option: RefCounted, rarity_weights: Dictionary) -> float:
	if option == null:
		return 0.0
	var payload_variant: Variant = option.get("payload")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		if payload.has("weight"):
			return maxf(float(payload.get("weight", 0.0)), 0.0)
	return maxf(float(rarity_weights.get(_string_or(option.get("rarity"), ""), 1.0)), 0.0)


static func get_option_learn_skill_id(option: RefCounted) -> StringName:
	if option == null:
		return &""
	var payload_variant: Variant = option.get("payload")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		if payload.has("learn_skill_id"):
			return StringName(_string_or(payload.get("learn_skill_id", ""), ""))
	return &""


static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
