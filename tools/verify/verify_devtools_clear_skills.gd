extends SceneTree


const DevDebugPanelScript: Script = preload("res://scripts/debug/dev_debug_panel.gd")
const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")


class DebugPlayer:
	extends Node

	var selected_character_id: StringName = &""
	var current_health: int = 100
	var max_health: int = 100
	var level: int = 1
	var current_experience: int = 0
	var experience_to_next_level: int = 100
	var move_speed: float = 220.0
	var attack_speed_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5
	var armor: int = 0

	func _init() -> void:
		add_to_group(&"player")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("developer_mode_enabled", true)
	var player := DebugPlayer.new()
	player.name = "Player"
	root.add_child(player)
	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	player.add_child(skill_manager)
	_expect(bool(skill_manager.call("set_primary_attack_method", &"fireball")), "test player sets fireball attack method before clearing")
	_expect(bool(skill_manager.call("add_skill", &"fire_dash_blazing_run")), "test player learns a skill before clearing")

	var panel: CanvasLayer = DevDebugPanelScript.new() as CanvasLayer
	panel.name = "DevDebugPanel"
	root.add_child(panel)
	await process_frame

	var clear_button := panel.find_child("ClearSkillsButton", true, false) as Button
	_expect(clear_button != null, "DevDebugPanel exposes Clear Skills button")
	if clear_button != null:
		clear_button.pressed.emit()
	_expect(skill_manager.call("get_all_skills").is_empty(), "Clear Skills button clears current SkillManager")
	_expect(skill_manager.call("get_primary_attack_method") == null, "Clear Skills button clears primary attack method")

	panel.queue_free()
	player.queue_free()
	root.set_meta("developer_mode_enabled", false)
	await process_frame
	if not _failed:
		print("[verify_devtools_clear_skills] PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_devtools_clear_skills] FAIL %s actual=%s" % [label, str(actual)])
