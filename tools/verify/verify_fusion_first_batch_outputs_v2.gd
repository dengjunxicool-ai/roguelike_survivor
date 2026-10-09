extends "res://tools/verify/verify_fusion_second_batch_v2.gd"
func run() -> void:
 setup();nearby=[make_enemy(Vector2(80,0)),make_enemy(Vector2(120,0)),make_enemy(Vector2(160,0))]
 for e: Enemy in [enemy]+nearby: e.get_node("StatusEffectManager").set_physics_process(false)
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json"))
 for row: Dictionary in rows.slice(0,30):
  clean();await process_frame;await physics_frame
  var c: Dictionary=second_fixture(row,"positive")
  for id: String in row.required_skills: install(StringName(id))
  install(StringName(row.skill_id))
  bus.emit_skill_event(StringName(row.positive_fixture.event),c)
  for object: Node in root.get_children():
   if object.has_method("geometry_shape") or object.has_method("_begin_return") or object.get_script()==preload("res://scripts/skills/fusion_soul_minion.gd"): object.set_physics_process(false)
  await process_frame
  for object: Node in root.get_children():
   if object.has_method("geometry_shape") or object.has_method("_begin_return"): object.set_physics_process(false)
  check_expected(row,c,6)
  for object: Node in root.get_children():
   if object.has_method("_begin_return") and String(object.damage_packet.get("origin_skill_id",""))==String(row.skill_id):
    var before: int=enemy.packets.size()
    object._on_body_entered(enemy)
    expect(enemy.packets.size()>before,row.skill_id+" real emitted projectile settles damage")
    expect(not enemy.packets[-1].can_generate_secondary_proc,row.skill_id+" actual projectile child provenance")
    break
 clean();await process_frame
 if failed==0: print("[verify_fusion_first_batch_outputs_v2] PASS")
 finish()
