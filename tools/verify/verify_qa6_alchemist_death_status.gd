extends "res://tools/verify/qa_app_fixture.gd"

const ENEMY = preload("res://scenes/enemies/enemy.tscn")
var active_trait: RefCounted
var run_parent: Node

func make_enemy() -> Node2D:
	var enemy: Node2D = ENEMY.instantiate()
	enemy.enemy_id = &"small_slime"
	run_parent.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(80, 0)
	enemy.current_health = 1000
	enemy.max_health = 1000
	enemy.set_physics_process(false)
	return enemy

func zone_count() -> int:
	return int(active_trait.get_debug_state().active_trait_zones)

func kill(enemy: Node2D) -> void:
	enemy.take_damage(DamagePacket.from_dictionary({"raw_amount": 5000, "damage_type": "direct_physical", "damage_origin": "primary_attack", "source_id": "qa6_status_death", "source_skill_id": "alchemist_flask", "source_instance_id": str(player.get_instance_id()), "can_crit": false, "can_trigger_reaction": false}, player, enemy))

func run() -> void:
	await setup_run()
	ui.transition_to("TITLE")
	ui.transition_to("CHARACTER_SELECT")
	ui._on_loadout_confirmed(&"alchemist")
	check(await ui._start_run(&"abandoned_dungeon"), "real alchemist run starts")
	await create_timer(0.3, true).timeout
	player = get_first_node_in_group(&"player")
	run_parent = ui._run_scene_coordinator.get_run_scene_parent(self)
	run_parent.process_mode = Node.PROCESS_MODE_DISABLED
	active_trait = player.get_node("CharacterTraitSystem")._controller._active_trait
	# Remove probability and caps only in this fixture to prove status eligibility.
	active_trait.config.params.kill_chance = 1.0
	active_trait.config.params.same_source_cooldown = 0.0
	active_trait.config.params.max_zones = 100
	for id: StringName in [&"burning", &"poison", &"chilled", &"frozen", &"cursed", &"wound", &"judgment", &"acid_mark"]:
		var enemy: Node2D = make_enemy()
		var statuses: Node = enemy.get_node("StatusEffectManager")
		check(statuses.apply_status(id, {"power": 10.0, "duration": 5.0, "source": player}), "real status applies " + String(id))
		check(statuses.has_status(id), "target carries " + String(id))
		var before: int = zone_count()
		kill(enemy)
		check(zone_count() == before + 1, "status-bearing death creates potion zone " + String(id))
		await settle(2)
	var clean: Node2D = make_enemy()
	var before_clean: int = zone_count()
	kill(clean)
	check(zone_count() == before_clean, "death without status never creates potion zone")
	await settle(2)
	var cursed: Node2D = make_enemy()
	var curse_manager: Node = cursed.get_node("StatusEffectManager")
	check(curse_manager.apply_status(&"cursed", {"power": 5000.0, "source": player, "attacker": player, "source_skill_id": "curse_attack_cursing"}), "lethal resolving curse applies")
	var before_curse: int = zone_count()
	check(curse_manager.resolve_cursed(&"forced"), "real curse resolves after removal from active table")
	print("resolving curse health=", cursed.current_health)
	check(cursed.current_health <= 0, "curse resolution really kills target")
	check(zone_count() == before_curse + 1, "curse resolution death preserves status eligibility from death snapshot")
	await finish()
