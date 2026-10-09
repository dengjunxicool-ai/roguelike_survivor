## 文件用途：将玩家移动、受击、击杀和施法事件包装为特性系统统一事件。
## 使用方式：先 setup 绑定 CharacterTraitController，再由 CharacterTraitSystem 转入对应事件入口。
extends RefCounted
class_name CharacterEventBridge


const CharacterEventScript: Script = preload("res://scripts/characters/events/character_event.gd")

var _controller: RefCounted


## 作用：保存控制器引用，供后续事件包装与发送。
## 使用：先 setup 绑定 CharacterTraitController，再由 CharacterTraitSystem 转入对应事件入口。
func setup(controller: RefCounted) -> void:
	_controller = controller


## 作用：按移动标志发出移动或停止事件，并把帧时长写入载荷。
## 使用：delta 为本帧经过的秒数。
func emit_movement(is_moving: bool, delta: float) -> void:
	var event_type: StringName = CharacterEventScript.PLAYER_MOVED if is_moving else CharacterEventScript.PLAYER_STOPPED
	_emit(event_type, {"delta": delta})


## 作用：仅把 on_cast 转为角色特性施法事件，其余技能事件忽略。
## 使用：event_name 为统一技能事件名；event 为当前事件或规则载荷。
func emit_skill_event(event_name: StringName, event: Dictionary) -> void:
	if event_name != &"on_cast":
		return
	_emit(CharacterEventScript.SKILL_CAST, event)


## 作用：把玩家受击载荷发送到特性控制器。
## 使用：event 为当前事件或规则载荷。
func emit_player_damaged(event: Dictionary) -> void:
	_emit(CharacterEventScript.PLAYER_DAMAGED, event)


## 作用：把敌人死亡载荷发送到特性控制器。
## 使用：event 为当前事件或规则载荷。
func emit_enemy_killed(event: Dictionary) -> void:
	_emit(CharacterEventScript.ENEMY_KILLED, event)


## 作用：创建深拷贝载荷的统一特性事件对象。
## 使用：event_type 为特性事件类型；payload 为事件附加字段。
func make_event(event_type: StringName, payload: Dictionary = {}) -> RefCounted:
	return CharacterEventScript.new(event_type, payload)


## 作用：在控制器有效且支持事件接口时投递包装后的事件。
## 使用：event_type 为特性事件类型；payload 为事件附加字段。
func _emit(event_type: StringName, payload: Dictionary) -> void:
	if _controller == null or not _controller.has_method("handle_event"):
		return
	_controller.call("handle_event", CharacterEventScript.new(event_type, payload))
