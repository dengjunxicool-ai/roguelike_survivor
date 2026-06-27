extends SceneTree


const RunChoiceModalControllerScript: Script = preload("res://scripts/ui/modals/run_choice_modal_controller.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller: RefCounted = RunChoiceModalControllerScript.new()
	var option: Dictionary = {
		"id": "level_up_upgrade:learn_frost_summon_ice_crystal_guard",
		"type": "level_up_upgrade",
		"display_name": "冰晶守卫",
		"description": "召唤固定冰晶守卫，周期性释放冰脉冲，减速附近敌人",
		"payload": {
			"learn_skill_id": &"frost_summon_ice_crystal_guard"
		}
	}
	var text: String = String(controller.call("_get_option_effect_text", option))
	var failed: bool = false
	failed = _expect(text.contains("守卫持续 16s"), "summary shows guard duration", text) or failed
	failed = _expect(text.contains("每 1.4s 释放冰脉冲"), "summary shows pulse cooldown", text) or failed
	failed = _expect(text.contains("伤害 0.34P"), "summary shows pulse damage scale", text) or failed
	failed = _expect(text.contains("范围 180px"), "summary shows pulse radius", text) or failed
	if not failed:
		print("[verify_skill_card_effect_summary] PASS")
	quit(1 if failed else 0)


func _expect(condition: bool, label: String, actual: Variant) -> bool:
	if condition:
		return false
	push_error("[verify_skill_card_effect_summary] FAIL %s actual=%s" % [label, str(actual)])
	return true
