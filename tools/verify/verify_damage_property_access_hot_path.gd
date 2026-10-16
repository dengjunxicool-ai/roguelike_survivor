## Optional combat reads preserve dynamic metadata and avoid static property-list allocation.
extends SceneTree
const ReaderPath: String = "res://scripts/combat/optional_combat_property_reader.gd"
const Resolver = preload("res://scripts/combat/target_damage_profile_resolver.gd")
const Scaling = preload("res://scripts/combat/damage_output_scaling.gd")
const Context = preload("res://scripts/combat/damage_calculation_context.gd")
const Packet = preload("res://scripts/combat/damage_packet.gd")
class StaticValues:
 extends Node2D
 var damage_multiplier: float = 1.25
 var fire_damage_multiplier_add: float = 0.2
 var empty_value: Variant = null
class OnlyGet:
 extends Node2D
 var getter_reads: int = 0
 func _get(key: StringName) -> Variant:
  getter_reads += 1
  return 99.0 if key == &"field_damage_multiplier_add" else null
class InheritedOnlyGet:
 extends OnlyGet
class DynamicOutput:
 extends Node2D
 var list_reads: int = 0
 var read_order: Array[String] = []
 var unlocked: bool = false
 func _get_property_list() -> Array[Dictionary]:
  list_reads += 1
  var out: Array[Dictionary] = [{"name":"damage_multiplier","type":TYPE_FLOAT}]
  if unlocked:
   for key: String in ["field_damage_multiplier_add","area_damage_multiplier_add","fire_damage_multiplier_add","boss_damage_multiplier_add"]: out.append({"name":key,"type":TYPE_FLOAT})
  return out
 func _get(key: StringName) -> Variant:
  read_order.append(String(key))
  if key == &"damage_multiplier": unlocked = true; return 1.25
  return 0.1
class Validated:
 extends Node2D
 var checks: int = 0
 var damage_multiplier: float = 1.5
 func _validate_property(_property: Dictionary) -> void: checks += 1
var reader: Script
var failed: int = 0
func _init() -> void: call_deferred("run")
func expect(ok: bool,label: String) -> void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok: failed += 1
func run() -> void:
 expect(ResourceLoader.exists(ReaderPath),"shared optional combat property reader exists")
 if not ResourceLoader.exists(ReaderPath): quit(1); return
 reader = load(ReaderPath)
 var plain := StaticValues.new()
 root.add_child(plain)
 expect(not reader.uses_dynamic_properties(plain),"ordinary object uses static direct-get path")
 expect(reader.read_float(plain,"damage_multiplier",1.0)==1.25,"static current value is read")
 expect(reader.read_float(plain,"missing",7.0)==7.0,"static missing key uses fallback")
 expect(reader.read_float(plain,"empty_value",7.0)==7.0,"static explicit null uses fallback")
 expect(reader.read_float(null,"missing",7.0)==7.0,"null object uses fallback")
 plain.damage_multiplier = 1.75
 expect(reader.read_float(plain,"damage_multiplier",1.0)==1.75,"next read observes current value without cache")
 plain.free()
 for inherited: bool in [false,true]:
  var hidden: OnlyGet = InheritedOnlyGet.new() if inherited else OnlyGet.new()
  root.add_child(hidden)
  expect(reader.uses_dynamic_properties(hidden),"direct or inherited _get keeps metadata whitelist")
  hidden.getter_reads = 0
  expect(reader.read_float(hidden,"field_damage_multiplier_add",0.0)==0.0,"unlisted dynamic _get value remains ignored")
  expect(hidden.getter_reads==0,"unlisted dynamic value getter is never called")
  hidden.free()
 var validated := Validated.new()
 root.add_child(validated)
 validated.checks = 0
 expect(reader.uses_dynamic_properties(validated),"validate_property retains original metadata path")
 expect(reader.read_float(validated,"damage_multiplier",1.0)==1.5 and validated.checks>0,"validate_property executes before listed value getter")
 validated.free()
 var dynamic := DynamicOutput.new()
 root.add_child(dynamic)
 dynamic.list_reads = 0
 dynamic.read_order.clear()
 dynamic.unlocked = false
 var target := Node2D.new()
 root.add_child(target)
 target.set_meta("enemy_rank","boss")
 var packet: DamagePacket = Packet.from_dictionary({"raw_amount":100,"amount":100,"damage_origin":"field","damage_type":"area_direct","element":"fire","attacker":dynamic,"uses_character_damage_multiplier":true})
 var context: DamageCalculationContext = Context.create(packet,target,dynamic)
 var character: float = Scaling.character_damage_multiplier_for_context(context)
 var origin: float = Scaling.origin_bonus_total_for_context(context)
 var element: float = Scaling.element_bonus_total_for_context(context)
 var rank: float = Scaling.enemy_type_bonus_total_for_context(context)
 expect(is_equal_approx(character,1.25) and is_equal_approx(origin,0.2) and is_equal_approx(element,0.1) and is_equal_approx(rank,0.1),"dynamic outgoing values preserve live schema changes")
 expect(dynamic.list_reads==5,"dynamic outgoing re-enumerates for each original read")
 expect(dynamic.read_order==["damage_multiplier","field_damage_multiplier_add","area_damage_multiplier_add","fire_damage_multiplier_add","boss_damage_multiplier_add"],"dynamic outgoing getter order is unchanged")
 target.free()
 dynamic.free()
 verify_actual("res://scenes/enemies/enemy.tscn")
 verify_actual("res://scenes/characters/player.tscn")
 reader = null
 await process_frame
 await process_frame
 print("[verify_damage_property_access_hot_path] failures=",failed)
 quit(1 if failed>0 else 0)
func verify_actual(path: String) -> void:
 var target: Node = load(path).instantiate()
 root.add_child(target)
 target.set_physics_process(false)
 var executor: Node = target.get_node_or_null("SkillExecutor")
 if executor != null: executor.set_physics_process(false)
 expect(not reader.uses_dynamic_properties(target),"real target uses direct get: "+path)
 expect(reader.read_float(target,"field_damage_multiplier_add",0.0)==0.0,"absent real outgoing bonus remains zero: "+path)
 target.armor = 13
 var first: RefCounted = Resolver.resolve(target)
 expect(first.armor==13.0 and first.defense==13.0,"real target defense fallback remains armor: "+path)
 target.armor = 21
 expect(Resolver.resolve(target).armor==21.0,"real target next resolve stays live: "+path)
 target.queue_free()
