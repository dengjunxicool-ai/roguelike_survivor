## 文件用途：在伤害计算前拒绝非法包并克隆可计算的输入。
## 使用方式：DamageSystem 创建计算上下文时调用 prepare；失败返回 null，不进入计算。
extends RefCounted
class_name DamagePacketPreparation

## 作用：校验输入后克隆包、补目标ID并执行诊断校验。
## 使用：packet 必须非空；校验失败报错并返回 null，克隆保留原始错误。
static func prepare(packet: DamagePacket, target: Node = null) -> DamagePacket:
	var errors: Array[String] = packet.validate()
	if not errors.is_empty():
		push_error("Invalid DamagePacket: " + "; ".join(errors))
		return null
	var prepared: DamagePacket = packet.clone()
	if target != null:
		prepared.target_id = str(target.get_instance_id())
	prepared.reaction_depth = maxi(prepared.reaction_depth, 0)
	DamagePacketValidator.validate_packet(prepared, target)
	return prepared
