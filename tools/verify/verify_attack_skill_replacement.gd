extends SceneTree


const SkillManagerScript: Script = preload("res://scripts/skills/skill_manager.gd")
const RunHudStateProviderScript: Script = preload("res://scripts/ui/hud/run_hud_state_provider.gd")


class TestPlayer:
	extends Node2D

	var selected_character_id: StringName = &""
	var max_health: int = 100
	var current_health: int = 100
	var level: int = 1
	var current_experience: int = 0
	var experience_to_next_level: int = 10

	func _init() -> void:
		add_to_group(&"player")

	func set_run_modifier_source(_source_id: Variant, _modifiers: Variant) -> void:
		pass


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := TestPlayer.new()
	player.name = "Player"
	root.add_child(player)

	var skill_manager: Node = SkillManagerScript.new()
	skill_manager.name = "SkillManager"
	skill_manager.set("max_active_skills", 1)
	player.add_child(skill_manager)

	_expect(bool(skill_manager.call("add_skill", &"fireball")), "learns initial fireball", "add_skill=false")
	_expect(skill_manager.call("get_all_skills").size() == 1, "starts with one active skill slot", skill_manager.call("get_all_skills").size())
	_expect(bool(skill_manager.call("add_skill", &"fire_attack_searing")), "searing attack replaces initial fireball even when active slots are full", "add_skill=false")
	_expect(not bool(skill_manager.call("has_skill", &"fireball")), "fireball is no longer an active learned skill after replacement", "fireball still active")
	_expect(bool(skill_manager.call("has_skill", &"fire_attack_searing")), "searing attack becomes the active attack skill", "missing searing")
	_expect(skill_manager.call("get_all_skills").size() == 1, "replacement keeps one HUD skill slot", skill_manager.call("get_all_skills").size())

	var searing := skill_manager.call("get_skill", &"fire_attack_searing") as RefCounted
	_expect(searing != null, "can read searing skill instance", searing)
	if searing != null:
		var definition := searing.get("definition") as RefCounted
		_expect(_has_fireball_projectile_event(definition), "searing attack reuses fireball projectile visual runtime", definition.get("events") if definition != null else [])
		_expect(_cooldown_seconds(definition) > 0.0, "searing attack keeps cast cooldown from initial fireball runtime", _cooldown_seconds(definition))

	var provider: RefCounted = RunHudStateProviderScript.new()
	var state: Dictionary = provider.call("build", {"tree": self})
	var primary_skill: Dictionary = state.get("primary_skill", {})
	var slots: Array = state.get("skills", [])
	_expect(String(primary_skill.get("id", "")) == "fire_attack_searing", "HUD primary slot shows replacement skill id", primary_skill)
	_expect(slots.is_empty(), "HUD ordinary active slots exclude primary attack replacement", slots)

	player.queue_free()
	await process_frame
	if not _failed:
		print("[verify_attack_skill_replacement] PASS")
	quit(1 if _failed else 0)


func _has_fireball_projectile_event(definition: RefCounted) -> bool:
	if definition == null:
		return false
	var events_variant: Variant = definition.get("events")
	if not (events_variant is Array):
		return false
	for event_variant: Variant in events_variant:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		for action_variant: Variant in event.get("actions", []):
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var params: Dictionary = action.get("params", {}) if action.get("params", {}) is Dictionary else {}
			if String(params.get("projectile_id", "")) == "fireball_projectile" or String(event.get("source_id", "")) == "fireball_projectile":
				return true
	return false


func _cooldown_seconds(definition: RefCounted) -> float:
	if definition == null:
		return 0.0
	var components_variant: Variant = definition.get("components")
	if not (components_variant is Array):
		return 0.0
	for component_variant: Variant in components_variant:
		if not (component_variant is Dictionary):
			continue
		var component: Dictionary = component_variant
		if String(component.get("type", "")) != "cooldown":
			continue
		var params: Dictionary = component.get("params", {}) if component.get("params", {}) is Dictionary else {}
		return float(params.get("seconds", 0.0))
	return 0.0


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_attack_skill_replacement] FAIL %s actual=%s" % [label, str(actual)])
