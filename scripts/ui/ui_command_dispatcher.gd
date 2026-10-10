## 文件用途：把界面命令路由到升级、奖励、遗物和存档服务。
## 使用方式：dispatch 接收命令及玩家/树上下文，返回 handled 等结果字段供页面更新。

extends RefCounted
class_name UICommandDispatcher


const COMMAND_APPLY_CHOICE_OPTION: StringName = &"apply_choice_option"
const COMMAND_PURCHASE_META_UPGRADE: StringName = &"purchase_meta_upgrade"
const COMMAND_PURCHASE_CHARACTER: StringName = &"purchase_character"
const COMMAND_ADD_SOUL_STONES: StringName = &"add_soul_stones"
const RunStatsTrackerScript: Script = preload("res://scripts/game/run_stats_tracker.gd")


## 作用：解析命令类型并分派局内选项、永久升级购买、角色购买或货币操作。
## 使用：command 可为字典或有 to_dictionary 的对象；context 提供 player/tree，返回 handled 等执行结果。
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


## 作用：根据 payload 区分局内奖励与普通升级并执行对应入口。
## 使用：option/context 来自 dispatch；返回处理结果和升级 ID 或已消费奖励信息。
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
		var parts: PackedStringArray = String(upgrade_id).split(":")
		if parts.size() >= 2 and parts[0] == "level_up_upgrade":
			var definition: Dictionary = preload("res://scripts/upgrades/skill_learn_definition_repository.gd").resolve_upgrade(StringName(parts[1]))
			var manager: Node = player.get_node_or_null("SkillManager")
			var data: Dictionary = GameData.get_skill(definition.get("learn_skill_id", ""))
			if manager != null and manager.is_active_skill_full() and not data.is_empty() and preload("res://scripts/skills/skill_slot_policy.gd").counts_active_capacity(data):
				var service: RefCounted = preload("res://scripts/skills/skill_replacement_service.gd").new()
				var tx: Dictionary = service.begin(player, StringName(String(data.id)), parts[2] if parts.size() > 2 else "normal")
				if tx.is_empty(): return {"handled": false}
				return {"handled": true, "replacement_pending": true, "transaction": tx, "service": service, "applied_upgrade_id": upgrade_id}
		player.call(&"apply_upgrade", upgrade_id)
		return {"handled": true, "applied_upgrade_id": upgrade_id}
	return {"handled": false}


## 作用：按 payload 依次应用货币/经验、治疗、遗物和升级奖励并记录统计。
## 使用：player 有效后执行；reward_kind 提供事件来源，升级经 Player.apply_upgrade；可能写入 user:// 存档。
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

	var option_id: String = String(option.get("id", ""))
	if player.has_method("apply_upgrade") and (option_id.begins_with("level_up_upgrade:") or option_id.begins_with("skill_level_up:")):
		player.call("apply_upgrade", StringName(option_id))
	else:
		var upgrade_id: StringName = StringName(String(payload.get("upgrade_id", "")))
		if upgrade_id != &"" and player.has_method("apply_upgrade"):
			player.call("apply_upgrade", StringName("level_up_upgrade:%s" % String(upgrade_id)))

	var tracker: Node = RunStatsTrackerScript.get_active(tree)
	if tracker != null and tracker.has_method("record_reward_taken"):
		tracker.call("record_reward_taken", String(payload.get("reward_kind", "elite")))


## 作用：按玩家生命上限和治疗比例回复血量并记录治疗。
## 使用：payload.heal_percent 为比例；不超过上限，生效后发 health_changed。
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


## 作用：经玩家 RelicManager 添加遗物，成功后记录获取事件。
## 使用：relic_id 为配置 ID；缺管理器或添加失败时不统计。
func _apply_relic_reward(relic_id: StringName, player: Node, tree: SceneTree) -> void:
	var relic_manager: Node = player.get_node_or_null("RelicManager")
	if relic_manager == null or not relic_manager.has_method("add_relic"):
		return
	if not bool(relic_manager.call("add_relic", relic_id)):
		return
	var tracker: Node = RunStatsTrackerScript.get_active(tree)
	if tracker != null and tracker.has_method("record_relic_gained"):
		tracker.call("record_relic_gained", relic_id)


## 作用：购买局外升级。
## 使用：本文件由 dispatch 调用；输入 upgrade_id（升级ID）；可能写入 user:// 存档；返回字典包含 handled/purchased/upgrade_id。
func _purchase_meta_upgrade(upgrade_id: StringName) -> Dictionary:
	if upgrade_id == &"":
		return {"handled": false, "purchased": false}
	var purchased: bool = SaveManager.purchase_permanent_upgrade(upgrade_id)
	return {
		"handled": true,
		"purchased": purchased,
		"upgrade_id": upgrade_id
	}


## 作用：购买角色。
## 使用：本文件由 dispatch 调用；输入 character_id（角色ID）；可能写入 user:// 存档；返回字典包含 handled/purchased/character_id。
func _purchase_character(character_id: StringName) -> Dictionary:
	if character_id == &"":
		return {"handled": false, "purchased": false}
	var purchased: bool = SaveManager.purchase_character(character_id)
	return {
		"handled": true,
		"purchased": purchased,
		"character_id": character_id
	}


## 作用：添加灵魂石。
## 使用：本文件由 dispatch 调用；输入 amount（数量）；可能写入 user:// 存档；返回字典包含 handled/added/total。
func _add_soul_stones(amount: int) -> Dictionary:
	if amount <= 0:
		return {"handled": false, "added": 0, "total": SaveManager.get_soul_stones()}
	var total: int = SaveManager.add_soul_stones(amount)
	return {
		"handled": true,
		"added": amount,
		"total": total
	}


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 dispatch、_apply_choice_option、_command_to_dictionary 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 作用：命令转换字典；具体处理委托给 command.to_dictionary。
## 使用：本文件由 dispatch 调用；输入 command（命令）；返回结果字典。
func _command_to_dictionary(command: Variant) -> Dictionary:
	if command is Dictionary:
		return _get_dictionary(command)
	if command is RefCounted and command.has_method("to_dictionary"):
		var command_data: Variant = command.call("to_dictionary")
		return _get_dictionary(command_data)
	return {}
