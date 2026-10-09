extends "res://tools/verify/skill_m2_combat_fixture.gd"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 setup();enemy.get_node("StatusEffectManager").set_physics_process(false)
 var original: RefCounted=install(&"thunder_cast_chain_lightning")
 var chaos: RefCounted=install(&"chaos_cast_mutation_pulse")
 install(&"chaos_power_fission_burst");install(&"chaos_core_chaos_singularity")
 bus.emit_skill_event(&"on_cast",ctx(enemy,original));await process_frame
 for i: int in 25:
  var c: Dictionary=ctx(enemy,chaos);c.status_id="instability"
  bus.emit_skill_event(&"status_max_stack_reached",c)
  await process_frame
  for n: Node in root.get_children():
   if n.has_method("geometry_shape") or n.has_method("_begin_return"):n.set_physics_process(false)
 await physics_frame;bus.process_pending_events()
 manager.active_skills.erase(original.skill_id)
 manager._clear_origin_runtime(root,original.skill_id)
 await process_frame
 advance(2);bus.update_skill_cycles();await process_frame
 var copies: int=0
 for n: Node in root.get_children():
  if n.has_method("_begin_return") and String(n.source_id)=="chain_lightning_bolt" and n.damage_packet.get("is_copy",false):copies+=1
 expect(copies==0,"removing snapshot source prevents armed singularity replay")
 var bursts: int=0
 for n: Node in root.get_children():
  if n.has_method("geometry_shape") and String(n.source_id)=="chaos_singularity_burst":bursts+=1
 expect(bursts==1,"source removal preserves the owned singularity burst")
 print("[verify_m3_review_copy_removal] " + ("PASS" if failed==0 else "FAIL"))
 finish()
