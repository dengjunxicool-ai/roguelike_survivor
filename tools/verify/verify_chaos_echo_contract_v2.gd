extends "res://tools/verify/verify_base_skill_behavior_v2.gd"
const Cooldowns=preload("res://scripts/skills/skill_component_runner.gd")
func run() -> void:
 setup();enemy.get_node("StatusEffectManager").set_physics_process(false)
 var echo: RefCounted=install(&"chaos_power_echo_cast")
 var cast: RefCounted=install(&"chaos_cast_mutation_pulse")
 bus.emit_skill_event(&"on_cast",ctx(enemy,cast))
 await process_frame
 var snapshot: Dictionary=bus.get_cast_snapshot()
 expect(not snapshot.is_empty(),"echo source is an actual recorded output")
 var counter: int=output_count("chaos_cast_mutation_pulse")
 # The successful initial cast is charge one; copied success never advances charge.
 var copied: Dictionary=ctx(enemy,cast);copied.is_copy=true;copied.can_generate_secondary_proc=false;copied.proc_depth=1
 bus.emit_skill_event(&"skill_cast_succeeded",copied)
 expect(output_count("chaos_cast_mutation_pulse")==counter,"copied successful cast cannot echo")
 for i: int in 2:
  bus.emit_skill_event(&"skill_cast_succeeded",ctx(enemy,cast))
 expect(output_count("chaos_cast_mutation_pulse")==counter,"first three chaos casts have no echo")
 bus.emit_skill_event(&"skill_cast_succeeded",ctx(enemy,cast));await process_frame
 expect(output_count("chaos_cast_mutation_pulse")==counter+1,"fourth chaos cast emits original pulse once")
 var copied_output: bool=false
 for a: Node in root.get_children():
  if a.has_method("geometry_shape") and a.source_id==&"mutation_pulse_area" and a.damage_packet.get("is_copy",false):
   copied_output=true
   var before: int=enemy.packets.size();a._execute_apply_actions()
   expect(enemy.packets.size()>before and int(enemy.packets[-1].raw_amount)==36,"actual echo pulse is forty percent of ninety power")
 expect(copied_output,"echo marks actual copied output")
 clean_base();await process_frame
 var static_skill: RefCounted=install(&"thunder_passive_static_charge")
 var thunder: RefCounted=install(&"thunder_cast_chain_lightning")
 var c: Dictionary=ctx(enemy,thunder);c.damage_packet={"element":"lightning"};c.damage_amount=100
 var runner: RefCounted=Cooldowns.new();var before_cd: float=runner.get_cooldown(thunder,c)
 for i: int in 17: bus.emit_skill_event(&"post_damage_hit",c)
 expect(is_equal_approx(runner.get_cooldown(thunder,c),before_cd),"seventeen hits do not grant static cooldown bonus")
 bus.emit_skill_event(&"post_damage_hit",c)
 expect(is_equal_approx(runner.get_cooldown(thunder,c),before_cd*.9),"eighteenth hit grants actual ten percent cooldown bonus "+str(runner.get_cooldown(thunder,c))+" base "+str(before_cd))
 expect(is_equal_approx(float(Aggregator.collect(Query.for_skill(Fixture.skill("attack"),player),manager).get("attack_speed_multiplier_add",0)),.2),"static grants twenty percent speed only to attacks")
 advance(4.01);player.get_node("ModifierStore").tick_timed_sources(4.01)
 expect(is_equal_approx(runner.get_cooldown(thunder,c),before_cd),"static buff expires after four combat seconds")
 clean_base();await process_frame
 if failed==0: print("[verify_chaos_echo_contract_v2] PASS")
 finish()
