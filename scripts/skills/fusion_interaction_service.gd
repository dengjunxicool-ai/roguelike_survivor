extends RefCounted
const Geometry = preload("res://scripts/skills/skill_object_geometry.gd")
const Areas = preload("res://scripts/combat/area_effect_manager.gd")
var _contacts: Dictionary = {}
func reset() -> void: _contacts.clear()
func key(object: Node) -> String:
 return "%d:%d" % [object.get_instance_id(),int(object.get("spawn_generation"))]
func clear_object(object: Node) -> void:
 var prefix: String = "%d:" % object.get_instance_id()
 for id: String in _contacts.keys():
  if id.begins_with(prefix) or id.split("/")[1].begins_with(prefix): _contacts.erase(id)
func observe_area(bus: Node,area: Node2D) -> void:
 if not bus.interaction_interest(&"area_overlap",area): return
 var shape: Dictionary = area.geometry_shape()
 var active: Dictionary = {}
 for other: Node in Areas.get_or_create(area).query_areas(Geometry.bounds(shape)):
  if other == area or other.get("caster") != area.get("caster") or not bus.area_pair_relevant(area,other): continue
  if not Geometry.overlaps(shape,other.geometry_shape()): continue
  var pair: String = key(area)+"/"+key(other)
  active[pair] = true
  var entered: bool = not _contacts.has(pair)
  if entered: _contacts[pair] = {"object":weakref(area),"other":weakref(other),"next_emit":0.0}
  if float(_contacts[pair].next_emit)>bus.combat_seconds(): continue
  _contacts[pair].next_emit=bus.combat_seconds()+1.0
  bus.emit_skill_event(&"area_overlap",_context(bus,area,{"other_area":other,"interaction_key":pair,"interaction_entered":entered}))
 _remove_exited(key(area)+"/",active)
func observe_projectile(bus: Node,object: Node2D,from: Vector2,to: Vector2,radius: float) -> void:
 if not bus.interaction_interest(&"projectile_area_entered",object): return
 var active: Dictionary = {}
 var box: Rect2 = Rect2(from,Vector2.ZERO).expand(to).grow(radius)
 for area: Node in Areas.get_or_create(object).query_areas(box):
  if area.get("caster") != object.get("caster"): continue
  var pair: String = key(object)+"/"+key(area)
  var shape: Dictionary = area.geometry_shape()
  if Geometry.contains(shape,to): active[pair] = true
  if not _contacts.has(pair) and Geometry.swept(shape,from,to,radius):
   _contacts[pair] = {"object":weakref(object),"other":weakref(area)}
   bus.emit_skill_event(&"projectile_area_entered",_context(bus,object,{"projectile":object,"area":area,"interaction_key":pair,"interaction_entered":true,"position":to}))
 _remove_exited(key(object)+"/",active)
func _remove_exited(prefix: String,active: Dictionary) -> void:
 for pair: String in _contacts.keys():
  if pair.begins_with(prefix) and not active.has(pair): _contacts.erase(pair)
func _context(bus: Node,object: Node2D,extra: Dictionary) -> Dictionary:
 var c: Dictionary = {"caster":object.caster,"owner":object.caster,"skill_manager":object.skill_manager,"event_bus":bus,"parent":object.get_parent(),"position":object.global_position,"origin_skill_id":object.damage_packet.get("origin_skill_id",object.damage_packet.get("source_skill_id",object.source_id)),"damage_packet":object.damage_packet,"source":object}
 if object.has_method("geometry_shape"): c["area"] = object
 c.merge(extra,true)
 return c
