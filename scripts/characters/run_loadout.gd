## 文件用途：保存本局选择角色的配置快照及角色定义。
## 使用方式：由 CharacterLoadoutService 创建，开局前用 is_valid 检查非空角色 ID 和配置。
extends RefCounted
class_name RunLoadout


const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")

var character_id: StringName = &""
var character_data: Dictionary = {}
var character_definition: RefCounted


## 作用：深拷贝角色配置，读取角色 ID，非空配置同时创建 CharacterDefinition。
## 使用：由 CharacterLoadoutService 创建，开局前用 is_valid 检查非空角色 ID 和配置。
func _init(character_config: Dictionary = {}) -> void:
	character_data = character_config.duplicate(true)
	character_id = StringName(String(character_data.get("id", "")))
	if not character_data.is_empty():
		character_definition = CharacterDefinitionScript.new(character_data)


## 作用：检查装配快照是否同时具有角色 ID 和非空角色配置。
## 使用：由 CharacterLoadoutService 创建，开局前用 is_valid 检查非空角色 ID 和配置。
func is_valid() -> bool:
	return character_id != &"" and not character_data.is_empty()
