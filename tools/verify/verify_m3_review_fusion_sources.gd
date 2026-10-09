extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Area=preload("res://scripts/combat/area_effect.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 setup();enemy.get_node("StatusEffectManager").set_physics_process(false)
 var frost: RefCounted=install(&"frost_cast_glacial_lance")
 var rift: RefCounted=install(&"chaos_cast_void_rift")
 install(&"frost_cast_frost_field");player.set_meta("character_level",6)
 var policy: RefCounted=preload("res://scripts/skills/skill_requirement_policy.gd").new()
 expect(not policy.evaluate(player,GameData.get_skill(&"fusion_frost_chaos_rift_avalanche")).available,"avalanche unavailable without its base shatter producer")
 install(&"frost_power_shatter_execute")
 expect(policy.evaluate(player,GameData.get_skill(&"fusion_frost_chaos_rift_avalanche")).available,"avalanche available with actual base shatter producer")
 install(&"fusion_frost_chaos_rift_avalanche")
 bus.emit_skill_event(&"on_cast",ctx(enemy,rift));await process_frame
 for n: Node in root.get_children():
  if n.has_method("geometry_shape"):n.set_physics_process(false)
 enemy.current_health=900
 enemy.apply_status(&"frozen",{"duration":1.2})
 bus.execute_adapted_actions([{"type":"deal_damage","params":{"amount":1,"damage_type":"frost"}}],ctx(enemy,frost))
 await process_frame
 expect(enemy.current_health==0 and bus.fusion_output_count("fusion_frost_chaos_rift_avalanche")==1,"base frozen execution produces one actual avalanche near rift")
 manager.clear_skills();bus.reset_run_state()
 for n: Node in root.get_children():
  if n.has_method("geometry_shape"):n.queue_free()
 await process_frame
 enemy.current_health=10000;enemy.get_node("StatusEffectManager").clear_statuses()
 var holy: RefCounted=install(&"holy_cast_judgment_hammer")
 install(&"holy_cast_divine_barrier")
 install(&"fusion_holy_curse_penitence_barrier")
 var area: Node=Area.new();root.add_child(area);area.position=enemy.position
 area.setup({"source_id":"judgment_hammer_impact","radius":150,"duration":0.2,"caster":player,"skill_manager":manager,"skill_instance":holy,"event_bus":bus,"damage_packet":{"origin_skill_id":holy.skill_id,"source_skill_id":holy.skill_id},"damage":0});area.set_physics_process(false)
 var death: Dictionary=ctx(enemy,holy);death.target_statuses=[{"id":"cursed","stacks":1}]
 bus.emit_skill_event(&"on_enemy_killed",death)
 expect(is_equal_approx(area.duration,0.2) and bus.fusion_output_count("fusion_holy_curse_penitence_barrier")==0,"wrong holy hammer area never extends from penitence")
 manager.clear_skills();bus.reset_run_state()
 holy=install(&"holy_cast_judgment_hammer");install(&"holy_cast_divine_barrier");install(&"fusion_fire_holy_burning_light_barrier")
 area=Area.new();root.add_child(area);area.position=enemy.position
 area.setup({"source_id":"judgment_hammer_impact","radius":150,"duration":0.2,"caster":player,"skill_manager":manager,"skill_instance":holy,"event_bus":bus,"damage_packet":{"origin_skill_id":holy.skill_id,"source_skill_id":holy.skill_id},"damage":0});area.set_physics_process(false)
 death=ctx(enemy,holy);death.target_statuses=[{"id":"burning","stacks":1}]
 bus.emit_skill_event(&"on_enemy_killed",death)
 expect(bus.fusion_output_count("fusion_fire_holy_burning_light_barrier")==0,"wrong holy hammer area never grants burning-barrier death shield")
 print("[verify_m3_review_fusion_sources] " + ("PASS" if failed==0 else "FAIL"))
 finish()
