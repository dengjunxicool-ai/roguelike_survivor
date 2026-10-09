## 文件用途：复制敌人配置容器、应用等阶分组并解析行为攻击范围。
## 使用方式：EnemyBase 初始化时调用静态接口；duplicate_* 复制容器，apply_classification_metadata 登记分组，behavior_attack_range 返回行为射程。

extends RefCounted
class_name EnemyConfigHelper


## 作用：深拷贝有效字典，类型不符时返回空字典。
## 使用：value 为任意配置值；调用者修改返回容器不会改变原配置。
static func duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 作用：深拷贝数组中的字典条目并忽略其他类型条目。
## 使用：value 为配置数组；非数组返回空列表，结果为 Array[Dictionary]。
static func duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			result.append(item.duplicate(true))
	return result


## 作用：根据已有 enemy_rank 元数据或配置设置敌人等阶并重建 Boss、精英、核心分组。
## 使用：enemy 必须是有效节点；已有元数据覆盖 enemy_config 的等阶，移除过期分组后登记当前等阶。
static func apply_classification_metadata(enemy: Node, enemy_config: Dictionary) -> void:
	if enemy == null:
		return
	var enemy_rank: String = String(enemy.get_meta("enemy_rank", enemy_config["enemy_rank"]))
	enemy.set_meta("enemy_rank", enemy_rank)
	for group: StringName in [&"bosses", &"elites", &"boss_cores"]:
		if enemy.is_in_group(group):
			enemy.remove_from_group(group)
	if enemy_rank == "boss":
		enemy.add_to_group(&"bosses")
	elif enemy_rank == "elite":
		enemy.add_to_group(&"elites")
	elif enemy_rank == "boss_core":
		enemy.add_to_group(&"boss_cores")


## 作用：按行为类型读取首选射程或触发半径，缺少配置时使用基础攻击范围。
## 使用：behavior 为行为字典，attack_range 为基础值；支持射手、自爆、召唤、伤害池、突进及 Boss 行为；返回计算或读取的数值。
static func behavior_attack_range_fallback(behavior: Dictionary, attack_range: float) -> float:
	match String(behavior.get("type", "")):
		"keep_distance_and_shoot":
			return float(behavior.get("preferred_distance", attack_range))
		"explode_near_player":
			return float(behavior.get("trigger_radius", attack_range))
		"summon_and_chase":
			return float(behavior.get("summon_range", behavior.get("attack_range", attack_range)))
		"chase_and_cast_pool":
			return float(behavior.get("cast_range", behavior.get("attack_range", attack_range)))
		"dash_attack":
			return float(behavior.get("dash_trigger_range", behavior.get("attack_range", attack_range)))
		"boss_dungeon_heart":
			return float(behavior.get("skill_range", behavior.get("attack_range", attack_range)))
		_:
			return attack_range


## 作用：为召唤、伤害池、突进和 Boss 行为解析专用射程。
## 使用：behavior 为行为字典，attack_range 为基础值；其他行为类型直接使用基础范围；返回计算或读取的数值。
static func behavior_attack_range(behavior: Dictionary, attack_range: float) -> float:
	match String(behavior.get("type", "")):
		"summon_and_chase":
			return float(behavior.get("summon_range", behavior.get("attack_range", attack_range)))
		"chase_and_cast_pool":
			return float(behavior.get("cast_range", behavior.get("attack_range", attack_range)))
		"dash_attack":
			return float(behavior.get("dash_trigger_range", behavior.get("attack_range", attack_range)))
		"boss_dungeon_heart":
			return float(behavior.get("skill_range", behavior.get("attack_range", attack_range)))
		_:
			return attack_range
