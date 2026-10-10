## 文件用途：锁定环形弹幕的原点与安全缺口，预警结束后请求完整释放。
extends Node2D

const Telegraph = preload("res://scripts/enemies/combat/enemy_attack_telegraph.gd")
signal enemy_attack_finished(generation: int)
var spawn_generation := 1
var _owner: WeakRef
var _elapsed := 0.0
var _warning := 0.6
var _finished := false
var _release: Callable
var _telegraph: Node2D

func setup(owner: Node, params: Dictionary, release: Callable) -> void:
	_owner = weakref(owner)
	_release = release
	_warning = maxf(float(params.get("warning_time", 0.6)), 0.001)
	_telegraph = Telegraph.new()
	add_child(_telegraph)
	_telegraph.call("configure", &"ring", params)

func _physics_process(delta: float) -> void:
	if _finished:
		return
	var owner: Node = _owner.get_ref() as Node
	if owner == null or owner.is_queued_for_deletion() or owner.get("_is_dead") == true:
		despawn_or_free()
		return
	_elapsed += delta
	_telegraph.call("set_progress", _elapsed / _warning)
	if _elapsed + 0.000001 >= _warning:
		_release_ring()

func _release_ring() -> void:
	if _finished:
		return
	_release.call()
	despawn_or_free()

func despawn_or_free() -> void:
	_finish()
	queue_free()

func _finish() -> void:
	if not _finished:
		_finished = true
		enemy_attack_finished.emit(spawn_generation)

func _exit_tree() -> void:
	_finish()
