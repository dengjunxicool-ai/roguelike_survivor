## 文件用途：整理永久升级等级、价格和是否可买的展示模型。
## 使用方式：永久升级页创建实例后调用 build，读取 GameData 与 SaveManager，不执行购买。

extends RefCounted
class_name MetaUpgradeViewModelBuilder


## 作用：整理上下文和配置为页面展示模型。
## 使用：由页面或局内编排的构建流程调用；结果按声明类型供后续展示/执行使用；返回字典包含 id/display_name/current_level/max_level/cost/is_maxed/can_purchase/button_text 等字段。
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
