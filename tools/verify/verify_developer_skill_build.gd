extends SceneTree

const APP := preload("res://scenes/app/app_bootstrap.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const Build := preload("res://scripts/game/developer_skill_build.gd")
const Loadouts := preload("res://scripts/characters/character_loadout_service.gd")
var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	create_timer(40.0, true).timeout.connect(func() -> void: push_error("developer build timeout"); quit(1))
	var app: Node = APP.instantiate()
	root.add_child(app)
	for frame: int in range(5): await process_frame
	var ui: Node = app.get_node("UIManager")
	ui.call("start_developer_debug_run", {"character_id": "mage", "map_id": "abandoned_dungeon"})
	await _wait_for_run(ui)
	var panel: Node = root.find_child("DevDebugPanel", true, false)
	_expect(panel != null, "original developer entry opens its panel")
	_expect(bool(root.get_meta("debug_control_mode", false)) and bool(root.get_meta("debug_manual_spawn_only", false)), "original developer entry retains manual controls")
	if panel != null:
		_expect(panel.find_child("StartSkillBuildButton", true, false) != null, "run setup offers start with build")
		var panel_control: Control = panel.get("_panel")
		_expect(panel_control.get_global_rect().end.y <= root.get_visible_rect().end.y, "developer toolbar fits viewport so its page can scroll")
	var build: Array = [
		{"skill_id": "fire_attack_searing", "level": 4, "rarity": "legendary"},
		{"skill_id": "fire_passive_burning_focus", "level": 3, "rarity": "epic"},
		{"skill_id": "fire_core_inferno_cycle", "level": 1, "rarity": "rare"}
	]
	var picker: OptionButton = panel.find_child("BuildSkillOption", true, false) if panel != null else null
	var add: Button = panel.find_child("AddBuildSkillButton", true, false) if panel != null else null
	var start: Button = panel.find_child("StartSkillBuildButton", true, false) if panel != null else null
	if picker != null and add != null and start != null:
		var setup_controller: RefCounted = panel.get("_run_setup_controller")
		var school_picker: OptionButton = setup_controller.get("_school_option")
		# Filtering must tolerate null fusion_school on ordinary school skills.
		for school: String in ["frost", "fire", "thunder", "curse", "holy", "chaos", ""]:
			_select_skill(school_picker, school)
			school_picker.item_selected.emit(school_picker.selected)
			_expect(picker.item_count > 0, "school filter offers skills for " + school)
			if school != "":
				for index: int in range(picker.item_count):
					var data: Dictionary = GameData.get_skill(picker.get_item_metadata(index))
					_expect(data.get("school", "") == school or data.get("fusion_school", "") == school, "school filter excludes unrelated skills for " + school)
			if school == "frost":
				_expect(_has_option(picker, "frost_cast_frost_field"), "frost filter includes frost skills")
				_expect(_has_option(picker, "fusion_fire_frost_steam_mist"), "frost filter includes fusion secondary school")
				_expect(not _has_option(picker, "fire_attack_searing"), "frost filter excludes fire-only skills")
		var baseline: int = int(get_first_node_in_group(&"player").get_node("SkillManager").get("run_generation"))
		_select_skill(picker, "fire_cast_meteor_rain")
		add.pressed.emit()
		var temporary: Node = panel.find_child("BuildEntry_fire_cast_meteor_rain", true, false)
		if temporary != null:
			for button: Button in temporary.find_children("*", "Button", true, false): button.pressed.emit()
		await process_frame
		_expect(panel.find_child("BuildEntry_fire_cast_meteor_rain", true, false) == null, "remove deletes only selected build entry")
		_select_skill(picker, "fire_cast_meteor_rain")
		add.pressed.emit()
		panel.find_child("ClearSkillBuildButton", true, false).emit_signal("pressed")
		await process_frame
		_expect(panel.find_child("SkillBuildList", true, false).get_child_count() == 0, "clear build restores empty selection")
		for entry: Dictionary in build:
			_select_skill(picker, entry.skill_id)
			add.pressed.emit()
			var card: Node = panel.find_child("BuildEntry_" + entry.skill_id, true, false)
			_expect(card != null, "adding skill creates an editable build entry")
			if card != null:
				var level: SpinBox = card.find_child("BuildLevel", true, false)
				var rarity: OptionButton = card.find_child("BuildRarity", true, false)
				level.value = entry.level
				var rarity_index: int = ["normal", "rare", "epic", "legendary"].find(entry.rarity)
				rarity.select(rarity_index)
				rarity.item_selected.emit(rarity_index)
		_expect(int(get_first_node_in_group(&"player").get_node("SkillManager").get("run_generation")) == baseline, "editing build does not change current run")
		await process_frame
		var page: Control = panel.find_child("CategoryPage_run_setup", true, false)
		var page_scroll: ScrollContainer = page.get_parent().get_parent()
		page_scroll.scroll_vertical = 380
		await process_frame
		_expect(start.get_global_rect().end.y <= root.get_visible_rect().end.y, "start with build is visible after scrolling setup")
		await _capture("developer-build-setup")
		root.set_meta("debug_enemy_forced_state", "idle")
		start.pressed.emit()
	else:
		ui.call("start_developer_debug_run", {"character_id": "mage", "map_id": "abandoned_dungeon", "skill_build": build, "play_build": true})
	await _wait_for_run(ui)
	var player: Node = get_first_node_in_group(&"player")
	var manager: Node = player.get_node("SkillManager")
	_expect(String(ui.get("current_state")) == "RUNNING" and not paused, "build enters running state")
	_expect(not bool(root.get_meta("debug_control_mode", true)), "build enables automatic combat")
	_expect(not bool(root.get_meta("debug_manual_spawn_only", true)), "build enables normal waves")
	_expect(String(root.get_meta("debug_enemy_forced_state", "")) == "", "build clears forced enemy states from prior debugging")
	for entry: Dictionary in build:
		var skill: RefCounted = manager.call("get_skill", entry.skill_id)
		_expect(skill != null, "build grants " + entry.skill_id + " without progression prerequisites")
		if skill != null:
			_expect(int(skill.get("current_level")) == entry.level and String(skill.get("current_rarity")) == entry.rarity, "build applies level and rarity for " + entry.skill_id)
	_expect(manager.call("get_primary_attack_method") == null, "selected attack replaces character default")
	_expect(not manager.call("add_skill", &"frost_core_absolute_zero"), "ordinary learning still enforces prerequisites")
	if panel != null: _expect(not bool(panel.get("visible")), "build hides developer toolbar for playing")
	for frame: int in range(8): await physics_frame
	var spawner: Node = get_first_node_in_group(&"enemy_spawner")
	_expect(float(spawner.get("_elapsed_time")) > 0.0, "normal wave timeline advances after build start")
	# A bad build must be rejected before resetting the existing run.
	var generation: int = int(manager.get("run_generation"))
	ui.call("start_developer_debug_run", {"skill_build": [{"skill_id": "unknown_skill", "level": 1, "rarity": "normal"}], "play_build": true})
	await process_frame
	_expect(int(manager.get("run_generation")) == generation, "invalid build does not reset current run")
	for invalid: Array in [
		[{"skill_id": "fire_cast_meteor_rain", "level": 6, "rarity": "normal"}],
		[{"skill_id": "fire_cast_meteor_rain", "level": 1, "rarity": "invalid"}],
		[{"skill_id": "fire_cast_meteor_rain"}, {"skill_id": "fire_cast_meteor_rain"}],
		[{"skill_id": "fire_attack_searing"}, {"skill_id": "frost_attack_frost_shard"}],
		[{"skill_id": "fire_core_inferno_cycle"}, {"skill_id": "frost_core_absolute_zero"}],
		[{"skill_id": "fire_cast_meteor_rain"}, {"skill_id": "frost_cast_frost_field"}, {"skill_id": "thunder_cast_chain_lightning"}],
		[{"skill_id": "fire_passive_burning_focus"}, {"skill_id": "fire_passive_overheated_casting"}, {"skill_id": "fire_passive_scorched_ground_affinity"}, {"skill_id": "frost_passive_frozen_vulnerability"}],
		[{"skill_id": "fire_cast_meteor_rain"}, {"skill_id": "fire_cast_lava_rift"}, {"skill_id": "fire_cast_scorching_vortex"}, {"skill_id": "fire_summon_crimson_dragon"}, {"skill_id": "fire_summon_ember_fox_pack"}, {"skill_id": "fire_power_combustion_chain"}]
	]:
		var accepted: bool = await ui.call("start_developer_debug_run", {"skill_build": invalid, "play_build": true})
		_expect(not accepted and int(manager.get("run_generation")) == generation, "invalid level, rarity, duplicate or slot conflict preserves run")
	# An empty build resets prior skills and restores the character's primary attack.
	ui.call("start_developer_debug_run", {"character_id": "mage", "map_id": "abandoned_dungeon", "skill_build": [], "play_build": true})
	await _wait_for_run(ui)
	var primary: RefCounted = manager.call("get_primary_attack_method")
	_expect(primary != null and String(primary.get("skill_id")) == "fireball", "empty build restores default attack")
	_expect(not manager.call("has_skill", &"fire_core_inferno_cycle"), "next build clears prior skills")
	# Primary attacks can also have a custom level and rarity.
	await ui.call("start_developer_debug_run", {"character_id": "mage", "skill_build": [{"skill_id": "fireball", "level": 3, "rarity": "epic"}], "play_build": true})
	await _wait_for_run(ui)
	primary = manager.call("get_primary_attack_method")
	_expect(primary != null and int(primary.get("current_level")) == 3 and String(primary.get("current_rarity")) == "epic", "default attack accepts custom level and rarity")
	await ui.call("start_developer_debug_run", {"character_id": "mage", "skill_build": [{"skill_id": "fusion_fire_frost_steam_mist", "level": 1, "rarity": "legendary"}], "play_build": true})
	_expect(manager.call("has_skill", &"fusion_fire_frost_steam_mist"), "fusion can be granted without its progression prerequisites")
	await _wait_for_run(ui)
	for dash_build: Array in [
		[{"skill_id": "fire_dash_blazing_run", "level": 5, "rarity": "legendary"}],
		[{"skill_id": "frost_dash_ice_shard_assault", "level": 5, "rarity": "epic"}],
		[{"skill_id": "frost_cast_frost_field", "level": 5, "rarity": "epic"}, {"skill_id": "thunder_cast_chain_lightning", "level": 5, "rarity": "epic"}]
	]:
		var accepted: bool = await ui.call("start_developer_debug_run", {"character_id": "mage", "skill_build": dash_build, "play_build": true})
		_expect(accepted, "starting loadout must not conflict with selected dash or consume a third school")
		await _wait_for_run(ui)
		_expect(manager.call("get_all_skills").size() == dash_build.size(), "build owns exactly its selected non-primary skills")
		for entry: Dictionary in dash_build:
			var owned: RefCounted = manager.call("get_skill", entry.skill_id)
			_expect(owned != null and int(owned.get("current_level")) == entry.level and String(owned.get("current_rarity")) == entry.rarity, "dash and two-school build entries are applied")
	var full_build: Array[Dictionary] = []
	for id: String in ["frost_attack_frostbite", "frost_dash_ice_shard_assault", "frost_cast_frost_field", "frost_cast_glacial_lance", "frost_cast_blizzard_cloud", "frost_passive_frozen_vulnerability", "frost_summon_frost_wolf", "frost_summon_ice_crystal_guard", "frost_passive_chill_extension", "frost_core_absolute_zero", "fusion_frost_fire_frostburn_shards", "fire_passive_overheated_casting"]:
		full_build.append({"skill_id": id, "level": int(GameData.get_skill(id).max_level), "rarity": "legendary"})
	var full_accepted: bool = await ui.call("start_developer_debug_run", {"character_id": "mage", "skill_build": full_build, "play_build": true})
	_expect(full_accepted, "user's full frost/fire mage build starts successfully")
	await _wait_for_run(ui)
	_expect(manager.call("get_all_skills").size() == 12, "full build occupies exactly all 12 selected slots")
	for entry: Dictionary in full_build:
		var owned: RefCounted = manager.call("get_skill", entry.skill_id)
		_expect(owned != null and int(owned.get("current_level")) == entry.level and String(owned.get("current_rarity")) == entry.rarity, "full build applies " + entry.skill_id)
	# Unexpected runtime rejection reports the offending skill instead of a generic slot error.
	manager.set("max_active_skills", 0)
	var rejected: bool = await ui.call("start_developer_debug_run", {"character_id": "mage", "skill_build": [{"skill_id": "fire_cast_meteor_rain"}], "play_build": true})
	_expect(not rejected and String(ui.get("last_developer_run_error")).contains(String(GameData.get_skill(&"fire_cast_meteor_rain").display_name)), "application failure identifies the rejected skill")
	manager.set("max_active_skills", 5)
	root.set_meta("developer_mode_enabled", false)
	_expect(not manager.call("add_developer_skill", &"fire_core_inferno_cycle"), "developer grant is unavailable in ordinary mode")
	ui.call("_teardown_run_scene")
	app.queue_free()
	if panel != null and is_instance_valid(panel): panel.queue_free()
	await process_frame
	await process_frame
	# The full UI flow was verified above; check the inventory on an isolated player.
	root.set_meta("developer_mode_enabled", true)
	var inventory_player: Node = PLAYER.instantiate()
	root.add_child(inventory_player)
	await _verify_build_inventory(inventory_player, inventory_player.get_node("SkillManager"))
	inventory_player.queue_free()
	await process_frame
	if not _failed: print("[verify_developer_skill_build] PASS")
	quit(1 if _failed else 0)

func _verify_build_inventory(player: Node, manager: Node) -> void:
	var cases := 0
	root.set_meta("debug_control_mode", true)
	root.set_meta("debug_manual_spawn_only", true)
	for character: Dictionary in GameData.get_character_pool():
		var loadout: RefCounted = Loadouts.build_loadout(character.id)
		player.call("reset_for_loadout", loadout)
		for data: Dictionary in GameData.get_all_skill_pool():
			if not Build.is_selectable(data, character): continue
			var errors: Array[String] = []
			var accepted: bool = Build.apply(player, [{"skill_id": String(data.id), "level": int(data.max_level), "rarity": "legendary"}], errors)
			_expect(accepted, "%s can apply selectable skill %s: %s" % [character.id, data.id, errors])
			var owned: RefCounted = manager.call("get_primary_attack_method") if bool(data.get("is_starting_skill", false)) else manager.call("get_skill", data.id)
			_expect(owned != null and int(owned.get("current_level")) == int(data.max_level) and String(owned.get("current_rarity")) == "legendary", "inventory entry retains requested growth: " + String(data.id))
			cases += 1
			# Flush deferred UI/runtime cleanup between independent builds.
			await process_frame
	print("[verify_developer_skill_build] inventory cases=%d" % cases)

func _has_option(picker: OptionButton, id: String) -> bool:
	for index: int in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == id: return true
	return false

func _select_skill(picker: OptionButton, id: String) -> void:
	for index: int in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == id:
			picker.select(index)
			return
	_expect(false, "skill picker includes " + id)

func _capture(label: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir=") and DisplayServer.get_name() != "headless":
			var directory: String = argument.trim_prefix("--capture-dir=")
			if not directory.to_lower().begins_with("e:/codex/"): return
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _wait_for_run(ui: Node) -> void:
	for frame: int in range(240):
		await process_frame
		if not bool(ui.get("_run_loading_active")): break
	await process_frame
	await process_frame

func _expect(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error("[verify_developer_skill_build] FAIL " + message)
