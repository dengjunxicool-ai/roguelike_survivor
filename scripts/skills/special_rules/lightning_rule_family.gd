## 文件用途：实现闪电弹跳、电压、过载、感电及感电消耗反应。
## 使用方式：宿主在投射物命中时调用；规则可消耗状态层数、生成衍生电击并用来源冷却限制重复触发。
extends RefCounted

const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")

static var _overload_target_cooldowns: Dictionary = {}

static var _overload_shock_lightning_cooldowns: Dictionary = {}

static var _shock_hit_cooldowns: Dictionary = {}

static var _magnetic_storm_cooldowns: Dictionary = {}

static var _voltage_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：依次执行闪电弹跳、电压、过载、感电与感电消耗反应。
## 使用：rules 为当前技能有效规则；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_lightning_projectile_hit_rules(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	host._apply_lightning_chain_bounce(rules, context)
	host._apply_voltage_on_elite_boss_hit(rules, context)
	host._apply_overload_on_voltage(rules, context)
	host._apply_shock_on_lightning_orb_hit(rules, context)
	host._apply_shock_consume_reaction(rules, context)


## 作用：按连锁弹跳规则派生额外闪电命中。
## 使用：rules 读取 lightning_chain_bounce；context 为施放或命中上下文；需由仍存活的宿主创建并调度。
func _apply_lightning_chain_bounce(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("lightning_chain_bounce"):
		return
	SpecialDamageRuleHandlerScript.execute_lightning_chain_bounce(rules, context, host._get_skill_damage(context))


## 作用：强敌命中在同来源冷却允许时累积电压层数。
## 使用：rules 读取 voltage_on_elite_boss_hit；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_voltage_on_elite_boss_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("voltage_on_elite_boss_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	if not host._is_elite(target) and not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("voltage_on_elite_boss_hit", {}))
	var key: String = "voltage:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_voltage_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.45)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("status_id", "voltage"))), {
		"stacks": int(rule.get("stack", 1)),
		"max_stacks": int(rule.get("max_stacks", 5)),
		"duration": float(rule.get("duration", 4.0))
	})


## 作用：电压满足门槛后消耗层数并触发过载伤害与感电相关效果。
## 使用：rules 读取 overload_on_voltage/shock_upgrade；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_overload_on_voltage(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("overload_on_voltage"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("overload_on_voltage", {}))
	var status_id: StringName = StringName(String(rule.get("status_id", "voltage")))
	var stacks: int = int(target.call("get_status_stack", status_id))
	var required_stacks: int = maxi(int(rule.get("required_stacks", 5)), 1)
	if stacks < required_stacks:
		return
	var key: String = "lightning_overload:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_overload_target_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.2)), 0.0)):
		return
	var had_shock: bool = target.has_method("has_status") and bool(target.call("has_status", &"shock"))
	var consume_stacks: int = stacks if bool(rule.get("consume_all", true)) else maxi(int(rule.get("consume_stacks", required_stacks)), 0)
	if consume_stacks > 0 and target.has_method("consume_status_stack"):
		target.call("consume_status_stack", status_id, consume_stacks)
	var amount: int = maxi(int(rule.get("amount", 18)), 0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.lightning_overload_intents(rules, context, amount))
	if target.has_method("apply_status"):
		target.call("apply_status", StringName(String(rule.get("apply_status_id", "shock"))), {
			"stacks": 1,
			"max_stacks": 1,
			"duration": float(rule.get("apply_status_duration", 0.8)) + float(host._get_dictionary(rules.get("shock_upgrade", {})).get("duration_add", 0.0))
		})
	if had_shock:
		host._apply_overload_shock_lightning(rules, context)


## 作用：过载与感电条件满足且冷却允许时生成衍生闪电伤害。
## 使用：rules 读取 overload_shock_lightning；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_overload_shock_lightning(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("overload_shock_lightning"):
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("overload_shock_lightning", {}))
	var key: String = "overload_shock_lightning:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_overload_shock_lightning_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.overload_shock_lightning_intents(rules, context, maxi(int(rule.get("amount", 26)), 0)))


## 作用：闪电球命中在冷却允许时施加感电，包含感电升级修正。
## 使用：rules 读取 shock_on_lightning_orb_hit/shock_upgrade；context 携带 target；需由仍存活的宿主创建并调度。
func _apply_shock_on_lightning_orb_hit(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("shock_on_lightning_orb_hit"):
		return
	var target: Node = context.get("target") as Node
	if target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("shock_on_lightning_orb_hit", {}))
	var key: String = "shock_hit:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if now_seconds < float(_shock_hit_cooldowns.get(key, 0.0)):
		return
	if randf() > clampf(float(rule.get("chance", 0.2)), 0.0, 1.0):
		return
	if not host._reserve_cooldown(_shock_hit_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 0.8)), 0.0)):
		return
	target.call("apply_status", StringName(String(rule.get("shock_status_id", "shock"))), {
		"duration": float(rule.get("shock_duration", 0.8)) + float(host._get_dictionary(rules.get("shock_upgrade", {})).get("duration_add", 0.0)),
		"stacks": 1,
		"max_stacks": 1
	})


## 作用：目标带感电时处理消耗反应、触发计数与磁暴追加效果。
## 使用：rules 读取 shock_consume_reaction/shock_upgrade/magnetic_storm_on_shock_consume；context 携带 target/projectile/skill_id；写入 lightning_shock_trigger_count/lightning_magnetic_storm_checked 元数据；需由仍存活的宿主创建并调度。
func _apply_shock_consume_reaction(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("shock_consume_reaction"):
		return
	var target: Node = context.get("target") as Node
	var projectile: Node = context.get("projectile") as Node
	if target == null or not target.has_method("has_status") or not bool(target.call("has_status", &"shock")):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("shock_consume_reaction", {}))
	var max_triggers: int = maxi(int(rule.get("max_triggers_per_orb", 2)), 1)
	var trigger_count: int = int(projectile.get_meta("lightning_shock_trigger_count", 0)) if projectile != null else 0
	if trigger_count >= max_triggers:
		return
	if projectile != null:
		projectile.set_meta("lightning_shock_trigger_count", trigger_count + 1)
	if target.has_method("consume_status_stack"):
		target.call("consume_status_stack", &"shock", 1)
	var upgrade: Dictionary = host._get_dictionary(rules.get("shock_upgrade", {}))
	var amount: int = maxi(roundi(float(rule.get("amount", 8)) * maxf(1.0 + float(upgrade.get("damage_multiplier_add", 0.0)), 0.0)), 0)
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.shock_consume_reaction_intents(rules, context, amount))
	SpecialDamageRuleHandlerScript.spread_shock_from_shock(rules, context)
	if not rules.has("magnetic_storm_on_shock_consume"):
		return
	var storm_rule: Dictionary = host._get_dictionary(rules.get("magnetic_storm_on_shock_consume", {}))
	if projectile != null:
		if bool(projectile.get_meta("lightning_magnetic_storm_checked", false)):
			return
		projectile.set_meta("lightning_magnetic_storm_checked", true)
	var key: String = "magnetic_storm:%s" % String(context.get("skill_id", "lightning_orb"))
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_magnetic_storm_cooldowns, key, now_seconds, maxf(float(storm_rule.get("same_source_cooldown", 2.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.execute_magnetic_storm_on_shock_consume(rules, context)


## 作用：按感电升级规则修饰状态参数。
## 使用：params 读取 duration；context 为施放或命中上下文；会原地更新 params.duration；需由仍存活的宿主创建并调度。
func _get_shock_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if rules.is_empty():
		return params
	var rule: Dictionary = host._get_dictionary(rules.get("shock_upgrade", {}))
	if rule.is_empty():
		return params
	params["duration"] = float(params.get("duration", 0.8)) + float(rule.get("duration_add", 0.0))
	return params
