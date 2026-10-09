## 文件用途：登记特性类型到实现脚本的映射。
## 使用方式：控制器通过 create 按配置 type 创建实例，未知类型警告并返回 null。
extends RefCounted
class_name TraitRegistry


const SkillCastStackTraitScript: Script = preload("res://scripts/characters/traits/skill_cast_stack_trait.gd")
const MovingBonusTraitScript: Script = preload("res://scripts/characters/traits/moving_bonus_trait.gd")
const PeriodicShieldTraitScript: Script = preload("res://scripts/characters/traits/periodic_shield_trait.gd")
const StatusKillRandomAreaTraitScript: Script = preload("res://scripts/characters/traits/status_kill_random_area_trait.gd")
const HpLostStackTraitScript: Script = preload("res://scripts/characters/traits/hp_lost_stack_trait.gd")

static var _types: Dictionary = {
	"skill_cast_stack": SkillCastStackTraitScript,
	"moving_bonus": MovingBonusTraitScript,
	"passive_with_periodic_shield": PeriodicShieldTraitScript,
	"status_kill_random_area": StatusKillRandomAreaTraitScript,
	"hp_lost_stack": HpLostStackTraitScript
}


## 作用：按注册类型实例化角色特性，未知类型发警告并返回 null。
## 使用：控制器通过 create 按配置 type 创建实例，未知类型警告并返回 null；无法解析或创建时返回 null。
static func create(trait_type: String) -> RefCounted:
	var script: Script = _types.get(trait_type, null)
	if script == null:
		push_warning("[TraitRegistry] Unknown character trait type: %s" % trait_type)
		return null
	return script.new()


## 作用：判断特性注册表是否登记指定配置类型。
## 使用：控制器通过 create 按配置 type 创建实例，未知类型警告并返回 null。
static func has_type(trait_type: String) -> bool:
	return _types.has(trait_type)
