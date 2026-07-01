extends SceneTree


const RunChoiceModalControllerScript: Script = preload("res://scripts/ui/modals/run_choice_modal_controller.gd")
const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const UpgradePoolScript: Script = preload("res://scripts/upgrades/upgrade_pool.gd")


class TestPlayer:
	extends Node

	func set_run_modifier_source(_source_id: Variant, _modifiers: Variant) -> void:
		pass

	func clear_run_modifier_source(_source_id: Variant) -> void:
		pass


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := TestPlayer.new()
	root.add_child(player)
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	_expect(bool(skill_manager.call("add_skill", &"fire_attack_searing", "normal")), "learns normal searing attack")

	var pool: RefCounted = UpgradePoolScript.new()
	var option: RefCounted = _find_level_option(pool.call("_build_skill_level_up_options", player), &"fire_attack_searing")
	_expect(option != null, "creates searing level-up option")
	if option != null:
		option.set("rarity", "rare")
		option.set("description", "")
		var payload: Dictionary = option.get("payload")
		payload["current_rarity"] = "normal"
		payload["target_rarity"] = "rare"
		option.set("payload", payload)
		var controller: RefCounted = RunChoiceModalControllerScript.new()
		var option_dictionary: Dictionary = option.call("to_dictionary")
		var meta_text: String = String(controller.call("_get_option_meta_text", option_dictionary))
		var effect_text: String = String(controller.call("_get_option_effect_text", option_dictionary))
		_expect(meta_text == "稀有", "meta text shows only the localized card rarity", meta_text)
		_expect(not meta_text.contains("当前") and not meta_text.contains("normal"), "meta text omits extra rarity words", meta_text)
		_expect(effect_text.contains("27%"), "effect text shows scaled Lv2 rare attack damage", effect_text)

	player.queue_free()
	await process_frame
	if not _failed:
		print("[verify_skill_card_scaled_values_and_rarity] PASS")
	quit(1 if _failed else 0)


func _find_level_option(options: Array, skill_id: StringName) -> RefCounted:
	for option_variant: Variant in options:
		var option: RefCounted = option_variant as RefCounted
		if option != null and String(option.get("id")).begins_with("skill_level_up:%s:" % String(skill_id)):
			return option
	return null


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_card_scaled_values_and_rarity] FAIL %s actual=%s" % [label, str(actual)])
