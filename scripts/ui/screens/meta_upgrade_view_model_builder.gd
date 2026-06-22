extends RefCounted
class_name MetaUpgradeViewModelBuilder


func build() -> Dictionary:
	var upgrades: Array[Dictionary] = []
	for upgrade: Dictionary in GameData.get_permanent_upgrade_pool():
		var upgrade_id: StringName = StringName(String(upgrade.get("id", "")))
		if upgrade_id == &"":
			continue
		var current_level: int = SaveManager.get_permanent_upgrade_level(upgrade_id)
		var max_level: int = int(upgrade.get("max_level", 1))
		var cost: int = SaveManager.get_permanent_upgrade_cost(upgrade_id)
		var is_maxed: bool = current_level >= max_level
		upgrades.append({
			"id": upgrade_id,
			"display_name": String(upgrade.get("display_name", upgrade_id)),
			"current_level": current_level,
			"max_level": max_level,
			"cost": cost,
			"is_maxed": is_maxed,
			"can_purchase": not is_maxed and SaveManager.can_purchase_permanent_upgrade(upgrade_id),
			"button_text": "已满级" if is_maxed else "强化 %d" % cost
		})
	return {
		"souls": SaveManager.get_soul_stones(),
		"upgrades": upgrades
	}
