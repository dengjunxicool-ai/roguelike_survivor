## 文件用途：按火系规则修饰燃烧持续时间、普通与 Boss 叠层上限以及 power 或伤害数值。
## 使用方式：FireRuleFamily 传基础参数、规则与 Boss 判定；apply 原地修改 params 并返回同一字典供目标状态入口使用。
extends RefCounted
class_name BurnStatusRuleHelper


## 作用：原地按燃烧规则调整时长、普通或 Boss 层数上限及 power/伤害倍率，返回同一参数字典。
## 使用：params 读取 duration/max_stacks/power/damage；rules 读取 burn_duration_add/burn_max_stacks_add/boss_burn_max_stacks_add/burn_damage_multiplier_add；target 为本次命中目标；会原地更新 params.duration/max_stacks/power。
static func apply(params: Dictionary, rules: Dictionary, target: Node, base_max_stacks: int, base_damage: float, is_boss_target: bool) -> Dictionary:
	if rules.has("burn_duration_add"):
		params["duration"] = float(params.get("duration", 3.0)) + float(rules.get("burn_duration_add", 0.0))
	if rules.has("burn_max_stacks_add") or rules.has("boss_burn_max_stacks_add"):
		var current_max_stacks: int = int(params.get("max_stacks", base_max_stacks))
		var add_stacks: int = int(rules.get("burn_max_stacks_add", 0))
		if is_boss_target:
			add_stacks = int(rules.get("boss_burn_max_stacks_add", add_stacks))
		params["max_stacks"] = maxi(current_max_stacks + add_stacks, 1)
	if rules.has("burn_damage_multiplier_add"):
		var multiplier: float = maxf(1.0 + float(rules.get("burn_damage_multiplier_add", 0.0)), 0.0)
		if params.has("power"):
			params["power"] = maxf(float(params.get("power", 0.0)) * multiplier, 0.0)
		else:
			var current_damage: float = float(params.get("damage", params.get("tick_damage", base_damage)))
			if current_damage > 0:
				params["damage"] = maxf(current_damage * multiplier, 0.0)
	return params
