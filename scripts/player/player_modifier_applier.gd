## 文件用途：把已聚合属性快照应用到玩家基础字段、生命值和环境倍率。
## 使用方式：Player 的属性来源接口调用 apply(player,modifiers)；输入为聚合字典，动态作用域另由 ModifierStore 查询。

extends RefCounted
class_name PlayerModifierApplier

const SNAPSHOT_FIELDS: Array[String] = [
	"max_health", "attack_speed_multiplier", "armor", "experience_gain_multiplier",
	"coin_gain_multiplier", "soul_gain_multiplier", "damage_taken_multiplier", "skill_area_multiplier",
	"rare_weight_add", "epic_weight_add", "legendary_weight_add", "level_up_rerolls",
	"enemy_spawn_count_multiplier_add", "boss_hp_multiplier_add", "on_hit_slow_chance_add",
	"slow_percent", "slow_duration", "revive_hp_percent", "thorns_damage",
	"thorns_area_radius", "status_duration_multiplier", "aura_slow_enabled", "aura_radius"
]
var _base_snapshot: Dictionary = {}
var _last_snapshot: Dictionary = {}
const MAX_SNAPSHOT_KEYS: Array[String] = ["slow_percent", "slow_duration", "revive_hp_percent", "thorns_area_radius", "aura_radius"]
var _revive_sources: Dictionary = {}
var _base_revives: int = 0
var _last_revive_balance: int = -1

func reset_snapshot() -> void:
	_base_snapshot.clear()
	_last_snapshot.clear()
	_revive_sources.clear()
	_base_revives = 0
	_last_revive_balance = -1

## Rebuild sustained fields from their base, preserving changes made outside this applier
## (including consumed revives). Healing and skill levels are events, never replayed here.
func apply_snapshot(player: Node, modifiers: Dictionary, revive_grants: Dictionary = {}) -> void:
	var old_max: int = int(player.get("max_health"))
	var current: int = int(player.get("current_health"))
	for field: String in SNAPSHOT_FIELDS:
		var value: Variant = player.get(field)
		if not _base_snapshot.has(field):
			_base_snapshot[field] = value
		elif value != _last_snapshot.get(field):
			if typeof(value) == TYPE_BOOL:
				_base_snapshot[field] = value
			else:
				_base_snapshot[field] += value - _last_snapshot[field]
		player.set(field, _base_snapshot[field])
	var sustained: Dictionary = modifiers.duplicate(true)
	for key: String in ["heal", "heal_percent_max", "all_owned_skills_level_add", "revive_count_add"]:
		sustained.erase(key)
	apply(player, sustained, false)
	_refresh_revives(player, revive_grants)
	var new_max: int = int(player.get("max_health"))
	player.set("current_health", mini(current + maxi(new_max - old_max, 0), new_max))
	for field: String in SNAPSHOT_FIELDS:
		_last_snapshot[field] = player.get(field)
	if old_max != new_max:
		player.emit_signal("health_changed", int(player.get("current_health")), new_max)

## Attribute externally consumed charges in registration order. Removed sources keep their
## spent ledger, so replacing the same source cannot grant its used charge again.
func _refresh_revives(player: Node, grants: Dictionary) -> void:
	var current: int = maxi(int(player.get("revive_count_add")), 0)
	if _last_revive_balance < 0:
		_base_revives = current
	elif current > _last_revive_balance:
		_base_revives += current - _last_revive_balance
	elif current < _last_revive_balance:
		var spent: int = _last_revive_balance - current
		var base_spent: int = mini(_base_revives, spent)
		_base_revives -= base_spent
		spent -= base_spent
		for source: Dictionary in _revive_sources.values():
			var available: int = maxi(int(source.granted) - int(source.consumed), 0)
			var source_spent: int = mini(available, spent)
			source.consumed += source_spent
			spent -= source_spent
	for source: Dictionary in _revive_sources.values():
		source.granted = 0
	for source_id: String in grants.keys():
		if not _revive_sources.has(source_id):
			_revive_sources[source_id] = {"granted":0,"consumed":0}
		_revive_sources[source_id].granted = maxi(int(grants[source_id]), 0)
	var balance: int = _base_revives
	for source: Dictionary in _revive_sources.values():
		balance += maxi(int(source.granted) - int(source.consumed), 0)
	player.set("revive_count_add", balance)
	_last_revive_balance = balance

func apply_events(player: Node, modifiers: Dictionary) -> void:
	var levels: int = int(modifiers.get("all_owned_skills_level_add", 0))
	if levels != 0:
		player.call("_upgrade_all_owned_skills", levels)
	var heal: int = int(modifiers.get("heal", 0))
	heal += roundi(float(player.get("max_health")) * float(modifiers.get("heal_percent_max", 0.0)))
	if heal > 0:
		preload("res://scripts/player/player_healing.gd").apply(player, heal)


## 作用：按既定顺序应用技能全体升级、血量、基础属性与环境修正。
## 使用：player 为玩家节点，modifiers 为已聚合快照；会更新字段、发血量信号并通知生成器。
func apply(player: Node, modifiers: Dictionary, emit_health: bool = true) -> void:
	var all_owned_skills_level_add: int = int(modifiers.get("all_owned_skills_level_add", 0))
	if all_owned_skills_level_add != 0:
		player.call("_upgrade_all_owned_skills", all_owned_skills_level_add)

	_apply_health_modifiers(player, modifiers, emit_health)
	_multiply_float(player, "move_speed", float(modifiers.get("move_speed_multiplier", 1.0)))
	_multiply_float(player, "move_speed", 1.0 + float(modifiers.get("move_speed_multiplier_add", 0.0)))
	_multiply_float(player, "damage_multiplier", float(modifiers.get("damage_multiplier", 1.0)))
	_add_float(player, "damage_multiplier", float(modifiers.get("damage_multiplier_add", 0.0)))
	_multiply_float(player, "attack_speed_multiplier", float(modifiers.get("attack_speed_multiplier", 1.0)))
	_add_float(player, "attack_speed_multiplier", float(modifiers.get("attack_speed_multiplier_add", 0.0)))
	_add_float(player, "crit_chance", float(modifiers.get("crit_chance_add", 0.0)))
	_add_float(player, "crit_damage", float(modifiers.get("crit_damage_add", 0.0)))
	_add_int(player, "armor", int(modifiers.get("armor_add", 0)))
	_add_float(player, "experience_gain_multiplier", float(modifiers.get("experience_gain_multiplier_add", 0.0)))
	_add_float(player, "coin_gain_multiplier", float(modifiers.get("coin_gain_multiplier_add", 0.0)))
	_add_float(player, "soul_gain_multiplier", float(modifiers.get("soul_gain_multiplier_add", 0.0)))
	_add_float(player, "damage_taken_multiplier", float(modifiers.get("damage_taken_multiplier_add", 0.0)))
	_multiply_float(player, "skill_area_multiplier", float(modifiers.get("skill_area_multiplier", 1.0)))
	_add_float(player, "skill_area_multiplier", float(modifiers.get("skill_area_multiplier_add", 0.0)))
	_add_float(player, "rare_weight_add", float(modifiers.get("rare_weight_add", 0.0)))
	_add_float(player, "epic_weight_add", float(modifiers.get("epic_weight_add", 0.0)))
	_add_float(player, "legendary_weight_add", float(modifiers.get("legendary_weight_add", 0.0)))
	_add_int(player, "level_up_rerolls", int(modifiers.get("level_up_reroll_add", 0)))
	_multiply_float(player, "pickup_radius", 1.0 + float(modifiers.get("pickup_radius_multiplier_add", 0.0)))
	_add_float(player, "pickup_radius", float(modifiers.get("pickup_radius_add", 0.0)))
	_add_float(player, "enemy_spawn_count_multiplier_add", float(modifiers.get("enemy_spawn_count_multiplier_add", 0.0)))
	_add_float(player, "boss_hp_multiplier_add", float(modifiers.get("boss_hp_multiplier_add", 0.0)))
	_add_float(player, "fire_damage_multiplier_add", float(modifiers.get("fire_damage_multiplier_add", 0.0)))
	_add_float(player, "poison_damage_multiplier_add", float(modifiers.get("poison_damage_multiplier_add", 0.0)))
	_add_float(player, "on_hit_slow_chance_add", float(modifiers.get("on_hit_slow_chance_add", 0.0)))
	_set_max_float(player, "slow_percent", float(modifiers.get("slow_percent", player.get("slow_percent"))))
	_set_max_float(player, "slow_duration", float(modifiers.get("slow_duration", player.get("slow_duration"))))
	_add_int(player, "revive_count_add", int(modifiers.get("revive_count_add", 0)))
	_set_max_float(player, "revive_hp_percent", float(modifiers.get("revive_hp_percent", player.get("revive_hp_percent"))))
	_add_int(player, "thorns_damage", int(modifiers.get("thorns_damage", 0)))
	_set_max_float(player, "thorns_area_radius", float(modifiers.get("thorns_area_radius", player.get("thorns_area_radius"))))
	_multiply_float(player, "status_duration_multiplier", float(modifiers.get("status_duration_multiplier", 1.0)))
	_add_float(player, "status_duration_multiplier", float(modifiers.get("status_duration_multiplier_add", 0.0)))
	if modifiers.has("aura_slow_enabled"):
		player.set("aura_slow_enabled", bool(modifiers.get("aura_slow_enabled", player.get("aura_slow_enabled"))))
	_set_max_float(player, "aura_radius", float(modifiers.get("aura_radius", player.get("aura_radius"))))

	_clamp_min_float(player, "attack_speed_multiplier", 0.1)
	_clamp_min_float(player, "damage_taken_multiplier", 0.1)
	_clamp_min_float(player, "experience_gain_multiplier", 0.1)
	_clamp_min_float(player, "coin_gain_multiplier", 0.1)
	_clamp_min_float(player, "soul_gain_multiplier", 0.1)
	_clamp_min_float(player, "status_duration_multiplier", 0.1)
	_clamp_min_float(player, "pickup_radius", 1.0)
	player.call("_apply_environment_modifiers")


## 作用：依次处理生命上限加值、倍率和治疗并限制当前血量。
## 使用：增加上限时补充对应血量；治疗不超过新上限，每个生效步骤发 health_changed。
func _apply_health_modifiers(player: Node, modifiers: Dictionary, emit_health: bool = true) -> void:
	var max_hp_add: int = int(modifiers.get("max_hp_add", 0))
	if max_hp_add != 0:
		var max_health: int = int(player.get("max_health")) + max_hp_add
		var current_health: int = mini(int(player.get("current_health")) + max_hp_add, max_health)
		player.set("max_health", max_health)
		player.set("current_health", current_health)
		if emit_health:
			player.emit_signal("health_changed", current_health, max_health)

	var max_hp_multiplier_add: float = float(modifiers.get("max_hp_multiplier_add", 0.0))
	if max_hp_multiplier_add != 0.0:
		var old_max_health: int = int(player.get("max_health"))
		var new_max_health: int = maxi(roundi(float(old_max_health) * (1.0 + max_hp_multiplier_add)), 1)
		var new_current_health: int = mini(int(player.get("current_health")) + maxi(new_max_health - old_max_health, 0), new_max_health)
		player.set("max_health", new_max_health)
		player.set("current_health", new_current_health)
		if emit_health:
			player.emit_signal("health_changed", new_current_health, new_max_health)

	var heal: int = int(modifiers.get("heal", 0))
	if modifiers.has("heal_percent_max"):
		heal += roundi(float(player.get("max_health")) * float(modifiers.get("heal_percent_max", 0.0)))
	if heal > 0:
		preload("res://scripts/player/player_healing.gd").apply(player, heal)


## 作用：将非零 amount 加到指定浮点属性。
## 使用：target/property 指定对象与字段；就地写入，不聚合来源。
func _add_float(target: Node, property: StringName, amount: float) -> void:
	if amount != 0.0:
		target.set(property, float(target.get(property)) + amount)


## 作用：以 multiplier 乘指定浮点属性。
## 使用：倍率为 1 时不写入；target 必须有对应可读属性。
func _multiply_float(target: Node, property: StringName, multiplier: float) -> void:
	if multiplier != 1.0:
		target.set(property, float(target.get(property)) * multiplier)


## 作用：将非零 amount 加到指定整数属性。
## 使用：target/property 指定字段；将现有值按 int 转换后写回。
func _add_int(target: Node, property: StringName, amount: int) -> void:
	if amount != 0:
		target.set(property, int(target.get(property)) + amount)


## 作用：让指定浮点属性取当前值和 value 中较大者。
## 使用：用于保留更强减速、回复比例等效果；就地修改 target。
func _set_max_float(target: Node, property: StringName, value: float) -> void:
	target.set(property, maxf(float(target.get(property)), value))


## 作用：把指定浮点属性限制为不小于 minimum。
## 使用：apply 最后用于限制倍率/拾取半径；就地修改 target。
func _clamp_min_float(target: Node, property: StringName, minimum: float) -> void:
	target.set(property, maxf(float(target.get(property)), minimum))
