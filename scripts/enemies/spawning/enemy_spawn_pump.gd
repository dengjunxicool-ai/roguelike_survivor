## 驱动生成失败重试；使用弱引用，生成服务和 owner 不形成持有环。
extends Node
var service: RefCounted
func _physics_process(delta: float) -> void:
	if service != null:
		service.call("retry_pending",delta)
		if not bool(service.call("has_work")):
			queue_free()
func _exit_tree() -> void:
	if service != null:
		service.call("cancel_all",&"owner_exit",false)
