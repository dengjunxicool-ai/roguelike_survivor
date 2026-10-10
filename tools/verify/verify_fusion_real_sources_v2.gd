extends "res://tools/verify/verify_fusion_second_batch_v2.gd"
const Executor=preload("res://scripts/skills/skill_action_executor.gd")
func run() -> void:
 setup();nearby=[make_enemy(Vector2(80,0)),make_enemy(Vector2(120,0)),make_enemy(Vector2(160,0)),make_enemy(Vector2(200,0))]
 for e: Enemy in [enemy]+nearby: e.get_node("StatusEffectManager").set_physics_process(false)
 var fire: RefCounted=install(&"fire_attack_searing");install(&"fusion_fire_chaos_molten_split")
 enemy.apply_status(&"instability",{"stacks":1,"duration":6})
 var bolt: Node2D=Projectile.new();root.add_child(bolt);fixture_objects.append(bolt)
 bolt.setup({"source_id":"fire_searing_bolt","caster":player,"skill_manager":manager,"skill_instance":fire,"event_bus":bus,"damage":100,"damage_packet":{"origin_skill_id":fire.skill_id,"source_skill_id":fire.skill_id,"can_generate_secondary_proc":true,"proc_depth":0}});bolt.set_physics_process(false)
 var c: Dictionary=ctx(enemy,fire);c.projectile=bolt
 Executor.new().execute_action({"type":"deal_damage","params":{"amount":100,"damage_type":"fire","source_type":"attack"}},c)
 await process_frame
 expect(bus.fusion_output_count("fusion_fire_chaos_molten_split")==1 and output_count("fusion_fire_chaos_molten_split")==2,"actual projectile damage retains form and splits two")
 clean();await process_frame
 var storm: RefCounted=install(&"thunder_cast_storm_circle");install(&"fusion_thunder_curse_black_thunder_convergence")
 nearby[0].apply_status(&"cursed",{"stacks":1,"duration":6,"power":100})
 bus.emit_skill_event(&"on_cast",ctx(enemy,storm))
 var cloud: Node=null
 for a: Node in AreaManager.get_or_create(player).get_active_areas():
  if String(a.source_id)=="thunderstorm_cloud": cloud=a
 expect(cloud!=null,"actual storm cloud exists")
 if cloud!=null:
  cloud.set_physics_process(false)
  for i: int in 5:
   cloud._damage_body(enemy)
   await process_frame
   expect(bus.fusion_output_count("fusion_thunder_curse_black_thunder_convergence")==int(i==4),"real storm strike "+str(i+1)+" only fifth converges")
 clean();await process_frame
 # A true Frozen death transfers the complete curse without a second settlement.
 var curse: RefCounted=install(&"curse_cast_doom_circle");install(&"fusion_curse_frost_ice_coffin_contract")
 enemy.apply_status(&"cursed",{"stacks":2,"duration":6,"power":123});enemy.apply_status(&"frozen",{"duration":1.2})
 nearby[1].current_health=20000
 var before: float=total_damage()
 Executor.new().execute_action({"type":"deal_damage","params":{"amount":1,"damage_type":"curse"}},ctx(enemy,curse))
 expect(nearby[1].get_status_stack(&"cursed")==0,"alive Frozen hit never transfers curse")
 enemy.current_health=1
 Executor.new().execute_action({"type":"deal_damage","params":{"amount":1,"damage_type":"curse"}},ctx(enemy,curse))
 expect(not enemy.has_status(&"cursed") and nearby[1].get_status_stack(&"cursed")==2,"actual Frozen death transfers to highest health target")
 expect(is_equal_approx(total_damage()-before,2),"transfer does not resolve corpse curse")
 clean();await process_frame
 install(&"holy_power_divine_punishment");install(&"thunder_power_overload_burst");install(&"fusion_holy_thunder_holy_thunder_judgment")
 enemy.apply_status(&"conductive",{"stacks":1,"duration":6})
 enemy.apply_status(&"judgment",{"stacks":5,"duration":6})
 bus.process_pending_events()
 expect(bus.fusion_output_count("fusion_holy_thunder_holy_thunder_judgment")==1,"real Judgment forces exactly one overload")
 var overload_packet: bool=false
 for packet: Dictionary in enemy.packets: overload_packet=overload_packet or String(packet.get("listener_skill_id",""))=="thunder_power_overload_burst"
 expect(overload_packet and not enemy.has_status(&"overload"),"forced overload deals the real base reaction packet")
 expect(bus.get("_pending_events").is_empty() and enemy.packets.size()<20,"Judgment overload propagation terminates")
 clean();await process_frame
 install(&"fusion_curse_holy_absolution_harvest")
 enemy.apply_status(&"judgment",{"stacks":1,"duration":6});enemy.apply_status(&"cursed",{"stacks":1,"duration":6,"power":100})
 enemy.current_health=50
 enemy.get_node("StatusEffectManager").resolve_cursed(&"test")
 await process_frame
 expect(int(player.get_meta("fire_passive_shield",0))==20 and output_count("fusion_curse_holy_absolution_harvest")==1,"actual Cursed kill preserves death snapshot and emits extra holy beam")
 clean();await process_frame
 if failed==0: print("[verify_fusion_real_sources_v2] PASS")
 finish()
