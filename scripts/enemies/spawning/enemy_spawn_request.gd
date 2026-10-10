## 文件用途：构建敌人生成请求并携带位置、场景与来源信息。
## 使用方式：由生成调用者组装请求，交给 EnemySpawnService.spawn。

extends RefCounted
class_name EnemySpawnRequest


## 作用：深拷贝参数并写入规范化敌人 ID，补齐默认来源和倍率字典。
## 使用：enemy_id 为配置标识，params 为生成选项；返回请求供 EnemySpawnService.spawn 使用，缺省来源为 unknown。
static func create(enemy_id: Variant, params: Dictionary = {}) -> Dictionary:
	var request: Dictionary = params.duplicate(true)
	request["enemy_id"] = StringName(String(enemy_id))
	if not request.has("source_type"):
		request["source_type"] = "unknown"
	if not request.has("multipliers"):
		request["multipliers"] = {}
	return request


## 作用：构建来源为 map_event、等阶为 normal 的地图事件生成请求。
## 使用：enemy_id 为配置标识，multipliers 为生成倍率；选位由生成服务负责；返回字典包含 source_type/multipliers/enemy_rank。
static func map_event(enemy_id: Variant, multipliers: Dictionary = {}) -> Dictionary:
	return create(enemy_id, {
		"source_type": "map_event",
		"multipliers": multipliers,
		"enemy_rank": "normal"
	})


## 作用：构建带指定位置、倍率与召唤者来源且不奖励灵魂的召唤请求。
## 使用：position 为世界坐标，source_id 为召唤者标识；返回请求，未直接生成节点。
static func summon(enemy_id: Variant, position: Vector2, multipliers: Dictionary = {}, source_id: Variant = "") -> Dictionary:
	return create(enemy_id, {
		"source_type": "summon",
		"source_id": String(source_id),
		"position": position,
		"multipliers": multipliers,
		"reward_policy": {
			"award_soul": false,
			"drop_experience": false
		}
	})


## 作用：构建固定位置、禁用灵魂和经验掉落的 Boss 核心生成请求。
## 使用：hp/armor/resistances 为核心属性；入树后覆盖血量、防御和零移速，来源/等阶均标为 boss_core；返回字典包含 source_type/position/spawn_clearance/multipliers/enemy_rank/reward_policy/award_soul/drop_experience 等字段。
static func boss_core(enemy_id: Variant, position: Vector2, hp: int, armor: int, resistances: Dictionary = {}) -> Dictionary:
	return create(enemy_id, {
		"source_type": "boss_core",
		"position": position,
		"spawn_clearance": 0.0,
		"multipliers": {"hp": 1.0, "damage": 0.01, "exp": 0.0},
		"enemy_rank": "boss_core",
		"reward_policy": {
			"award_soul": false,
			"drop_experience": false
		},
		"post_ready_properties": {
			"max_health": hp,
			"current_health": hp,
			"armor": armor,
			"resistances": resistances.duplicate(true),
			"move_speed": 0.0,
			"dropped_experience": 0,
			"soul_drop": 0
		}
	})
