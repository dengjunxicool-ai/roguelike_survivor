extends Node
class_name SynergyManager


const SYNERGY_DATA_PATH: String = "res://data/synergies.json"

signal synergies_changed(active_synergy_ids: Array[StringName])

var active_synergies: Array[StringName] = []
var recognized_synergies: Array[StringName] = []
var _synergy_definitions: Dictionary = {}


func _ready() -> void:
	_load_synergy_definitions()
	refresh_active_synergies(get_parent())


func refresh_active_synergies(player: Node) -> void:
	_load_synergy_definitions()
	active_synergies.clear()
	recognized_synergies.clear()

	var owned_tags: Dictionary = _get_owned_skill_tags(player)
	for synergy_id_variant: Variant in _synergy_definitions.keys():
		var synergy_id: StringName = StringName(String(synergy_id_variant))
		var synergy: Dictionary = _synergy_definitions[synergy_id]
		recognized_synergies.append(synergy_id)
		if _requirements_met(synergy, owned_tags):
			active_synergies.append(synergy_id)

	synergies_changed.emit(active_synergies.duplicate())


func has_synergy(synergy_id: Variant) -> bool:
	return active_synergies.has(StringName(String(synergy_id)))


func on_damage_dealt(event: Dictionary) -> Dictionary:
	var adjusted_event: Dictionary = event.duplicate(true)
	if not has_synergy(&"frozen_physical_bonus"):
		return adjusted_event

	var damage_type: StringName = StringName(String(adjusted_event.get("damage_type", "")))
	var element: StringName = StringName(String(adjusted_event.get("element", "")))
	if damage_type != &"direct_physical" and damage_type != &"physical" and element != &"physical":
		return adjusted_event

	var target: Node = adjusted_event.get("target") as Node
	if not _target_has_status(target, &"freeze"):
		return adjusted_event

	var amount: int = int(adjusted_event.get("amount", 0))
	adjusted_event["amount"] = maxi(roundi(float(amount) * 1.4), 0)
	adjusted_event["synergy_id"] = &"frozen_physical_bonus"
	return adjusted_event


func on_enemy_killed(event: Dictionary) -> Dictionary:
	var adjusted_event: Dictionary = event.duplicate(true)
	return adjusted_event


func on_skill_cast(event: Dictionary) -> Dictionary:
	return event.duplicate(true)


func on_status_applied(event: Dictionary) -> Dictionary:
	var adjusted_event: Dictionary = event.duplicate(true)
	if not has_synergy(&"poison_slow_bonus"):
		return adjusted_event

	var target: Node = adjusted_event.get("target") as Node
	if _target_has_status(target, &"poison") and _target_has_status(target, &"slow"):
		adjusted_event["poison_tick_interval_multiplier"] = 0.75
		adjusted_event["synergy_id"] = &"poison_slow_bonus"

	return adjusted_event


func get_status_tick_interval_multiplier(target: Node, status_id: Variant) -> float:
	if StringName(String(status_id)) != &"poison" or not has_synergy(&"poison_slow_bonus"):
		return 1.0
	if not (_target_has_status(target, &"poison") and _target_has_status(target, &"slow")):
		return 1.0

	return 0.75


func _load_synergy_definitions() -> void:
	if not _synergy_definitions.is_empty():
		return

	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_synergy_definitions"):
		var definitions_variant: Variant = data_manager.call("get_synergy_definitions")
		if definitions_variant is Array:
			_index_synergy_definitions(definitions_variant)
			if not _synergy_definitions.is_empty():
				return

	_index_synergy_definitions(_load_synergies_from_file())


func _load_synergies_from_file() -> Array[Dictionary]:
	if not FileAccess.file_exists(SYNERGY_DATA_PATH):
		push_error("[SynergyManager] Synergy data file does not exist: %s" % SYNERGY_DATA_PATH)
		return []

	var file: FileAccess = FileAccess.open(SYNERGY_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("[SynergyManager] Could not open synergy data file: %s" % SYNERGY_DATA_PATH)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("[SynergyManager] Could not parse synergy data as Dictionary: %s" % SYNERGY_DATA_PATH)
		return []

	var document: Dictionary = parsed
	var synergies_variant: Variant = document.get("synergies", [])
	if not (synergies_variant is Array):
		push_error("[SynergyManager] Expected data/synergies.json.synergies to be an Array.")
		return []

	var synergies: Array[Dictionary] = []
	for synergy_variant: Variant in synergies_variant:
		if synergy_variant is Dictionary:
			var synergy: Dictionary = synergy_variant
			synergies.append(synergy.duplicate(true))
		else:
			push_error("[SynergyManager] Expected every synergy definition to be a Dictionary.")

	return synergies


func _index_synergy_definitions(synergies: Array) -> void:
	for synergy_variant: Variant in synergies:
		if not (synergy_variant is Dictionary):
			continue

		var synergy: Dictionary = synergy_variant
		var synergy_id: StringName = StringName(String(synergy.get("id", "")))
		if synergy_id == &"":
			push_error("[SynergyManager] Synergy definition is missing id.")
			continue

		_synergy_definitions[synergy_id] = synergy.duplicate(true)


func _requirements_met(synergy: Dictionary, owned_tags: Dictionary) -> bool:
	var required_tags: Array[String] = _get_string_array(synergy.get("required_skill_tags", []))
	for tag: String in required_tags:
		if not owned_tags.has(tag):
			return false

	return true


func _get_owned_skill_tags(player: Node) -> Dictionary:
	var tags: Dictionary = {}
	if player == null:
		return tags

	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var skill_instances_variant: Variant = skill_manager.call("get_all_skills")
		if skill_instances_variant is Array:
			for skill_instance_variant: Variant in skill_instances_variant:
				var skill_instance: RefCounted = skill_instance_variant as RefCounted
				if skill_instance == null:
					continue

				var definition: RefCounted = skill_instance.get("definition") as RefCounted
				_add_definition_tags(tags, definition)

	return tags


func _add_definition_tags(target: Dictionary, definition: RefCounted) -> void:
	if definition == null:
		return

	var tags_variant: Variant = definition.get("tags")
	if not (tags_variant is Array):
		return

	for tag_variant: Variant in tags_variant:
		target[String(tag_variant)] = true


func _target_has_status(target: Node, status_id: StringName) -> bool:
	if target == null:
		return false
	if target.has_method("has_status"):
		return bool(target.call("has_status", status_id))

	var status_manager: Node = target.get_node_or_null("StatusEffectManager")
	if status_manager != null and status_manager.has_method("has_status"):
		return bool(status_manager.call("has_status", status_id))

	return false


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if not (value is Array):
		return strings

	var items: Array = value
	for item: Variant in items:
		strings.append(String(item))

	return strings
