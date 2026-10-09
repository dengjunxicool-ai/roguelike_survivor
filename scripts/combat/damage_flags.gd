## 文件用途：保存暴击、反应和防御/抗性/易伤/最小伤害的处理开关。
## 使用方式：DamagePacket 作为子对象持有；通过字典转换在构建与事件视图间传递。
extends RefCounted
class_name DamageFlags


var can_crit: bool = true
var can_trigger_reaction: bool = true
var ignore_defense: bool = false
var ignore_resistance: bool = false
var ignore_vulnerability: bool = false
var ignore_min_damage: bool = false


## 作用：从包字典读取各规则布尔开关，缺失使用对象默认值。
## 使用：返回独立 flags；默认值仍应由包解析阶段补齐规则策略。
static func from_dictionary(packet: Dictionary) -> RefCounted:
	var flags: RefCounted = new()
	flags.can_crit = bool(packet.get("can_crit", flags.can_crit))
	flags.can_trigger_reaction = bool(packet.get("can_trigger_reaction", flags.can_trigger_reaction))
	flags.ignore_defense = bool(packet.get("ignore_defense", flags.ignore_defense))
	flags.ignore_resistance = bool(packet.get("ignore_resistance", flags.ignore_resistance))
	flags.ignore_vulnerability = bool(packet.get("ignore_vulnerability", flags.ignore_vulnerability))
	flags.ignore_min_damage = bool(packet.get("ignore_min_damage", flags.ignore_min_damage))
	return flags


## 作用：深复制输入并写入当前暴击、反应和忽略开关。
## 使用：原字典不变，返回用于包序列化的新字典。
func apply_to_dictionary(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	result["can_crit"] = can_crit
	result["can_trigger_reaction"] = can_trigger_reaction
	result["ignore_defense"] = ignore_defense
	result["ignore_resistance"] = ignore_resistance
	result["ignore_vulnerability"] = ignore_vulnerability
	result["ignore_min_damage"] = ignore_min_damage
	return result
