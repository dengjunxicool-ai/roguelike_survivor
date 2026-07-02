extends RefCounted
class_name EnemyStatusDisplayController


var _owner: Node2D
var _status_label: Label


func setup(owner: Node2D) -> void:
	_owner = owner


func update(_snapshot: Array[Dictionary]) -> void:
	if _owner == null:
		return

	_hide_existing_label()


func _hide_existing_label() -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		_status_label = _owner.get_node_or_null("StatusLabel") as Label
	if _status_label == null:
		return
	_status_label.text = ""
	_status_label.visible = false
