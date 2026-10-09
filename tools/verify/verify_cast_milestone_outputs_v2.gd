extends "res://tools/verify/verify_base_skill_behavior_v2.gd"
func run() -> void:
 setup();nearby=[]
 player.get_node("ModifierStore").set_physics_process(false)
 enemy.get_node("StatusEffectManager").set_physics_process(false)
 for i: int in 6: nearby.append(make_enemy(Vector2(80+i*20,0)))
 for e: Enemy in nearby: e.get_node("StatusEffectManager").set_physics_process(false)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/base_skill_behavior_cases.json"))
 for row: Dictionary in data.cases:
  if not String(row.id).contains("_cast_"): continue
  for level: int in [1,3,5]:
   clean_base();await process_frame;await physics_frame
   var skill: RefCounted=install(StringName(row.id));skill.current_level=level
   var d: float=1.0+.12*(level-1);var t: float=1.0+.06*(level-1);var radius_growth: float=1.0+.05*(level-1)
   var id: String=String(row.id)
   if id=="fire_cast_scorching_vortex": enemy.apply_status(&"burning",{"stacks":1})
   if id=="thunder_cast_emp_ring": enemy.apply_status(&"conductive",{"stacks":5})
   if id=="curse_cast_doom_circle": enemy.apply_status(&"cursed",{"stacks":3,"power":100})
   if id in ["holy_cast_holy_ray","holy_cast_judgment_hammer"]: enemy.apply_status(&"judgment",{"stacks":5 if id=="holy_cast_holy_ray" else 3})
   bus.emit_skill_event(&"on_cast",ctx(enemy,skill))
   for node: Node in root.get_children():
    if node.has_method("geometry_shape") or node.has_method("_begin_return"): node.set_physics_process(false)
   await process_frame
   for node: Node in root.get_children():
    if node.has_method("geometry_shape") or node.has_method("_begin_return"): node.set_physics_process(false)
   var objects: Array=objects_for(row)
   expect(not objects.is_empty(),id+" Lv"+str(level)+" actual output exists")
   if objects.is_empty(): continue
   var object: Node=objects[0]
   match id:
    "fire_cast_meteor_rain":
     expect(objects.size()==(3 if level==1 else 4),"meteor actual 3/4/4")
     object._on_body_entered(enemy);await process_frame
     var ground: Node=area_by(&"meteor_burning_ground")
     expect(ground!=null and is_equal_approx(ground.duration,(4.0 if level==5 else 3.0)*t),"meteor ground duration before single growth")
    "fire_cast_lava_rift":
     expect(is_equal_approx(object.effect_width,80.64 if level>=3 else 67.2),"lava actual width milestone")
     if level==5:
      object._finish_damage_window();await process_frame
      expect(area_by(&"lava_rift_end_burst")!=null,"lava expiry creates one endpoint burst")
    "fire_cast_scorching_vortex":
     enemy.packets.clear();object._damage_body(enemy)
     close_damage(50*d*(1.15 if level>=3 else 1.0),"vortex Burning bonus Lv"+str(level))
     if level==5:
      object._age=object.duration;object._tick_timer=100
      for turn: int in 10:
       object._physics_process(0)
       if object._returned: break
       await physics_frame
      enemy.packets.clear();object._damage_body(enemy)
      close_damage(25*d*1.15,"vortex one half-damage return")
      expect(object._returned,"vortex return state")
    "frost_cast_frost_field","frost_cast_blizzard_cloud":
     if enemy.get_status_stack(&"chilled")==0: object._damage_body(enemy)
     expect(enemy.get_status_stack(&"chilled")== (2 if (id=="frost_cast_frost_field" and level>=3) or (id=="frost_cast_blizzard_cloud" and level==5) else 1),id+" actual first Chilled stacks")
     var duration: float=3 if id=="frost_cast_frost_field" else (6 if level>=3 else 5)
     expect(is_equal_approx(object.duration,duration*t),id+" actual duration")
    "frost_cast_glacial_lance":
     expect(object.pierce==(6 if level==1 else 8),"lance actual pierce 6/8/8")
     enemy.packets.clear();object._on_body_entered(enemy)
     await process_frame;close_damage(125*d,"lance actual unFrozen direct hit")
     nearby[0].apply_status(&"frozen");object._on_body_entered(nearby[0]);await process_frame
     var splash: Node=area_by(&"shatter_splash")
     expect(splash!=null and is_equal_approx(splash.radius,(126.0 if level==5 else 100.8)*radius_growth),"lance Frozen splash radius")
    "thunder_cast_chain_lightning":
     enemy.packets.clear();object._on_body_entered(enemy);await process_frame
     close_damage(100*d,"chain original direct hit")
     var hits: int=0
     for e: Enemy in nearby:
      if not e.packets.is_empty(): hits+=1
     expect(hits==(4 if level==1 else 5),"chain actual 4/5/5 neighbor hits")
    "thunder_cast_storm_circle":
     if enemy.get_status_stack(&"chilled")==0: object._damage_body(enemy);await process_frame
     expect(enemy.get_status_stack(&"conductive")== (2 if level>=3 else 1),"storm actual first strike stacks")
     if level==5:
      enemy.packets.clear();object._age=object.duration-object.tick_interval;object._damage_body(enemy);await process_frame
      close_damage(120*d,"storm actual final strike 1.5 damage")
    "thunder_cast_emp_ring": close_damage((180 if level==1 else 200)*d,"EMP actual conductive bonus")
    "curse_cast_black_serpent_hunt":
     expect(objects.size()==(2 if level==1 else 3),"serpent actual 2/3/3")
     enemy.get_node("StatusEffectManager").clear_statuses();object._on_body_entered(enemy);await process_frame
     expect(enemy.get_status_stack(&"cursed")== (2 if level==5 else 1),"serpent first uncursed stacks")
    "curse_cast_death_scythe":
     enemy.packets.clear();object._on_body_entered(enemy);await process_frame
     close_damage(100*d,"scythe actual outgoing damage")
     if level>=3:
      enemy.packets.clear();object._begin_return();object._on_body_entered(enemy);await process_frame
      close_damage(50*d,"scythe actual half return damage")
    "curse_cast_doom_circle":
     expect(is_equal_approx(object.duration,(1.2 if level==1 else 1.0)*t),"doom actual delay milestone")
     enemy.packets.clear();object._finish_damage_window();await process_frame
     close_damage((420 if level==5 else 380)*d,"doom pre-consumption three-stack bonus once")
    "holy_cast_holy_ray":
     expect(objects.size()== (3 if level==1 else 5 if level==5 else 4),"holy ray full main target adds exactly one beam")
     if level==5:
      var extra: int=0
      for p: Node in objects:
       if p.damage==roundi(40*d): extra+=1
      expect(extra==1,"holy ray actual 0.4P extra beam")
    "holy_cast_divine_barrier": expect(is_equal_approx(object.duration,(6 if level==5 else 5)*t),"barrier actual 5/5/6 duration")
    "holy_cast_judgment_hammer":
     expect(is_equal_approx(object.radius,(135.24 if level>=3 else 117.6)*radius_growth),"hammer actual radius milestone")
     close_damage((280 if level==5 else 240)*d,"hammer actual high Judgment bonus")
    "chaos_cast_void_rift":
     expect(is_equal_approx(object.radius,(241.5 if level>=3 else 210)*radius_growth),"rift actual radius milestone")
     if level==5:
      enemy.packets.clear();object._finish_damage_window();await process_frame
      close_damage(50*d,"rift actual expiry damage")
      expect(area_by(&"void_rift_expire_burst")!=null,"rift one expiry burst")
    "chaos_cast_singularity_barrage":
     expect(objects.size()== (5 if level==1 else 6),"barrage actual 5/6/6")
     enemy.apply_status(&"instability");object._on_body_entered(enemy);await process_frame;await physics_frame
     var child_damage: int=roundi((28 if level==5 else 22)*d)
     var child: bool=false
     for p: Node in objects_for(row): child=child or p.damage==child_damage
     expect(child,"barrage actual split damage 22/22/28 before growth")
    "chaos_cast_mutation_pulse":
     expect(enemy.get_status_stack(&"instability")== (2 if level==1 else 3),"mutation actual stacks")
     if level==5:
      object._finish_damage_window();await process_frame
      expect(area_by(&"mutation_pulse_echo")==null,"mutation echo waits half second")
      advance(.5);bus.update_skill_cycles();await process_frame
      var echo: Node=area_by(&"mutation_pulse_echo")
      expect(echo!=null,"mutation delayed real echo")
      expect(enemy.get_status_stack(&"instability")==3,"echo does not add instability")
 clean_base();await process_frame;await physics_frame
 if failed==0: print("[verify_cast_milestone_outputs_v2] PASS")
 finish()
func area_by(id: StringName) -> Node:
 for node: Node in root.get_children():
  if node.has_method("geometry_shape") and not node.is_queued_for_deletion() and node.source_id==id: return node
 return null
func close_damage(wanted: float,label: String) -> void:
 var actual: float=0
 for p: Dictionary in enemy.packets: actual+=float(p.raw_amount)
 expect(absf(actual-roundf(wanted))<=1,label+" actual "+str(actual)+" expected "+str(roundf(wanted)))
