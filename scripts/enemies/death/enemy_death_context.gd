## 文件用途：封装敌人死亡原因与奖励策略上下文。
## 使用方式：静态 create 为 EnemyDeathPipeline.execute 准备字典。

extends RefCounted
class_name EnemyDeathContext


## 作用：创建。
## 使用：供本模块调用者使用；输入 cause（原因）、policy（策略）、source_context（来源上下文）；返回字典包含 cause/policy/source_context。
static func create(cause: String = "damage", policy: Dictionary = {}, source_context: Dictionary = {}) -> Dictionary:
	return {
		"cause": cause,
		"policy": policy.duplicate(true),
		"source_context": source_context.duplicate(true)
	}
