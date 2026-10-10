extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Area = preload("res://scripts/combat/area_effect.gd")
func _initialize() -> void: call_deferred("run")
func projectiles() -> Array:
 var out: Array=[]
 for n: Node in root.get_children():
  if n.has_method("_begin_return") and not n.is_queued_for_deletion(): out.append(n)
 return out
func run() -> void:
 setup()
 enemy.get_node("StatusEffectManager").set_physics_process(false)
 var skill: RefCounted=install(&"thunder_cast_chain_lightning")
 skill.current_level=5
 bus.emit_skill_event(&"on_cast",ctx(enemy,skill))
 await process_frame
 var original: Node=projectiles().back();original.set_physics_process(false)
 original._on_body_entered(enemy)
 var snap: Dictionary=bus.get_cast_snapshot()
 enemy.packets.clear()
 bus.replay_cast(snap,ctx(enemy,skill),0.4)
 await process_frame
 var copied: Node=projectiles().back();copied.set_physics_process(false)
 copied._on_body_entered(enemy)
 expect(enemy.packets.size()==2 and enemy.packets[0].raw_amount==59 and enemy.packets[1].raw_amount==18,"Lv5 main and last-target bonus both copied at 40 percent")
 manager.clear_skills();bus.reset_run_state();enemy.get_node("StatusEffectManager").clear_statuses();enemy.packets.clear()
 for n: Node in projectiles(): n.queue_free()
 await process_frame
 var holy: RefCounted=install(&"holy_cast_holy_ray");holy.current_level=5
 enemy.apply_status(&"judgment",{"stacks":5,"duration":8.0})
 bus.emit_skill_event(&"on_cast",ctx(enemy,holy));await process_frame
 var holy_snapshot: Dictionary=bus.get_cast_snapshot()
 for n: Node in projectiles(): n.queue_free()
 await process_frame
 enemy.packets.clear()
 expect(bus.replay_cast(holy_snapshot,ctx(enemy,holy),0.4),"Lv5 holy ray replays real projectiles")
 await process_frame
 var extra: Node=null
 for n: Node in projectiles():
  n.set_physics_process(false)
  if extra==null or n.damage<extra.damage:extra=n
 expect(extra!=null and extra.damage==24,"Lv5 extra holy ray damage receives 40 percent scaling")
 if extra!=null:
  extra._on_body_entered(enemy)
  expect(enemy.packets.size()==1 and enemy.packets[0].raw_amount==24,"Lv5 copied extra holy ray settles actual 24 damage")
 manager.clear_skills();bus.reset_run_state();enemy.get_node("StatusEffectManager").clear_statuses();enemy.packets.clear()
 for n: Node in projectiles():n.queue_free()
 var thunder: RefCounted=install(&"thunder_cast_chain_lightning")
 install(&"fusion_frost_thunder_lightning_ice_pillar")
 enemy.apply_status(&"frozen",{"duration":1.2})
 var c: Dictionary=ctx(enemy,thunder);c.damage_amount=100
 bus.emit_skill_event(&"post_damage_hit",c)
 await process_frame
 var pillar: Node=null
 for n: Node in root.get_children():
  if n.has_method("geometry_shape") and String(n.source_id)=="lightning_ice_pillar":pillar=n
 if pillar!=null:
  pillar.set_physics_process(false)
  pillar._age=0.0
  enemy.position=Vector2(130,0)
  enemy.packets.clear()
  pillar._physics_process_profiled(0.99)
  expect(enemy.packets.is_empty(),"pillar waits for one second independent pulse")
  pillar._physics_process_profiled(0.01)
  expect(enemy.packets.size()==1 and enemy.packets[0].raw_amount==25,"pillar pulse hits outer target without inner occupants")
  enemy.position=pillar.position
  var other: Enemy=make_enemy(pillar.position+Vector2(20,0));other.get_node("StatusEffectManager").set_physics_process(false)
  enemy.packets.clear();other.packets.clear()
  pillar._physics_process_profiled(1.0)
  expect(enemy.packets.size()==1 and enemy.packets[0].raw_amount==25 and other.packets.size()==1,"two inner targets receive exactly one pulse each")
  other.position=Vector2(900,0);enemy.packets.clear()
  pillar._physics_process_profiled(1.0)
  expect(enemy.packets.size()==1 and enemy.packets[0].raw_amount==25,"one inner occupant also receives exactly one pulse")
 else:expect(false,"real ice pillar generated")
 print("[verify_m3_review_copy_and_pillar] " + ("PASS" if failed==0 else "FAIL"))
 finish()
