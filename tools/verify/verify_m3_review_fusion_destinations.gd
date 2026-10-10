extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Area=preload("res://scripts/combat/area_effect.gd")
func _initialize() -> void:call_deferred("run")
func make_area(skill: RefCounted,id: String,pos: Vector2) -> Node:
 var n: Node=Area.new();root.add_child(n);n.position=pos
 n.setup({"source_id":id,"radius":100,"duration":4,"caster":player,"skill_manager":manager,"skill_instance":skill,"event_bus":bus,"damage_packet":{"origin_skill_id":skill.skill_id,"source_skill_id":skill.skill_id},"damage":0});n.set_physics_process(false)
 return n
func run() -> void:
 setup();var far_enemy: Enemy=make_enemy(Vector2(600,0))
 var chaos: RefCounted=install(&"chaos_cast_void_rift")
 var thunder: RefCounted=install(&"thunder_dash_ball_lightning")
 install(&"fusion_chaos_thunder_warp_lightning_orb")
 var rift: Node=make_area(chaos,"void_rift_field",Vector2.ZERO)
 var orb: Node=make_area(thunder,"ball_lightning_orb",Vector2.ZERO)
 bus.observe_area(orb)
 expect(orb.position==far_enemy.position,"warp orb chooses farthest eligible enemy, not nearest")
 manager.clear_skills();bus.reset_run_state();rift.free();orb.free()
 chaos=install(&"chaos_cast_void_rift")
 var frost: RefCounted=install(&"frost_cast_frost_field")
 install(&"fusion_chaos_frost_zero_rift")
 rift=make_area(chaos,"void_rift_field",Vector2.ZERO)
 var field: Node=make_area(frost,"frost_field",Vector2.ZERO)
 await process_frame
 var copies: int=0
 for n: Node in root.get_children():
  if n.has_method("geometry_shape") and String(n.source_id)=="zero_rift_copy":
   copies+=1
   expect(n.position==far_enemy.position,"zero rift copy chooses farthest eligible enemy")
 expect(copies==1,"one zero rift copy generated")
 print("[verify_m3_review_fusion_destinations] " + ("PASS" if failed==0 else "FAIL"))
 finish()
