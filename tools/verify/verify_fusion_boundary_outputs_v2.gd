extends "res://tools/verify/verify_fusion_second_batch_v2.gd"
const Geometry=preload("res://scripts/skills/skill_object_geometry.gd")
func run() -> void:
 setup()
 nearby=[make_enemy(Vector2(80,0)),make_enemy(Vector2(120,0)),make_enemy(Vector2(160,0)),make_enemy(Vector2(200,0))]
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json"))
 var avalanche: Dictionary=row_for(rows,"fusion_frost_chaos_rift_avalanche")
 clean();await process_frame
 var c: Dictionary=fixture(avalanche,"positive")
 c.area.position=Vector2(75,0)
 install(StringName(avalanche.skill_id))
 bus.emit_skill_event(StringName(avalanche.positive_fixture.event),c)
 var output: Node=find_output(&"rift_avalanche")
 expect(output!=null and output.position==Vector2(75,0),"avalanche originates at actual nearby rift")
 var harvest: Dictionary=row_for(rows,"fusion_frost_curse_cold_scythe_harvest")
 clean();await process_frame
 c=second_fixture(harvest,"positive")
 for e: Enemy in nearby: e.get_node("StatusEffectManager").clear_statuses()
 install(StringName(harvest.skill_id))
 bus.emit_skill_event(StringName(harvest.positive_fixture.event),c)
 expect(output_count(harvest.skill_id)==6,"harvest prefers Cursed but still homes when none are Cursed")
 var fork: Dictionary=row_for(rows,"fusion_chaos_frost_shattered_ice_warp")
 clean();await process_frame
 c=second_fixture(fork,"positive")
 c.projectile.damage_packet.origin_skill_id="holy_cast_holy_ray"
 c.projectile.damage_packet.source_skill_id="holy_cast_holy_ray"
 c.can_generate_secondary_proc=false;c.proc_depth=1
 install(StringName(fork.skill_id))
 bus.emit_skill_event(StringName(fork.positive_fixture.event),c)
 expect(bus.fusion_output_count(fork.skill_id)==0,"ice-shard exception requires the actual object's producer")
 var crystal: Dictionary=row_for(rows,"fusion_frost_fire_crystalized_flame")
 clean();await process_frame
 c=second_fixture(crystal,"positive")
 c.other_area.position=Vector2(190,0)
 install(StringName(crystal.skill_id))
 bus.emit_skill_event(&"area_overlap",c);await process_frame
 var emitted: int=0
 for object: Node in root.get_children():
  if object.has_method("_begin_return") and object.source_id==&"crystal_flame_spike":
   emitted+=1
   expect(Geometry.contains(c.area.geometry_shape(),object.global_position) and Geometry.contains(c.other_area.geometry_shape(),object.global_position),"crystal spikes originate in the actual overlap")
 expect(emitted==5,"five crystal spikes at overlap")
 clean();await process_frame
 if failed==0: print("[verify_fusion_boundary_outputs_v2] PASS")
 finish()
func row_for(rows: Array,id: String) -> Dictionary:
 for row: Dictionary in rows:
  if row.skill_id==id: return row
 return {}
func find_output(id: StringName) -> Node:
 for obj: Node in root.get_children():
  if not obj.is_queued_for_deletion() and obj.has_method("geometry_shape") and obj.source_id==id: return obj
 return null
