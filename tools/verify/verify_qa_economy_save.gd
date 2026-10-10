## Regression for R2-01/08/09; run only through run_isolated_godot.ps1.
extends SceneTree

const Validator = preload("res://scripts/core/content_config_validator.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	if not ProjectSettings.globalize_path(SaveManager.SAVE_PATH).replace("\\", "/").begins_with("E:/codex/"):
		print("FAIL save must be isolated on E:/codex")
		quit(1)
		return
	SaveManager.reset_progress()
	for upgrade: Dictionary in GameData.get_permanent_upgrade_pool():
		var id := StringName(upgrade.id)
		SaveManager.reset_progress()
		check(SaveManager.get_permanent_upgrade_cost(id) > 0, "%s has a positive explicit price" % id)
		check(not SaveManager.purchase_permanent_upgrade(id), "%s zero balance rejects purchase" % id)
		check(SaveManager.get_permanent_upgrade_level(id) == 0, "%s rejected purchase preserves level" % id)
	var owner: Node = root.get_node("DataManager")
	var original: Array = owner.get("_permanent_upgrade_pool").duplicate(true)
	# Hand-calculated prices: 100, 150, 225; a three-level fixture exercises the real persistence API.
	var price_fixture: Array[Dictionary] = [{"id": "qa_price", "max_level": 3, "cost_base": 100, "cost_growth": 1.5}]
	owner.set("_permanent_upgrade_pool", price_fixture)
	check(not GameData.get_permanent_upgrade(&"qa_price").is_empty(), "price fixture published to runtime owner")
	SaveManager.reset_progress()
	SaveManager.add_soul_stones(99)
	check(not SaveManager.purchase_permanent_upgrade(&"qa_price"), "insufficient 99 rejects 100 price")
	check(SaveManager.get_soul_stones() == 99 and SaveManager.get_permanent_upgrade_level(&"qa_price") == 0, "insufficient funds leave both fields unchanged")
	SaveManager.add_soul_stones(1)
	check(SaveManager.purchase_permanent_upgrade(&"qa_price"), "exact balance purchases level one")
	check(SaveManager.get_soul_stones() == 0 and SaveManager.get_permanent_upgrade_level(&"qa_price") == 1, "one transaction pays 100 and gains one level")
	check(SaveManager.get_permanent_upgrade_cost(&"qa_price") == 150, "next level uses growth price 150")
	SaveManager.add_soul_stones(375)
	check(SaveManager.purchase_permanent_upgrade(&"qa_price") and SaveManager.get_soul_stones() == 225, "second purchase pays 150")
	check(SaveManager.get_permanent_upgrade_cost(&"qa_price") == 225, "third level costs 225")
	check(SaveManager.purchase_permanent_upgrade(&"qa_price") and SaveManager.get_soul_stones() == 0, "third purchase pays exact 225")
	SaveManager.add_soul_stones(1000)
	check(not SaveManager.purchase_permanent_upgrade(&"qa_price") and SaveManager.get_permanent_upgrade_level(&"qa_price") == 3 and SaveManager.get_soul_stones() == 1000, "max level blocks further charge and level gain")
	for invalid: Dictionary in [{"max_level": 1}, {"max_level": 1,"cost_base": 100}, {"max_level": 1,"cost_growth": 1}, {"max_level": 1,"cost_base": 0,"cost_growth": 1}, {"max_level": 1,"cost_base": -1,"cost_growth": 1}, {"max_level": 1,"cost_base": "100","cost_growth": 1}, {"max_level": 1,"cost_base": 100,"cost_growth": 0}, {"max_level": 1,"cost_base": 100,"cost_growth": 0.5}, {"max_level": 1,"cost_base": INF,"cost_growth": 1}]:
		SaveManager.reset_progress()
		SaveManager.add_soul_stones(1000)
		invalid["id"] = "qa_invalid"
		var invalid_fixture: Array[Dictionary] = [invalid]
		owner.set("_permanent_upgrade_pool", invalid_fixture)
		check(not SaveManager.purchase_permanent_upgrade(&"qa_invalid"), "invalid pricing rejects purchase " + str(invalid))
	owner.set("_permanent_upgrade_pool", original)
	verify_schema()
	verify_save_faults()
	verify_character_transaction()
	SaveManager.reset_progress()
	print("[qa_economy_save] failures=", failures)
	quit(1 if failures else 0)

func verify_schema() -> void:
	var loaded: Dictionary = Validator.load_sources()
	for field: String in ["cost_base", "cost_growth"]:
		var documents: Dictionary = loaded.documents.duplicate(true)
		documents["res://data/upgrades/upgrades.json"].permanent_upgrades[0].erase(field)
		check(not Validator.validate_documents(documents, loaded.schema).is_empty(), "runtime schema rejects missing " + field)
		for value: Variant in [0, 0.5, -1, "100", INF]:
			documents = loaded.documents.duplicate(true)
			documents["res://data/upgrades/upgrades.json"].permanent_upgrades[0][field] = value
			check(not Validator.validate_documents(documents, loaded.schema).is_empty(), "runtime schema rejects invalid %s=%s" % [field, value])

func verify_save_faults() -> void:
	SaveManager.reset_progress()
	SaveManager.add_soul_stones(123)
	SaveManager.save_value("permanent_upgrades", "meta_health", 2)
	SaveManager.save_value("custom", "untouched", "preserve me")
	SaveManager.set_master_volume_percent(55)
	check(SaveManager.get_soul_stones() == 123 and SaveManager.get_permanent_upgrade_level(&"meta_health") == 2 and SaveManager.load_value("custom", "untouched") == "preserve me", "ordinary settings update preserves progress and unknown sections")
	var before: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("corrupted=???\n" + before)
	file.close()
	before = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	# The parser error is deliberate negative input. Restore the engine setting immediately.
	var print_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var saver := SaveManager.new()
	check(saver.call("save_value", "settings", "master_volume", 30) == false, "corrupt save write reports failure")
	check(not SaveManager.purchase_permanent_upgrade(&"meta_health"), "corrupt save purchase reports failure")
	check(SaveManager.add_soul_stones(5) == -1, "corrupt save reward reports failure")
	check(not SaveManager.mark_map_cleared(&"qa_map"), "corrupt save progress reports failure")
	check(SaveManager.increment_counter(&"total_runs") == -1 and SaveManager.set_counter_max(&"max_kills", 10) == -1, "corrupt save counters report failure")
	check(SaveManager.increment_character_specialization(&"mage", &"kills") == -1, "corrupt save specialization reports failure")
	check(not SaveManager.mark_map_challenge_completed(&"qa_map", &"qa_goal") and not SaveManager.mark_challenge_completed(&"qa_goal"), "corrupt save challenges report failure")
	check(saver.call("save_last_run_summary", {"kill_count": 1}) == false and saver.call("set_unlocked", "achievement", &"qa_goal") == false, "corrupt save summary and unlock report failure")
	check(saver.call("set_master_volume_percent", 40) == false and saver.call("set_fullscreen_enabled", true) == false and saver.call("set_language_id", "en") == false, "corrupt save settings report failure")
	Engine.print_error_messages = print_errors
	saver.free()
	check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == before, "corrupt save remains byte-for-byte unchanged")
	SaveManager.reset_progress()
	SaveManager.add_soul_stones(1000)
	SaveManager.save_value("permanent_upgrades", "meta_health", 2)
	before = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var temporary_path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH + ".tmp")
	DirAccess.make_dir_absolute(temporary_path)
	print_errors = Engine.print_error_messages
	Engine.print_error_messages = false
	check(not SaveManager.purchase_permanent_upgrade(&"meta_health"), "failed temporary save reports purchase failure")
	check(not SaveManager.spend_soul_stones(20), "failed temporary save reports payment failure")
	check(SaveManager.add_soul_stones(5) == -1, "failed temporary save reports reward failure")
	saver = SaveManager.new()
	check(saver.call("reset_progress") == false, "failed temporary save reports reset failure")
	saver.free()
	Engine.print_error_messages = print_errors
	check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == before, "failed purchase preserves both money and level in previous file")
	DirAccess.remove_absolute(temporary_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	saver = SaveManager.new()
	check(saver.call("save_value", "settings", "master_volume", 40) == true and SaveManager.get_master_volume_percent() == 40.0, "missing file creates a valid new save")
	saver.free()

func verify_character_transaction() -> void:
	var owner: Node = root.get_node("DataManager")
	var original: Dictionary = owner.get("_character_definitions").duplicate(true)
	owner.set("_character_definitions", {&"qa_character": {"id": "qa_character", "unlock": {"type": "soul_cost", "cost": 100}}})
	check(not GameData.get_character(&"qa_character").is_empty(), "character purchase fixture reaches runtime owner")
	SaveManager.reset_progress()
	SaveManager.add_soul_stones(100)
	var before: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var temporary_path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH + ".tmp")
	DirAccess.make_dir_absolute(temporary_path)
	var print_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	check(not SaveManager.purchase_character(&"qa_character"), "failed character transaction reports failure")
	Engine.print_error_messages = print_errors
	check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == before and not SaveManager.is_character_unlocked(&"qa_character"), "failed character transaction preserves balance and locked status")
	DirAccess.remove_absolute(temporary_path)
	SaveManager.reset_progress()
	SaveManager.add_soul_stones(100)
	check(SaveManager.purchase_character(&"qa_character") and SaveManager.get_soul_stones() == 0 and SaveManager.is_character_unlocked(&"qa_character"), "successful character transaction charges exact balance and unlocks together")
	owner.set("_character_definitions", original)
