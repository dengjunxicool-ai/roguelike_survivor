## 文件用途：定义特性使用的统一事件类型及隔离的事件载荷。
## 使用方式：用 new 或 create 传入事件类型和载荷字典，载荷会深拷贝后交给特性控制器。
extends RefCounted
class_name CharacterEvent


const PLAYER_MOVED: StringName = &"player_moved"
const PLAYER_STOPPED: StringName = &"player_stopped"
const SKILL_CAST: StringName = &"skill_cast"
const PLAYER_DAMAGED: StringName = &"player_damaged"
const ENEMY_KILLED: StringName = &"enemy_killed"

var type: StringName = &""
var payload: Dictionary = {}


## 作用：保存事件类型并深拷贝事件载荷，隔离后续字典修改。
## 使用：event_type 为特性事件类型。
func _init(event_type: StringName = &"", event_payload: Dictionary = {}) -> void:
	type = event_type
	payload = event_payload.duplicate(true)


## 作用：用事件类型与载荷构造新的 CharacterEvent，载荷由构造器深拷贝。
## 使用：event_type 为特性事件类型。
static func create(event_type: StringName, event_payload: Dictionary = {}) -> CharacterEvent:
	return CharacterEvent.new(event_type, event_payload)
