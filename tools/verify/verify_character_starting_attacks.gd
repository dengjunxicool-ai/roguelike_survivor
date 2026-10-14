extends SceneTree

const Initializer = preload("res://scripts/characters/character_run_initializer.gd")
const LoadoutService = preload("res://scripts/characters/character_loadout_service.gd")
const EXPECTED := {"mage": "fireball", "ranger": "ranger_bolt", "paladin": "paladin_smite", "alchemist": "alchemist_flask"}
const StatService = preload("res://scripts/skills/skill_stat_service.gd")
const Query = preload("res://scripts/modifiers/modifier_query.gd")
var failed := false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[character_starting_attacks] " + message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	for character: String in EXPECTED:
		check(LoadoutService.validate_loadout(character), character + " loadout validates")
		var app: Node = load("res://scenes/app/app_bootstrap.tscn").instantiate()
		root.add_child(app)
		for frame: int in range(5): await process_frame
		var ui: Node = app.get_node("UIManager")
		ui.transition_to("TITLE")
		ui.transition_to("CHARACTER_SELECT")
		ui._character_loadout_controller.refresh(StringName(character))
		ui._on_loadout_confirmed(StringName(character))
		check(await ui._start_run("abandoned_dungeon"), character + " starts through normal loadout")
		var player: Node2D = get_first_node_in_group(&"player")
		var manager: Node = player.get_node("SkillManager")
		var executor: Node = player.get_node("SkillExecutor")
		player.set_physics_process(false)
		executor.set_physics_process(false)
		player.get_parent().set_process(false)
		for spawner: Node in get_nodes_in_group(&"enemy_spawner"): spawner.set_process(false)
		for old_enemy: Node in get_nodes_in_group(&"enemies"): old_enemy.queue_free()
		await physics_frame
		check(String(manager.get_primary_attack_id()) == EXPECTED[character], character + " has its distinct primary attack")
		check(manager.get_all_skills().is_empty(), character + " starter occupies no learned slot")
		check(manager.get_learned_god_schools().is_empty(), character + " starter reserves neither school")
		var primary: RefCounted = manager.get_primary_attack_method()
		var config: Dictionary = GameData.get_skill(primary.skill_id)
		check(bool(config.get("is_starting_skill", false)) and not bool(config.get("offer_in_upgrade_pool", true)), character + " starter remains outside learning offers")
		check(String(config.get("exclusive_group", "")) == "", character + " starter has no god attack exclusivity")
		if character == "ranger":
			check(float(config.base.projectile_speed) > 420, "ranger bolt travels faster than mage fireball")
			check(int(config.base.get("pierce", 0)) > 0, "ranger bolt pierces")
			var resting_speed: float = float(StatService.get_effective_stat(primary, "projectile_speed", 0, manager, null, player))
			player.get_node("CharacterTraitSystem").handle_movement(true, 3.0)
			check(float(StatService.get_effective_stat(primary, "projectile_speed", 0, manager, null, player)) > resting_speed, "ranger movement trait accelerates its starting bolt")
		if character == "paladin":
			check(String(config.base.element) == "holy" and float(config.base.range) <= 150, "paladin smite is a close holy attack")
			var damage_query: RefCounted = Query.for_player(player, &"damage")
			damage_query.damage_origin = &"primary_attack"
			damage_query.element = &"holy"
			check(float(player.get_node("CharacterTraitSystem").get_modifiers(damage_query).get("primary_attack_damage_multiplier_add", 0)) > 0, "paladin initial shield boosts starting smite damage")
		var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
		enemy.set("enemy_id", &"small_slime")
		enemy.position = player.position + Vector2(60, 0)
		player.get_parent().add_child(enemy)
		enemy.set("max_health", 999)
		enemy.set("current_health", 999)
		enemy.set_physics_process(false)
		var second_enemy: Node2D = null
		if character == "ranger" or character == "paladin":
			second_enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
			second_enemy.set("enemy_id", &"small_slime")
			second_enemy.position = player.position + Vector2(110, 0)
			player.get_parent().add_child(second_enemy)
			second_enemy.set("max_health", 999)
			second_enemy.set("current_health", 999)
			second_enemy.set_physics_process(false)
		for frame: int in range(3): await process_frame
		var camera: Camera2D = root.get_camera_2d()
		if camera != null: camera.force_update_scroll()
		check(preload("res://scripts/skills/targeting_service.gd").find_target(player, "nearest_enemy", {"range": 540}) == enemy, character + " fixture enemy is targetable")
		check(executor.debug_cast_all_skills() == 1, character + " starter casts through real skill executor")
		for frame: int in range(40): await physics_frame
		check(int(enemy.get("current_health")) < 999, character + " starter deals real damage")
		if second_enemy != null:
			check(int(second_enemy.get("current_health")) < 999, character + " starting attack hits a second enemy")
		if character == "alchemist":
			check(enemy.has_status(&"burning"), "alchemist flask immediately applies supported burning DOT")
			var direct_hit_health: int = int(enemy.get("current_health"))
			# The fixture freezes enemy movement; drive its real status owner once.
			enemy.call("_update_status_effects", 1.05)
			check(int(enemy.get("current_health")) < direct_hit_health, "alchemist starting burn ticks real DOT damage")
			var dot_query: RefCounted = Query.for_player(player, &"damage")
			dot_query.damage_origin = &"status_dot"
			dot_query.element = &"fire"
			check(float(player.get_node("CharacterTraitSystem").get_modifiers(dot_query).get("dot_damage_multiplier_add", 0)) >= 0.25, "alchemist starting DOT receives trait bonus")
		check(manager.add_skill(&"fire_cast_meteor_rain", "normal"), character + " freely learns first school")
		check(manager.add_skill(&"holy_cast_holy_ray", "normal"), character + " freely learns second school")
		check(manager.add_skill(&"holy_attack_judgment", "normal"), character + " can replace starting attack")
		check(manager.upgrade_skill(&"holy_attack_judgment", "normal"), character + " replacement remains upgradeable")
		print("[character_starting_attacks] checked " + character)
		ui._teardown_run_scene()
		app.queue_free()
		for frame: int in range(5): await process_frame
	print("[character_starting_attacks] " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
