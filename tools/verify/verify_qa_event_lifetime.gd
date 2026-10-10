extends SceneTree
const F = preload("res://tools/verify/skill_rebalance_fixture.gd")
const Context = preload("res://scripts/skills/skill_event_context.gd")
const Area = preload("res://scenes/combat/area_effect.tscn")
var failures: int = 0
var events: Array[Dictionary] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error("[qa-lifetime] " + label)
func run() -> void:
	create_timer(15.0).timeout.connect(func() -> void: push_error("[qa-lifetime] timeout"); quit(1))
	var c: Dictionary = F.build(self)
	c.event_bus.subscribe(&"area_tick", func(context: Dictionary) -> void: events.append(context))
	var source: Node2D = Node2D.new()
	root.add_child(source)
	var area: Area2D = Area.instantiate()
	root.add_child(area)
	area.setup({"caster":source, "event_bus":c.event_bus, "source_id":"qa_enemy_zone", "damage":10, "damage_packet":{"raw_amount":10,"source_id":"qa_enemy_zone","damage_origin":"field"},"duration":10.0})
	area.set_physics_process(false)
	source.free()
	check(area._damage_body(c.target), "real residual area still hits")
	check(c.target.packets.size() == 1 and c.target.packets[0].raw_amount == 10, "residual damage snapshot survives source death")
	check(events.size() == 1, "residual event dispatched once after source death")
	if not events.is_empty(): check(events[0].has("caster") and events[0].get("caster") == null and events[0].get("source_id") == "qa_enemy_zone", "invalid caster removed, numeric origin preserved")
	var dead: Node = Node.new()
	var input: Dictionary = {"target":dead,"skill_manager":dead,"caster":dead,"nested":{"nodes":[[dead]]},"origin_skill_id":"qa_origin"}
	dead.free()
	var normalized: Dictionary = Context.from_context(input, &"area_tick")
	check(normalized.get("target") == null and normalized.get("caster") == null, "invalid target and caster normalized before casts")
	check(normalized.get("nested",{}).get("nodes",[[]])[0][0] == null, "nested array invalid references purged")
	check(normalized.get("origin_skill_id") == &"qa_origin", "origin identity retained")
	print("[qa-lifetime] failures=", failures)
	quit(1 if failures else 0)
