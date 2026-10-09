extends "res://tools/verify/skill_m2_combat_fixture.gd"
func _initialize() -> void:call_deferred("run")
func last_projectile() -> Node:
 var result: Node=null
 for n: Node in root.get_children():
  if n.has_method("_begin_return") and not n.is_queued_for_deletion() and not n._is_destroying:result=n
 return result
func run() -> void:
 setup();enemy.get_node("StatusEffectManager").set_physics_process(false)
 manager.set_primary_attack_method(&"fireball")
 var skill: RefCounted=manager.get_primary_attack_method()
 bus.emit_skill_event(&"on_cast",ctx(enemy,skill));await process_frame
 var original: Node=last_projectile();original.set_physics_process(false);original._on_body_entered(enemy)
 await process_frame;await process_frame
 expect(enemy.packets.size()==1 and enemy.packets[0].raw_amount==16,"original fireball retains one hit packet")
 var snap: Dictionary=bus.get_cast_snapshot()
 enemy.packets.clear()
 expect(bus.replay_cast(snap,ctx(enemy,skill),0.35),"owned primary attack snapshot accepted")
 await process_frame
 var copied: Node=last_projectile()
 expect(copied!=null,"copied attack exists")
 if copied==null:finish();return
 copied.set_physics_process(false);copied._on_body_entered(enemy)
 await process_frame;await process_frame
 expect(enemy.packets.size()==1 and enemy.packets[0].raw_amount==6,"35 percent copied attack carries real six-damage hit")
 if not enemy.packets.is_empty():expect(enemy.packets[0].is_copy and not enemy.packets[0].can_generate_secondary_proc,"copied attack packet retains bounded provenance")
 print("[verify_m3_review_copy_attack] " + ("PASS" if failed==0 else "FAIL"))
 finish()
