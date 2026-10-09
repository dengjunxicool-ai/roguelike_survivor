extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Area = preload("res://scripts/combat/area_effect.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const AreaManager = preload("res://scripts/combat/area_effect_manager.gd")
var fixture_objects: Array[Node] = []
var nearby: Array[Enemy] = []
func _init() -> void: call_deferred("run")
func run() -> void:
 setup()
 nearby=[make_enemy(Vector2(80,0)),make_enemy(Vector2(120,0)),make_enemy(Vector2(160,0))]
 var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json"))
 expect(rows.size()>=30,"thirty first-batch semantic fixtures")
 for row: Dictionary in rows:
  for variant: String in ["wrong_event","missing_status_or_resource","wrong_source_or_spatial_object","positive"]:
   clean()
   var c: Dictionary=fixture(row,variant)
   install(StringName(row.skill_id))
   var before: float=total_damage()
   var event: StringName=StringName(row.positive_fixture.event) if variant!="wrong_event" else &"never_a_fusion_event"
   bus.emit_skill_event(event,c)
   var count: int=bus.fusion_output_count(row.skill_id)
   expect(count==(1 if variant=="positive" else 0),row.skill_id+" "+variant+" triggers "+str(count))
   if variant=="positive":
    if row.expected_damage!=null: expect(is_equal_approx(total_damage()-before,float(row.expected_damage)),row.skill_id+" actual packet damage")
    expect(output_count(row.skill_id)==int(row.expected_spawn_count),row.skill_id+" actual output object count "+str(output_count(row.skill_id)))
    bus.emit_skill_event(event,c)
    expect(bus.fusion_output_count(row.skill_id)==row.max_trigger_count,row.skill_id+" repeated interaction bounded by ICD")
    var child: Dictionary=c.duplicate(true);child.can_generate_secondary_proc=false;child.proc_depth=1
    advance(2.1);bus.emit_skill_event(event,child)
    expect(bus.fusion_output_count(row.skill_id)==row.max_trigger_count,row.skill_id+" derived output cannot start fusion chain")
    verify_special(row,c)
   await process_frame
 clean()
 if failed==0: print("[verify_fusion_semantics_v2] PASS")
 finish()
func clean() -> void:
 manager.clear_skills();bus.reset_run_state()
 for node: Node in fixture_objects:
  if is_instance_valid(node): node.free()
 fixture_objects.clear()
 for node: Node in root.get_children():
  if node.has_method("geometry_shape") or node.has_method("_begin_return") or node.get_script()==preload("res://scripts/skills/fusion_soul_minion.gd"):
   if not node.is_queued_for_deletion(): node.queue_free()
 for e: Enemy in [enemy]+nearby:
  e.current_health=10000;e.packets.clear();e.get_node("StatusEffectManager").clear_statuses();e.set_meta("preparing_attack",true)
 player.set_meta("fire_passive_shield",0)
func fixture(row: Dictionary,variant: String) -> Dictionary:
 var f: Dictionary=row.positive_fixture
 var source: RefCounted=install(StringName(f.origin))
 var c: Dictionary=ctx(enemy,source)
 c.origin_skill_id=source.skill_id;c.origin_skill_instance=source;c.damage_amount=100.0;c.amount=20.0;c.shield_amount=20.0;c.status_id=StringName(f.event_status);c.reaction_kind=f.reaction;c.reaction_id="fixture-1";c.resolved_raw_damage=75.0
 c.reaction_actions=[{"type":"spawn_area","params":{"area_id":"divine_punishment_strike","radius":100.8,"duration":0.2,"damage":0,"actions_on_apply":[{"type":"deal_damage","params":{"amount":{"stat":"power","scale":1.6},"damage_type":"holy"}}]}}]
 if variant!="missing_status_or_resource":
  for state: String in f.statuses: enemy.apply_status(StringName(state),{"stacks":1,"duration":6.0,"power":100.0})
 else:
  c.amount=0.0;c.shield_amount=0.0;c.resolved_raw_damage=0.0;c.reaction_actions=[];c.reaction_kind="wrong";enemy.set_meta("preparing_attack",false)
 for e: Enemy in nearby:
  for state: String in ["cursed","conductive","chilled","judgment"]: e.apply_status(StringName(state),{"stacks":1,"duration":6.0,"power":100.0})
 if row.skill_id=="fusion_curse_thunder_curse_lightning_backlash": nearby[0].get_node("StatusEffectManager").clear_statuses()
 c.target_statuses=enemy.get_node("StatusEffectManager").get_status_snapshot()
 c.damage_packet={"source_type":"projectile" if String(f.objects)=="projectile" else "skill"}
 if String(f.objects)=="projectile":
  var p: Node2D=Projectile.new();root.add_child(p);fixture_objects.append(p)
  p.setup({"source_id":"fixture","damage_packet":{"source_skill_id":source.skill_id},"caster":player,"skill_manager":manager,"event_bus":bus,"damage":0});p.set_physics_process(false);c.source=p;c.projectile=p
 var kinds: Array=String(f.objects).split("+")
 for kind: String in kinds:
  if kind=="" or kind=="projectile": continue
  var id: String="frost_cast_frost_field" if kind=="frost" else "fire_cast_lava_rift" if kind in ["fire","lava"] else "chaos_cast_void_rift" if kind=="rift" else "holy_cast_divine_barrier" if kind=="holy" else "thunder_dash_ball_lightning"
  var owner: RefCounted=install(StringName(id))
  var a: Node2D=Area.new();root.add_child(a);fixture_objects.append(a);a.position=enemy.position
  a.setup({"area_id":"fixture","source_id":"void_rift_field" if kind=="rift" else "ball_lightning_orb" if kind=="orb" else "fixture","radius":100.0,"duration":10.0,"tick_interval":1.0,"damage":0,"damage_packet":{"origin_skill_id":id,"source_skill_id":id},"caster":player,"skill_manager":manager,"skill_instance":owner,"event_bus":bus});a.set_physics_process(false)
  if kind=="rift" and c.has("area"): c.other_area=a
  elif kind!="rift" or not c.has("area"): c.area=a
  if kind=="rift": c.rift=a
 if c.has("other_area"): c.interaction_key="fixture-pair";c.interaction_entered=true
 if variant=="wrong_source_or_spatial_object":
  if row.skill_id=="fusion_curse_fire_burning_soul_minion": c.target_statuses=[]
  c.origin_skill_id=&"unowned_source";c.origin_skill_instance=null;c.reaction_kind="wrong";c.status_id=&"wrong";c.amount=0.0;c.shield_amount=0.0;enemy.set_meta("preparing_attack",false)
  if not fixture_objects.is_empty(): fixture_objects[0].position=Vector2(10000,10000)
 if variant=="missing_status_or_resource" and String(f.objects)!="":
  if not fixture_objects.is_empty(): fixture_objects[0].position=Vector2(10000,10000)
 return c
func total_damage() -> float:
 var total: float=0.0
 for e: Enemy in [enemy]+nearby:
  for p: Dictionary in e.packets: total+=float(p.get("raw_amount",0.0))
 return total
func output_count(id: String) -> int:
 var n: int=0
 for object: Node in root.get_children():
  if object.is_queued_for_deletion(): continue
  if object.has_method("geometry_shape") or object.has_method("_begin_return"):
   if String(object.damage_packet.get("origin_skill_id",""))==id: n+=1
  elif object.get_script()==preload("res://scripts/skills/fusion_soul_minion.gd"): n+=1
 return n
func verify_special(row: Dictionary,c: Dictionary) -> void:
 var id: String=row.skill_id
 if id=="fusion_curse_fire_ash_soul_pact": expect(is_equal_approx(float(enemy.get_node("StatusEffectManager").export_status(&"cursed").get("fusion_resolve_bonus",0)),.08),"ash pact adds next-resolution 8 percent")
 if id=="fusion_thunder_frost_cryo_capacitor": expect(nearby[0].get_status_stack(&"conductive")==2 and enemy.get_status_stack(&"conductive")==0,"capacitor spreads to one other chilled enemy")
 if id=="fusion_curse_thunder_black_serpent_conduction": expect(nearby[0].get_status_stack(&"cursed")==2 and nearby[1].get_status_stack(&"cursed")==2 and nearby[2].get_status_stack(&"cursed")==1,"snake spreads curse to exactly two")
 if id=="fusion_chaos_thunder_warp_lightning_orb": expect(c.area.position!=Vector2(30,0) and is_equal_approx(c.area.duration,3.0),"real orb moved and lifetime reset")
 if id=="fusion_chaos_frost_zero_rift": expect(is_equal_approx(c.area.radius,184.0),"original frost area expands one R")
 if id=="fusion_curse_holy_confession_curse_seal": expect(not enemy.get_meta("preparing_attack",true) and not enemy.has_status(&"cursed"),"confession interrupts real preparation and resolves once")
