extends "res://tools/verify/verify_fusion_semantics_v2.gd"
const Query=preload("res://scripts/modifiers/modifier_query.gd")
const Aggregator=preload("res://scripts/modifiers/modifier_aggregator.gd")
var exercised: Array[String]=[]
func run() -> void:
 setup()
 player.get_node("ModifierStore").set_physics_process(false)
 enemy.get_node("StatusEffectManager").set_physics_process(false)
 nearby=[]
 for i: int in 6: nearby.append(make_enemy(Vector2(80+20*i,0)))
 for e: Enemy in nearby: e.get_node("StatusEffectManager").set_physics_process(false)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/base_skill_behavior_cases.json"))
 for row: Dictionary in data.cases:
  clean_base();await process_frame
  if row.get("status","")!="" and row.kind!="status": enemy.apply_status(StringName(row.status),{"stacks":1,"duration":6,"power":100})
  var skill: RefCounted=install(StringName(row.id))
  if row.kind=="modifier":
   var query_skill: RefCounted=install(&"thunder_cast_chain_lightning")
   var q: RefCounted=Query.for_skill(query_skill,player)
   var values: Dictionary=Aggregator.collect(q,manager)
   for stat: String in row.stats: expect(is_equal_approx(float(values.get(stat,0)),float(row.stats[stat])),row.id+" real query "+stat)
   manager.clear_skills()
   values=Aggregator.collect(q,manager)
   for stat: String in row.stats: expect(is_zero_approx(float(values.get(stat,0))),row.id+" removal stops "+stat)
  else:
   var c: Dictionary=ctx(enemy,skill)
   c.damage_packet={"element":"lightning"};c.damage_amount=100.0
   c.status_id=StringName(row.get("status",""));c.source_tags=[&"ice_mist"]
   # Counterexamples use the actual wrong event; no dummy listener event is added.
   bus.emit_skill_event(&"attack_hit" if row.event!="attack_hit" else &"dash_end",c)
   expect(measure(row)==0,row.id+" unrelated event has no output")
   if row.get("status","")!="" and row.kind!="status":
    c.target_statuses=enemy.get_node("StatusEffectManager").get_status_snapshot()
   if row.id=="chaos_power_chaos_exchange":
    for e: Enemy in nearby.slice(0,2): e.apply_status(&"instability",{"stacks":1})
   if row.kind=="timed":
    c.target=player;player.add_to_group(&"player")
   var threshold: int=int(row.get("threshold",1))
   for i: int in threshold:
    if row.event=="on_enemy_killed" and threshold>1 and row.id!="curse_summon_bone_servant":
     var corpse: Enemy=make_enemy(Vector2(40,0));fixture_objects.append(corpse)
     corpse.get_node("StatusEffectManager").set_physics_process(false)
     corpse.apply_status(StringName(row.status),{"stacks":1,"power":100})
     corpse.current_health=0;c.target=corpse;c.position=corpse.position
     c.target_statuses=corpse.get_node("StatusEffectManager").get_status_snapshot()
    c.resolution_id=row.id+str(i)
    c.event_id=100+i
    bus.emit_skill_event(StringName(row.event),c)
    await physics_frame
    bus.process_pending_events()
    if threshold>1 and i==threshold-2: expect(measure(row)==0,row.id+" below threshold no output")
   await process_frame
   for node: Node in root.get_children():
    if node.has_method("geometry_shape") or node.has_method("_begin_return") or node.has_meta("summon_definition_id"): node.set_physics_process(false)
   if row.kind=="timed" or row.kind=="charge":
    var probe: RefCounted=install(&"fire_cast_lava_rift")
    var actual: float=float(Aggregator.collect(Query.for_skill(probe,player),manager).get("damage_multiplier_add",0))
    if row.kind=="charge": actual=float(player.get_node("ModifierStore").get_cast_charge_snapshot().multiplier)-1.0
    expect(is_equal_approx(actual,float(row.modifier)),row.id+" actual cast damage source")
    if row.kind=="timed":
     player.get_node("ModifierStore").tick_timed_sources(5.01)
     expect(is_zero_approx(float(Aggregator.collect(Query.for_skill(probe,player),manager).get("damage_multiplier_add",0))),row.id+" expires after five seconds")
   else:
    var wanted: float=float(row.get("count",row.get("stacks",row.get("shield",row.get("damage",row.get("health",510)-500)))))
    expect(is_equal_approx(measure(row),wanted),row.id+" actual output "+str(measure(row))+" expected "+str(wanted))
   if row.id=="frost_power_ice_mist_guard":
    var break_row: Dictionary={"kind":"area","output":"frost_ring"}
    c.source_tags=[&"wrong_shield"]
    bus.emit_skill_event(&"shield_broken",c)
    expect(objects_for(break_row).is_empty(),"ice mist ignores another shield breaking")
    c.source_tags=[&"ice_mist"]
    bus.emit_skill_event(&"shield_broken",c)
    await process_frame
    expect(objects_for(break_row).size()==1,"actual ice mist shield break emits one cold ring")
   if row.has("value"):
    for obj: Node in objects_for(row):
     if row.kind=="area": expect(is_equal_approx(obj.duration,float(row.value)),row.id+" real duration")
     elif float(row.value)>0: expect(is_equal_approx(obj.damage,float(row.value)),row.id+" real projectile damage")
  exercised.append(row.id)
 clean_base();await process_frame
 expect(exercised.size()+data.bindings.size()==84,"84 unique base IDs have behavior fixtures or executed specialized bindings")
 if failed==0: print("[verify_base_skill_behavior_v2] PASS")
 finish()
func measure(row: Dictionary) -> float:
 match String(row.kind):
  "status": return enemy.get_status_stack(StringName(row.status))
  "heal": return player.current_health-500
  "shield": return int(player.get_meta("fire_passive_shield",0))
  "spread":
   var total: int=0
   for e: Enemy in nearby: total+=e.get_status_stack(&"cursed")
   return total
  "damage":
   var total: float=0
   for p: Dictionary in enemy.packets: total+=float(p.raw_amount)
   return total
  "charge": return player.get_node("ModifierStore").get("_cast_charges").size()
  "timed": return float(Aggregator.collect(Query.for_skill(Fixture.skill(),player),manager).get("damage_multiplier_add",0))
  _: return objects_for(row).size()
func objects_for(row: Dictionary) -> Array:
 var out: Array=[]
 if not row.has("output"): return out
 for node: Node in root.get_children():
  if node.is_queued_for_deletion(): continue
  if row.kind=="summon":
   if String(node.get_meta("summon_definition_id",node.get_meta("action_summon_id",node.name)))==String(row.output): out.append(node)
  elif node.has_method("geometry_shape") or node.has_method("_begin_return"):
   if String(node.source_id)==String(row.output): out.append(node)
 return out
func clean_base() -> void:
 clean()
 player.current_health=500
 for node: Node in root.get_children():
  if node.has_meta("summon_definition_id") or node.has_meta("action_summon_id"): node.queue_free()
