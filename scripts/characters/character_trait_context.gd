## 文件用途：向特性提供玩家、角色运行时和场景树访问上下文。
## 使用方式：由 CharacterTraitController 创建并传给特性 setup；可读取初始技能或同步调试状态。
extends RefCounted
class_name CharacterTraitContext


var owner: Node
var runtime: Node
var tree: SceneTree


## 作用：保存玩家和角色运行时引用，并从玩家获取当前场景树。
## 使用：由 CharacterTraitController 创建并传给特性 setup；可读取初始技能或同步调试状态。
func _init(context_owner: Node = null, context_runtime: Node = null) -> void:
	owner = context_owner
	runtime = context_runtime
	tree = owner.get_tree() if owner != null else null


## 作用：取得角色当前配置的初始技能标识，未装配角色时返回空标识。
## 使用：由 CharacterTraitController 创建并传给特性 setup；可读取初始技能或同步调试状态。
func get_starting_skill_id() -> StringName:
	if runtime != null:
		return StringName(String(runtime.call("get_starting_skill_id")))
	return &""


## 作用：将给定特性状态深拷贝写入角色运行时，避免共享可变字典。
## 使用：由 CharacterTraitController 创建并传给特性 setup；可读取初始技能或同步调试状态。
func sync_trait_state(state: Dictionary) -> void:
	if runtime != null:
		runtime.set("trait_runtime_state", state.duplicate(true))
