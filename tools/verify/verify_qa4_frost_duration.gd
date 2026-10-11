extends "res://tools/verify/qa_app_fixture.gd"

const POOL = preload("res://scripts/upgrades/upgrade_pool.gd")
const STAT = preload("res://scripts/skills/skill_stat_service.gd")
const PREVIEW = preload("res://scripts/ui/skill_preview_service.gd")
const ADAPTER = preload("res://scripts/skills/skill_effect_adapter.gd")
const EXECUTOR = preload("res://scripts/skills/skill_action_executor.gd")
const ENEMY = preload("res://scenes/enemies/enemy.tscn")

func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s actual=%.3f expected=%.3f" % [label, actual, expected])

func learn_card(id: StringName, first: bool) -> void:
	var options: Array = POOL.new()._build_god_skill_learn_options(player) if first else POOL.new()._build_skill_level_up_options(player)
	var selected: StringName = &""
	for option: RefCounted in options:
		if String(option.id).contains(String(id)):
			selected = option.id
	check(selected != &"" and player.apply_upgrade(selected), "production card %s" % id)

func find_area(id: StringName) -> Node:
	for area: Node in get_nodes_in_group(&"area_effects"):
		if StringName(str(area.get("source_id"))) == id and not area.is_queued_for_deletion():
			return area
	return null

func dispose(area: Node) -> void:
	if area != null:
		area.get_parent().remove_child(area)
		area.queue_free()

func cast(skill_id: StringName, enemy: Node, area_id: StringName) -> Node:
	var skill: RefCounted = manager.get_skill(skill_id)
	var context: Dictionary = {"caster":player,"owner":player,"skill_manager":manager,"skill_instance":skill,"target":enemy,"skill_id":skill_id,"origin_skill_id":skill_id,"scheduled_cast":true,"power":float(player.attack_power)}
	player.get_node("SkillEventBus").emit_skill_event(&"on_cast", context)
	var area: Node = find_area(area_id)
	check(area != null, "%s on_cast creates %s" % [skill_id, area_id])
	return area

func run() -> void:
	await setup_run()
	check(manager.add_skill(&"frost_attack_frostbite", "normal"), "learn frost school attack")
	learn_card(&"frost_cast_frost_field", true)
	var enemy: Node = ENEMY.instantiate()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(200, 0)
	var area: Node = cast(&"frost_cast_frost_field", enemy, &"frost_field")
	if area != null:
		close(area.duration, 3.0, "unlearned field duration")
		dispose(area)
	var wants: Array[float] = [3.60, 3.72, 3.84, 3.96, 4.08]
	var bonuses: Array[float] = [0.20, 0.24, 0.28, 0.32, 0.36]
	for level_now: int in range(1, 6):
		learn_card(&"frost_passive_chill_extension", level_now == 1)
		var skill: RefCounted = manager.get_skill(&"frost_cast_frost_field")
		var mods: Dictionary = STAT.get_combined_modifiers(skill, manager, null, player)
		close(float(mods.get("frost_area_duration_multiplier_add", 0.0)), bonuses[level_now - 1], "queried bonus Lv%d" % level_now)
		area = cast(&"frost_cast_frost_field", enemy, &"frost_field")
		if area != null:
			close(area.duration, wants[level_now - 1], "real field Lv%d" % level_now)
			if level_now == 1:
				check(bool(area.call("_damage_body", enemy)), "real frost field tick hits target")
				var chilled_duration: float = 0.0
				for status: Dictionary in enemy.get_node("StatusEffectManager").get_status_snapshot():
					if StringName(status.get("id")) == &"chilled":
						chilled_duration = float(status.get("duration_remaining", 0.0))
				close(chilled_duration, 7.2, "Chilled remains single 20 percent extension")
			dispose(area)
		var preview: Dictionary = PREVIEW.build(player, &"frost_cast_frost_field", 1, "normal")
		close(float(preview.get("duration", 0.0)), wants[level_now - 1], "UI preview Lv%d" % level_now)
	check(manager.add_skill(&"frost_cast_blizzard_cloud", "normal"), "learn second frost area")
	area = cast(&"frost_cast_blizzard_cloud", enemy, &"blizzard_cloud")
	if area != null:
		close(area.duration, 6.8, "blizzard base 5 times Lv5 bonus")
		dispose(area)
	var field: RefCounted = manager.get_skill(&"frost_cast_frost_field")
	var path_effect: Dictionary = GameData.get_skill(&"frost_cast_frost_field").trigger_rules[0].effects[0].effects_on_expire[0]
	var path_context: Dictionary = {"caster":player,"owner":player,"skill_manager":manager,"skill_instance":field,"skill_id":&"frost_cast_frost_field","position":enemy.global_position,"target":enemy}
	check(bool(EXECUTOR.new().execute_action(ADAPTER.to_action(path_effect, field), path_context)), "production expiry action creates frost path")
	area = find_area(&"frost_path")
	check(area != null, "frost path exists")
	if area != null:
		close(area.duration, 4.08, "derived frost path gets bonus once")
		dispose(area)
	check(manager.add_skill(&"fire_cast_scorching_vortex", "normal"), "learn non-frost area")
	area = cast(&"fire_cast_scorching_vortex", enemy, &"scorching_vortex")
	if area != null:
		close(area.duration, 4.0, "non-frost area unaffected")
		dispose(area)
	manager.clear_skills()
	check(manager.add_skill(&"frost_attack_frostbite", "normal"), "relearn frost school after removal")
	check(manager.add_skill(&"frost_cast_frost_field", "normal"), "relearn frost field after passive removal")
	area = cast(&"frost_cast_frost_field", enemy, &"frost_field")
	if area != null:
		close(area.duration, 3.0, "passive removal restores base")
		dispose(area)
	enemy.queue_free()
	await finish()
