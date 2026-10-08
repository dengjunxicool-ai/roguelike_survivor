extends SceneTree

const Source: Script = preload("res://scripts/modifiers/modifier_source.gd")
const Query: Script = preload("res://scripts/modifiers/modifier_query.gd")
const Calculator: Script = preload("res://scripts/skills/skill_modifier.gd")
const Relics: Script = preload("res://scripts/relics/relic_manager.gd")
const Store: Script = preload("res://scripts/modifiers/modifier_store.gd")
var failed: bool = false

class Owner:
	extends Node
	var registered: Array = []
	func set_run_modifier_source(_id: String, effects: Array) -> void:
		registered = effects.duplicate(true)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var effects: Array = [
		{"stat": "damage", "op": "add", "value": 10, "scope": {}, "source": "skill"},
		{"stat": "damage", "op": "add", "value": 5, "scope": {}, "source": "skill"},
		{"stat": "damage", "op": "multiply", "value": 2, "scope": {}, "source": "skill"},
		{"stat": "damage", "op": "multiply", "value": 3, "scope": {}, "source": "skill"},
		{"stat": "damage", "op": "multiplier_add", "value": 0.5, "scope": {}, "source": "skill"}
	]
	if not Source.has_method("flatten_effects"):
		_expect(false, "strict effect-list entry exists")
	else:
		var flat: Dictionary = Source.flatten_effects(effects)
		_expect(Calculator.calculate(100, "damage", flat) == 1035, "add before additive multiplier before product")
		effects.append({"stat": "damage", "op": "override", "value": 7, "scope": {}, "source": "skill"})
		effects.append({"stat": "damage", "op": "override", "value": 9, "scope": {}, "source": "skill"})
		_expect(Calculator.calculate(100, "damage", Source.flatten_effects(effects)) == 9, "last override wins")
		var scoped: Array = [{"stat": "damage", "op": "multiplier_add", "value": 0.2, "scope": {"domain": "damage", "element": ["fire"]}, "source": "relic"}]
		var fire: RefCounted = Query.for_damage(DamagePacket.from_dictionary({"raw_amount": 1, "source_instance_id": "scope:fire", "element": "fire"}))
		var ice: RefCounted = Query.for_damage(DamagePacket.from_dictionary({"raw_amount": 1, "source_instance_id": "scope:ice", "element": "ice"}))
		_expect(Source.flatten_effects(scoped, "relic", fire).get("fire_damage_multiplier_add") == 0.2, "matching element scope")
		_expect(Source.flatten_effects(scoped, "relic", ice).is_empty(), "nonmatching scope filtered")
		_expect(not Source.validate_effects({"damage_add": 1}).is_empty(), "flat config rejected")
		_expect(not Source.validate_effects([{"stat": "damage", "op": "mystery", "value": 1, "scope": {}, "source": "skill"}]).is_empty(), "unknown operation rejected")
	var snapshot: Dictionary = {"damage_add": 3}
	var copy: Dictionary = Source.flatten(snapshot)
	copy["damage_add"] = 99
	_expect(snapshot.damage_add == 3, "snapshot output remains independent")
	var store: Node = Store.new()
	store.set_source("mixed", {"damage_add": 2}, [&"skill"])
	store.merge_source("mixed", [{"stat": "damage", "op": "add", "value": 3, "scope": {"domain": "skill"}, "source": "skill"}], [&"skill"])
	var query: RefCounted = Query.new()
	query.scope = &"skill"
	_expect(store.collect(query).get("damage_add") == 5, "store merges explicit snapshot and effects in order")
	store.free()
	var owner := Owner.new()
	root.add_child(owner)
	var relics: Node = Relics.new()
	owner.add_child(relics)
	relics.call("_register_modifier_block", "test:negative", [{"stat": "damage_taken", "op": "multiplier_add", "value": 0.08, "scope": {"domain": "player"}, "source": "relic"}])
	_expect(owner.registered.size() == 1, "negative effect array registered")
	owner.registered.clear()
	relics.set("_relic_definitions", {&"shieldbreaker_covenant": {"id": "shieldbreaker_covenant", "negative_modifier": [{"stat": "damage_taken", "op": "multiplier_add", "value": 0.08, "scope": {"domain": "player"}, "source": "relic"}]}})
	_expect(bool(relics.call("add_relic", &"shieldbreaker_covenant")), "configured negative relic added")
	_expect(owner.registered.size() == 1, "add_relic retains configured negative Array")
	owner.queue_free()
	await process_frame
	if not failed:
		print("[verify_modifier_effect_contract] PASS")
	quit(1 if failed else 0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("[verify_modifier_effect_contract] FAIL " + label)
