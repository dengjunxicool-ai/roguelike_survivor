## 文件用途：把已发布召唤配置封装成含移动、选目标、攻击和视觉默认值的独立定义。
## 使用方式：从GameData通过from_id查询，或from_dictionary解析；SummonManager/SummonController使用该对象。
extends RefCounted
class_name SummonDefinition


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
var scene_path: String = "res://scenes/summons/summon_controller.tscn"
var max_count: int = 1
var duration: float = 18.0
var movement: Dictionary = {}
var targeting: Dictionary = {}
var attack: Dictionary = {}
var visual: Dictionary = {}


## 作用：解析身份、场景、上限和寿命，并为三个组件合并默认配置。
## 使用：data为定义字典，嵌套配置深复制，数量至少1、时长至少0.05。
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


## 作用：从GameData查询召唤ID并生成定义对象。
## 使用：ID为空或定义缺失返回null，不读JSON文件。
static func from_id(definition_id: Variant) -> RefCounted:
	var id_string: String = String(definition_id)
	if id_string == "":
		return null
	var data: Dictionary = GameData.get_summon(StringName(id_string))
	return from_dictionary(data) if not data.is_empty() else null


## 作用：导出定义各字段和嵌套配置副本。
## 使用：外部修改返回字典不会污染组件配置。
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


## 作用：复制默认配置后按覆盖项逐键替换。
## 使用：仅顶层合并，overrides值优先。
static func _merged(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	for key: Variant in overrides.keys():
		merged[key] = overrides[key]
	return merged


## 作用：读取字典配置，非字典输入返回空字典。
## 使用：value为待检查配置；返回深复制，嵌套修改不会污染输入。
static func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
