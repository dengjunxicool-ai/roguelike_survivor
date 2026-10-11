extends "res://tools/verify/qa_app_fixture.gd"
const QUERY = preload("res://scripts/modifiers/modifier_query.gd")
const STAT = preload("res://scripts/skills/skill_stat_service.gd")
const POOL = preload("res://scripts/upgrades/upgrade_pool.gd")
const ENEMY = preload("res://scenes/enemies/enemy.tscn")
const ADAPTER = preload("res://scripts/skills/skill_effect_adapter.gd")
const EXECUTOR = preload("res://scripts/skills/skill_action_executor.gd")
const ID = &"fire_passive_burning_focus"
const TRACKER = preload("res://scripts/game/run_stats_tracker.gd")
var attack: RefCounted
func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.0001, "%s actual=%s expected=%s" % [label, actual, expected])
func burn(expected: float, label: String) -> void:
	var enemy: Node = ENEMY.instantiate()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(enemy)
	enemy.global_position = player.global_position
	var effect: Dictionary = GameData.get_skill(&"fire_attack_searing").trigger_rules[0].effects[0]
	var context: Dictionary = {"caster":player,"skill_instance":attack,"skill_manager":manager,"target":enemy,"origin_skill_id":"fire_attack_searing","skill_id":"fire_attack_searing"}
	check(EXECUTOR.new().execute_action(ADAPTER.to_action(effect, attack), context), label + " status applied")
	close(float(enemy.get_node("StatusEffectManager").get_status_snapshot()[0].duration_remaining), expected, label)
	enemy.queue_free()
func run() -> void:
	await setup_run()
	check(manager.add_skill(&"fire_attack_searing", "normal"), "learn real searing")
	attack = manager.get_skill(&"fire_attack_searing")
	var expected_player: Array = [1.2,1.24,1.28,1.32,1.36]
	var expected_burn: Array = [4.8,4.96,5.12,5.28,5.44]
	var expected_store: Array = [0.2,0.24,0.28,0.32,0.36]
	for level_now: int in range(1,6):
		var options: Array = POOL.new()._build_god_skill_learn_options(player) if level_now == 1 else POOL.new()._build_skill_level_up_options(player)
		var selected: StringName = &""
		for option: RefCounted in options:
			if String(option.id).contains(String(ID)): selected = option.id
		check(selected != &"" and player.apply_upgrade(selected), "normal upgrade card level %d" % level_now)
		close(player.status_duration_multiplier, expected_player[level_now-1], "player level %d" % level_now)
		close(player.get_node("ModifierStore").collect(QUERY.for_player(player)).get("status_duration_multiplier_add",0.0), expected_store[level_now-1], "store level %d" % level_now)
		burn(expected_burn[level_now-1], "production burn level %d" % level_now)
		player.refresh_run_modifier_snapshot()
		close(player.status_duration_multiplier, expected_player[level_now-1], "idempotent refresh level %d" % level_now)
	manager.clear_skills()
	close(player.status_duration_multiplier, 1.0, "clear skills removes persistent duration")
	_test_source_lifecycle()
	_test_scoped_consumption()
	_test_reset_and_events()
	await finish()
func _test_source_lifecycle() -> void:
	player.current_health = player.max_health - 40
	var hp: int = player.current_health
	var max_hp: int = player.max_health
	var tracker: Node = TRACKER.get_active(self)
	var healing_before: int = tracker.healing_used
	player.set_run_modifier_source("qa:durable", {"status_duration_multiplier_add":0.2,"attack_speed_multiplier_add":0.2,"skill_area_multiplier_add":0.3,"max_hp_add":10,"revive_count_add":1,"heal":5})
	close(player.status_duration_multiplier,1.2,"first stable source")
	check(player.current_health == hp+15 and player.max_health == max_hp+10,"max HP growth preserves wound and heals once")
	player.revive_count_add -= 1
	player.current_health -= 7
	player.set_run_modifier_source("qa:durable", {"status_duration_multiplier_add":0.3,"attack_speed_multiplier_add":0.3,"skill_area_multiplier_add":0.4,"max_hp_add":20,"revive_count_add":1,"heal":5})
	close(player.status_duration_multiplier,1.3,"stable source overwrite")
	close(player.attack_speed_multiplier,1.3,"attack speed overwrite")
	close(player.skill_area_multiplier,1.4,"area overwrite")
	check(player.current_health == hp+18 and player.max_health == max_hp+20,"overwrite preserves new damage without repeat heal")
	check(player.revive_count_add == 0,"overwrite preserves consumed revival")
	check(tracker.healing_used == healing_before+5,"heal counted once")
	player.merge_run_modifier_source("qa:durable", {"status_duration_multiplier_add":0.1,"heal":3})
	close(player.status_duration_multiplier,1.4,"explicit merge accumulates contribution")
	check(tracker.healing_used == healing_before+8,"merge executes new healing only")
	player.set_run_modifier_source("qa:independent", {"status_duration_multiplier":1.5})
	close(player.status_duration_multiplier,1.9,"multiple additive and multiplicative sources")
	player.refresh_run_modifier_snapshot()
	close(player.status_duration_multiplier,1.9,"multiple source refresh")
	player.clear_run_modifier_source("qa:durable")
	close(player.status_duration_multiplier,1.5,"clear one source retains other")
	check(player.revive_count_add == 0,"clear cannot restore consumed revive")
	check(tracker.healing_used == healing_before+8,"clear cannot roll back healing statistic")
	player.clear_run_modifier_source("qa:independent")
	close(player.status_duration_multiplier,1.0,"clear all restores base")
	player.set_run_modifier_source("qa:new-revive", {"revive_count_add":1})
	check(player.revive_count_add == 1,"independent newly granted revival remains usable")
	player.clear_run_modifier_source("qa:new-revive")
	player.set_run_modifier_source("qa:revive-A", {"revive_count_add":1})
	player.set_run_modifier_source("qa:revive-B", {"revive_count_add":1})
	check(player.revive_count_add == 2,"two independent revive grants")
	player.revive_count_add -= 1
	player.clear_run_modifier_source("qa:revive-A")
	check(player.revive_count_add == 1,"FIFO consumption: clear spent first source retains second revival")
	player.set_run_modifier_source("qa:revive-A", {"revive_count_add":1})
	check(player.revive_count_add == 1,"re-registering spent source cannot restore its charge")
	player.clear_run_modifier_source("qa:revive-B")
	check(player.revive_count_add == 0,"clear unspent source removes its own charge")
	player.clear_run_modifier_source("qa:revive-A")
	player.set_run_modifier_source("qa:weak", {"slow_percent":0.2,"slow_duration":1.0,"thorns_area_radius":20.0})
	player.set_run_modifier_source("qa:strong", {"slow_percent":0.4,"slow_duration":2.0,"thorns_area_radius":40.0})
	close(player.slow_percent,0.4,"max-valued slow sources retain strongest")
	close(player.thorns_area_radius,40.0,"max-valued radius retains strongest")
	player.clear_run_modifier_source("qa:strong")
	close(player.slow_percent,0.2,"clear strongest restores weaker slow")
	player.clear_run_modifier_source("qa:weak")
	var speed: float = player.move_speed
	var pickup: float = player.pickup_radius
	var damage: float = player.damage_multiplier
	player.set_run_modifier_source("qa:dynamic", {"move_speed_multiplier_add":0.2,"pickup_radius_multiplier_add":0.3,"damage_multiplier_add":0.4})
	player.refresh_run_modifier_snapshot()
	close(player.move_speed,speed,"dynamic movement leaves base field unchanged")
	close(player._get_effective_move_speed(),speed*1.2,"dynamic movement consumed once")
	close(player.pickup_radius,pickup,"dynamic pickup leaves base field unchanged")
	close(player.get_effective_pickup_radius(),pickup*1.3,"dynamic pickup consumed once")
	close(player.damage_multiplier,damage,"dynamic damage leaves base field unchanged")
	player.clear_run_modifier_source("qa:dynamic")
func _test_scoped_consumption() -> void:
	check(manager.add_skill(&"fire_attack_searing", "normal"), "relearn searing for distinct sources")
	attack = manager.get_skill(&"fire_attack_searing")
	var effects: Array[Dictionary] = [
		{"type":"add_modifier","stat":"status_duration","op":"multiplier_add","value":0.2,"scope":{},"source":"skill"},
		{"type":"add_modifier","stat":"status_duration","op":"multiplier_add","value":0.3,"scope":{"domain":"skill","skill_id":"fire_attack_searing"},"source":"skill"},
		{"type":"add_modifier","stat":"status_duration","op":"multiplier_add","value":0.1,"scope":{"owner_has_shield":"true"},"source":"skill"},
		{"type":"add_modifier","stat":"attack_speed","op":"multiplier_add","value":0.2,"scope":{},"source":"skill"},
		{"type":"add_modifier","stat":"skill_area","op":"multiplier_add","value":0.25,"scope":{},"source":"skill"},
		{"type":"add_modifier","stat":"radius","op":"multiplier_add","value":0.1,"scope":{"domain":"skill","skill_id":"fire_attack_searing"},"source":"skill"}
	]
	attack.definition.effects.assign(effects)
	manager._refresh_skill_modifier_payload(attack)
	attack.runtime_modifiers = {"status_duration_multiplier_add":0.1,"attack_speed_multiplier_add":0.1,"area_radius_multiplier_add":0.1}
	close(STAT.calculate_value(attack,"cooldown",10.0,manager,null,player),7.6923076923,"player and independent runtime attack speed consumed once")
	close(STAT.calculate_value(attack,"area_radius",100.0,manager,null,player),150.0,"player area and scoped runtime radius preserved")
	var relics: Node = player.get_node("RelicManager")
	relics._relic_definitions[&"qa:duration"] = {"id":"qa:duration","tags":["fire"],"modifiers":[{"stat":"status_duration","op":"multiplier_add","value":0.1,"scope":{"domain":"skill"},"source":"relic"}]}
	check(relics.add_relic(&"qa:duration"), "real relic manager accepts independent duration fixture")
	close(player.status_duration_multiplier,1.2,"only unscoped effect enters player snapshot")
	close(STAT.calculate_value(attack,"status_duration",4.0,manager,relics,player),7.2,"independent runtime skill scope and relic duration preserved")
	player.set_meta("fire_passive_shield",5)
	close(STAT.calculate_value(attack,"status_duration",4.0,manager,relics,player),7.68,"conditional skill contribution retained before player refresh")
	player.refresh_run_modifier_snapshot()
	close(player.status_duration_multiplier,1.2,"shield condition remains a query contribution")
	close(STAT.calculate_value(attack,"status_duration",4.0,manager,relics,player),7.68,"conditional source is independent of snapshot refresh")
	player.set_meta("fire_passive_shield",0)
	close(STAT.calculate_value(attack,"status_duration",4.0,manager,relics,player),7.2,"shield expiry changes duration without snapshot refresh")
	player.refresh_run_modifier_snapshot()
	close(player.status_duration_multiplier,1.2,"shield expiry clears snapshot contribution")
	relics.owned_relics.erase(&"qa:duration")
	manager.clear_skills()
func _test_reset_and_events() -> void:
	check(manager.add_skill(&"fire_attack_searing", "normal"), "relearn searing for event test")
	attack = manager.get_skill(&"fire_attack_searing")
	player.set_run_modifier_source("qa:skill-event", {"all_owned_skills_level_add":1})
	check(attack.current_level == 2,"new source upgrades owned skills once")
	player.set_run_modifier_source("qa:skill-event", {"all_owned_skills_level_add":1})
	player.refresh_run_modifier_snapshot()
	check(attack.current_level == 2,"set and refresh cannot replay skill level event")
	player.clear_run_modifier_source("qa:skill-event")
	check(attack.current_level == 2,"clear cannot roll back skill level event")
	player.set_run_modifier_source("qa:reset", {"max_hp_add":20,"attack_speed_multiplier_add":0.3,"status_duration_multiplier_add":0.4,"revive_count_add":1})
	var healing_before: int = ui._run_stats_tracker.healing_used
	player.reset_for_loadout(player._run_loadout)
	close(player.status_duration_multiplier,1.0,"loadout reset clears old duration")
	close(player.attack_speed_multiplier,1.0,"loadout reset clears old attack speed")
	check(player.max_health == int(GameData.get_character(&"mage").base_stats.max_hp),"loadout reset retains character max HP")
	check(player.current_health == player.max_health and player.revive_count_add == 0,"loadout reset restores new life without old revive source")
	check(ui._run_stats_tracker.healing_used == healing_before,"loadout reset does not replay healing")
	SaveManager.add_soul_stones(1000)
	check(SaveManager.purchase_permanent_upgrade(&"meta_health"),"buy real permanent health upgrade")
	player.reset_for_loadout(player._run_loadout)
	check(player.max_health == int(GameData.get_character(&"mage").base_stats.max_hp)+20,"new loadout applies permanent health once")
	player.set_run_modifier_source("qa:permanent-peer", {"max_hp_add":10})
	player.refresh_run_modifier_snapshot()
	check(player.max_health == int(GameData.get_character(&"mage").base_stats.max_hp)+30,"permanent and independent health refresh once")
	player.reset_for_loadout(player._run_loadout)
	check(player.max_health == int(GameData.get_character(&"mage").base_stats.max_hp)+20,"second loadout restores permanent health once")
