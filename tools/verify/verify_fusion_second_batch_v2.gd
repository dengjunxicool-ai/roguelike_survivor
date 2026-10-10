extends "res://tools/verify/verify_fusion_semantics_v2.gd"
func run() -> void:
 setup()
 nearby=[make_enemy(Vector2(80,0)),make_enemy(Vector2(120,0)),make_enemy(Vector2(160,0)),make_enemy(Vector2(200,0))]
 for e: Enemy in [enemy]+nearby: e.get_node("StatusEffectManager").set_physics_process(false)
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json")).slice(30)
 expect(rows.size()==30,"second thirty independent contracts")
 for row: Dictionary in rows:
  for variant: String in ["wrong_event","missing_status_or_resource","wrong_source_or_spatial_object","positive"]:
   clean();await process_frame
   var c: Dictionary=second_fixture(row,variant)
   for id: String in row.required_skills: install(StringName(id))
   install(StringName(row.skill_id))
   var before: float=total_damage()
   var duration_before: float=float(enemy.get_node("StatusEffectManager").export_status(&"cursed").get("duration_remaining",0))
   var event: StringName=StringName(row.positive_fixture.event) if variant!="wrong_event" else &"never_a_fusion_event"
   for i: int in int(row.expected_behavior.get("repeat",1)):
    c.strike_id="fixture-strike-"+str(i)
    bus.emit_skill_event(event,c)
    if variant=="positive" and i<4 and int(row.expected_behavior.get("repeat",1))==5: expect(bus.fusion_output_count(row.skill_id)==0,"storm strikes one through four do not converge")
   if variant=="positive" and row.expected_behavior.has("delay"):
    expect(output_count(row.skill_id)==0,row.skill_id+" not before delay")
    advance(float(row.expected_behavior.delay));bus.update_skill_cycles()
   var count: int=bus.fusion_output_count(row.skill_id)
   expect(count==(1 if variant=="positive" else 0),row.skill_id+" "+variant+" outputs "+str(count))
   if variant=="positive":
    if row.expected_damage!=null: expect(is_equal_approx(total_damage()-before,float(row.expected_damage)),row.skill_id+" real raw damage "+str(total_damage()-before))
    expect(output_count(row.skill_id)==int(row.expected_spawn_count),row.skill_id+" object count "+str(output_count(row.skill_id)))
    bus.emit_skill_event(event,c)
    expect(bus.fusion_output_count(row.skill_id)==row.max_trigger_count,row.skill_id+" same interaction bounded")
    check_expected(row,c,duration_before)
    var settled_count: int=bus.fusion_output_count(row.skill_id)
    var child: Dictionary=c.duplicate(true);child.can_generate_secondary_proc=false;child.proc_depth=1;child.origin_skill_id=row.skill_id
    advance(2.1);bus.emit_skill_event(event,child)
    expect(bus.fusion_output_count(row.skill_id)==settled_count,row.skill_id+" cannot recursively trigger")
   for obj: Node in root.get_children():
    if obj.has_method("geometry_shape") or obj.has_method("_begin_return"): obj.set_physics_process(false)
 clean();await process_frame
 if failed==0: print("[verify_fusion_second_batch_v2] PASS")
 finish()
func second_fixture(row: Dictionary,variant: String) -> Dictionary:
 var normalized: Dictionary=row.duplicate(true)
 normalized.positive_fixture.objects=String(normalized.positive_fixture.objects).replace("storm","fire")
 var c: Dictionary=fixture(normalized,variant)
 var behavior: Dictionary=row.expected_behavior
 c.elapsed=behavior.get("elapsed",1.0) if variant!="missing_status_or_resource" else 0.0
 c.source_id=behavior.get("source_id","fixture")
 c.source_instance_id="fixture-storm-cloud"
 c.strike_id="fixture-strike"
 c.chain_candidates=nearby.duplicate()
 c.chain_result={}
 c.cursed_snapshot=enemy.get_node("StatusEffectManager").export_status(&"cursed")
 if c.has("projectile"):
  c.projectile.source_id=StringName(behavior.get("projectile_id","fixture"))
  c.projectile.damage=28;c.projectile.position=Vector2.ZERO
  c.projectile.direction=Vector2.RIGHT
 var area_objects: Array=[]
 for node: Node in fixture_objects:
  if node.has_method("geometry_shape"): area_objects.append(node)
 if not area_objects.is_empty(): c.area=area_objects[0]
 for a: Node in area_objects:
  if String(a.damage_packet.get("origin_skill_id",""))=="holy_cast_divine_barrier": a.source_id=&"divine_barrier_field"
  if String(a.damage_packet.get("origin_skill_id",""))=="fire_cast_lava_rift": a.source_id=&"lava_rift"
 if area_objects.size()>1:
  c.other_area=area_objects[1];c.interaction_key="fixture-second-pair";c.interaction_entered=true
 if String(row.positive_fixture.objects)=="rift+rift": area_objects[1].position=Vector2(120,0)
 if String(row.positive_fixture.objects)=="storm":
  c.area.damage_packet.origin_skill_id="thunder_cast_storm_circle";c.area.damage_packet.source_skill_id="thunder_cast_storm_circle";c.area.source_id=&"lightning_strike_area"
 if variant=="missing_status_or_resource":
  if not area_objects.is_empty(): area_objects[0].position=Vector2(10000,10000)
 if variant=="wrong_source_or_spatial_object" and not area_objects.is_empty(): area_objects[0].position=Vector2(10000,10000)
 if variant=="wrong_source_or_spatial_object" and String(row.positive_fixture.event)=="on_enemy_killed": c.target_statuses=[]
 if row.skill_id=="fusion_chaos_curse_rift_curse_exchange": nearby[-1].get_node("StatusEffectManager").consume_status_stack(&"cursed",3)
 if variant=="missing_status_or_resource" and row.skill_id=="fusion_thunder_curse_black_thunder_convergence":
  for e: Enemy in nearby: e.get_node("StatusEffectManager").consume_status_stack(&"cursed",3)
 if not c.reaction_actions.is_empty(): c.reaction_actions[0].params.tick_interval=1.0
 return c
func check_expected(row: Dictionary,c: Dictionary,duration_before: float) -> void:
 var b: Dictionary=row.expected_behavior
 var status: Node=enemy.get_node("StatusEffectManager")
 if b.has("base_output"):
  var found: bool=false
  for a: Node in AreaManager.get_or_create(player).get_active_areas(): found=found or String(a.source_id)==String(b.base_output)
  expect(found,"forced overload produces the owned base reaction")
 if b.has("pulse_damage"):
  var hit: bool=false
  for e: Enemy in [enemy]+nearby:
   for p: Dictionary in e.packets:
    if String(p.get("origin_skill_id",""))==String(row.skill_id):
     expect(is_equal_approx(float(p.raw_amount),float(b.pulse_damage)),"barrier half-second pulse really settles ten damage")
     hit=true
  expect(hit,"barrier edge pulse hits an actual edge enemy")
 if b.has("stored_charge"):
  var entry: Dictionary=c.duplicate(true);entry.event_name=&"area_tick";entry.area=c.area
  entry.origin_skill_id=&"fire_cast_lava_rift";entry.skill_id=entry.origin_skill_id;entry.skill_instance=manager.get_skill(entry.origin_skill_id)
  entry.interaction_entered=true;entry.target_statuses=[]
  var before: float=total_damage()
  bus.emit_skill_event(&"area_tick",entry)
  expect(is_equal_approx(total_damage()-before,70),"stored fire-ground charge settles on next enemy entry")
  expect(enemy.get_status_stack(&"conductive")>=1,"ground charge adds Conductive")
  before=total_damage();bus.emit_skill_event(&"area_tick",entry)
  expect(is_equal_approx(total_damage(),before),"ground charge consumes once")
 if b.has("orb_damage"):
  var orb: Node=c.area
  expect(is_equal_approx(orb.duration,3.0) and is_equal_approx(orb.tick_interval,.5),"actual orb refreshes three seconds and half-second tick")
  var before: int=nearby[-1].packets.size()
  orb._damage_body(nearby[-1])
  expect(nearby[-1].packets.size()>before and is_equal_approx(float(nearby[-1].packets[-1].raw_amount),18),"actual relocated orb settles eighteen damage")
 if b.has("curse_exchange"):
  var status_snapshot: Dictionary=nearby[-1].get_node("StatusEffectManager").export_status(&"cursed")
  expect(int(status_snapshot.get("stacks",0))==1 and is_equal_approx(float(status_snapshot.get("power",0)),100) and is_equal_approx(float(status_snapshot.get("duration_remaining",0)),3),"rift copies one actual curse stack with its power and deadline")
 if b.has("shield"): expect(int(player.get_meta("fire_passive_shield",0))==int(b.shield),row.skill_id+" actual shield")
 if b.has("curse_duration_delta"): expect(is_equal_approx(float(status.export_status(&"cursed").get("duration_remaining",0)),duration_before+float(b.curse_duration_delta)),row.skill_id+" actual curse deadline")
 if b.has("curse_transfer"): expect(not enemy.has_status(&"cursed") and nearby[0].get_status_stack(&"cursed")==2,row.skill_id+" death transfers without resolving")
 if b.has("relocated_damage"): expect(is_equal_approx(c.projectile.damage,float(b.relocated_damage)) and c.projectile.position!=Vector2.ZERO,row.skill_id+" original shard relocated and adjusted once")
 if b.has("chain_priority"): expect(c.chain_result.get("target")==nearby[0],"next real chain selects a cursed candidate")
 for kind: String in ["projectiles","areas"]:
  for id: String in b.get(kind,{}):
   var objects: Array=[]
   for obj: Node in root.get_children():
    if not obj.is_queued_for_deletion() and obj.get("source_id")==StringName(id): objects.append(obj)
   var values: Array=b[kind][id]
   expect(objects.size()==(int(values[0]) if kind=="projectiles" else int(values[3]) if values.size()>3 else 1),row.skill_id+" actual output identity "+id)
   for obj: Node in objects:
    if kind=="projectiles": expect(is_equal_approx(float(obj.damage),float(values[1])),id+" projectile damage")
    else:
     expect(is_equal_approx(obj.duration,float(values[0])) and is_equal_approx(obj.tick_interval,float(values[1])),id+" actual duration and tick")
     var actions: Array=obj.actions_on_apply if not obj.actions_on_apply.is_empty() else obj.actions_on_tick
     var damage: float=0
     for action: Dictionary in actions:
      if String(action.type)=="deal_damage":
       var amount: Variant=action.params.get("amount",0)
       damage+=100.0*float(amount.get("scale",0)) if amount is Dictionary else float(amount)
     expect(is_equal_approx(damage,float(values[2])),id+" one damage payload "+str(damage))
