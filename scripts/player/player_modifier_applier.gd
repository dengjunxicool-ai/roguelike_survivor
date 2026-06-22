extends RefCounted
class_name PlayerModifierApplier


func apply(player: Node, modifiers: Dictionary) -> void:
	var all_owned_skills_level_add: int = int(modifiers.get("all_owned_skills_level_add", 0))
	if all_owned_skills_level_add != 0:
		player.call("_upgrade_all_owned_skills", all_owned_skills_level_add)

	_apply_health_modifiers(player, modifiers)
	_multiply_float(player, "move_speed", float(modifiers.get("move_speed_multiplier", 1.0)))
	_multiply_float(player, "move_speed", 1.0 + float(modifiers.get("move_speed_multiplier_add", 0.0)))
	_multiply_float(player, "damage_multiplier", float(modifiers.get("damage_multiplier", 1.0)))
	_add_float(player, "damage_multiplier", float(modifiers.get("damage_multiplier_add", 0.0)))
	_multiply_float(player, "attack_speed_multiplier", float(modifiers.get("attack_speed_multiplier", 1.0)))
	_add_float(player, "attack_speed_multiplier", float(modifiers.get("attack_speed_multiplier_add", 0.0)))
	_add_float(player, "crit_chance", float(modifiers.get("crit_chance_add", 0.0)))
	_add_float(player, "crit_damage", float(modifiers.get("crit_damage_add", 0.0)))
	_add_int(player, "armor", int(modifiers.get("armor_add", 0)))
	_add_float(player, "experience_gain_multiplier", float(modifiers.get("experience_gain_multiplier_add", 0.0)))
	_add_float(player, "coin_gain_multiplier", float(modifiers.get("coin_gain_multiplier_add", 0.0)))
	_add_float(player, "soul_gain_multiplier", float(modifiers.get("soul_gain_multiplier_add", 0.0)))
	_add_float(player, "damage_taken_multiplier", float(modifiers.get("damage_taken_multiplier_add", 0.0)))
	_multiply_float(player, "skill_area_multiplier", float(modifiers.get("skill_area_multiplier", 1.0)))
	_add_float(player, "skill_area_multiplier", float(modifiers.get("skill_area_multiplier_add", 0.0)))
	_add_float(player, "rare_weight_add", float(modifiers.get("rare_weight_add", 0.0)))
	_add_float(player, "epic_weight_add", float(modifiers.get("epic_weight_add", 0.0)))
	_add_float(player, "legendary_weight_add", float(modifiers.get("legendary_weight_add", 0.0)))
	_add_int(player, "level_up_rerolls", int(modifiers.get("level_up_reroll_add", 0)))
	_multiply_float(player, "pickup_radius", 1.0 + float(modifiers.get("pickup_radius_multiplier_add", 0.0)))
	_add_float(player, "pickup_radius", float(modifiers.get("pickup_radius_add", 0.0)))
	_add_float(player, "enemy_spawn_count_multiplier_add", float(modifiers.get("enemy_spawn_count_multiplier_add", 0.0)))
	_add_float(player, "boss_hp_multiplier_add", float(modifiers.get("boss_hp_multiplier_add", 0.0)))
	_add_float(player, "fire_damage_multiplier_add", float(modifiers.get("fire_damage_multiplier_add", 0.0)))
	_add_float(player, "poison_damage_multiplier_add", float(modifiers.get("poison_damage_multiplier_add", 0.0)))
	_add_float(player, "on_hit_slow_chance_add", float(modifiers.get("on_hit_slow_chance_add", 0.0)))
	_set_max_float(player, "slow_percent", float(modifiers.get("slow_percent", player.get("slow_percent"))))
	_set_max_float(player, "slow_duration", float(modifiers.get("slow_duration", player.get("slow_duration"))))
	_add_int(player, "revive_count_add", int(modifiers.get("revive_count_add", 0)))
	_set_max_float(player, "revive_hp_percent", float(modifiers.get("revive_hp_percent", player.get("revive_hp_percent"))))
	_add_int(player, "thorns_damage", int(modifiers.get("thorns_damage", 0)))
	_set_max_float(player, "thorns_area_radius", float(modifiers.get("thorns_area_radius", player.get("thorns_area_radius"))))
	_multiply_float(player, "status_duration_multiplier", float(modifiers.get("status_duration_multiplier", 1.0)))
	_add_float(player, "status_duration_multiplier", float(modifiers.get("status_duration_multiplier_add", 0.0)))
	if modifiers.has("aura_slow_enabled"):
		player.set("aura_slow_enabled", bool(modifiers.get("aura_slow_enabled", player.get("aura_slow_enabled"))))
	_set_max_float(player, "aura_radius", float(modifiers.get("aura_radius", player.get("aura_radius"))))

	_clamp_min_float(player, "attack_speed_multiplier", 0.1)
	_clamp_min_float(player, "damage_taken_multiplier", 0.1)
	_clamp_min_float(player, "experience_gain_multiplier", 0.1)
	_clamp_min_float(player, "coin_gain_multiplier", 0.1)
	_clamp_min_float(player, "soul_gain_multiplier", 0.1)
	_clamp_min_float(player, "status_duration_multiplier", 0.1)
	_clamp_min_float(player, "pickup_radius", 1.0)
	player.call("_apply_environment_modifiers")


func _apply_health_modifiers(player: Node, modifiers: Dictionary) -> void:
	var max_hp_add: int = int(modifiers.get("max_hp_add", 0))
	if max_hp_add != 0:
		var max_health: int = int(player.get("max_health")) + max_hp_add
		var current_health: int = mini(int(player.get("current_health")) + max_hp_add, max_health)
		player.set("max_health", max_health)
		player.set("current_health", current_health)
		player.emit_signal("health_changed", current_health, max_health)

	var max_hp_multiplier_add: float = float(modifiers.get("max_hp_multiplier_add", 0.0))
	if max_hp_multiplier_add != 0.0:
		var old_max_health: int = int(player.get("max_health"))
		var new_max_health: int = maxi(roundi(float(old_max_health) * (1.0 + max_hp_multiplier_add)), 1)
		var new_current_health: int = mini(int(player.get("current_health")) + maxi(new_max_health - old_max_health, 0), new_max_health)
		player.set("max_health", new_max_health)
		player.set("current_health", new_current_health)
		player.emit_signal("health_changed", new_current_health, new_max_health)

	var heal: int = int(modifiers.get("heal", 0))
	if modifiers.has("heal_percent_max"):
		heal += roundi(float(player.get("max_health")) * float(modifiers.get("heal_percent_max", 0.0)))
	if heal > 0:
		var max_health: int = int(player.get("max_health"))
		var current_health: int = mini(int(player.get("current_health")) + heal, max_health)
		player.set("current_health", current_health)
		player.emit_signal("health_changed", current_health, max_health)


func _add_float(target: Node, property: StringName, amount: float) -> void:
	if amount != 0.0:
		target.set(property, float(target.get(property)) + amount)


func _multiply_float(target: Node, property: StringName, multiplier: float) -> void:
	if multiplier != 1.0:
		target.set(property, float(target.get(property)) * multiplier)


func _add_int(target: Node, property: StringName, amount: int) -> void:
	if amount != 0:
		target.set(property, int(target.get(property)) + amount)


func _set_max_float(target: Node, property: StringName, value: float) -> void:
	target.set(property, maxf(float(target.get(property)), value))


func _clamp_min_float(target: Node, property: StringName, minimum: float) -> void:
	target.set(property, maxf(float(target.get(property)), minimum))
