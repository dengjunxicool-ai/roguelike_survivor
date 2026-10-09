## 文件用途：保留敌人状态展示接口，并统一清空和隐藏已有状态标签。
## 使用方式：setup 绑定敌人后 update(snapshot)；当前实现忽略快照，不创建或显示状态文字。

extends RefCounted
class_name EnemyStatusDisplayController


var _owner: Node2D
var _status_label: Label


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner


## 作用：清空并隐藏敌人场景中已有的 StatusLabel。
## 使用：先 setup 绑定 owner；_snapshot 当前不被读取，调用不会显示状态文字。
func update(_snapshot: Array[Dictionary]) -> void:
	if _owner == null:
		return

	_hide_existing_label()


## 作用：查找并缓存 StatusLabel，再清空文字并关闭可见性。
## 使用：由 update 调用；没有有效标签时直接返回，不新建控件。
func _hide_existing_label() -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		_status_label = _owner.get_node_or_null("StatusLabel") as Label
	if _status_label == null:
		return
	_status_label.text = ""
	_status_label.visible = false
