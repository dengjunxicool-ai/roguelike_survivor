## 文件用途：将局内快照与玩家/Boss/技能状态整理为 HUD 字典。
## 使用方式：UIManager 周期调用 build(context)，结果只用于展示，不修改战斗数据。

extends RefCounted
class_name RunHudStateProvider


const RunResultStateBuilderScript: Script = preload("res://scripts/ui/run_result_state_builder.gd")
const MAX_HUD_ACTIVE_SKILLS: int = 5
const MAX_HUD_PASSIVE_SKILLS: int = 3


## 作用：整理上下文和配置为页面展示模型。
## 使用：由页面或局内编排的构建流程调用；结果按声明类型供后续展示/执行使用；输入 context（上下文）；返回字典包含 run_seconds/run_duration/wave_index/wave_id/wave_remaining_seconds/wave_duration_seconds/wave_spawned_count/wave_total_count 等字段。
func build(context: Dictionary) -> Dictionary:
	var tree: SceneTree = context.get("tree", null) as SceneTree
	var state: Dictionary = {
		"run_seconds": float(context.get("run_seconds", 0.0)),
		"run_duration": float(context.get("run_duration", 0.0)),
		"wave_index": int(context.get("wave_index", 0)),
		"wave_id": String(context.get("wave_id", "")),
		"wave_remaining_seconds": float(context.get("wave_remaining_seconds", 0.0)),
		"wave_duration_seconds": float(context.get("wave_duration_seconds", 0.0)),
		"wave_spawned_count": int(context.get("wave_spawned_count", 0)),
		"wave_total_count": int(context.get("wave_total_count", 0)),
		"kill_count": int(context.get("kill_count", 0)),
		"run_stats": RunResultStateBuilderScript.get_run_stats_summary(context.get("run_stats_tracker", null) as Node)
	}
	state["kills"] = int(state.get("kill_count", 0))
	var spawner: Node = tree.get_first_node_in_group(&"enemy_spawner") if tree!=null else null
	if spawner!=null and spawner.has_method("_get_wave_progress_snapshot"):
		state["wave_progress"]=spawner.call("_get_wave_progress_snapshot")
	state["boss_notice"]="第 8 波后 Boss 登场"
	state["souls"] = SaveManager.get_soul_stones()

	var player: Node = tree.get_first_node_in_group(&"player") if is_instance_valid(tree) else null
	_enrich_from_player(state, player)
	state["boss"] = _build_boss_state(tree)
	state["status_summary"] = _get_status_summary(tree)
	state["debug_stats"] = _build_debug_stats(tree)
	return state


## 作用：补全来源玩家。
## 使用：本文件由 build 调用；输入 state（状态）、player（玩家）。
func _enrich_from_player(state: Dictionary, player: Node) -> void:
	if not is_instance_valid(player):
		return
	var max_health: float = maxf(1.0, float(player.get("max_health") if player.get("max_health") != null else 100.0))
	var health: float = clampf(float(player.get("current_health") if player.get("current_health") != null else max_health), 0.0, max_health)
	state["max_health"] = max_health
	state["health"] = health
	state["level"] = int(player.get("level") if player.get("level") != null else state.get("level", 1))
	state["exp"] = int(player.get("current_experience") if player.get("current_experience") != null else state.get("exp", 0))
	state["exp_required"] = int(player.get("experience_to_next_level") if player.get("experience_to_next_level") != null else state.get("exp_required", 1))
	state["character_id"] = String(player.get("selected_character_id") if player.get("selected_character_id") != null else state.get("character_id", ""))
	var runtime := player.get_node_or_null("CharacterRuntime")
	if runtime != null:
		state["character_id"] = String(runtime.call("get_character_id"))
		state["main_attack"] = String(runtime.call("get_starting_skill_id"))
	var skill_level: int = _get_starting_skill_level(player)
	if skill_level > 0:
		state["main_attack_level"] = skill_level
	var skill_slots: Dictionary = _build_skill_slots(player, String(state.get("main_attack", "")))
	state["primary_skill"] = skill_slots.get("primary_skill", {})
	state["dash_skill"] = skill_slots.get("dash_skill", {})
	state["active_skills"] = skill_slots.get("active_skills", [])
	state["passive_skills"] = skill_slots.get("passive_skills", [])
	state["core_skill"] = skill_slots.get("core_skill", {})
	state["fusion_skill"] = skill_slots.get("fusion_skill", {})
	state["skills"] = state["active_skills"]


## 作用：构建Boss状态。
## 使用：本文件由 build 调用；输入 tree（场景树）；返回字典包含 visible/max_health/health/name。
func _build_boss_state(tree: SceneTree) -> Dictionary:
	var boss: Node = _find_boss_enemy(tree)
	if not is_instance_valid(boss):
		return {"visible": false}
	var max_health: float = maxf(1.0, float(boss.get("max_health") if boss.get("max_health") != null else 1.0))
	var health: float = clampf(float(boss.get("current_health") if boss.get("current_health") != null else 0.0), 0.0, max_health)
	var enemy_data: Variant = boss.get("enemy_data")
	return {
		"visible": true,
		"max_health": max_health,
		"health": health,
		"name": str(enemy_data.get("name", "Boss")) if enemy_data is Dictionary else "Boss"
	}


## 作用：构建调试属性统计。
## 使用：本文件由 build 调用；输入 tree（场景树）；返回字典包含 fps/enemy_count/projectile_count/pickup_count。
func _build_debug_stats(tree: SceneTree) -> Dictionary:
	if not OS.is_debug_build() or not is_instance_valid(tree):
		return {}
	return {
		"fps": Engine.get_frames_per_second(),
		"enemy_count": tree.get_nodes_in_group("enemy").size(),
		"projectile_count": tree.get_nodes_in_group("projectile").size(),
		"pickup_count": tree.get_nodes_in_group("pickup").size()
	}


## 作用：获取起始技能等级，供当前模块后续逻辑使用。
## 使用：本文件由 _enrich_from_player 调用；输入 player（玩家）；返回计算或读取的数值。
func _get_starting_skill_level(player: Node) -> int:
	if not is_instance_valid(player):
		return 0
	var runtime := player.get_node_or_null("CharacterRuntime")
	var skill_manager := player.get_node_or_null("SkillManager")
	if runtime == null or skill_manager == null or not skill_manager.has_method("get_skill"):
		return 0
	if skill_manager.has_method("get_primary_attack_method"):
		var primary_attack := skill_manager.call("get_primary_attack_method") as RefCounted
		if primary_attack != null and String(primary_attack.get("skill_id")) == String(runtime.call("get_starting_skill_id")):
			return int(primary_attack.get("current_level"))
	var skill_instance := skill_manager.call("get_skill", StringName(String(runtime.call("get_starting_skill_id")))) as RefCounted
	if skill_instance == null:
		return 0
	return int(skill_instance.get("current_level"))


## 作用：构建技能槽位组。
## 使用：本文件由 _enrich_from_player 调用；输入 player（玩家）、main_attack_id（主要攻击ID）；返回结果字典。
func _build_skill_slots(player: Node, main_attack_id: String = "") -> Dictionary:
	var active_slots: Array[Dictionary] = []
	var passive_slots: Array[Dictionary] = []
	var primary_slot: Dictionary = {}
	var dash_slot: Dictionary = {}
	if not is_instance_valid(player):
		return _skill_slot_result(primary_slot, dash_slot, active_slots, passive_slots)
	var skill_manager := player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_all_skills"):
		return _skill_slot_result(primary_slot, dash_slot, active_slots, passive_slots)
	if skill_manager.has_method("get_primary_attack_method"):
		var primary_attack := skill_manager.call("get_primary_attack_method") as RefCounted
		if primary_attack != null:
			primary_slot = _build_skill_slot(player, primary_attack)
	var skill_instances_variant: Variant = skill_manager.call("get_all_skills")
	if not (skill_instances_variant is Array):
		return _skill_slot_result(primary_slot, dash_slot, active_slots, passive_slots)
	for skill_variant: Variant in skill_instances_variant:
		var skill_instance := skill_variant as RefCounted
		if skill_instance == null:
			continue
		var skill_id: String = _string_from_value(skill_instance.get("skill_id"))
		if skill_id == "":
			continue
		var definition := skill_instance.get("definition") as RefCounted
		var slot: Dictionary = _build_skill_slot(player, skill_instance)
		if _is_primary_skill(skill_id, slot, main_attack_id):
			primary_slot = slot
		elif _is_dash_skill(skill_instance, definition):
			dash_slot = slot
		elif String(slot.get("skill_type", "")) == "passive":
			if passive_slots.size() < MAX_HUD_PASSIVE_SKILLS:
				passive_slots.append(slot)
		elif String(slot.get("skill_type", "")) in ["core", "fusion"]:
			continue
		elif active_slots.size() < MAX_HUD_ACTIVE_SKILLS:
			active_slots.append(slot)
	var result: Dictionary = _skill_slot_result(primary_slot, dash_slot, active_slots, passive_slots)
	for instance: RefCounted in skill_manager.get_all_skills():
		var slot: Dictionary = _build_skill_slot(player, instance)
		var type: String = String(slot.get("skill_type", ""))
		if type in ["core", "fusion"]: result[type + "_skill"] = slot
	return result


## 作用：技能槽位结果。
## 使用：本文件由 _build_skill_slots 调用；输入 primary_slot（主要槽位）、dash_slot（突进槽位）、active_slots（活跃槽位组）、passive_slots（passive槽位组）；返回字典包含 primary_skill/dash_skill/active_skills/passive_skills。
func _skill_slot_result(primary_slot: Dictionary, dash_slot: Dictionary, active_slots: Array[Dictionary], passive_slots: Array[Dictionary]) -> Dictionary:
	return {
		"primary_skill": primary_slot,
		"dash_skill": dash_slot,
		"active_skills": active_slots,
		"passive_skills": passive_slots
	}


## 作用：构建技能槽位。
## 使用：本文件由 _build_skill_slots 调用；输入 player（玩家）、skill_instance（技能实例）；返回字典包含 id/display_name/level/cooldown_remaining/cooldown_total/icon/skill_type。
func _build_skill_slot(player: Node, skill_instance: RefCounted) -> Dictionary:
	var skill_id: String = _string_from_value(skill_instance.get("skill_id"))
	var definition := skill_instance.get("definition") as RefCounted
	var cooldown_remaining: float = maxf(float(skill_instance.get("cooldown_remaining")), 0.0)
	var cooldown_total: float = _resolve_skill_cooldown_total(definition)
	if definition != null and skill_instance is SkillInstance:
		cooldown_total = preload("res://scripts/skills/skill_component_runner.gd").new().get_cooldown(skill_instance,{"caster":player,"owner":player,"skill_instance":skill_instance})
	if _is_dash_skill(skill_instance, definition):
		cooldown_remaining = _get_player_float(player, "_dash_cooldown_remaining", cooldown_remaining)
		cooldown_total = _get_player_float(player, "dash_cooldown", cooldown_total)
	if cooldown_remaining > cooldown_total:
		cooldown_total = cooldown_remaining
	return {
		"id": skill_id,
		"display_name": _resolve_skill_display_name(skill_id, definition),
		"level": int(skill_instance.get("current_level")),
		"cooldown_remaining": cooldown_remaining,
		"cooldown_total": cooldown_total,
		"icon": _resolve_skill_icon_path(skill_id, definition),
		"skill_type": _resolve_skill_type(skill_instance, definition),
		"feedback": _skill_feedback(player,skill_instance)
	}


## 作用：判断主要技能，返回布尔判断结果。
## 使用：本文件由 _build_skill_slots 调用；输入 skill_id（技能ID）、slot（槽位）、main_attack_id（主要攻击ID）。
func _is_primary_skill(skill_id: String, slot: Dictionary, main_attack_id: String) -> bool:
	if main_attack_id != "" and skill_id == main_attack_id:
		return true
	var skill_type: String = String(slot.get("skill_type", ""))
	if skill_type == "attack":
		return true
	var skill_data: Dictionary = GameData.get_skill(StringName(skill_id))
	return bool(skill_data.get("is_starting_skill", false))


## 作用：解析技能展示名称，供当前模块后续逻辑使用。
## 使用：本文件由 _build_skill_slot 调用；输入 skill_id（技能ID）、definition（定义）；返回 String 文本/标识。
func _resolve_skill_display_name(skill_id: String, definition: RefCounted) -> String:
	if definition != null:
		var display_name: String = _string_from_value(definition.get("display_name"))
		if display_name != "":
			return display_name
	var skill_data: Dictionary = GameData.get_skill(StringName(skill_id))
	return String(skill_data.get("display_name", skill_id))


## 作用：解析技能图标路径，供当前模块后续逻辑使用。
## 使用：本文件由 _build_skill_slot 调用；输入 skill_id（技能ID）、definition（定义）；返回 String 文本/标识。
func _resolve_skill_icon_path(skill_id: String, definition: RefCounted) -> String:
	if definition != null:
		for key: String in ["icon", "texture", "background_texture"]:
			var value: String = _string_from_value(definition.get(key))
			if value != "":
				return value
		var visual: Dictionary = _get_dictionary_from_value(definition.get("visual"))
		for key: String in ["icon", "texture", "background_texture"]:
			var value: String = String(visual.get(key, ""))
			if value != "":
				return value
	var skill_data: Dictionary = GameData.get_skill(StringName(skill_id))
	for key: String in ["icon", "texture", "background_texture"]:
		var data_value: String = String(skill_data.get(key, ""))
		if data_value != "":
			return data_value
	var data_visual: Dictionary = _get_dictionary_from_value(skill_data.get("visual", {}))
	for key: String in ["icon", "texture", "background_texture"]:
		var visual_value: String = String(data_visual.get(key, ""))
		if visual_value != "":
			return visual_value
	return ""


## 作用：解析技能冷却总量，供当前模块后续逻辑使用。
## 使用：本文件由 _build_skill_slot 调用；输入 definition（定义）；返回计算或读取的数值。
func _resolve_skill_cooldown_total(definition: RefCounted) -> float:
	if definition == null:
		return 0.0
	for rule_variant: Variant in _get_array_from_value(definition.get("trigger_rules")):
		if not (rule_variant is Dictionary):
			continue
		var rule: Dictionary = rule_variant
		if String(rule.get("trigger", "")) == "cast_skill" and rule.has("cooldown"):
			return maxf(float(rule.get("cooldown", 0.0)), 0.0)
	for component_variant: Variant in _get_array_from_value(definition.get("components")):
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "cooldown":
			continue
		var params: Dictionary = _get_dictionary_from_value(component.get("params", {}))
		return maxf(float(params.get("seconds", 0.0)), 0.0)
	if definition.has_method("get_base_stat"):
		return maxf(float(definition.call("get_base_stat", "cooldown", 0.0)), 0.0)
	var base: Dictionary = _get_dictionary_from_value(definition.get("base"))
	return maxf(float(base.get("cooldown", 0.0)), 0.0)


## 作用：判断突进技能，返回布尔判断结果。
## 使用：本文件由 _build_skill_slots、_build_skill_slot 调用；输入 skill_instance（技能实例）、definition（定义）。
func _is_dash_skill(skill_instance: RefCounted, definition: RefCounted) -> bool:
	if skill_instance != null and _string_from_value(skill_instance.get("skill_type")) == "dash":
		return true
	return definition != null and _string_from_value(definition.get("skill_type")) == "dash"


## 作用：解析技能类型，供当前模块后续逻辑使用。
## 使用：本文件由 _build_skill_slot 调用；输入 skill_instance（技能实例）、definition（定义）；返回 String 文本/标识。
func _resolve_skill_type(skill_instance: RefCounted, definition: RefCounted) -> String:
	var instance_type: String = _string_from_value(skill_instance.get("skill_type")) if skill_instance != null else ""
	if instance_type != "":
		return instance_type
	return _string_from_value(definition.get("skill_type")) if definition != null else ""


## 作用：获取玩家浮点，供当前模块后续逻辑使用。
## 使用：本文件由 _build_skill_slot 调用；输入 player（玩家）、property_name（属性名称）、fallback（回退）；返回计算或读取的数值。
func _get_player_float(player: Node, property_name: String, fallback: float = 0.0) -> float:
	if not is_instance_valid(player):
		return fallback
	var value: Variant = player.get(property_name)
	return fallback if value == null else maxf(float(value), 0.0)


## 作用：获取状态效果摘要，供当前模块后续逻辑使用。
## 使用：本文件由 build 调用；输入 tree（场景树）；返回 String 文本/标识。
func _get_status_summary(tree: SceneTree) -> String:
	var enemy := _find_priority_enemy(tree)
	if not is_instance_valid(enemy):
		return "-"
	var statuses := _get_dictionary(enemy, ["status_stacks", "_status_stacks", "active_statuses"])
	if statuses.is_empty():
		return "-"
	return _format_count_dictionary(statuses)


## 作用：查找Boss敌人，供当前模块后续逻辑使用。
## 使用：本文件由 _build_boss_state 调用；输入 tree（场景树）；返回 Node 对象/值。
func _find_boss_enemy(tree: SceneTree) -> Node:
	if not is_instance_valid(tree):
		return null
	for enemy: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if String(enemy.get_meta("enemy_rank", "")) == "boss":
			return enemy
	return null


## 作用：查找优先级敌人，供当前模块后续逻辑使用。
## 使用：本文件由 _get_status_summary 调用；输入 tree（场景树）；返回 Node 对象/值。
func _find_priority_enemy(tree: SceneTree) -> Node:
	if not is_instance_valid(tree):
		return null
	var fallback: Node = null
	for enemy: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if fallback == null:
			fallback = enemy
		var statuses := _get_dictionary(enemy, ["status_stacks", "_status_stacks", "active_statuses"])
		if not statuses.is_empty():
			return enemy
	return fallback


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _get_status_summary、_find_priority_enemy 调用；输入 object（对象）、keys（keys）。
func _get_dictionary(object: Object, keys: Array[String]) -> Dictionary:
	for key: String in keys:
		var value: Variant = object.get(key)
		if value is Dictionary:
			return value
	return {}


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 _resolve_skill_icon_path、_resolve_skill_cooldown_total 调用；输入 value（值）。
func _get_dictionary_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 _resolve_skill_cooldown_total 调用；输入 value（值）。
func _get_array_from_value(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：字符串来源值，为界面/配置读取提供类型和回退处理。
## 使用：本文件由 _build_skill_slots、_build_skill_slot、_resolve_skill_display_name 调用；输入 value（值）；返回 String 文本/标识。
func _string_from_value(value: Variant) -> String:
	return "" if value == null else String(value)


## 作用：格式化数量字典。
## 使用：本文件由 _get_status_summary 调用；输入 values（值列表）；返回 String 文本/标识。
func _format_count_dictionary(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key: Variant in values.keys():
		var value: Variant = values[key]
		if value is int or value is float:
			if int(value) <= 0:
				continue
			parts.append("%s %d" % [str(key), int(value)])
		elif value:
			parts.append(str(key))
		if parts.size() >= 3:
			break
	return " / ".join(parts) if not parts.is_empty() else "-"

## 读取资源余量和复制快照，不把内部计数键暴露给玩家。
func _skill_feedback(player: Node, skill: RefCounted) -> String:
	if skill == null: return ""
	if _string_from_value(skill.get("skill_type")) == "core":
		var definition: RefCounted = skill.get("definition")
		for rule: Dictionary in definition.get("trigger_rules"):
			if rule.has("counter_key") and rule.has("threshold"):
				return "充能 %.0f/%.0f" % [float(skill.get_meta(str(rule.counter_key),0.0)),float(rule.threshold)]
	if String(skill.get("skill_id")) == "chaos_power_echo_cast":
		var bus: Node = player.get_node_or_null("SkillEventBus")
		if bus == null: return "等待施法"
		var charge: int = int(bus.chaos_state().echo_count)
		if charge >= 4: return "回声就绪" if not bus.get_cast_snapshot({"skill_type":"cast"}).is_empty() else "等待施法"
		return "回声充能 %d/4" % charge
	return ""
