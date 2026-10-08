extends SceneTree

const Validator := preload("res://scripts/core/content_config_validator.gd")
const Facade := preload("res://scripts/game/game_data.gd")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var loaded := Validator.load_sources()
	_expect(loaded.errors.is_empty(), "all schema sources readable")
	var documents: Dictionary = loaded.documents
	var schema: Dictionary = loaded.schema
	_expect(Validator.validate_documents(documents, schema).is_empty(), "all canonical content valid")
	var invalid := documents.duplicate(true)
	invalid["res://data/skills/skills.json"].skills[0]["type"] = "attack"
	_expect(_contains(Validator.validate_documents(invalid, schema), "unknown definition field"), "old skill fields rejected")
	invalid = documents.duplicate(true)
	invalid["res://data/enemies/enemies.json"].monsters[0].base_stats.max_hp = -1
	_expect(_contains(Validator.validate_documents(invalid, schema), "negative max_hp"), "invalid numeric range rejected")
	invalid = documents.duplicate(true)
	invalid["res://data/skills/skills.json"].skills.append(invalid["res://data/skills/skills.json"].skills[0].duplicate(true))
	_expect(_contains(Validator.validate_documents(invalid, schema), "duplicate ID"), "duplicate skill ID rejected")
	invalid = documents.duplicate(true)
	invalid["res://data/characters/characters.json"].characters[0].starting_skill_id = "missing"
	_expect(_contains(Validator.validate_documents(invalid, schema), "unknown skills reference"), "dangling skill reference rejected")
	invalid = documents.duplicate(true)
	invalid["res://data/skills/skills.json"].skills[0].max_level = "five"
	_expect(_contains(Validator.validate_documents(invalid, schema), "invalid type"), "wrong field type rejected")
	invalid = documents.duplicate(true)
	invalid["res://data/skills/skills.json"].skills[0].runtime_rules = []
	_expect(not Validator.validate_documents(invalid, schema).is_empty(), "runtime_rules must be an object")
	var invalid_number := documents.duplicate(true)
	invalid_number["res://data/enemies/enemies.json"].monsters[0].base_stats.max_hp = "broken-number"
	_expect(not Validator.validate_documents(invalid_number, schema).is_empty(), "nested base stats require numbers")
	invalid_number = documents.duplicate(true)
	invalid_number["res://data/enemies/enemies.json"].monsters[0].base_stats.erase("contact_interval")
	_expect(not Validator.validate_documents(invalid_number, schema).is_empty(), "mandatory nested fields required")
	var invalid_effect := documents.duplicate(true)
	invalid_effect["res://data/relics/relics.json"].relics[0].modifiers[0].stat = 42
	invalid_effect["res://data/relics/relics.json"].relics[0].modifiers[0].source = ""
	_expect(not Validator.validate_documents(invalid_effect, schema).is_empty(), "Modifier stat and source require nonempty strings")
	var invalid_reference := documents.duplicate(true)
	invalid_reference["res://data/waves/waves.json"].waves[0].groups[0].enemy_ids = ["missing_enemy"]
	_expect(not Validator.validate_documents(invalid_reference, schema).is_empty(), "wave enemy references validated")
	invalid_reference = documents.duplicate(true)
	invalid_reference["res://data/skills/skills.json"].skills[0].school = "missing_god"
	_expect(not Validator.validate_documents(invalid_reference, schema).is_empty(), "skill school references validated")
	invalid_reference = documents.duplicate(true)
	invalid_reference["res://data/summons/summons.json"].summons[0].scene_path = "not-a-real-scene.tscn"
	_expect(not Validator.validate_documents(invalid_reference, schema).is_empty(), "malformed resource paths rejected")
	var owner: Node = root.get_node("DataManager")
	_expect(owner.get("is_loaded") == true, "owner publishes only validated content")
	if not owner.has_method("replace_documents"):
		_expect(false, "owner provides atomic replacement")
		quit(1)
		return
	var original: Array = owner.get_skill_definitions()
	var errors: Array = owner.replace_documents(invalid)
	_expect(not errors.is_empty(), "invalid replacement rejected")
	_expect(owner.get_skill_definitions() == original and owner.is_loaded, "invalid replacement preserves previous snapshot")
	_expect(owner.replace_documents(documents).is_empty(), "valid replacement accepted")
	var wave_before: Dictionary = owner.get_wave_config()
	var goals_before: Dictionary = owner.get_progression_goals()
	documents["res://data/waves/waves.json"].run["__mutated"] = true
	documents["res://data/progression/progression_goals.json"]["__mutated"] = true
	_expect(owner.get_wave_config() == wave_before and owner.get_progression_goals() == goals_before, "published documents detached from caller")
	var starting_before: Array = owner.get_starting_skill_definitions()
	documents["res://data/skills/skills.json"].starting_skills[0].base["__mutated"] = true
	_expect(owner.get_starting_skill_definitions() == starting_before, "ordered pool storage detached from caller")
	var gods := Facade.get_god_pool()
	var summons := Facade.get_summon_pool()
	_expect(not gods.is_empty() and not summons.is_empty(), "gods and summons use same owner")
	var id := StringName(summons[0].id)
	summons[0].movement["__mutated"] = true
	_expect(not Facade.get_summon(id).movement.has("__mutated"), "summon results deeply isolated")
	var status_snapshot: Dictionary = owner.get("_status_definitions")
	owner.set("_status_definitions", {})
	_expect(Facade.get_status_pool().is_empty() and Facade.get_status(&"burning").is_empty(), "empty owner is authoritative")
	owner.set("_status_definitions", status_snapshot)
	if not failed:
		print("[verify_content_owner_contract] PASS")
	quit(1 if failed else 0)

func _contains(errors: Array[String], phrase: String) -> bool:
	for error: String in errors:
		if error.contains(phrase): return true
	return false

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("[verify_content_owner_contract] FAIL " + label)
