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


static func create(trait_type: String) -> RefCounted:
	var script: Script = _types.get(trait_type, null)
	if script == null:
		push_warning("[TraitRegistry] Unknown character trait type: %s" % trait_type)
		return null
	return script.new()


static func has_type(trait_type: String) -> bool:
	return _types.has(trait_type)
