## 文件用途：按实际攻击实例与生成代次限制 Boss 并发，失败撤回本次创建。
extends RefCounted

var _tokens: Dictionary = {}
var _next_token := 0
var _cast_gap := 0.0

func setup(_owner: Node) -> void:
	reset()

func try_reserve(skill_id: StringName, group: StringName, cap: int) -> int:
	if _cast_gap > 0.000001 or _tokens.size() >= cap:
		return -1
	for record: Dictionary in _tokens.values():
		if record.skill_id == skill_id or group == &"area_denial" and record.group == group:
			return -1
	_next_token += 1
	_tokens[_next_token] = {"skill_id": skill_id, "group": group, "committed": false, "nodes": {}}
	return _next_token

func attach(token: int, node: Node) -> void:
	if not _tokens.has(token) or node == null:
		return
	var generation: int = int(node.get("spawn_generation"))
	var id := node.get_instance_id()
	var finished := Callable(self, "_on_finished").bind(token, id, generation)
	var exited := Callable(self, "_on_exited").bind(token, id, generation)
	_tokens[token].nodes[id] = {"ref": weakref(node), "generation": generation, "finished": finished, "exited": exited}
	node.connect("enemy_attack_finished", finished)
	node.tree_exiting.connect(exited)

func commit(token: int) -> void:
	if not _tokens.has(token):
		return
	_tokens[token].committed = true
	_cast_gap = 0.4
	if _tokens[token].nodes.is_empty():
		_tokens.erase(token)

func cancel(token: int) -> void:
	if not _tokens.has(token):
		return
	var nodes: Dictionary = _tokens[token].nodes
	_tokens.erase(token)
	for entry: Dictionary in nodes.values():
		var node: Node = entry.ref.get_ref() as Node
		_disconnect(node, entry)
		if node != null and node.get("spawn_generation") == entry.generation:
			if node.has_method("despawn_or_free"):
				node.call("despawn_or_free")
			else:
				node.queue_free()

func tick(delta: float) -> void:
	_cast_gap = maxf(_cast_gap - delta, 0.0)
	for token: int in _tokens.keys():
		for id: int in _tokens[token].nodes.keys():
			var entry: Dictionary = _tokens[token].nodes[id]
			var node: Node = entry.ref.get_ref() as Node
			if node == null or node.is_queued_for_deletion() or node.get("spawn_generation") != entry.generation:
				_on_finished(entry.generation, token, id, entry.generation)
				if not _tokens.has(token):
					break

func reset() -> void:
	for token: int in _tokens.keys():
		cancel(token)
	_cast_gap = 0.0

func _on_exited(token: int, id: int, generation: int) -> void:
	_on_finished(generation, token, id, generation)

func _on_finished(emitted_generation: int, token: int, id: int, expected_generation: int) -> void:
	if emitted_generation != expected_generation or not _tokens.has(token) or not _tokens[token].nodes.has(id):
		return
	var entry: Dictionary = _tokens[token].nodes[id]
	_disconnect(entry.ref.get_ref() as Node, entry)
	_tokens[token].nodes.erase(id)
	if _tokens[token].committed and _tokens[token].nodes.is_empty():
		_tokens.erase(token)

func _disconnect(node: Node, entry: Dictionary) -> void:
	if node == null:
		return
	if node.is_connected("enemy_attack_finished", entry.finished):
		node.disconnect("enemy_attack_finished", entry.finished)
	if node.tree_exiting.is_connected(entry.exited):
		node.tree_exiting.disconnect(entry.exited)
