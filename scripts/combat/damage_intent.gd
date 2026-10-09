## 文件用途：保存目标与克隆伤害包，表示可稍后应用的一次伤害意图。
## 使用方式：用 create 构造，再调用 apply 进入统一受击服务；policy 仅保存为意图元数据。
extends RefCounted
class_name DamageIntent


const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")

var target: Node = null
var packet: DamagePacket
var application_policy: StringName = &"default"


## 作用：绑定目标并克隆伤害包，保存应用策略名称。
## 使用：克隆保留校验错误；不会立即触发伤害。
static func create(target_node: Node, damage_packet: DamagePacket, policy: StringName = &"default") -> RefCounted:
	var intent: RefCounted = new()
	intent.target = target_node
	intent.packet = damage_packet.clone()
	intent.application_policy = policy
	return intent


## 作用：将保存的目标与包送入统一伤害应用服务。
## 使用：返回应用结果，按目标类型执行受击副作用。
func apply() -> RefCounted:
	return DamageApplicationServiceScript.apply_damage(target, packet)
