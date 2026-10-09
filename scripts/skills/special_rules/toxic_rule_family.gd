## 文件用途：实现毒瓶毒云的状态转换、毒核、稳定场效与玩家解毒增益。
## 使用方式：宿主按毒云 tick、施放及玩家更新调度；状态伤害与叠层上限根据普通和强敌目标分别计算。
extends RefCounted

const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")

static var _toxic_core_boss_pulse_cooldowns: Dictionary = {}

static var _poison_cloud_tick_poison_cooldowns: Dictionary = {}

static var _antidote_cloud_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：按毒系死亡规则生成毒云或毒死亡爆炸。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_toxic_enemy_kill_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	SpecialDamageRuleHandlerScript.execute_toxic_vial_small_cloud(rules, context)
	SpecialDamageRuleHandlerScript.execute_poison_death_explosion(rules, context)


## 作用：毒瓶区域 tick 时依次施加毒种、毒核、中毒和稳定场效果并检查 Boss 脉冲。
## 使用：rules 读取 toxic_vial_base；context 携带 source_id/target；需由仍存活的宿主创建并调度。
func _apply_toxic_vial_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("toxic_vial_base"):
		return
	if String(context.get("source_id", "")) != "poison_cloud_area":
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	host._apply_toxin_seed_on_poison_cloud_tick(rules, target)
	host._apply_toxic_core_on_poison_cloud_tick(rules, target)
	host._convert_toxic_vial_status_to_poison(rules, context, target, "toxin_seed_to_poison")
	host._convert_toxic_vial_status_to_poison(rules, context, target, "toxic_core_to_poison")
	host._apply_poison_on_cloud_tick_chance(rules, context, target)
	host._apply_poison_cloud_stable_effects(rules, target)
	host._apply_toxic_core_boss_pulse(rules, context, target)


## 作用：毒云命中时按规则累积毒种状态。
## 使用：rules 读取 toxin_seed_on_poison_cloud_tick；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_toxin_seed_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("toxin_seed_on_poison_cloud_tick") or target == null or not target.has_method("apply_status"):
		return
	if host._is_elite(target) or host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("toxin_seed_on_poison_cloud_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "toxin_seed"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 4)), 1)
	})


## 作用：毒云命中强敌时按规则累积毒核。
## 使用：rules 读取 toxic_core_on_strong_cloud_tick；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_toxic_core_on_poison_cloud_tick(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("toxic_core_on_strong_cloud_tick") or target == null or not target.has_method("apply_status"):
		return
	if not (host._is_elite(target) or host._is_boss(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("toxic_core_on_strong_cloud_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "toxic_core"))), {
		"duration": float(rule.get("duration", 5.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 4)), 1)
	})


## 作用：满足源状态层数条件时消耗源状态并转换为中毒。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _convert_toxic_vial_status_to_poison(rules: Dictionary, context: Dictionary, target: Node, rule_key: String) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has(rule_key) or target == null or not target.has_method("get_status_stack") or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get(rule_key, {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "toxin_seed")))
	var required: int = maxi(int(rule.get("required_stacks", 4)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	if target.has_method("consume_status_stack"):
		var consume_count: int = 99 if bool(rule.get("consume_all", true)) else required
		target.call("consume_status_stack", status_id, consume_count)
	host._apply_poison_status_from_toxic_vial(rules, context, target, maxi(int(rule.get("apply_stacks", 1)), 1))


## 作用：毒云 tick 通过概率与冷却判断后施加中毒。
## 使用：rules 读取 poison_on_cloud_tick_chance；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_poison_on_cloud_tick_chance(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("poison_on_cloud_tick_chance") or target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("poison_on_cloud_tick_chance", {}))
	var key: String = "poison_cloud_tick:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if now_seconds < float(_poison_cloud_tick_poison_cooldowns.get(key, 0.0)):
		return
	if randf() > clampf(float(rule.get("chance", 0.2)), 0.0, 1.0):
		return
	if not host._reserve_cooldown(_poison_cloud_tick_poison_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.0)), 0.0)):
		return
	host._apply_poison_status_from_toxic_vial(rules, context, target, maxi(int(rule.get("stacks", 1)), 1))


## 作用：以毒瓶基础规则和目标分类构造中毒参数并施加到目标。
## 使用：rules 读取 toxic_vial_base；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_poison_status_from_toxic_vial(rules: Dictionary, context: Dictionary, target: Node, stacks: int) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var base: Dictionary = host._get_dictionary(rules.get("toxic_vial_base", {}))
	var poison_params: Dictionary = host._get_poison_status_params({
		"duration": float(base.get("poison_duration", 4.0)),
		"damage": int(base.get("poison_damage", 12)),
		"tick_interval": float(base.get("poison_tick_interval", 1.0)),
		"stacks": 1,
		"max_stacks": int(base.get("poison_max_stacks", 3))
	}, context.merged({"target": target}))
	poison_params["stacks"] = maxi(stacks, 1)
	target.call("apply_status", &"poison", poison_params)


## 作用：刷新毒云内敌人的限时伤害降低，并施加配置减速。
## 使用：rules 读取 poison_cloud_enemy_damage_down/poison_cloud_slow；target 为本次命中目标；写入 toxic_vial_enemy_damage_down_until/toxic_vial_enemy_damage_multiplier_add 元数据；需由仍存活的宿主创建并调度。
func _apply_poison_cloud_stable_effects(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var now_seconds: float = host._now_seconds()
	if rules.has("poison_cloud_enemy_damage_down"):
		var damage_rule: Dictionary = host._get_dictionary(rules.get("poison_cloud_enemy_damage_down", {}))
		target.set_meta("toxic_vial_enemy_damage_down_until", now_seconds + maxf(float(damage_rule.get("duration", 0.6)), 0.0))
		target.set_meta("toxic_vial_enemy_damage_multiplier_add", float(damage_rule.get("damage_multiplier_add", -0.08)))
	if rules.has("poison_cloud_slow") and target.has_method("apply_status"):
		var slow_rule: Dictionary = host._get_dictionary(rules.get("poison_cloud_slow", {}))
		target.call("apply_status", StringName(String(slow_rule.get("status_id", "slow"))), {
			"duration": float(slow_rule.get("duration", 0.6)),
			"slow_percent": float(slow_rule.get("slow_percent", 0.15)),
			"boss_slow_percent": float(slow_rule.get("boss_slow_percent", 0.08))
		})


## 作用：Boss 毒核层数满足条件且冷却允许时触发毒核脉冲。
## 使用：rules 读取 toxic_core_boss_pulse；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_toxic_core_boss_pulse(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("toxic_core_boss_pulse") or not host._is_boss(target):
		return
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("toxic_core_boss_pulse", {}))
	var required_status: StringName = StringName(String(rule.get("required_status_id", "poison")))
	var max_stacks: int = host._poison_max_stacks_for_target(rules, target)
	if bool(rule.get("required_full_poison", true)) and int(target.call("get_status_stack", required_status)) < max_stacks:
		return
	var key: String = "toxic_core:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_toxic_core_boss_pulse_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.0)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.execute_toxic_core_boss_pulse(rules, context, maxi(int(rule.get("amount", 20)), 0)))


## 作用：玩家低血施放毒瓶满足冷却后生成解毒云并治疗。
## 使用：rules 读取 antidote_cloud_on_low_hp；context 携带 caster；需由仍存活的宿主创建并调度。
func _apply_toxic_vial_antidote_on_cast(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("antidote_cloud_on_low_hp"):
		return
	var caster: Node = context.get("caster") as Node
	if caster == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("antidote_cloud_on_low_hp", {}))
	if host._player_health_ratio(caster) > float(rule.get("hp_threshold", 0.35)):
		return
	var key: String = "antidote:%s" % host._target_key(caster)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_antidote_cloud_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 18.0)), 0.0)):
		return
	host._heal_player(caster, maxi(int(rule.get("heal", 6)), 0))
	SpecialDamageRuleHandlerScript.execute_antidote_cloud(rules, context)


## 作用：根据玩家毒云边缘增益窗口设置或移除移动属性来源。
## 使用：rules 读取 poison_cloud_edge_speed_buff；context 携带 caster；写入 toxic_vial_edge_speed_until 元数据；需由仍存活的宿主创建并调度。
func _update_toxic_vial_player_cloud(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("poison_cloud_edge_speed_buff"):
		return
	var player: Node2D = context.get("caster") as Node2D
	if player == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("poison_cloud_edge_speed_buff", {}))
	var near_edge: bool = false
	var tree: SceneTree = player.get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"areas"):
			var area: Node2D = node as Node2D
			if area == null or not bool(area.get_meta("toxic_vial_poison_cloud", false)):
				continue
			var radius: float = maxf(float(area.get_meta("toxic_vial_poison_cloud_radius", 105.0)), 1.0)
			var edge_width: float = maxf(float(rule.get("edge_width", 24.0)), 1.0)
			var distance: float = player.global_position.distance_to(area.global_position)
			if absf(distance - radius) <= edge_width:
				near_edge = true
				break
	var modifier_id: String = "toxic_vial_edge_speed"
	if near_edge:
		var modifiers: Array = [{
			"stat": "move_speed",
			"op": "multiplier_add",
			"value": float(rule.get("move_speed_multiplier_add", 0.08)),
			"scope": {"domain": "player"}
		}]
		if player.has_method("set_run_modifier_source"):
			player.call("set_run_modifier_source", modifier_id, modifiers)
		player.set_meta("toxic_vial_edge_speed_until", host._now_seconds() + maxf(float(rule.get("duration", 1.0)), 0.0))
	elif host._now_seconds() > float(player.get_meta("toxic_vial_edge_speed_until", 0.0)) and player.has_method("clear_run_modifier_source"):
		player.call("clear_run_modifier_source", modifier_id)


## 作用：结合毒瓶基础和强敌调整规则修饰中毒参数。
## 使用：params 读取 duration/damage/tick_interval/damage_multiplier_add；context 携带 target；会原地更新 params.duration/damage/tick_interval；需由仍存活的宿主创建并调度。
func _get_poison_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	var target: Node = context.get("target") as Node
	var base: Dictionary = host._get_dictionary(rules.get("toxic_vial_base", {}))
	if not base.is_empty():
		params["duration"] = float(params.get("duration", base.get("poison_duration", 4.0)))
		params["damage"] = int(params.get("damage", base.get("poison_damage", 12)))
		params["tick_interval"] = float(params.get("tick_interval", base.get("poison_tick_interval", 1.0)))
	params["max_stacks"] = host._poison_max_stacks_for_target(rules, target)
	if (host._is_elite(target) or host._is_boss(target)) and rules.has("poison_elite_boss_tuning"):
		var tuning: Dictionary = host._get_dictionary(rules.get("poison_elite_boss_tuning", {}))
		params["damage_multiplier_add"] = float(params.get("damage_multiplier_add", 0.0)) + float(tuning.get("elite_boss_dot_multiplier_add", 0.1))
	return params


## 作用：按普通、精英与 Boss 分类计算中毒层数上限。
## 使用：rules 读取 toxic_vial_base/poison_max_stack_tuning；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _poison_max_stacks_for_target(rules: Dictionary, target: Node) -> int:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var base: Dictionary = host._get_dictionary(rules.get("toxic_vial_base", {}))
	var max_stacks: int = maxi(int(base.get("poison_max_stacks", 3)), 1)
	if rules.has("poison_max_stack_tuning"):
		var tuning: Dictionary = host._get_dictionary(rules.get("poison_max_stack_tuning", {}))
		if host._is_boss(target):
			max_stacks += int(tuning.get("boss_max_stacks_add", 0))
		else:
			max_stacks += int(tuning.get("max_stacks_add", 0))
	return maxi(max_stacks, 1)
