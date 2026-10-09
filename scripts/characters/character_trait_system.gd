## 文件用途：作为玩家节点上的角色特性门面，连接事件桥和特性控制器。
## 使用方式：挂在玩家下，initialize 传入 CharacterRuntime；玩家移动、受击和技能总线通过公开入口转入特性。
extends Node
class_name CharacterTraitSystem


const CharacterTraitControllerScript: Script = preload("res://scripts/characters/character_trait_controller.gd")
const CharacterEventBridgeScript: Script = preload("res://scripts/characters/character_event_bridge.gd")
const ModifierQueryScript: Script = preload("res://scripts/modifiers/modifier_query.gd")
const DamageAbsorbResultScript: Script = preload("res://scripts/characters/events/damage_absorb_result.gd")

var character_runtime: Node
var _controller: RefCounted = CharacterTraitControllerScript.new()
var _event_bridge: RefCounted = CharacterEventBridgeScript.new()


## 作用：将已创建的特性控制器绑定到事件桥。
## 使用：挂在玩家下，initialize 传入 CharacterRuntime；玩家移动、受击和技能总线通过公开入口转入特性。
func _ready() -> void:
	_event_bridge.call("setup", _controller)


## 作用：每帧把 delta 秒数传给特性控制器推进计时与状态同步。
## 使用：delta 为本帧经过的秒数。
func _process(delta: float) -> void:
	if _controller != null and _controller.has_method("process"):
		_controller.call("process", delta)


## 作用：绑定角色运行时，补建桥与控制器，再用父节点玩家初始化当前特性。
## 使用：挂在玩家下，initialize 传入 CharacterRuntime；玩家移动、受击和技能总线通过公开入口转入特性。
func initialize(runtime: Node) -> void:
	character_runtime = runtime
	if _event_bridge == null:
		_event_bridge = CharacterEventBridgeScript.new()
	if _controller == null:
		_controller = CharacterTraitControllerScript.new()
	_event_bridge.call("setup", _controller)
	_controller.call("initialize", character_runtime, get_parent())


## 作用：将移动状态与秒数交给特性事件桥。
## 使用：delta 为本帧经过的秒数。
func handle_movement(is_moving: bool, delta: float) -> void:
	_event_bridge.call("emit_movement", is_moving, delta)


## 作用：将技能事件名和载荷交给特性事件桥转换。
## 使用：event_name 为统一技能事件名；event 为当前事件或规则载荷。
func handle_skill_event(event_name: StringName, event: Dictionary) -> void:
	_event_bridge.call("emit_skill_event", event_name, event)


## 作用：适配技能总线的载荷在前、事件名在后的回调签名。
## 使用：event 为当前事件或规则载荷；event_name 为统一技能事件名。
func handle_skill_bus_event(event: Dictionary, event_name: StringName) -> void:
	handle_skill_event(event_name, event)


## 作用：把击杀载荷经事件桥交给当前角色特性。
## 使用：event 为当前事件或规则载荷。
func handle_enemy_killed(event: Dictionary) -> void:
	_event_bridge.call("emit_enemy_killed", event)


## 作用：把受击载荷经事件桥交给当前角色特性。
## 使用：event 为当前事件或规则载荷。
func handle_player_damaged(event: Dictionary) -> void:
	_event_bridge.call("emit_player_damaged", event)


## 作用：请求当前特性吸收伤害并返回剩余伤害；缺特性时保留原值。
## 使用：amount 为本次伤害或动作数值；event 为当前事件或规则载荷。
func request_damage_absorb(amount: int, event: Dictionary = {}) -> RefCounted:
	if _controller == null or not _controller.has_method("request_damage_absorb"):
		return DamageAbsorbResultScript.unchanged(amount)
	var character_event: RefCounted = _event_bridge.call("make_event", &"damage_absorb_requested", event) as RefCounted
	return _controller.call("request_damage_absorb", amount, character_event) as RefCounted


## 作用：从特性控制器取得查询范围内的属性快照，控制器不可用时返回空字典。
## 使用：query 为携带作用域与过滤信息的属性查询；无适用数据时返回空字典。
func get_modifiers(query: RefCounted) -> Dictionary:
	if _controller == null or not _controller.has_method("collect_modifiers"):
		return {}
	var modifiers: Variant = _controller.call("collect_modifiers", query)
	if modifiers is Dictionary:
		return modifiers
	return {}


## 作用：用玩家作用域构造查询并读取角色特性属性。
## 使用：挂在玩家下，initialize 传入 CharacterRuntime；玩家移动、受击和技能总线通过公开入口转入特性。
func get_player_modifiers(scope: StringName = &"player") -> Dictionary:
	return get_modifiers(ModifierQueryScript.for_player(get_parent(), scope))


## 作用：返回当前特性运行状态，包括 ，供运行时与调试查询。
## 使用：挂在玩家下，initialize 传入 CharacterRuntime；玩家移动、受击和技能总线通过公开入口转入特性；无适用数据时返回空字典。
func get_debug_state() -> Dictionary:
	if _controller != null and _controller.has_method("get_debug_state"):
		var state: Variant = _controller.call("get_debug_state")
		if state is Dictionary:
			return state
	return {}
