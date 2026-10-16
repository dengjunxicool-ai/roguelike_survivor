## 触发规则先按事件过滤；无关规则不计算成长，匹配规则仍逐次读取等级/品质。
extends SceneTree
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
const Definition = preload("res://scripts/skills/skill_definition.gd")
const Bus = preload("res://scripts/skills/skill_event_bus.gd")
class CountingInstance:
 extends RefCounted
 var definition: RefCounted
 var level_reads: int = 0
 var level_value: int = 1
 var current_level: int:
  get:
   level_reads += 1
   return level_value
 var current_rarity: String = "normal"
 var runtime_events: Array[Dictionary] = []
 func _init(value: RefCounted) -> void: definition = value
class SkillOwner:
 extends Node
 var skills: Array[RefCounted] = []
 func get_all_skills() -> Array[RefCounted]: return skills
var adapter_script: Script = Adapter
var failed: int = 0
func _init() -> void: call_deferred("run")
func expect(condition: bool,label: String) -> void:
 print(("PASS " if condition else "FAIL ")+label)
 if not condition: failed += 1
func run() -> void:
 var supports_filter: bool = false
 for method: Dictionary in adapter_script.get_script_method_list():
  if String(method.name) == "to_events": supports_filter = method.args.size() >= 3
 expect(supports_filter,"to_events supports optional event filter while retaining two-argument API")
 if not supports_filter: quit(1); return
 verify_irrelevant_work()
 verify_equivalence_and_order()
 verify_growth_is_live()
 verify_real_build()
 verify_bus_paths()
 print("[verify_trigger_rule_event_filter] failures=",failed)
 quit(1 if failed > 0 else 0)
func filtered(skill: RefCounted,event: StringName) -> Array:
 return adapter_script.call("to_events",skill,skill.definition,event)
func old_filtered(skill: RefCounted,event: StringName) -> Array:
 var out: Array = []
 for entry: Dictionary in Adapter.to_events(skill,skill.definition):
  if entry.trigger == event: out.append(entry)
 return out
func make_skill(rules: Array) -> CountingInstance:
 return CountingInstance.new(Definition.new({"id":"filter_fixture","school":"fire","skill_type":"attack","rarity":"normal","max_level":5,"trigger_rules":rules}))
func verify_irrelevant_work() -> void:
 var skill := make_skill([{"trigger":"attack_hit","conditions":[{"type":"random_chance","chance_per_level":0.1}],"effects":[{"type":"damage","power_scale":2.0}]}])
 var out: Array = filtered(skill,&"status_tick")
 expect(out.is_empty(),"unrelated trigger returns no actions")
 expect(skill.level_reads == 0,"unrelated rule never reads current_level or calculates growth")
 var all: Array = Adapter.to_events(skill,skill.definition)
 expect(all.size() == 1 and skill.level_reads > 0,"legacy unfiltered API still adapts its rule")
func verify_equivalence_and_order() -> void:
 var skill := make_skill([
  {"trigger":"cast_skill","source_id":"first","effects":[{"type":"damage","power_scale":1.0}]},
  {"trigger":"attack_hit","effects":[{"type":"apply_status","status_id":"burning","stacks":1}]},
  {"trigger":"on_cast","source_id":"second","cooldown":0.7,"effects":[{"type":"damage","power_scale":2.0}]},
  {"trigger":"fixture_unknown_event","source_id":"unknown","effects":[{"type":"damage","power_scale":3.0}]},
  {"trigger":"","effects":[{"type":"damage","power_scale":4.0}]},
  {}])
 for event: StringName in [&"on_cast",&"attack_hit",&"fixture_unknown_event",&"never_occurs"]:
  expect(filtered(skill,event) == old_filtered(skill,event),"filtered payload equals legacy payload: "+String(event))
 var cast_events: Array = filtered(skill,&"on_cast")
 expect(cast_events.size() == 2 and cast_events[0].source_id == "first" and cast_events[1].source_id == "second","aliases normalize before filtering and preserve rule order")
 expect(filtered(skill,&"") == Adapter.to_events(skill,skill.definition),"empty filter retains unfiltered API")
 var empty := make_skill([])
 expect(filtered(empty,&"on_cast").is_empty(),"empty rule list remains empty")
 expect(adapter_script.call("to_events",null,null,&"on_cast").is_empty(),"null definition remains empty")
func verify_growth_is_live() -> void:
 var skill := make_skill([{"trigger":"attack_hit","conditions":[{"type":"random_chance","chance_per_level":0.1}],"effects":[{"type":"damage","power_scale":2.0}]}])
 var low: Array = filtered(skill,&"attack_hit")
 skill.level_value = 5
 skill.current_rarity = "epic"
 var high: Array = filtered(skill,&"attack_hit")
 expect(high == old_filtered(skill,&"attack_hit"),"level and rarity changes are reflected immediately")
 expect(float(high[0].actions[0].params.amount.scale) > float(low[0].actions[0].params.amount.scale),"matching damage still grows with level and rarity")
 expect(float(high[0].conditions[0].params.chance) > float(low[0].conditions[0].params.chance),"matching probability still reads current level")
func verify_real_build() -> void:
 var ids: Array[String] = ["fire_cast_meteor_rain","thunder_summon_storm_lynx","thunder_power_overload_burst","fire_attack_searing","fusion_fire_thunder_thunderburn_meteor","fire_summon_crimson_dragon","fire_core_inferno_cycle","thunder_passive_superconductor"]
 var events: Array[StringName] = [&"status_tick",&"status_applied",&"post_damage_hit",&"area_tick",&"status_max_stack_reached",&"on_enemy_killed",&"on_cast",&"attack_hit",&"summon_attack_hit"]
 var equivalent: bool = true
 var comparisons: int = 0
 for id: String in ids:
  var skill := CountingInstance.new(Definition.new(GameData.get_skill(StringName(id))))
  for level: int in [1,skill.definition.max_level]:
   skill.level_value = level
   for rarity: String in ["normal","epic"]:
    skill.current_rarity = rarity
    for event: StringName in events:
     equivalent = (filtered(skill,event) == old_filtered(skill,event)) and equivalent
     comparisons += 1
 expect(equivalent,"real eight-skill build preserves all "+str(comparisons)+" payload comparisons")
func verify_bus_paths() -> void:
 var source := make_skill([{"trigger":"attack_hit","effects":[{"type":"damage","power_scale":2.0}]}])
 var owned := make_skill([{"trigger":"cast_skill","effects":[{"type":"damage","power_scale":3.0}]}])
 var owner := SkillOwner.new()
 owner.skills = [source,owned]
 var bus: Node = Bus.new()
 # Drive the real source + owned dispatch paths with an unrelated DOT event.
 bus.call("_execute_skill_events",&"status_tick",{"skill_instance":source,"skill_manager":owner})
 expect(source.level_reads == 0,"real bus source path never grows an unrelated rule")
 expect(owned.level_reads == 0,"real bus owned path never grows an unrelated rule")
 expect(bus.call("_get_skill_events",source,source.definition,&"attack_hit") == old_filtered(source,&"attack_hit"),"real bus source matching payload is unchanged")
 # _ready() normally attaches the clock; this intentionally tree-free bus must free it explicitly.
 var clock: Node = bus.get("_clock")
 clock.free()
 bus.free()
 owner.free()
