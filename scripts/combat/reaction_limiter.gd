## 文件用途：限制元素反应递归、冷却、同来源次数与目标数量，并管理Boss控制转换和韧性奖励窗口。
## 使用方式：触发前can_trigger检查，成功触发后record_trigger登记；反应包构建关闭再次反应。
extends RefCounted
class_name ReactionLimiter


const ReactionDamageBuilderScript: Script = preload("res://scripts/combat/reaction_damage_builder.gd")

const DEFAULT_REACTION_LIMITS: Dictionary = {
	"death_explosion": {"cooldown": 0.2, "max_targets": 8},
	"lightning_bounce": {"cooldown": 0.0, "max_bounces": 2},
	"shock": {"cooldown": 0.4, "max_per_source": 2},
	"overload": {"cooldown": 1.2, "boss_damage_multiplier": 0.75},
	"chain_end_burst": {"cooldown": 0.3, "max_targets": 6},
	"combustion": {"cooldown": 1.0, "max_targets": 8, "boss_damage_multiplier": 0.75},
	"acid_burst": {"cooldown": 2.0, "boss_damage_multiplier": 0.75},
	"shatter": {"cooldown": 1.5, "tier": "major"},
	"poison_cloud_spread": {"cooldown": 0.5, "max_active": 4},
	"shield_counter": {"cooldown": 7.0}
}
const BOSS_POISE_STACKS_REQUIRED: int = 5
const BOSS_POISE_STACK_DURATION_SECONDS: float = 6.0
const BOSS_POISE_WINDOW_SECONDS: float = 4.0

static var _reaction_cooldowns: Dictionary = {}
static var _source_counts: Dictionary = {}
static var _source_count_expires_at: Dictionary = {}
static var _target_sets: Dictionary = {}


## 作用：复制包并规范非负反应深度，缺失触发开关时按来源与深度补充。
## 使用：返回新字典，已有开关不会覆盖。
static func prepare_damage_packet(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	var depth: int = maxi(int(result.get("reaction_depth", 0)), 0)
	result["reaction_depth"] = depth
	if not result.has("can_trigger_reaction"):
		result["can_trigger_reaction"] = String(result.get("damage_origin", "")) != "reaction" and depth <= 0
	return result


## 作用：从基础字典和反应配置tier生成反应包。
## 使用：不直接应用伤害，amount为反应原始值。
static func make_reaction_packet(base_packet: Dictionary, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build(base_packet, reaction_type, amount, element, reaction_tier(reaction_type))


## 作用：从字典、typed包或上下文生成反应包并读取配置tier。
## 使用：返回规范字典供动作层继续应用。
static func make_reaction_packet_any(packet_source: Variant, reaction_type: String, amount: float, element: Variant = &"neutral") -> Dictionary:
	return ReactionDamageBuilderScript.build_any(packet_source, reaction_type, amount, element, reaction_tier(reaction_type))


## 作用：读取反应登记的tier，缺失返回normal。
## 使用：reaction_type为登记反应名。
static func reaction_tier(reaction_type: String) -> String:
	return String(_get_limit(reaction_type).get("tier", "normal"))


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> bool:
	return can_trigger_any(packet, reaction_type, target)


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> bool:
	if not bool(_packet_value(packet_source, "can_trigger_reaction", false)):
		return false
	if int(_packet_value(packet_source, "reaction_depth", 0)) >= 1:
		return false

	var now_seconds: float = _now_seconds()
	var resolved_target: Node = _resolve_target(packet_source, target)
	var key: String = _source_key_for_source(packet_source, reaction_type, resolved_target)
	var cooldown: float = float(_get_limit(reaction_type).get("cooldown", 0.0))
	if cooldown > 0.0 and now_seconds - float(_reaction_cooldowns.get(key, -9999.0)) < cooldown:
		return false
	if _is_count_limit_reached_for_source(packet_source, reaction_type, resolved_target, key, now_seconds):
		return false
	return true


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return can_trigger_any(calculation_context, reaction_type, target)


## 作用：检查触发开关、递归深度、来源冷却及次数/目标数量限制。
## 使用：支持字典/包/上下文，返回布尔值；可能清理过期计数但不登记触发。
static func can_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> bool:
	return can_trigger_any(packet_object, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger(packet: Dictionary, reaction_type: String, target: Node = null) -> void:
	record_trigger_any(packet, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger_any(packet_source: Variant, reaction_type: String, target: Node = null) -> void:
	var resolved_target: Node = _resolve_target(packet_source, target)
	var key: String = _source_key_for_source(packet_source, reaction_type, resolved_target)
	_reaction_cooldowns[key] = _now_seconds()
	_record_count_for_source(packet_source, reaction_type, resolved_target, key)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger_for_context(calculation_context: RefCounted, reaction_type: String, target: Node = null) -> void:
	record_trigger_any(calculation_context, reaction_type, target)


## 作用：按来源作用域记录触发时间、次数与目标集合。
## 使用：仅在反应确认触发后调用；不会重新检查限制。
static func record_trigger_for_packet_object(packet_object: RefCounted, reaction_type: String, target: Node = null) -> void:
	record_trigger_any(packet_object, reaction_type, target)


## 作用：读取包减防上限并限制0至95%，Boss闪电回流额外限制30%。
## 使用：target可由上下文补充，default_cap是普通公式默认值。
static func get_defense_reduction_cap(packet: Dictionary, target: Node, default_cap: float) -> float:
	return get_defense_reduction_cap_any(packet, target, default_cap)


## 作用：读取包减防上限并限制0至95%，Boss闪电回流额外限制30%。
## 使用：target可由上下文补充，default_cap是普通公式默认值。
static func get_defense_reduction_cap_any(packet_source: Variant, target: Node, default_cap: float) -> float:
	var resolved_target: Node = _resolve_target(packet_source, target)
	var cap: float = clampf(float(_packet_value(packet_source, "defense_reduction_cap", default_cap)), 0.0, 0.95)
	if _is_boss(resolved_target) and _has_special_tag_for_source(packet_source, "lightning_orb_backflow"):
		cap = minf(cap, 0.30)
	return cap


## 作用：读取包减防上限并限制0至95%，Boss闪电回流额外限制30%。
## 使用：target可由上下文补充，default_cap是普通公式默认值。
static func get_defense_reduction_cap_for_context(calculation_context: RefCounted, default_cap: float, target: Node = null) -> float:
	return get_defense_reduction_cap_any(calculation_context, target, default_cap)


## 作用：读取包减防上限并限制0至95%，Boss闪电回流额外限制30%。
## 使用：target可由上下文补充，default_cap是普通公式默认值。
static func get_defense_reduction_cap_for_packet_object(packet_object: RefCounted, target: Node, default_cap: float) -> float:
	return get_defense_reduction_cap_any(packet_object, target, default_cap)


## 作用：为Boss读取对应反应的特殊承伤倍率。
## 使用：非Boss或没有reaction_type返回1。
static func get_special_final_modifier(packet: Dictionary, target: Node) -> float:
	return get_special_final_modifier_any(packet, target)


## 作用：为Boss读取对应反应的特殊承伤倍率。
## 使用：非Boss或没有reaction_type返回1。
static func get_special_final_modifier_any(packet_source: Variant, target: Node = null) -> float:
	var resolved_target: Node = _resolve_target(packet_source, target)
	var modifier: float = 1.0
	if _is_boss(resolved_target):
		var reaction_type: String = String(_packet_value(packet_source, "reaction_type", ""))
		if reaction_type != "":
			modifier *= maxf(float(_get_limit(reaction_type).get("boss_damage_multiplier", 1.0)), 0.0)
	return modifier


## 作用：为Boss读取对应反应的特殊承伤倍率。
## 使用：非Boss或没有reaction_type返回1。
static func get_special_final_modifier_for_context(calculation_context: RefCounted, target: Node = null) -> float:
	return get_special_final_modifier_any(calculation_context, target)


## 作用：为Boss读取对应反应的特殊承伤倍率。
## 使用：非Boss或没有reaction_type返回1。
static func get_special_final_modifier_for_packet_object(packet_object: RefCounted, target: Node = null) -> float:
	return get_special_final_modifier_any(packet_object, target)


## 作用：将Boss定身/冻结/眩晕/麻痹转成1秒20%减速并累加韧性。
## 使用：其他目标/状态返回空字典，此函数会修改Boss韧性元数据。
static func apply_boss_control_conversion(target: Node, status_id: StringName) -> Dictionary:
	if not _is_boss(target):
		return {}
	if not [&"root", &"freeze", &"stun", &"paralyze"].has(status_id):
		return {}

	_add_boss_poise_stack(target)
	return {
		"convert_to_status": &"slow",
		"duration": 1.0,
		"slow_percent": 0.20
	}


## 作用：读取尚未过期的Boss韧性层数。
## 使用：非Boss或过期返回0，不清除元数据。
static func get_boss_poise_stacks(target: Node) -> int:
	if target == null or not _is_boss(target):
		return 0
	var now_seconds: float = _now_seconds()
	if now_seconds > float(target.get_meta("boss_poise_expires_at", -1.0)):
		return 0
	return int(target.get_meta("boss_poise_stacks", 0))


## 作用：重大反应在Boss韧性窗口内消费一次10%增伤。
## 使用：命中后关闭窗口；不符合条件返回1。
static func consume_boss_poise_bonus(target: Node, packet: Dictionary) -> float:
	return consume_boss_poise_bonus_any(target, packet)


## 作用：重大反应在Boss韧性窗口内消费一次10%增伤。
## 使用：命中后关闭窗口；不符合条件返回1。
static func consume_boss_poise_bonus_any(target: Node, packet_source: Variant) -> float:
	var resolved_target: Node = _resolve_target(packet_source, target)
	if not _is_boss(resolved_target):
		return 1.0
	if String(_packet_value(packet_source, "damage_origin", "")) != "reaction":
		return 1.0
	if String(_packet_value(packet_source, "reaction_tier", "")) != "major":
		return 1.0

	var now_seconds: float = _now_seconds()
	var window_until: float = float(resolved_target.get_meta("boss_poise_window_until", -1.0))
	if now_seconds > window_until:
		return 1.0

	resolved_target.set_meta("boss_poise_window_until", -1.0)
	return 1.10


## 作用：重大反应在Boss韧性窗口内消费一次10%增伤。
## 使用：命中后关闭窗口；不符合条件返回1。
static func consume_boss_poise_bonus_for_context(calculation_context: RefCounted, target: Node = null) -> float:
	return consume_boss_poise_bonus_any(target, calculation_context)


## 作用：重大反应在Boss韧性窗口内消费一次10%增伤。
## 使用：命中后关闭窗口；不符合条件返回1。
static func consume_boss_poise_bonus_for_packet_object(target: Node, packet_object: RefCounted) -> float:
	return consume_boss_poise_bonus_any(target, packet_object)


## 作用：追加韧性层并刷新6秒期限，满5层开启重大反应窗口。
## 使用：只对有效目标操作元数据；窗口默认4秒加可配置增量。
static func _add_boss_poise_stack(target: Node) -> void:
	if target == null:
		return

	var now_seconds: float = _now_seconds()
	var expires_at: float = float(target.get_meta("boss_poise_expires_at", -1.0))
	var stacks: int = int(target.get_meta("boss_poise_stacks", 0)) if now_seconds <= expires_at else 0
	stacks = mini(stacks + 1, BOSS_POISE_STACKS_REQUIRED)
	target.set_meta("boss_poise_stacks", stacks)
	target.set_meta("boss_poise_expires_at", now_seconds + BOSS_POISE_STACK_DURATION_SECONDS)
	if stacks >= BOSS_POISE_STACKS_REQUIRED:
		target.set_meta("boss_poise_stacks", 0)
		target.set_meta("boss_poise_recently_completed_at", now_seconds)
		target.set_meta("boss_poise_completed_count", int(target.get_meta("boss_poise_completed_count", 0)) + 1)
		target.set_meta("boss_poise_window_until", now_seconds + BOSS_POISE_WINDOW_SECONDS + maxf(float(target.get_meta("boss_poise_duration_add", 0.0)), 0.0))


## 作用：组合攻击者、原始来源、技能和反应名，按规则补实例作用域。
## 使用：target参数不参与键；用于共用冷却与计数。
static func _source_key(packet: Dictionary, reaction_type: String, target: Node = null) -> String:
	return _source_key_for_source(packet, reaction_type, target)


## 作用：组合攻击者、原始来源、技能和反应名，按规则补实例作用域。
## 使用：target参数不参与键；用于共用冷却与计数。
static func _source_key_for_source(packet_source: Variant, reaction_type: String, target: Node = null) -> String:
	var attacker_id: String = String(_packet_value(packet_source, "attacker_id", ""))
	var origin_id: String = String(_packet_value(packet_source, "source_origin_id", ""))
	var skill_id: String = String(_packet_value(packet_source, "source_skill_id", _packet_value(packet_source, "source_id", "")))
	var key: String = "%s:%s:%s:%s" % [attacker_id, origin_id, skill_id, reaction_type]
	if _uses_instance_scope_for_source(packet_source, reaction_type):
		var instance_id: String = String(_packet_value(packet_source, "source_instance_id", ""))
		if instance_id == "":
			instance_id = skill_id
		key = "%s:%s" % [key, instance_id]
	return key


## 作用：清理过期计数后检查单来源次数、弹跳、活跃和新目标数量上限。
## 使用：已有目标可在目标集合达到上限后再次命中，返回限制是否达到。
static func _is_count_limit_reached(packet: Dictionary, reaction_type: String, target: Node, key: String, now_seconds: float) -> bool:
	return _is_count_limit_reached_for_source(packet, reaction_type, target, key, now_seconds)


## 作用：清理过期计数后检查单来源次数、弹跳、活跃和新目标数量上限。
## 使用：已有目标可在目标集合达到上限后再次命中，返回限制是否达到。
static func _is_count_limit_reached_for_source(packet_source: Variant, reaction_type: String, target: Node, key: String, now_seconds: float) -> bool:
	_prune_counter(key, now_seconds)
	var limit: Dictionary = _get_limit(reaction_type)
	var count: int = int(_source_counts.get(key, 0))
	for count_key: String in ["max_per_source", "max_bounces", "max_active"]:
		var max_count: int = int(limit.get(count_key, 0))
		if max_count > 0 and count >= max_count:
			return true

	var max_targets: int = int(limit.get("max_targets", 0))
	if max_targets > 0:
		var target_id: String = _target_id_for_source(packet_source, target)
		var target_set: Dictionary = _target_sets.get(key, {})
		if target_id != "" and not target_set.has(target_id) and target_set.size() >= max_targets:
			return true
	return false


## 作用：刷新来源次数过期时间并将当前目标加入去重集合。
## 使用：key应与can_trigger检查使用相同来源键。
static func _record_count(packet: Dictionary, reaction_type: String, target: Node, key: String) -> void:
	_record_count_for_source(packet, reaction_type, target, key)


## 作用：刷新来源次数过期时间并将当前目标加入去重集合。
## 使用：key应与can_trigger检查使用相同来源键。
static func _record_count_for_source(packet_source: Variant, reaction_type: String, target: Node, key: String) -> void:
	var now_seconds: float = _now_seconds()
	_prune_counter(key, now_seconds)
	_source_counts[key] = int(_source_counts.get(key, 0)) + 1
	_source_count_expires_at[key] = now_seconds + _counter_window_seconds(reaction_type)

	var target_id: String = _target_id_for_source(packet_source, target)
	if target_id == "":
		return
	var target_set: Dictionary = _target_sets.get(key, {})
	target_set[target_id] = true
	_target_sets[key] = target_set


## 作用：过期时同时清除次数、期限与目标集合。
## 使用：now_seconds为毫秒时钟换算的秒值。
static func _prune_counter(key: String, now_seconds: float) -> void:
	if not _source_count_expires_at.has(key):
		return
	if now_seconds <= float(_source_count_expires_at[key]):
		return
	_source_count_expires_at.erase(key)
	_source_counts.erase(key)
	_target_sets.erase(key)


## 作用：按window、reset_after或cooldown优先级决定计数窗口。
## 使用：结果最少0.01秒。
static func _counter_window_seconds(reaction_type: String) -> float:
	var limit: Dictionary = _get_limit(reaction_type)
	if limit.has("window"):
		return maxf(float(limit["window"]), 0.01)
	if limit.has("reset_after"):
		return maxf(float(limit["reset_after"]), 0.01)
	return maxf(float(limit.get("cooldown", 0.0)), 0.01)


## 作用：识别显式实例作用域、持续来源及需要逐实例限制的反应。
## 使用：返回true时来源键追加source_instance_id。
static func _uses_instance_scope(packet: Dictionary, reaction_type: String) -> bool:
	return _uses_instance_scope_for_source(packet, reaction_type)


## 作用：识别显式实例作用域、持续来源及需要逐实例限制的反应。
## 使用：返回true时来源键追加source_instance_id。
static func _uses_instance_scope_for_source(packet_source: Variant, reaction_type: String) -> bool:
	if String(_packet_value(packet_source, "reaction_scope", "")) == "instance":
		return true
	var origin: String = String(_packet_value(packet_source, "damage_origin", ""))
	if origin == "field" or origin == "status_dot":
		return true
	if String(_packet_value(packet_source, "damage_type", "")) == "status_dot":
		return true
	return ["death_explosion", "lightning_bounce", "chain_end_burst", "poison_cloud_spread"].has(reaction_type)


## 作用：优先使用目标实例ID，否则从包取target_id。
## 使用：用于同来源目标数量去重。
static func _target_id(packet: Dictionary, target: Node) -> String:
	return _target_id_for_source(packet, target)


## 作用：优先使用目标实例ID，否则从包取target_id。
## 使用：用于同来源目标数量去重。
static func _target_id_for_source(packet_source: Variant, target: Node) -> String:
	if target != null:
		return str(target.get_instance_id())
	return String(_packet_value(packet_source, "target_id", ""))


## 作用：检查special_rule_tags数组是否含指定字符串或StringName。
## 使用：非数组返回false。
static func _has_special_tag(packet: Dictionary, tag: String) -> bool:
	return _has_special_tag_for_source(packet, tag)


## 作用：检查special_rule_tags数组是否含指定字符串或StringName。
## 使用：非数组返回false。
static func _has_special_tag_for_source(packet_source: Variant, tag: String) -> bool:
	var tags_variant: Variant = _packet_value(packet_source, "special_rule_tags", [])
	if not (tags_variant is Array):
		return false
	var tags: Array = tags_variant
	return tags.has(tag) or tags.has(StringName(tag))


## 作用：优先返回显式目标，否则仅从计算上下文取目标。
## 使用：字典/包不会从ID恢复节点，缺失返回null。
static func _resolve_target(packet_source: Variant, target: Node = null) -> Node:
	if target != null:
		return target
	if packet_source is DamageCalculationContext:
		return packet_source.get("target") as Node
	return null


## 作用：读取字典、DamagePacket 或计算上下文中的伤害字段。
## 使用：key 指定字段；不支持的输入类型返回 fallback。
static func _packet_value(packet_source: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).get(key, fallback)
	if packet_source is DamageCalculationContext:
		return packet_source.packet_value(key, fallback)
	if packet_source is DamagePacket:
		return packet_source.get_value(key, fallback)
	return fallback


## 作用：将支持的伤害来源转换为字典视图。
## 使用：接受字典、DamagePacket 或 DamageCalculationContext；不支持类型返回空字典。
static func _packet_dictionary(packet_source: Variant) -> Dictionary:
	if packet_source is Dictionary:
		return (packet_source as Dictionary).duplicate(true)
	if packet_source is DamageCalculationContext:
		return packet_source.packet_dict()
	if packet_source is DamagePacket:
		return packet_source.to_dictionary()
	return {}


## 作用：复制原标签列表并追加尚未存在的标签。
## 使用：String 与 StringName 同名视为重复；返回新数组。
static func _merge_tags(value: Variant, extra_tags: Array[String]) -> Array:
	var tags: Array = []
	if value is Array:
		tags = (value as Array).duplicate()
	for tag: String in extra_tags:
		if not tags.has(tag) and not tags.has(StringName(tag)):
			tags.append(tag)
	return tags


## 作用：读取反应名对应的限制字典。
## 使用：未登记反应返回空字典，由各查询使用中性默认值。
static func _get_limit(reaction_type: String) -> Dictionary:
	var value: Variant = DEFAULT_REACTION_LIMITS.get(reaction_type, {})
	if value is Dictionary:
		return value
	return {}


## 作用：检查节点enemy_rank元数据是否为boss。
## 使用：空节点返回false。
static func _is_boss(node: Node) -> bool:
	return node != null and String(node.get_meta("enemy_rank", "normal")) == "boss"


## 作用：将引擎毫秒时钟换算为秒。
## 使用：供运行时到期和冷却时间比较使用，不代表游戏内累计时间。
static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
