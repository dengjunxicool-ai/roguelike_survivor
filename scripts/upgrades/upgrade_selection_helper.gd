## 文件用途：提供选项洗牌、稀有度加权抽样和按卡片 ID、学习技能 ID 双重去重。
## 使用方式：UpgradePool 提供专属 RNG；填充和洗牌会原地修改数组，抽取优先使用 payload.weight。
extends RefCounted
class_name UpgradeSelectionHelper


## 作用：先洗牌候选，再按权重抽取并移除候选，去重填充至所需数量。
## 使用：selected_options 为原地填充的已选卡片；option_pool 为抽取时消耗的候选池；requested_count 为请求卡片数。
static func fill_from_weighted_pool(selected_options: Array, option_pool: Array, requested_count: int, rng: RandomNumberGenerator, rarity_weights: Dictionary) -> void:
	shuffle_options(option_pool, rng)
	while selected_options.size() < requested_count and not option_pool.is_empty():
		var option_index: int = pick_weighted_option_index(option_pool, rng, rarity_weights)
		var option: RefCounted = option_pool[option_index]
		option_pool.remove_at(option_index)
		add_unique_options(selected_options, [option], requested_count)


## 作用：按选项 ID 与 learn_skill_id 双重去重，将候选追加到数量上限。
## 使用：target 为本次命中目标；source 为来源数据或对象；max_count 为数量上限。
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


## 作用：按原顺序取前 count 项引用，数量截断到有效范围。
## 使用：options 为候选卡片列表；count 为所需数量。
static func take_options(options: Array, count: int) -> Array:
	var taken_options: Array = []
	var take_count: int = mini(maxi(count, 0), options.size())
	for option_index in range(take_count):
		taken_options.append(options[option_index])
	return taken_options


## 作用：使用传入随机流原地执行 Fisher–Yates 洗牌。
## 使用：options 为候选卡片列表；rng 为保持本次流程顺序的随机流。
static func shuffle_options(options: Array, rng: RandomNumberGenerator) -> void:
	for option_index in range(options.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, option_index)
		var value: Variant = options[option_index]
		options[option_index] = options[swap_index]
		options[swap_index] = value


## 作用：按候选权重累计区间抽取下标，总权重非正时改为均匀抽取。
## 使用：options 为候选卡片列表；rng 为保持本次流程顺序的随机流；rarity_weights 为稀有度权重表。
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


## 作用：优先取载荷显式 weight，否则按卡片 rarity 查询权重并截断非负。
## 使用：rarity_weights 为稀有度权重表。
static func get_option_weight(option: RefCounted, rarity_weights: Dictionary) -> float:
	if option == null:
		return 0.0
	var payload_variant: Variant = option.get("payload")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		if payload.has("weight"):
			return maxf(float(payload.get("weight", 0.0)), 0.0)
	return maxf(float(rarity_weights.get(_string_or(option.get("rarity"), ""), 1.0)), 0.0)


## 作用：读取卡片载荷 learn_skill_id，非学习卡返回空 ID。
## 使用：由本文件 add_unique_options 调用。
static func get_option_learn_skill_id(option: RefCounted) -> StringName:
	if option == null:
		return &""
	var payload_variant: Variant = option.get("payload")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		if payload.has("learn_skill_id"):
			return StringName(_string_or(payload.get("learn_skill_id", ""), ""))
	return &""


## 作用：把 Variant 转为字符串，null时使用默认文字。
## 使用：default_value 为缺值备用结果。
static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
