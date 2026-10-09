## 文件用途：封装敌方动作执行所需的敌人、动作和运行参数。
## 使用方式：通过静态 create 构建字典，交给 EnemyActionRegistry 分派。

extends RefCounted
class_name EnemyActionContext


## 作用：构建动作执行上下文，并深拷贝技能、动作和运行参数字典。
## 使用：owner 保留节点引用；返回 owner/skill/action/runtime_params，传给 EnemyActionRegistry.execute。
static func create(owner: Node, skill: Dictionary, action: Dictionary, runtime_params: Dictionary = {}) -> Dictionary:
	return {
		"owner": owner,
		"skill": skill.duplicate(true),
		"action": action.duplicate(true),
		"runtime_params": runtime_params.duplicate(true)
	}
