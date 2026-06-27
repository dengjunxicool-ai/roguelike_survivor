extends RefCounted
class_name SummonDefinition
const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")


const DEFAULT_MOVEMENT: Dictionary = {
	"move_speed": 180.0,
	"follow_distance": 80.0,
	"min_distance": 40.0,
	"leash_distance": 360.0,
	"teleport_distance": 720.0,
	"separation_radius": 32.0
}
const DEFAULT_TARGETING: Dictionary = {
	"detect_range": 300.0,
	"retarget_interval": 0.25,
	"target_priority": "nearest_to_summon"
}
const DEFAULT_ATTACK: Dictionary = {
	"attack_type": "melee",
	"attack_range": 48.0,
	"attack_cooldown": 1.2,
	"damage_type": "neutral",
	"damage_scale": 0.45,
	"on_hit_effects": []
}

var id: StringName = &""
var display_name: String = ""
var scene_path: String = "res://scenes/summon_controller.tscn"
var max_count: int = 1
var duration: float = 18.0
var movement: Dictionary = {}
var targeting: Dictionary = {}
var attack: Dictionary = {}
var visual: Dictionary = {}


static func from_dictionary(data: Dictionary) -> RefCounted:
	var definition: RefCounted = load("res://scripts/summons/summon_definition.gd").new()
	definition.id = StringName(String(data.get("id", "")))
	definition.display_name = String(data.get("name", definition.id))
	definition.scene_path = String(data.get("scene_path", definition.scene_path))
	definition.max_count = maxi(int(data.get("max_count", definition.max_count)), 1)
	definition.duration = maxf(float(data.get("duration", definition.duration)), 0.05)
	definition.movement = _merged(DEFAULT_MOVEMENT, _dictionary(data.get("movement", {})))
	definition.targeting = _merged(DEFAULT_TARGETING, _dictionary(data.get("targeting", {})))
	definition.attack = _merged(DEFAULT_ATTACK, _dictionary(data.get("attack", {})))
	definition.visual = _dictionary(data.get("visual", {}))
	return definition


static func from_id(definition_id: Variant) -> RefCounted:
	var id_string: String = String(definition_id)
	if id_string == "":
		return null
	var document: Dictionary = JsonDataLoaderScript.load_dictionary(DataPathsScript.SUMMONS_PATH, "SummonDefinition", JsonDataLoaderScript.REPORT_SILENT)
	for summon_variant: Variant in document.get("summons", []):
		if summon_variant is Dictionary and String((summon_variant as Dictionary).get("id", "")) == id_string:
			return from_dictionary(summon_variant as Dictionary)
	return null


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"scene_path": scene_path,
		"max_count": max_count,
		"duration": duration,
		"movement": movement.duplicate(true),
		"targeting": targeting.duplicate(true),
		"attack": attack.duplicate(true),
		"visual": visual.duplicate(true)
	}


static func _merged(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	for key: Variant in overrides.keys():
		merged[key] = overrides[key]
	return merged


static func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
