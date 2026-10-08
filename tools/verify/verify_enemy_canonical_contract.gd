extends SceneTree

const ConfigHelper: Script = preload("res://scripts/enemies/enemy_config_helper.gd")
const Request: Script = preload("res://scripts/enemies/spawning/enemy_spawn_request.gd")
const Cleanup: Script = preload("res://scripts/enemies/timeline/enemy_cleanup_service.gd")
const Resolver: Script = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const SpawnService: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const Tracker: Script = preload("res://scripts/game/run_stats_tracker.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for rank: String in ["normal", "elite", "boss", "boss_core"]:
		var enemy := Node2D.new()
		root.add_child(enemy)
		ConfigHelper.apply_classification_metadata(enemy, {"enemy_rank": rank})
		_expect(String(enemy.get_meta("enemy_rank", "")) == rank, "classification uses canonical rank " + rank)
		_expect(enemy.is_in_group("bosses") == (rank == "boss"), "Boss index derives from rank")
		_expect(enemy.is_in_group("elites") == (rank == "elite"), "elite index derives from rank")
		_expect(enemy.is_in_group("boss_cores") == (rank == "boss_core"), "core index derives from rank")
		_expect(not enemy.has_meta("enemy_type") and not enemy.has_meta("is_boss") and not enemy.has_meta("is_elite"), "rank has no duplicate facts")
		enemy.add_to_group("bosses")
		_expect(String(Resolver.resolve(enemy).target_type) == rank, "damage classification ignores conflicting group")
		enemy.free()
	var override := Node2D.new()
	override.set_meta("enemy_rank", "boss_core")
	ConfigHelper.apply_classification_metadata(override, {"enemy_rank": "normal"})
	_expect(String(override.get_meta("enemy_rank")) == "boss_core", "spawn override survives configured rank")
	override.free()
	var core: Dictionary = Request.boss_core("skeleton", Vector2.ZERO, 100, 8)
	_expect(core.get("enemy_rank", "") == "boss_core", "Boss core request uses canonical rank")
	_expect(not core.reward_policy.award_soul and not core.reward_policy.drop_experience, "core rewards remain suppressed")
	var summon: Dictionary = Request.summon("skeleton", Vector2.ZERO)
	_expect(summon.source_type == "summon" and not summon.reward_policy.award_soul, "summon provenance and reward policy remain independent")
	var owner := Node.new()
	root.add_child(owner)
	var cleanup: RefCounted = Cleanup.new()
	cleanup.setup(owner)
	for source: String in ["wave", "boss_minion"]:
		var enemy := Node2D.new()
		enemy.set_meta("enemy_rank", "normal")
		enemy.set_meta("spawn_source_type", source)
		enemy.add_to_group("enemy")
		owner.add_child(enemy)
	_expect(cleanup.get_alive_normal_enemy_count() == 1, "wave pressure excludes Boss minion provenance")
	_expect(cleanup.get_alive_boss_minion_count() == 1, "Boss minion count uses provenance")
	owner.free()
	await _verify_spawned_contract()
	print("[verify_enemy_canonical_contract] failed=%s" % failed)
	quit(1 if failed else 0)

func _verify_spawned_contract() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var service: RefCounted = SpawnService.new()
	service.setup(owner, load("res://scenes/enemies/enemy.tscn"))
	var tracker: Node = Tracker.new()
	root.add_child(tracker)
	for enemy_id: StringName in [&"small_slime", &"elite_skeleton", &"dungeon_heart"]:
		# Use the configured elite ID rather than guessing from its name.
		if enemy_id == &"elite_skeleton":
			for definition: Dictionary in GameData.get_enemy_pool():
				if definition.enemy_rank == "elite":
					enemy_id = StringName(definition.id)
					break
		var config: Dictionary = GameData.get_enemy(enemy_id)
		var enemy: Node2D = service.spawn(Request.create(enemy_id, {"parent": owner, "position": Vector2.ZERO, "spawn_clearance": 0.0}))
		_expect(enemy != null, "canonical request creates configured enemy")
		if enemy == null:
			continue
		_expect(String(enemy.get_meta("enemy_rank", "")) == String(config.enemy_rank), "ready keeps configured rank")
		_expect(is_equal_approx(float(enemy.get("damage_interval")), float(config.base_stats.contact_interval)), "ready reads canonical contact interval")
		tracker.record_enemy_killed(enemy)
		enemy.free()
	_expect(tracker.kill_count == 3 and tracker.elite_kill_count == 1 and tracker.boss_defeated, "kill statistics consume canonical classification")
	var core: Node2D = service.spawn(Request.boss_core("skeleton", Vector2.ZERO, 123, 7))
	_expect(core != null and String(core.get_meta("enemy_rank", "")) == "boss_core" and core.is_in_group("boss_cores"), "ready preserves core rank override and derived index")
	if core != null:
		_expect(core.get("max_health") == 123 and core.get("armor") == 7, "core post-ready attributes remain explicit")
		core.free()
	owner.free()
	tracker.free()
	await process_frame

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("[verify_enemy_canonical_contract] FAIL " + label)
