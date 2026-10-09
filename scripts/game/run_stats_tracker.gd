## 文件用途：记录伤害、状态、击杀、升级、遗物和地图事件并输出局内统计。
## 使用方式：运行场景创建后 reset_run；业务事件调用 record_*，HUD 与结算通过 get_summary 读取快照。

extends Node
class_name RunStatsTracker


signal event_recorded(event_name: StringName, payload: Dictionary)


var selected_character_id: StringName = &""
var selected_map_id: StringName = &""
var selected_map_name: String = ""

var run_seconds: float = 0.0
var boss_phase_started_at: float = -1.0
var boss_hp_at_30s: float = -1.0
var boss_damage_done: int = 0
var kill_count: int = 0
var elite_kill_count: int = 0
var boss_defeated: bool = false
var highest_alive_normal_enemies: int = 0
var seconds_near_alive_cap: float = 0.0

var damage_done_by_origin: Dictionary = {}
var damage_done_by_type: Dictionary = {}
var damage_done_by_element: Dictionary = {}
var damage_taken_by_source: Dictionary = {}
var last_damage_source: String = ""
var status_counts: Dictionary = {}
var reaction_counts: Dictionary = {}
var upgrade_counts: Dictionary = {}
var relics_gained: Array[StringName] = []
var elite_rewards_taken: int = 0
var boss_blessings_taken: int = 0
var poison_instances_taken: int = 0
var healing_used: int = 0
var lava_hits_taken: int = 0
var map_hazard_hits_taken: int = 0
var shield_break_kills: int = 0
var critical_kills: int = 0
var potion_zone_triggers: int = 0
var hunter_rhythm_seconds: float = 0.0
var overload_full_stack_boss_kill: bool = false
var boss_core_spawned_count: int = 0
var boss_core_destroyed_count: int = 0
var boss_core_total_lifetime: float = 0.0


## 作用：清空上一局全部累计值、分类字典、遗物与 Boss 采样状态，并登记本局角色和地图。
## 使用：开局调用；character_id/map_id 为配置 ID，map_name 为结算显示名。
func reset_run(character_id: Variant, map_id: Variant, map_name: String = "") -> void:
	selected_character_id = StringName(String(character_id))
	selected_map_id = StringName(String(map_id))
	selected_map_name = map_name
	run_seconds = 0.0
	boss_phase_started_at = -1.0
	boss_hp_at_30s = -1.0
	boss_damage_done = 0
	kill_count = 0
	elite_kill_count = 0
	boss_defeated = false
	highest_alive_normal_enemies = 0
	seconds_near_alive_cap = 0.0
	damage_done_by_origin.clear()
	damage_done_by_type.clear()
	damage_done_by_element.clear()
	damage_taken_by_source.clear()
	last_damage_source = ""
	status_counts.clear()
	reaction_counts.clear()
	upgrade_counts.clear()
	relics_gained.clear()
	elite_rewards_taken = 0
	boss_blessings_taken = 0
	poison_instances_taken = 0
	healing_used = 0
	lava_hits_taken = 0
	map_hazard_hits_taken = 0
	shield_break_kills = 0
	critical_kills = 0
	potion_zone_triggers = 0
	hunter_rhythm_seconds = 0.0
	overload_full_stack_boss_kill = false
	boss_core_spawned_count = 0
	boss_core_destroyed_count = 0
	boss_core_total_lifetime = 0.0


## 作用：把局内经过秒数更新为非负值。
## 使用：由运行时间同步入口调用；该值用于 DPS 和 Boss 核心寿命统计。
func set_run_time(seconds: float) -> void:
	run_seconds = maxf(seconds, 0.0)


## 作用：累计有效输出伤害，按来源、伤害类型和元素分类，并记录对 Boss 的输出。
## 使用：amount 必须为正；target 为受击节点，result 为结算结果，packet 提供来源标记；发出 damage_done 事件。
func record_damage_done(target: Node, amount: int, result: Dictionary, packet: Variant = {}) -> void:
	if amount <= 0:
		return
	var origin: String = _extract_origin(packet, result)
	var damage_type: String = String(result.get("damage_type", "unknown"))
	var element: String = String(result.get("element", "unknown"))
	_add_number(damage_done_by_origin, origin, amount)
	_add_number(damage_done_by_type, damage_type, amount)
	_add_number(damage_done_by_element, element, amount)
	if _is_boss(target):
		boss_damage_done += amount
	event_recorded.emit(&"damage_done", {"target": target, "amount": amount, "origin": origin, "damage_type": damage_type, "element": element})


## 作用：按来源累计有效承伤，并记录最近来源、毒伤、熔岩和地图危险次数。
## 使用：amount 必须为正；packet 的来源字段优先于 result，随后发出 damage_taken 事件。
func record_damage_taken(amount: int, result: Dictionary, packet: Variant = {}) -> void:
	if amount <= 0:
		return
	var source: String = _extract_taken_source(packet, result)
	_add_number(damage_taken_by_source, source, amount)
	last_damage_source = source
	if source == "poison":
		poison_instances_taken += 1
	if source == "lava" or source == "map_lava":
		lava_hits_taken += 1
	if source.begins_with("map_"):
		map_hazard_hits_taken += 1
	event_recorded.emit(&"damage_taken", {"amount": amount, "source": source})


## 作用：累计状态施加次数及指定反应计数，并广播对应统计事件。
## 使用：status_id 为状态 ID，target 为可选目标；感电另发 shock_triggered，同时广播 status_applied 和 apply_status。
func record_status_applied(status_id: Variant, target: Node = null) -> void:
	var id: String = String(status_id)
	if id == "":
		return
	_add_number(status_counts, id, 1)
	if ["overload", "combustion", "shatter", "soul_burn", "shock"].has(id):
		_add_number(reaction_counts, id, 1)
		if id == "shock":
			event_recorded.emit(&"shock_triggered", {"status_id": id, "target": target})
	event_recorded.emit(&"status_applied", {"status_id": id, "target": target})
	event_recorded.emit(&"apply_status", {"status_id": id, "target": target})


## 作用：累计普通、精英及 Boss 击杀，并记录击杀时的暴击和特定状态信息。
## 使用：enemy 应保留等阶、最近伤害与状态信息；死亡奖励入口调用一次，随后发出 enemy_killed。
func record_enemy_killed(enemy: Node) -> void:
	kill_count += 1
	var rank: String = _get_enemy_rank(enemy)
	if rank == "elite":
		elite_kill_count += 1
	if rank == "boss":
		boss_defeated = true
	if bool(enemy.get_meta("last_damage_was_critical", false)):
		critical_kills += 1
	if enemy != null and enemy.has_method("has_status"):
		if bool(enemy.call("has_status", &"armor_break")) or bool(enemy.call("has_status", &"holy_mark")) or bool(enemy.call("has_status", &"judgment")):
			shield_break_kills += 1
	event_recorded.emit(&"enemy_killed", {"enemy": enemy, "enemy_rank": rank})


## 作用：累计猎手节奏的有效持续时间。
## 使用：delta 为秒；用于结算猎手特质表现。
func record_hunter_rhythm(delta: float) -> void:
	hunter_rhythm_seconds += maxf(delta, 0.0)


## 作用：累计药剂区域触发次数并广播触发事件。
## 使用：角色特质成功触发时调用一次。
func record_potion_zone_triggered() -> void:
	potion_zone_triggers += 1
	event_recorded.emit(&"potion_zone_triggered", {})


## 作用：按升级 ID 累计本局选取次数。
## 使用：upgrade_id 为实际应用的升级标识，重复选择会递增同一计数。
func record_upgrade_applied(upgrade_id: Variant) -> void:
	_add_number(upgrade_counts, String(upgrade_id), 1)


## 作用：把非空遗物 ID 加入本局去重列表并广播首次获得事件。
## 使用：relic_id 为配置 ID；重复或空 ID 不修改列表也不广播事件。
func record_relic_gained(relic_id: Variant) -> void:
	var id: StringName = StringName(String(relic_id))
	if id != &"" and not relics_gained.has(id):
		relics_gained.append(id)
		event_recorded.emit(&"relic_gained", {"relic_id": id})


## 作用：统计精英奖励及 Boss 祝福选取，并广播奖励类型事件。
## 使用：kind 为奖励类别字符串；仅 elite/boss_blessing 增加专用奖励计数。
func record_reward_taken(kind: String) -> void:
	if kind == "elite":
		elite_rewards_taken += 1
	elif kind == "boss_blessing":
		boss_blessings_taken += 1
	event_recorded.emit(StringName("%s_reward" % kind), {"reward_kind": kind})


## 作用：把正数治疗量加入本局治疗总量。
## 使用：amount 为实际治疗值；零或负值忽略，计数代表治疗量而非次数。
func record_healing(amount: int) -> void:
	if amount > 0:
		healing_used += amount


## 作用：累计地图危险命中，并为熔岩裂隙或毒雾累加对应承伤次数。
## 使用：hazard_type 为危险类型；一次有效命中调用一次并广播 map_event。
func record_map_hazard_hit(hazard_type: String) -> void:
	map_hazard_hits_taken += 1
	if hazard_type == "lava_fissure":
		lava_hits_taken += 1
	elif hazard_type == "toxic_fog":
		poison_instances_taken += 1
	event_recorded.emit(&"map_event", {"map_variable": hazard_type})


## 作用：广播指定地图变量事件给统计订阅者。
## 使用：map_variable 为地图变量 ID；本函数不增加本地计数，仅发出 map_event。
func record_map_event(map_variable: String) -> void:
	event_recorded.emit(&"map_event", {"map_variable": map_variable})


## 作用：记录 Boss 核心生成计数并为节点保存生成时刻。
## 使用：core 为可选核心节点；传入节点时写入局内秒数元数据，供销毁统计使用。
func record_boss_core_spawned(core: Node = null) -> void:
	boss_core_spawned_count += 1
	if core != null:
		core.set_meta("boss_core_spawn_run_seconds", run_seconds)
	event_recorded.emit(&"boss_core_spawned", {"core": core})


## 作用：累计 Boss 核心摧毁数及可追踪核心的存活时间。
## 使用：core 为可选核心节点；有生成时刻元数据时累加寿命，供平均值计算。
func record_boss_core_destroyed(core: Node = null) -> void:
	boss_core_destroyed_count += 1
	var lifetime: float = 0.0
	if core != null and core.has_meta("boss_core_spawn_run_seconds"):
		lifetime = maxf(run_seconds - float(core.get_meta("boss_core_spawn_run_seconds")), 0.0)
	boss_core_total_lifetime += lifetime
	event_recorded.emit(&"boss_core_destroyed", {"core": core, "lifetime": lifetime})


## 作用：更新最高同时存活敌人数，并累计接近敌人数上限的时间。
## 使用：alive_count/max_alive 为数量，delta 为秒；达到上限的 85% 时累加压力时长。
func update_wave_pressure(alive_count: int, max_alive: int, delta: float) -> void:
	highest_alive_normal_enemies = maxi(highest_alive_normal_enemies, alive_count)
	if max_alive > 0 and float(alive_count) >= float(max_alive) * 0.85:
		seconds_near_alive_cap += maxf(delta, 0.0)


## 作用：首次登记 Boss 阶段起始时刻，经过 30 秒后保存剩余血量比例。
## 使用：boss 为当前 Boss 节点；调用频率由编排控制，已采样后不覆盖结果。
func update_boss_snapshot(boss: Node) -> void:
	if boss == null:
		return
	if boss_phase_started_at < 0.0:
		boss_phase_started_at = run_seconds
	var elapsed_boss: float = run_seconds - boss_phase_started_at
	if boss_hp_at_30s < 0.0 and elapsed_boss >= 30.0:
		var max_hp: float = maxf(float(boss.get("max_health")), 1.0)
		boss_hp_at_30s = clampf(float(boss.get("current_health")) / max_hp, 0.0, 1.0)


## 作用：输出角色地图、DPS、分类伤害、击杀、成长、特质及地图统计的结算快照。
## 使用：调用读取当前累积结果；内部分类字典深拷贝，派生总量和平均核心寿命在这里计算；返回字典包含 selected_character_id/selected_map_id/selected_map_name/run_seconds/boss_phase_started_at/boss_hp_at_30s/boss_damage_done/boss_dps 等字段。
func get_summary() -> Dictionary:
	var total_done: int = _sum_dictionary(damage_done_by_origin)
	var total_taken: int = _sum_dictionary(damage_taken_by_source)
	return {
		"selected_character_id": selected_character_id,
		"selected_map_id": selected_map_id,
		"selected_map_name": selected_map_name,
		"run_seconds": run_seconds,
		"boss_phase_started_at": boss_phase_started_at,
		"boss_hp_at_30s": boss_hp_at_30s,
		"boss_damage_done": boss_damage_done,
		"boss_dps": boss_damage_done / maxf(run_seconds - boss_phase_started_at, 1.0) if boss_phase_started_at >= 0.0 else 0.0,
		"kill_count": kill_count,
		"elite_kill_count": elite_kill_count,
		"boss_defeated": boss_defeated,
		"highest_alive_normal_enemies": highest_alive_normal_enemies,
		"seconds_near_alive_cap": seconds_near_alive_cap,
		"damage_done_by_origin": damage_done_by_origin.duplicate(true),
		"damage_done_by_type": damage_done_by_type.duplicate(true),
		"damage_done_by_element": damage_done_by_element.duplicate(true),
		"damage_done_total": total_done,
		"damage_taken_by_source": damage_taken_by_source.duplicate(true),
		"damage_taken_total": total_taken,
		"last_damage_source": last_damage_source,
		"status_counts": status_counts.duplicate(true),
		"reaction_counts": reaction_counts.duplicate(true),
		"upgrade_counts": upgrade_counts.duplicate(true),
		"relics_gained": relics_gained.duplicate(),
		"elite_rewards_taken": elite_rewards_taken,
		"boss_blessings_taken": boss_blessings_taken,
		"poison_instances_taken": poison_instances_taken,
		"healing_used": healing_used,
		"lava_hits_taken": lava_hits_taken,
		"map_hazard_hits_taken": map_hazard_hits_taken,
		"shield_break_kills": shield_break_kills,
		"critical_kills": critical_kills,
		"potion_zone_triggers": potion_zone_triggers,
		"hunter_rhythm_seconds": hunter_rhythm_seconds,
		"overload_full_stack_boss_kill": overload_full_stack_boss_kill,
		"boss_core_spawned_count": boss_core_spawned_count,
		"boss_core_destroyed_count": boss_core_destroyed_count,
		"boss_core_average_lifetime": boss_core_total_lifetime / maxf(float(boss_core_destroyed_count), 1.0) if boss_core_destroyed_count > 0 else 0.0
	}


## 作用：从场景树 run_stats_tracker 分组获取当前局统计节点。
## 使用：tree 可省略并使用 Engine 主循环；没有有效场景树或统计节点时返回 null。
static func get_active(tree: SceneTree = null) -> RunStatsTracker:
	var active_tree: SceneTree = tree if tree != null else Engine.get_main_loop() as SceneTree
	if active_tree == null:
		return null
	return active_tree.get_first_node_in_group(&"run_stats_tracker") as RunStatsTracker


## 作用：把本节点登记进 run_stats_tracker 分组。
## 使用：由 Godot 自动调用，供 get_active 查找当前局统计器。
func _ready() -> void:
	add_to_group(&"run_stats_tracker")


## 作用：按伤害包来源标记和结果类型确定输出伤害来源类别。
## 使用：依次检查 damage_origin/origin/source_type，再按结果伤害类型回退到持续、反应、领域或主攻击；返回 String 文本/标识。
func _extract_origin(packet: Variant, result: Dictionary) -> String:
	for key: String in ["damage_origin", "origin", "source_type"]:
		var value: String = _packet_string_value(packet, key)
		if value != "":
			return value
	var damage_type: String = String(result.get("damage_type", ""))
	if damage_type == "status_dot":
		return "status_dot"
	if damage_type == "reaction" or damage_type == "reaction_damage":
		return "reaction"
	if damage_type == "area_direct":
		return "field"
	return "primary_attack"


## 作用：按包的来源 ID、来源类型及元素确定承伤来源键。
## 使用：伤害包字段优先，缺失时使用 result；用于承伤分类统计；返回 String 文本/标识。
func _extract_taken_source(packet: Variant, result: Dictionary) -> String:
	for key: String in ["source_id", "source", "source_type", "element"]:
		var value: String = _packet_string_value(packet, key)
		if value != "":
			return value
	return String(result.get("element", "contact"))


## 作用：伤害包字符串值。
## 使用：本文件由 _extract_origin、_extract_taken_source 调用；输入 packet（伤害包）、key（键）；返回 String 文本/标识。
func _packet_string_value(packet: Variant, key: String) -> String:
	if packet is DamagePacket:
		return String(packet.get_value(key, ""))
	if packet is Dictionary:
		return String(packet.get(key, ""))
	return ""


## 作用：判断Boss，返回布尔判断结果。
## 使用：本文件由 record_damage_done 调用；输入 node（节点）。
func _is_boss(node: Node) -> bool:
	return node != null and String(node.get_meta("enemy_rank", "")) == "boss"


## 作用：获取敌人等阶，供当前模块后续逻辑使用。
## 使用：本文件由 record_enemy_killed 调用；输入 enemy（敌人）；返回 String 文本/标识。
func _get_enemy_rank(enemy: Node) -> String:
	if enemy == null:
		return "unknown"
	return String(enemy.get_meta("enemy_rank", "normal"))


## 作用：在指定字典的键上累加整数值。
## 使用：dictionary 为共享统计容器，key 为分类键；直接更新传入字典。
func _add_number(dictionary: Dictionary, key: String, value: int) -> void:
	dictionary[key] = int(dictionary.get(key, 0)) + value


## 作用：把统计字典内的数值相加为整数总量。
## 使用：传入分类计数字典；返回累积总值，不改变字典。
func _sum_dictionary(dictionary: Dictionary) -> int:
	var total: int = 0
	for value: Variant in dictionary.values():
		total += int(value)
	return total
