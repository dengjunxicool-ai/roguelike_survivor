extends RefCounted
class_name CharacterTraitContext


var owner: Node
var runtime: Node
var tree: SceneTree


func _init(context_owner: Node = null, context_runtime: Node = null) -> void:
	owner = context_owner
	runtime = context_runtime
	tree = owner.get_tree() if owner != null else null


func get_starting_skill_id() -> StringName:
	if runtime != null:
		return StringName(String(runtime.call("get_starting_skill_id")))
	return &""


func sync_trait_state(state: Dictionary) -> void:
	if runtime != null:
		runtime.set("trait_runtime_state", state.duplicate(true))
