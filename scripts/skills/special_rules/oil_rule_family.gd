## 文件用途：实现火油区域的易燃标记、油层爆燃、烟云和玩家移速增益。
## 使用方式：宿主在区域 tick、到期或玩家受击转入；烟云与油区通过运行元数据和属性来源维护时限。
extends RefCounted

const ReactionLimiterScript: Script = preload("res://scripts/combat/reaction_limiter.gd")
const SpecialDamageRuleHandlerScript: Script = preload("res://scripts/skills/special_damage_rule_handler.gd")

static var _fire_oil_flammable_burst_cooldowns: Dictionary = {}

static var _fire_oil_burn_in_merged_oil_cooldowns: Dictionary = {}

static var _fire_oil_flammable_poise_cooldowns: Dictionary = {}

static var _smoke_cloud_player_damaged_cooldowns: Dictionary = {}

var _host_ref: WeakRef

## 作用：弱引用保存特殊规则宿主，供本族复用共享伤害、状态与冷却入口。
## 使用：host 为仍存活的规则宿主。
func _init(host: RefCounted) -> void:
	_host_ref = weakref(host)


## 作用：火油区域 tick 时按区域类型处理烟云、燃烧、易燃标记、油层与爆燃。
## 使用：rules 读取 fire_oil_canister_base/fire_oil_burn_damage_in_big_oil/flammable_mark_burst_on_full_mark_tick/oil_fire_deflagration；context 携带 source_id/target；写入 fire_oil_burn_damage_until/fire_oil_burn_damage_multiplier_add/fire_oil_boss_burn_damage_multiplier 元数据；需由仍存活的宿主创建并调度。
func _apply_fire_oil_on_field_tick(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("fire_oil_canister_base"):
		return
	var source_id: String = String(context.get("source_id", ""))
	if source_id != "fire_oil_area" and source_id != "smoke_cloud_area":
		return
	var target: Node = context.get("target") as Node
	if target == null:
		return
	if source_id == "smoke_cloud_area":
		host._apply_smoke_cloud_target_effects(rules, target)
		return
	host._apply_burn_in_merged_oil(rules, context, target)
	host._apply_flammable_mark_on_oil_tick(rules, target)
	host._apply_oil_stack_on_fire_oil_tick(rules, target)
	if rules.has("fire_oil_burn_damage_in_big_oil"):
		var burn_rule: Dictionary = host._get_dictionary(rules.get("fire_oil_burn_damage_in_big_oil", {}))
		target.set_meta("fire_oil_burn_damage_until", host._now_seconds() + 0.75)
		target.set_meta("fire_oil_burn_damage_multiplier_add", float(burn_rule.get("burn_damage_multiplier_add", 0.3)))
		target.set_meta("fire_oil_boss_burn_damage_multiplier", float(burn_rule.get("boss_burn_damage_multiplier", 0.7)))
	if rules.has("flammable_mark_burst_on_full_mark_tick"):
		host._apply_flammable_mark_burst(rules, context, target)
	if rules.has("oil_fire_deflagration"):
		host._apply_fire_oil_deflagration(rules, context, target)


## 作用：合并油区命中在冷却允许时施加燃烧。
## 使用：rules 读取 burn_in_merged_oil；context 携带 area；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_burn_in_merged_oil(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("burn_in_merged_oil") or target == null or not target.has_method("apply_status"):
		return
	var area: Node = context.get("area") as Node
	if area == null or not bool(area.get_meta("fire_oil_merged_area", false)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("burn_in_merged_oil", {}))
	var key: String = "burn_in_merged_oil:%s:%s" % [str(area.get_instance_id()), host._target_key(target)]
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_fire_oil_burn_in_merged_oil_cooldowns, key, now_seconds, maxf(float(rule.get("interval", 1.5)), 0.05)):
		return
	var status_id: StringName = StringName(String(rule.get("status_id", "burning")))
	var status_params: Dictionary = {
		"duration": float(rule.get("duration", 3.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 1)), 1)
	}
	if status_id == &"burning":
		status_params = host._get_burn_status_params(status_params, context)
	target.call("apply_status", status_id, status_params)


## 作用：油区 tick 命中强敌时施加易燃标记并应用 Boss 调整。
## 使用：rules 读取 flammable_mark_on_strong_oil_tick/flammable_mark_boss_tuning；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_flammable_mark_on_oil_tick(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("flammable_mark_on_strong_oil_tick") or target == null or not target.has_method("apply_status"):
		return
	if not (host._is_elite(target) or host._is_boss(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flammable_mark_on_strong_oil_tick", {}))
	var duration: float = float(rule.get("duration", 4.0))
	if host._is_boss(target) and rules.has("flammable_mark_boss_tuning"):
		duration += float(host._get_dictionary(rules.get("flammable_mark_boss_tuning", {})).get("duration_add", 1.0))
	target.call("apply_status", StringName(String(rule.get("status_id", "flammable_mark"))), {
		"duration": duration,
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 5)), 1)
	})


## 作用：油区 tick 时为命中目标累积油层。
## 使用：rules 读取 oil_stack_on_fire_oil_tick；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_oil_stack_on_fire_oil_tick(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("oil_stack_on_fire_oil_tick") or target == null or not target.has_method("apply_status"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("oil_stack_on_fire_oil_tick", {}))
	target.call("apply_status", StringName(String(rule.get("status_id", "oil_stack"))), {
		"duration": float(rule.get("duration", 4.0)),
		"stacks": maxi(int(rule.get("stacks", 1)), 1),
		"max_stacks": maxi(int(rule.get("max_stacks", 3)), 1)
	})


## 作用：目标油层满足门槛且冷却允许时触发火油爆燃并记录来源冷却。
## 使用：rules 读取 oil_fire_deflagration/deflagration_upgrade；context 携带 area/source_instance_id；target 为本次命中目标；写入 fire_oil_deflagration_cooldowns 元数据；需由仍存活的宿主创建并调度。
func _apply_fire_oil_deflagration(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null or not target.has_method("get_status_stack"):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("oil_fire_deflagration", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "oil_stack")))
	var required: int = maxi(int(rule.get("required_stacks", 3)), 1)
	if int(target.call("get_status_stack", status_id)) < required:
		return
	var area: Node = context.get("area") as Node
	var key: String = "fire_oil_deflagration:%s:%s" % [String(context.get("source_instance_id", "")), host._target_key(target)]
	var upgrade: Dictionary = host._get_dictionary(rules.get("deflagration_upgrade", {}))
	var cooldown: float = maxf(float(upgrade.get("same_source_cooldown", rule.get("same_source_cooldown", 1.2))), 0.0)
	var now_seconds: float = host._now_seconds()
	if area != null:
		var cooldowns: Dictionary = {}
		var value: Variant = area.get_meta("fire_oil_deflagration_cooldowns", {})
		if value is Dictionary:
			cooldowns = (value as Dictionary).duplicate(true)
		if not host._reserve_cooldown(cooldowns, key, now_seconds, cooldown):
			return
		area.set_meta("fire_oil_deflagration_cooldowns", cooldowns)
	SpecialDamageRuleHandlerScript.execute_fire_oil_deflagration(rules, context)


## 作用：易燃标记满层 tick 满足冷却后触发爆发，并可影响 Boss 韧性。
## 使用：rules 读取 flammable_mark_burst_on_full_mark_tick/flammable_burst_boss_poise；context 为施放或命中上下文；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_flammable_mark_burst(rules: Dictionary, context: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null or not target.has_method("get_status_stack"):
		return
	if not (host._is_elite(target) or host._is_boss(target)):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flammable_mark_burst_on_full_mark_tick", {}))
	var status_id: StringName = StringName(String(rule.get("required_status_id", "flammable_mark")))
	if int(target.call("get_status_stack", status_id)) < maxi(int(rule.get("required_stacks", 5)), 1):
		return
	var key: String = "flammable_burst:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_fire_oil_flammable_burst_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 1.5)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.apply_intents(SpecialDamageRuleHandlerScript.fire_oil_flammable_burst_intents(rules, context, maxi(int(rule.get("amount", 14)), 0)))
	if host._is_boss(target) and rules.has("flammable_burst_boss_poise"):
		host._apply_flammable_burst_boss_poise(rules, target)


## 作用：给烟云内目标刷新限时伤害降低属性元数据。
## 使用：rules 读取 smoke_enemy_damage_down；target 为本次命中目标；写入 fire_oil_smoke_enemy_damage_down_until/fire_oil_smoke_enemy_damage_multiplier_add 元数据；需由仍存活的宿主创建并调度。
func _apply_smoke_cloud_target_effects(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null:
		return
	if rules.has("smoke_enemy_damage_down") and (not host._is_boss(target)) and (not host._is_elite(target)):
		var damage_rule: Dictionary = host._get_dictionary(rules.get("smoke_enemy_damage_down", {}))
		target.set_meta("fire_oil_smoke_enemy_damage_down_until", host._now_seconds() + maxf(float(damage_rule.get("duration", 0.6)), 0.0))
		target.set_meta("fire_oil_smoke_enemy_damage_multiplier_add", float(damage_rule.get("damage_multiplier_add", -0.15)))


## 作用：油区到期按配置生成烟云。
## 使用：rules 读取 smoke_cloud_on_oil_expire；context 携带 source_id；需由仍存活的宿主创建并调度。
func _apply_smoke_cloud_on_oil_expire(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("smoke_cloud_on_oil_expire"):
		return
	if String(context.get("source_id", "")) != "fire_oil_area":
		return
	SpecialDamageRuleHandlerScript.execute_smoke_cloud(rules, context, host._get_dictionary(rules.get("smoke_cloud_on_oil_expire", {})), "fire_oil_smoke_expire")


## 作用：玩家受伤在规则冷却允许时生成保护烟云。
## 使用：rules 读取 smoke_cloud_on_player_damaged；context 携带 player/caster；需由仍存活的宿主创建并调度。
func _apply_smoke_cloud_on_player_damaged(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("smoke_cloud_on_player_damaged"):
		return
	var player: Node = context.get("player", context.get("caster")) as Node
	if player == null:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("smoke_cloud_on_player_damaged", {}))
	var key: String = "smoke_damage:%s" % host._target_key(player)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_smoke_cloud_player_damaged_cooldowns, key, now_seconds, maxf(float(rule.get("same_source_cooldown", 16.0)), 0.0)):
		return
	SpecialDamageRuleHandlerScript.execute_smoke_cloud(rules, context, rule, "fire_oil_smoke_player_damaged")


## 作用：根据玩家是否处于烟云增益窗口设置或移除火油移速属性来源。
## 使用：rules 读取 smoke_player_speed_buff；context 携带 caster；写入 fire_oil_smoke_speed_until 元数据；需由仍存活的宿主创建并调度。
func _update_fire_oil_smoke_player_buff(rules: Dictionary, context: Dictionary) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("smoke_player_speed_buff"):
		return
	var player: Node2D = context.get("caster") as Node2D
	if player == null:
		return
	var inside_smoke: bool = false
	var tree: SceneTree = player.get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"areas"):
			var area: Node2D = node as Node2D
			if area == null or not bool(area.get_meta("fire_oil_smoke_cloud", false)):
				continue
			var radius: float = maxf(float(area.get_meta("fire_oil_smoke_radius", 95.0)), 1.0)
			if player.global_position.distance_squared_to(area.global_position) <= radius * radius:
				inside_smoke = true
				break
	var modifier_id: String = "fire_oil_smoke_speed"
	if inside_smoke:
		var rule: Dictionary = host._get_dictionary(rules.get("smoke_player_speed_buff", {}))
		var modifiers: Array = [{
			"stat": "move_speed",
			"op": "multiplier_add",
			"value": float(rule.get("move_speed_multiplier_add", 0.08)),
			"scope": {"domain": "player"}
		}]
		if player.has_method("set_run_modifier_source"):
			player.call("set_run_modifier_source", modifier_id, modifiers)
		player.set_meta("fire_oil_smoke_speed_until", host._now_seconds() + maxf(float(rule.get("duration", 0.6)), 0.0))
	elif host._now_seconds() > float(player.get_meta("fire_oil_smoke_speed_until", 0.0)) and player.has_method("clear_run_modifier_source"):
		player.call("clear_run_modifier_source", modifier_id)


## 作用：火系伤害命中带易燃标记目标时按层数修改易伤。
## 使用：packet 为待修饰伤害包视图；rules 读取 flammable_mark_fire_vulnerability；target 为本次命中目标；会原地更新 packet.vulnerability_total；需由仍存活的宿主创建并调度。
func _apply_flammable_mark_fire_vulnerability(packet: Dictionary, rules: Dictionary, target: Node, packet_object: RefCounted) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if not rules.has("flammable_mark_fire_vulnerability") or target == null or packet_object == null:
		return
	if String(packet_object.call("get_value", "element", "")) != "fire":
		return
	if not target.has_method("get_status_stack"):
		return
	var stacks: int = int(target.call("get_status_stack", &"flammable_mark"))
	if stacks <= 0:
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flammable_mark_fire_vulnerability", {}))
	packet["vulnerability_total"] = float(packet.get("vulnerability_total", 0.0)) + float(rule.get("fire_damage_taken_multiplier_add_per_stack", 0.01)) * float(stacks)


## 作用：易燃标记爆发对 Boss 在冷却允许时施加韧性效果。
## 使用：rules 读取 flammable_burst_boss_poise；target 为本次命中目标；需由仍存活的宿主创建并调度。
func _apply_flammable_burst_boss_poise(rules: Dictionary, target: Node) -> void:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	if target == null or not host._is_boss(target):
		return
	var rule: Dictionary = host._get_dictionary(rules.get("flammable_burst_boss_poise", {}))
	var key: String = "flammable_burst_poise:%s" % host._target_key(target)
	var now_seconds: float = host._now_seconds()
	if not host._reserve_cooldown(_fire_oil_flammable_poise_cooldowns, key, now_seconds, maxf(float(rule.get("same_target_cooldown", 2.5)), 0.0)):
		return
	for _i in range(maxi(int(rule.get("stacks", 1)), 1)):
		ReactionLimiterScript.apply_boss_control_conversion(target, &"stun")


## 作用：按 Boss 专用易燃标记规则修饰状态参数。
## 使用：params 读取 duration；context 携带 target；会原地更新 params.duration；需由仍存活的宿主创建并调度。
func _get_flammable_mark_status_params(params: Dictionary, context: Dictionary) -> Dictionary:
	var host: RefCounted = _host_ref.get_ref() as RefCounted
	var rules: Dictionary = host._get_rules(context)
	if host._is_boss(context.get("target") as Node) and rules.has("flammable_mark_boss_tuning"):
		params["duration"] = float(params.get("duration", 4.0)) + float(host._get_dictionary(rules.get("flammable_mark_boss_tuning", {})).get("duration_add", 1.0))
	return params
