## Rank-only callers must not build defensive profiles or reflect property metadata.
extends SceneTree
const Resolver = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const Counter = preload("res://scripts/skills/skill_resource_counter.gd")
const Bus = preload("res://scripts/skills/skill_event_bus.gd")
const Instance = preload("res://scripts/skills/skill_instance.gd")
const Definition = preload("res://scripts/skills/skill_definition.gd")
class CountingTarget:
 extends Node2D
 var list_reads: int = 0
 var current_health: int = 100
 var max_health: int = 100
 var armor: float = 7.0
 var defense: float = 9.0
 var resistances: Dictionary = {"fire":0.1}
 var player_damage_reduction_total: float = 0.2
 func _get_property_list() -> Array[Dictionary]:
  list_reads += 1
  return []
var resolver_script: Script = Resolver
var failed: int = 0
func _init() -> void: call_deferred("run")
func expect(value: bool,label: String) -> void:
 print(("PASS " if value else "FAIL ")+label)
 if not value: failed += 1
func run() -> void:
 expect(resolver_script.has_method("classify_target"),"rank-only classification API exists")
 if not resolver_script.has_method("classify_target"): quit(1); return
 expect(classify(null) == &"normal","null target defaults to normal")
 var target := CountingTarget.new()
 root.add_child(target)
 for rank: String in ["normal","elite","boss","future_rank",""]:
  target.set_meta("enemy_rank",rank)
  target.list_reads = 0
  expect(classify(target) == StringName(rank),"classification preserves live rank "+rank)
  expect(target.list_reads == 0,"classification never reflects properties for "+rank)
 target.set_meta("enemy_rank","boss")
 target.add_to_group(&"player")
 expect(classify(target) == &"player","player group takes priority over enemy_rank")
 target.remove_from_group(&"player")
 target.remove_meta("enemy_rank")
 expect(classify(target) == &"normal","missing rank defaults to normal after metadata change")
 verify_full_profile(target)
 verify_resource_counter(target)
 verify_bus_metric(target)
 target.free()
 print("[verify_target_classification_hot_path] failures=",failed)
 quit(1 if failed > 0 else 0)
func classify(target: Node) -> StringName:
 return resolver_script.call("classify_target",target)
func verify_full_profile(target: CountingTarget) -> void:
 target.armor = 17.0
 target.defense = 23.0
 target.resistances = {"fire":0.3}
 var first: RefCounted = Resolver.resolve(target)
 expect(first.armor == 17.0 and first.defense == 23.0 and first.resistances == {"fire":0.3},"full resolve retains current defensive values")
 first.resistances.fire = 0.9
 expect(target.resistances.fire == 0.3,"full resolve retains independent resistance snapshot")
 target.armor = 31.0
 target.defense = 41.0
 target.resistances.fire = 0.5
 target.player_damage_reduction_total = 0.4
 var second: RefCounted = Resolver.resolve(target)
 expect(second.armor == 31.0 and second.defense == 41.0 and second.resistances.fire == 0.5 and second.incoming_damage_reduction == 0.4,"full resolve remains fresh after defensive mutation")
func verify_resource_counter(target: CountingTarget) -> void:
 var skill: RefCounted = RefCounted.new()
 var context: Dictionary = {"target":target,"event_name":&"status_tick","status_id":&"burning","origin_skill_id":&"fire_attack_searing","status":{"coalesced_tick_count":1}}
 target.set_meta("enemy_rank","normal")
 target.list_reads = 0
 expect(Counter.event_amount(skill,"core","burning",context) == 0.0,"normal targets do not grant elite resource ticks")
 expect(target.list_reads == 0,"resource counter normal-rank rejection avoids full resolve")
 target.set_meta("enemy_rank","elite")
 var total: float = 0.0
 for index: int in range(5):
  context.event_id = index
  total += Counter.event_amount(skill,"core","burning",context)
 expect(total == 1.0,"five elite burning ticks still grant exactly one resource")
 expect(Counter.event_amount(skill,"core","burning",context) == 0.0,"duplicate elite event remains deduplicated")
 target.set_meta("enemy_rank","boss")
 context.event_id = 10
 context.status.coalesced_tick_count = 5
 expect(Counter.event_amount(skill,"core","burning",context) == 1.0,"boss coalesced ticks still grant resource")
 expect(target.list_reads == 0,"resource counter elite and boss classification avoids reflection")
 context.event_name = &"on_enemy_killed"
 expect(Counter.event_amount(skill,"death","burning",context) == 1.0 and Counter.event_amount(skill,"death","burning",context) == 0.0,"death resource remains once per corpse")
func verify_bus_metric(target: CountingTarget) -> void:
 var bus: Node = Bus.new()
 var skill: RefCounted = Instance.new(Definition.new({"id":"rank_fixture","school":"fire","skill_type":"passive","max_level":1}))
 target.set_meta("enemy_rank","boss")
 target.list_reads = 0
 bus.call("_execute_event_list",&"attack_hit",{"target":target,"origin_skill_id":&"rank_fixture"},skill,[{"trigger":&"attack_hit","actions":[]}])
 expect(target.list_reads == 0,"bus boss-trigger classification avoids full resolve")
 var clock: Node = bus.get("_clock")
 clock.free()
 bus.free()
