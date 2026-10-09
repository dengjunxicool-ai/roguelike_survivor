## 文件用途：保存是否使用角色倍率、是否使用等级系数及具体技能等级系数。
## 使用方式：由 DamagePacket 解析默认规则后持有，输出阶段据此决定缩放。
extends RefCounted
class_name DamageScaling


var uses_character_damage_multiplier: bool = true
var uses_skill_level_coefficient: bool = true
var skill_level_coefficient: float = 1.0


## 作用：读取缩放开关与等级系数，缺失字段沿用默认值。
## 使用：返回新 scaling 对象；数值合法性由包 validate 检查。
static func from_dictionary(packet: Dictionary) -> RefCounted:
	var scaling: RefCounted = new()
	scaling.uses_character_damage_multiplier = bool(packet.get("uses_character_damage_multiplier", scaling.uses_character_damage_multiplier))
	scaling.uses_skill_level_coefficient = bool(packet.get("uses_skill_level_coefficient", scaling.uses_skill_level_coefficient))
	scaling.skill_level_coefficient = float(packet.get("skill_level_coefficient", scaling.skill_level_coefficient))
	return scaling


## 作用：深复制字典并写入三个缩放字段。
## 使用：用于 DamagePacket.to_dictionary，输入不变。
func apply_to_dictionary(packet: Dictionary) -> Dictionary:
	var result: Dictionary = packet.duplicate(true)
	result["uses_character_damage_multiplier"] = uses_character_damage_multiplier
	result["uses_skill_level_coefficient"] = uses_skill_level_coefficient
	result["skill_level_coefficient"] = skill_level_coefficient
	return result
