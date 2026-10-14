extends SceneTree

const Initializer = preload("res://scripts/characters/character_run_initializer.gd")
const Provider = preload("res://scripts/ui/hud/run_hud_state_provider.gd")
const Pool = preload("res://scripts/upgrades/upgrade_pool.gd")
const SCHOOLS: Array[String] = ["fire", "frost", "thunder", "curse", "holy", "chaos"]
const ENTRIES := {
	"fire": "fire_cast_meteor_rain", "frost": "frost_cast_frost_field",
	"thunder": "thunder_cast_chain_lightning", "curse": "curse_cast_black_serpent_hunt",
	"holy": "holy_cast_holy_ray", "chaos": "chaos_cast_void_rift"
}
const DASHES := {
	"fire": "fire_dash_blazing_run", "frost": "frost_dash_ice_shard_assault",
	"thunder": "thunder_dash_ball_lightning", "curse": "curse_dash_soul_chain",
	"holy": "holy_dash_heavenly_wings", "chaos": "chaos_dash_rift_step"
}
var failed := false
var pair_checks := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("[normal_school_pairs] " + label)

func offered_ids(player: Node, pool: RefCounted) -> Array[String]:
	var ids: Array[String] = []
	for option: RefCounted in pool._build_god_skill_learn_options(player):
		ids.append(String(option.payload.get("learn_skill_id", "")))
	return ids

func run() -> void:
	var initializer := Initializer.new()
	var provider := Provider.new()
	var pool := Pool.new()
	for character: String in ["mage", "ranger", "paladin", "alchemist"]:
		paused = false
		var app: Node = load("res://scenes/app/app_bootstrap.tscn").instantiate()
		root.add_child(app)
		for frame: int in range(5): await process_frame
		var ui: Node = app.get_node("UIManager")
		ui.transition_to("TITLE")
		ui.transition_to("CHARACTER_SELECT")
		ui._character_loadout_controller.refresh(StringName(character))
		ui._on_loadout_confirmed(StringName(character))
		var started: bool = await ui._start_run("abandoned_dungeon")
		check(started and String(ui.current_state) == "RUNNING", character + " normal run starts")
		if not started:
			quit(1)
			return
		var player: Node = get_first_node_in_group(&"player")
		var manager: Node = player.get_node("SkillManager")
		paused = true
		check(not bool(root.get_meta("developer_mode_enabled", false)), character + " uses ordinary learning")
		check(manager.get_learned_god_schools().is_empty(), character + " starts without a locked school")
		check(String(manager.get_primary_attack_id()) == String(GameData.get_character(character).get("starting_skill_id", "")), character + " retains configured starting attack")
		var dash: Dictionary = provider._build_skill_slots(player).dash_skill
		check(not dash.is_empty(), character + " basic dash is visible in HUD")
		check(player.start_dash(Vector2.RIGHT), character + " basic dash works without a school")
		dash = provider._build_skill_slots(player).dash_skill
		check(is_equal_approx(float(dash.get("cooldown_remaining", -1)), float(player.get("dash_cooldown"))), character + " HUD reflects basic dash cooldown")
		for school: String in SCHOOLS:
			initializer.configure_starting_skills(player)
			check(offered_ids(player, pool).has(DASHES[school]), "%s offers %s dash before choosing any school" % [character, school])
			check(manager.add_skill(DASHES[school], "normal"), "%s can choose %s dash as first school" % [character, school])
			var learned: Array = manager.get_learned_god_schools()
			check(learned.size() == 1 and learned.has(StringName(school)), character + " first dash locks only its own school")
		for first: String in SCHOOLS:
			for second: String in SCHOOLS:
				if first == second: continue
				initializer.configure_starting_skills(player)
				var choices := offered_ids(player, pool)
				check(choices.has(ENTRIES[first]), "%s %s is offered as first school" % [character, first])
				check(manager.add_skill(ENTRIES[first], "normal"), "%s learns %s first" % [character, first])
				choices = offered_ids(player, pool)
				check(choices.has(ENTRIES[second]), "%s %s remains offered after %s" % [character, second, first])
				check(choices.has(DASHES[second]), "%s %s dash remains offered" % [character, second])
				check(manager.add_skill(DASHES[second], "normal"), "%s learns %s dash second" % [character, second])
				check(manager.add_skill(ENTRIES[second], "normal"), "%s learns second-school output" % character)
				var learned: Array = manager.get_learned_god_schools()
				check(learned.size() == 2 and learned.has(StringName(first)) and learned.has(StringName(second)), "%s locks only chosen pair %s/%s" % [character, first, second])
				check(String(provider._build_skill_slots(player).dash_skill.get("id", "")) == DASHES[second], character + " learned dash replaces basic HUD slot")
				choices = offered_ids(player, pool)
				for third: String in SCHOOLS:
					if third in [first, second]: continue
					check(not choices.has(ENTRIES[third]), character + " third school excluded from offers")
					check(not manager.add_skill(ENTRIES[third], "normal"), character + " third school rejected by learning")
				pair_checks += 1
		print("[normal_school_pairs] %s: 15 pairs in both orders checked" % character)
		ui._teardown_run_scene()
		app.queue_free()
		paused = false
		for frame: int in range(5): await process_frame
	check(pair_checks == 120, "four characters x 15 pairs x two orders")
	print("[normal_school_pairs] %s ordered_cases=%d" % ["FAIL" if failed else "PASS", pair_checks])
	quit(1 if failed else 0)
