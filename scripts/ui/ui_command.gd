## 文件用途：封装 UI 选择、购买与货币操作的命令数据。
## 使用方式：静态工厂构建命令，再由 UICommandDispatcher.dispatch 统一执行。

extends RefCounted
class_name UICommand


var type: StringName = &""
var payload: Dictionary = {}


## 作用：深拷贝命令 payload 并写入命令类型，返回命令字典。
## 使用：command_type 为已支持的类型；仅构建数据，不执行购买或修改战斗。
static func create(command_type: StringName, command_payload: Dictionary = {}) -> Dictionary:
	var result: Dictionary = command_payload.duplicate(true)
	result["type"] = command_type
	return result


## 作用：构建应用局内选择的命令字典。
## 使用：option 会深拷贝；交给 UICommandDispatcher.dispatch 后才实际应用；返回结果字典。
static func apply_choice_option(option: Dictionary) -> Dictionary:
	return create(&"apply_choice_option", {"option": option.duplicate(true)})


## 作用：构建购买永久升级的命令字典。
## 使用：upgrade_id 为配置 ID；本函数不扣费，由 dispatcher 执行；返回结果字典。
static func purchase_meta_upgrade(upgrade_id: StringName) -> Dictionary:
	return create(&"purchase_meta_upgrade", {"upgrade_id": upgrade_id})


## 作用：构建购买角色的命令字典。
## 使用：character_id 为配置 ID；本函数不解锁或扣费；返回结果字典。
static func purchase_character(character_id: StringName) -> Dictionary:
	return create(&"purchase_character", {"character_id": character_id})


## 作用：构建增加灵魂石的命令字典。
## 使用：amount 为请求数量；实际余额修改由 dispatcher 完成；返回结果字典。
static func add_soul_stones(amount: int) -> Dictionary:
	return create(&"add_soul_stones", {"amount": amount})


## 作用：把实例 payload 深拷贝并加入 type 字段。
## 使用：供 dispatcher 接收 UICommand 实例时转换；返回独立命令视图。
func to_dictionary() -> Dictionary:
	var result: Dictionary = payload.duplicate(true)
	result["type"] = type
	return result
