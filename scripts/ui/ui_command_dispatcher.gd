extends RefCounted
class_name UICommandDispatcher


const COMMAND_APPLY_CHOICE_OPTION: StringName = &"apply_choice_option"
const COMMAND_PURCHASE_META_UPGRADE: StringName = &"purchase_meta_upgrade"
const COMMAND_PURCHASE_CHARACTER: StringName = &"purchase_character"
const COMMAND_ADD_SOUL_STONES: StringName = &"add_soul_stones"
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")


func dispatch(command: Variant, context: Dictionary = {}) -> Dictionary:
	var command_data: Dictionary = _command_to_dictionary(command)
	var command_type: StringName = StringName(String(command_data.get("type", "")))
	match command_type:
		COMMAND_APPLY_CHOICE_OPTION:
			return _apply_choice_option(_get_dictionary(command_data.get("option", {})), context)
		COMMAND_PURCHASE_META_UPGRADE:
			return _purchase_meta_upgrade(StringName(String(command_data.get("upgrade_id", ""))))
		COMMAND_PURCHASE_CHARACTER:
			return _purchase_character(StringName(String(command_data.get("character_id", ""))))
		COMMAND_ADD_SOUL_STONES:
			return _add_soul_stones(int(command_data.get("amount", 0)))
		_:
			push_warning("Unknown UI command: %s" % String(command_type))
			return {"handled": false}


func _apply_choice_option(option: Dictionary, context: Dictionary) -> Dictionary:
	var player: Node = context.get("player", null) as Node
	var tree: SceneTree = context.get("tree", null) as SceneTree
	var payload: Dictionary = _get_dictionary(option.get("payload", {}))
	if payload.has("reward_kind"):
		_apply_run_reward_option(option, payload, player, tree)
		return {
			"handled": true,
			"consumed_reward": true,
			"reward_kind": String(payload.get("reward_kind", "elite"))
		}

	var upgrade_id: StringName = StringName(String(option.get("id", "")))
	if player != null and player.has_method("apply_upgrade") and upgrade_id != &"":
		player.call(&"apply_upgrade", upgrade_id)
		return {"handled": true, "applied_upgrade_id": upgrade_id}
	return {"handled": false}


func _apply_run_reward_option(option: Dictionary, payload: Dictionary, player: Node, tree: SceneTree) -> void:
	if player == null:
		return

	if payload.has("amount"):
		var amount: int = int(payload.get("amount", 0))
		match String(option.get("id", "")):
			"reward_soul_stones":
				SaveManager.add_soul_stones(amount)
			_:
				if player.has_method("add_experience"):
					player.call("add_experience", amount)

	if payload.has("heal_percent"):
		_apply_healing_reward(payload, player, tree)

	var relic_id: StringName = StringName(String(payload.get("relic_id", "")))
	if relic_id != &"":
		_apply_relic_reward(relic_id, player, tree)

	var upgrade_id: StringName = StringName(String(payload.get("upgrade_id", "")))
	if upgrade_id != &"" and player.has_method("apply_upgrade"):
		player.call("apply_upgrade", StringName("level_up_upgrade:%s" % String(upgrade_id)))
	elif player.has_method("apply_upgrade"):
		var option_id: String = String(option.get("id", ""))
		if option_id.begins_with("level_up_upgrade:") or option_id.begins_with("branch_choice:") or option_id.begins_with("skill_level_up:"):
			player.call("apply_upgrade", StringName(option_id))

	var tracker: Node = RunStatsTrackerScript.get_active(tree)
	if tracker != null and tracker.has_method("record_reward_taken"):
		tracker.call("record_reward_taken", String(payload.get("reward_kind", "elite")))


func _apply_healing_reward(payload: Dictionary, player: Node, tree: SceneTree) -> void:
	var max_health: int = int(player.get("max_health"))
	var heal_amount: int = maxi(roundi(float(max_health) * float(payload.get("heal_percent", 0.0))), 0)
	if heal_amount <= 0:
		return
	var current_health: int = mini(int(player.get("current_health")) + heal_amount, max_health)
	player.set("current_health", current_health)
	if player.has_signal("health_changed"):
		player.emit_signal("health_changed", current_health, max_health)
	var tracker: Node = RunStatsTrackerScript.get_active(tree)
	if tracker != null and tracker.has_method("record_healing"):
		tracker.call("record_healing", heal_amount)


func _apply_relic_reward(relic_id: StringName, player: Node, tree: SceneTree) -> void:
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	if relic_manager == null or not relic_manager.has_method("add_relic"):
		return
	if not bool(relic_manager.call("add_relic", relic_id)):
		return
	var tracker: Node = RunStatsTrackerScript.get_active(tree)
	if tracker != null and tracker.has_method("record_relic_gained"):
		tracker.call("record_relic_gained", relic_id)


func _purchase_meta_upgrade(upgrade_id: StringName) -> Dictionary:
	if upgrade_id == &"":
		return {"handled": false, "purchased": false}
	var purchased: bool = SaveManager.purchase_permanent_upgrade(upgrade_id)
	return {
		"handled": true,
		"purchased": purchased,
		"upgrade_id": upgrade_id
	}


func _purchase_character(character_id: StringName) -> Dictionary:
	if character_id == &"":
		return {"handled": false, "purchased": false}
	var purchased: bool = SaveManager.purchase_character(character_id)
	return {
		"handled": true,
		"purchased": purchased,
		"character_id": character_id
	}


func _add_soul_stones(amount: int) -> Dictionary:
	if amount <= 0:
		return {"handled": false, "added": 0, "total": SaveManager.get_soul_stones()}
	var total: int = SaveManager.add_soul_stones(amount)
	return {
		"handled": true,
		"added": amount,
		"total": total
	}


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _command_to_dictionary(command: Variant) -> Dictionary:
	if command is Dictionary:
		return _get_dictionary(command)
	if command is RefCounted and command.has_method("to_dictionary"):
		var command_data: Variant = command.call("to_dictionary")
		return _get_dictionary(command_data)
	return {}
