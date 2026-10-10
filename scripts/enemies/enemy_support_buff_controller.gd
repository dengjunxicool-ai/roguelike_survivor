## 文件用途：仅在敌人内部维护支援来源，同类效果取最强，来源死亡立即失效。
extends RefCounted
const Marker = preload("res://scripts/enemies/combat/enemy_support_marker.gd")
var _sources: Dictionary = {}
var _owner: WeakRef
var _marker: Node2D
func setup(owner: Node) -> void:
	_owner = weakref(owner)
func refresh(source: Node, effects: Array[Dictionary], duration: float) -> void:
	if not is_instance_valid(source) or duration <= 0.0:
		return
	var multiplier := 1.0
	for effect: Dictionary in effects:
		if effect.get("stat") != "move_speed" or effect.get("op") != "multiply" or effect.get("scope") != {"tag": "movement"} or effect.get("source") != "war_drum":
			return
		var value: Variant = effect.get("value")
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 1.0:
			return
		multiplier = maxf(multiplier, float(value))
	_sources[source.get_instance_id()] = {"source": weakref(source), "remaining": duration, "multiplier": multiplier}
	_update_marker()
func tick(delta: float) -> void:
	for id: int in _sources.keys():
		_sources[id].remaining -= delta
	_prune()
	_update_marker()
func get_move_speed_multiplier() -> float:
	_prune()
	var result := 1.0
	for entry: Dictionary in _sources.values():
		result = maxf(result, float(entry.multiplier))
	return result
func clear() -> void:
	_sources.clear()
	_update_marker()
func _prune() -> void:
	for id: int in _sources.keys():
		var entry: Dictionary = _sources[id]
		var source: Node = entry.source.get_ref() as Node
		if entry.remaining <= 0.0 or source == null or source.is_queued_for_deletion() or source.get("_is_dead") == true:
			_sources.erase(id)
func _update_marker() -> void:
	var owner: Node = _owner.get_ref() as Node if _owner != null else null
	if owner == null:
		return
	if not _sources.is_empty() and not is_instance_valid(_marker):
		_marker = Marker.new()
		_marker.position = Vector2(0, 20)
		owner.add_child(_marker)
	if is_instance_valid(_marker):
		_marker.visible = not _sources.is_empty()
