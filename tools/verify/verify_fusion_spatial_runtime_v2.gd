extends "res://tools/verify/verify_fusion_semantics_v2.gd"
var observed: int = 0
func run() -> void:
 setup();nearby=[make_enemy(Vector2(80,0)),make_enemy(Vector2(120,0)),make_enemy(Vector2(160,0))]
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json"))
 # Creation events have no impact target in the actual factory.
 var row: Dictionary=rows.filter(func(r: Dictionary)->bool:return r.skill_id=="fusion_chaos_frost_zero_rift")[0]
 var c: Dictionary=fixture(row,"positive");c.erase("target");install(StringName(row.skill_id))
 bus.emit_skill_event(&"area_created",c)
 expect(bus.fusion_output_count(row.skill_id)==1,"targetless frost creation near real rift clones area")
 clean();await process_frame
 # Cast target selection happens before the source emits projectiles.
 var source: RefCounted=install(&"frost_cast_glacial_lance")
 nearby[0].apply_status(&"judgment",{"stacks":2,"duration":6.0});nearby[1].apply_status(&"judgment",{"stacks":4,"duration":6.0})
 install(&"fusion_frost_holy_judgment_ice_lance")
 bus.subscribe(&"on_cast",func(context: Dictionary)->void: if context.origin_skill_id==&"frost_cast_glacial_lance": expect(context.target==nearby[1],"ice lance release retargets highest Judgment enemy"))
 bus.emit_skill_event(&"on_cast",ctx(enemy,source))
 clean();await process_frame
 # Genuine broadphase candidates still need narrowphase; pool generation is a new object.
 var a: Node2D=Area.new();var b: Node2D=Area.new();root.add_child(a);root.add_child(b);fixture_objects=[a,b]
 a.setup({"radius":20,"caster":player,"skill_manager":manager,"event_bus":bus,"damage":0});b.setup({"radius":20,"caster":player,"skill_manager":manager,"event_bus":bus,"damage":0})
 a.set_physics_process(false);b.set_physics_process(false)
 bus.subscribe(&"area_overlap",func(context: Dictionary)->void: if context.interaction_entered: observed+=1)
 b.position=Vector2(41,0);bus.observe_area(a);expect(observed==0,"indexed nearby nonintersection emits no overlap")
 b.position=Vector2(40,0);await physics_frame;bus.observe_area(a);expect(observed==1,"real grazing emits one entry")
 bus.observe_area(a);expect(observed==1,"continuous contact not another entry")
 b.position=Vector2(80,0);await physics_frame;bus.observe_area(a)
 b.position=Vector2(0,0);await physics_frame;bus.observe_area(a);expect(observed==2,"exit and second entry observed")
 b.prepare_for_pool_despawn();bus.observe_area(a);b.prepare_for_pool_spawn({"radius":20,"caster":player,"skill_manager":manager,"event_bus":bus,"damage":0});b.set_physics_process(false)
 bus.observe_area(a);expect(observed==3,"pool reuse has clean contact identity")
 fixture_objects.erase(b);b.queue_free();await process_frame;bus.observe_area(a);expect(observed==3,"destroyed object cannot trigger stale overlap")
 clean();await process_frame
 # Swept projectile entry catches a full crossing and preserves re-entry/generation identity.
 observed=0
 a=Area.new();root.add_child(a);fixture_objects=[a]
 a.setup({"radius":20,"caster":player,"skill_manager":manager,"event_bus":bus,"damage":0});a.set_physics_process(false)
 var bolt: Node2D=Projectile.new();root.add_child(bolt);fixture_objects.append(bolt)
 bolt.setup({"source_id":"fixture_bolt","caster":player,"skill_manager":manager,"event_bus":bus,"damage":0});bolt.set_physics_process(false)
 bus.subscribe(&"projectile_area_entered",func(_context: Dictionary)->void: observed+=1)
 bus.observe_projectile(bolt,Vector2(-100,21),Vector2(100,21),0.0);expect(observed==0,"projectile nearby miss is not entry")
 bus.observe_projectile(bolt,Vector2(-100,0),Vector2(0,0),0.0);expect(observed==1,"projectile swept entry")
 bus.observe_projectile(bolt,Vector2(0,0),Vector2(10,0),0.0);expect(observed==1,"projectile continuing inside does not enter twice")
 bus.observe_projectile(bolt,Vector2(10,0),Vector2(100,0),0.0)
 bus.observe_projectile(bolt,Vector2(100,0),Vector2(0,0),0.0);expect(observed==2,"projectile teleport exit and reentry")
 bolt.prepare_for_pool_despawn();bolt.prepare_for_pool_spawn({"source_id":"fixture_bolt","caster":player,"skill_manager":manager,"event_bus":bus,"damage":0});bolt.set_physics_process(false)
 bus.observe_projectile(bolt,Vector2(-100,0),Vector2(100,0),0.0);expect(observed==3,"reused projectile full crossing has fresh generation")
 clean();await process_frame
 # One steam object, one 0.14P packet each half-second, Chilled once per second.
 row=rows.filter(func(r: Dictionary)->bool:return r.skill_id=="fusion_fire_frost_steam_mist")[0]
 c=fixture(row,"positive");install(StringName(row.skill_id));bus.emit_skill_event(&"area_tick",c)
 var steam: Node=null
 for obj: Node in AreaManager.get_or_create(player).get_active_areas():
  if String(obj.source_id)=="steam_mist": steam=obj
 expect(steam!=null,"steam is one real area")
 if steam!=null:
  steam.set_physics_process(false)
  var before: float=total_damage();steam._damage_body(enemy)
  expect(is_equal_approx(total_damage()-before,14.0),"steam half-second damage 14P at 100P")
  expect(enemy.get_status_stack(&"chilled")==1,"steam first Chilled stack")
  advance(.5);before=total_damage();steam._damage_body(enemy)
  expect(is_equal_approx(total_damage()-before,14.0) and enemy.get_status_stack(&"chilled")==1,"second damage does not duplicate one-second Chilled")
  advance(.5);await physics_frame;steam._damage_body(enemy);expect(enemy.get_status_stack(&"chilled")==2,"steam next whole-second Chilled")
 clean();await process_frame
 # Curse bonus belongs to the next resolution of this target and caps at five ticks.
 row=rows.filter(func(r: Dictionary)->bool:return r.skill_id=="fusion_curse_fire_ash_soul_pact")[0]
 c=fixture(row,"positive");install(StringName(row.skill_id))
 for i: int in 6: bus.emit_skill_event(&"status_tick",c);advance(1.01)
 var status: Node=enemy.get_node("StatusEffectManager")
 expect(is_equal_approx(float(status.export_status(&"cursed").get("fusion_resolve_bonus",0)),.4),"five tick curse bonus bounded at forty percent")
 var before: float=total_damage();status.resolve_cursed(&"test");expect(is_equal_approx(total_damage()-before,105.0),"next actual curse packet includes capped bonus once")
 status.resolve_cursed(&"test");expect(is_equal_approx(total_damage()-before,105.0),"resolution cannot repeat")
 clean();await process_frame
 # Cursed is paused while Frozen, then resolves once and creates the icy burst.
 row=rows.filter(func(r: Dictionary)->bool:return r.skill_id=="fusion_frost_curse_ice_coffin_curse_burst")[0]
 c=fixture(row,"positive");install(StringName(row.skill_id));bus.emit_skill_event(&"status_applied",c)
 status=enemy.get_node("StatusEffectManager");before=float(status.export_status(&"cursed").duration_remaining)
 status.update_status_effects(1.0);expect(is_equal_approx(float(status.export_status(&"cursed").duration_remaining),before),"freeze pauses curse deadline")
 status.consume_status_duration(&"frozen",10.0)
 expect(not enemy.has_status(&"cursed") and output_count(row.skill_id)==1,"thaw resolves curse once and emits icy burst")
 clean();await process_frame
 # Removing a fusion cannot leave its Cursed pause source behind.
 row=rows.filter(func(r: Dictionary)->bool:return r.skill_id=="fusion_frost_curse_ice_coffin_curse_burst")[0]
 c=fixture(row,"positive");install(StringName(row.skill_id));bus.emit_skill_event(&"status_applied",c)
 status=enemy.get_node("StatusEffectManager");status.clear_origin(StringName(row.skill_id))
 expect(not status.export_status(&"cursed").get("pause_sources",{}).has(StringName(row.skill_id)),"removed fusion clears its curse pause source")
 clean();await process_frame
 # A real base barrier recovery is a true gain even though its action is a listener.
 var barrier_skill: RefCounted=install(&"holy_cast_divine_barrier")
 install(&"fusion_thunder_holy_shield_capacitor")
 bus.emit_skill_event(&"on_cast",ctx(null,barrier_skill))
 for obj: Node in AreaManager.get_or_create(player).get_active_areas():
  if String(obj.source_id)=="divine_barrier_field": obj.set_physics_process(false);obj._physics_process_profiled(1.0)
 expect(bus.fusion_output_count("fusion_thunder_holy_shield_capacitor")==1,"actual barrier recovery charges capacitor once")
 clean();await process_frame
 # Verify spatial capability against the real catalog cast, not a named test object.
 var rift_skill: RefCounted=install(&"chaos_cast_void_rift")
 bus.emit_skill_event(&"on_cast",ctx(enemy,rift_skill))
 var actual_rift: Node=null
 for obj: Node in AreaManager.get_or_create(player).get_active_areas():
  if String(obj.source_id)=="void_rift_field": actual_rift=obj
 expect(actual_rift!=null and bus.get("_fusion").area_is(actual_rift,"rift"),"real void_rift_field cast is recognized as a rift")
 clean();await process_frame
 if failed==0: print("[verify_fusion_spatial_runtime_v2] PASS")
 finish()
