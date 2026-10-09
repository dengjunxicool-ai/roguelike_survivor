extends SceneTree

const Policy: Script = preload("res://scripts/skills/skill_learning_policy.gd")
const Builder: Script = preload("res://scripts/upgrades/upgrade_option_builder.gd")
const Manager: Script = preload("res://scripts/skills/skill_manager.gd")
const Pool: Script = preload("res://scripts/upgrades/upgrade_pool.gd")
const Scaling: Script = preload("res://scripts/skills/skill_growth_scaling.gd")
var failed: bool = false

class Player:
	extends Node
	var current_health: int = 100
	var max_health: int = 100
	func set_run_modifier_source(_id: Variant, _value: Variant) -> void:
		pass
	func clear_run_modifier_source(_id: Variant) -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var learned: Array[StringName] = [&"fire", &"frost"]
	_expect(not Policy.can_learn_god_school({"skill_type": "cast", "school": "thunder"}, learned, 2), "two schools block a third school")
	_expect(Policy.can_learn_god_school({"skill_type": "cast", "school": "fire"}, learned, 2), "existing school stays learnable at cap")
	_expect(Policy.can_learn_god_school({"skill_type": "fusion"}, learned, 2), "fusion unlocks at school threshold")
	var one_school: Array[StringName] = [&"fire"]
	_expect(not Policy.can_learn_god_school({"skill_type": "fusion"}, one_school, 2), "fusion stays locked before school threshold")
	_expect(Policy.can_current_character_learn({"id": "pool", "offer_rule": {"required_schools": ["fire"]}}, &"mage", {}), "offer-rule skills bypass character starting restrictions")
	_expect(not Policy.can_current_character_learn({"id": "foreign"}, &"mage", {"starting_skill_id": "fireball"}), "foreign unlisted starting skill is rejected")
	_expect(Policy.can_current_character_learn({"id": "fireball"}, &"mage", {"starting_skill_id": "fireball"}), "character starting skill remains eligible")
	var upgrade: Dictionary = {"id": "guard", "display_name": "Guard", "max_level": 3, "tags": ["survival"], "level_descriptions": ["first", "second"], "rarity": "rare"}
	var original: Dictionary = upgrade.duplicate(true)
	var data: Dictionary = Builder.build_upgrade_data(upgrade, 1, 7.5, "recommended")
	_expect(data.id == "level_up_upgrade:guard" and data.level_text == "Lv2 / 3", "regular card keeps stable ID and progression text")
	_expect(data.payload.weight == 7.5 and data.description == "first" and data.recommended_reason == "recommended", "regular card preserves weight and first description")
	var debug: Dictionary = Builder.build_debug_data(upgrade, 1, &"holy")
	_expect(debug.description == "second" and debug.payload.debug_god_id == &"holy", "debug card selects current-level description and school context")
	_expect(upgrade == original, "pure card builders preserve their input")
	_verify_rng_and_order()
	print("[verify_learning_option_policies] failed=%s" % failed)
	quit(1 if failed else 0)

func _verify_rng_and_order() -> void:
	var player := Player.new()
	root.add_child(player)
	var manager: Node = Manager.new()
	manager.name = "SkillManager"
	player.add_child(manager)
	_expect(manager.add_skill("fire_cast_meteor_rain"), "first ordered skill is learned")
	_expect(manager.add_skill("frost_cast_frost_field"), "second ordered skill is learned")
	var pool: RefCounted = Pool.new()
	var rng: RandomNumberGenerator = pool.get("_rng")
	rng.seed = 618
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 618
	var expected_rarities: Array[String] = []
	for skill_id: StringName in [&"fire_cast_meteor_rain", &"frost_cast_frost_field"]:
		expected_rarities.append(String(manager.get_skill(skill_id).current_rarity))
	var options: Array = pool._build_skill_level_up_options(player)
	_expect(options.size() == 2, "both level-up cards are built")
	if options.size() == 2:
		_expect(String(options[0].id).begins_with("skill_level_up:fire_cast_meteor_rain:2:") and String(options[1].id).begins_with("skill_level_up:frost_cast_frost_field:2:"), "owned skill insertion order is preserved")
		_expect(options[0].rarity == expected_rarities[0] and options[1].rarity == expected_rarities[1], "upgrade cards preserve owned quality in insertion order")
	_expect(rng.state == expected_rng.state, "pure construction consumes no extra random draws")
	var state_before: int = rng.state
	pool._build_level_up_upgrade_options(player)
	_expect(rng.state == state_before, "regular card construction consumes no random draws")
	player.free()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("[verify_learning_option_policies] FAIL " + label)
