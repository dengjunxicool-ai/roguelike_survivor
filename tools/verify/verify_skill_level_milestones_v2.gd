extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Adapter = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
const Runner = preload("res://scripts/skills/skill_component_runner.gd")
const IDS := ["fire_cast_meteor_rain","fire_cast_lava_rift","fire_cast_scorching_vortex","frost_cast_frost_field","frost_cast_glacial_lance","frost_cast_blizzard_cloud","thunder_cast_chain_lightning","thunder_cast_storm_circle","thunder_cast_emp_ring","curse_cast_black_serpent_hunt","curse_cast_death_scythe","curse_cast_doom_circle","holy_cast_holy_ray","holy_cast_divine_barrier","holy_cast_judgment_hammer","chaos_cast_void_rift","chaos_cast_singularity_barrage","chaos_cast_mutation_pulse"]
func _init() -> void: call_deferred("run")
func run() -> void:
	setup()
	expect(ResourceLoader.exists("res://scripts/skills/skill_growth_profile.gd"), "id-based immutable milestones exist")
	if failed > 0: finish(); return
	var profile: Script = load("res://scripts/skills/skill_growth_profile.gd")
	for id: String in IDS:
		var data: Dictionary = GameData.get_skill(id)
		expect(not data.is_empty(), id+" exists, no invented alias")
		var skill: RefCounted = install(StringName(id))
		var original: Dictionary = data.duplicate(true)
		var lv1: Array = profile.resolve_actions(data,1)
		var lv3: Array = profile.resolve_actions(data,3)
		var lv5: Array = profile.resolve_actions(data,5)
		expect(lv1 != lv3 and lv3 != lv5, id+" has actual Lv3 and Lv5 behavior")
		expect(profile.resolve_actions(data,5) == lv5 and data == original, id+" repeated resolution immutable")
		expect(profile.resolve_actions(data,4) == lv3, id+" Lv3 persists without repeated addition")
		expect(profile.describe_next_milestone(data,1).level == 3 and profile.describe_next_milestone(data,3).level == 5, id+" next milestone data shared with preview")
		skill.current_level = 5
		var events: Array = Adapter.to_events(skill,skill.definition)
		expect(not events.is_empty(), id+" final actions use normal adapter")
		var cd: float = Runner.new().get_cooldown(skill,ctx(enemy,skill))
		expect(is_equal_approx(cd,float(data.trigger_rules[0].cooldown)*0.84),id+" cooldown growth applied once")
		manager.active_skills.erase(StringName(id))
	var meteor: Dictionary = GameData.get_skill("fire_cast_meteor_rain")
	expect(profile.resolve_actions(meteor,1)[0].count == 3 and profile.resolve_actions(meteor,3)[0].count == 4 and profile.resolve_actions(meteor,5)[0].count == 4,"meteor counts 3/4/4")
	var lance: Dictionary = GameData.get_skill("frost_cast_glacial_lance")
	expect(profile.resolve_actions(lance,1)[0].pierce == 6 and profile.resolve_actions(lance,3)[0].pierce == 8 and profile.resolve_actions(lance,5)[0].pierce == 8,"lance pierce 6/8/8")
	var field: RefCounted = install(&"frost_cast_frost_field")
	field.current_level = 3
	bus.emit_skill_event(&"on_cast",ctx(enemy,field))
	await process_frame
	var region: AreaEffect = find_area(&"frost_field")
	expect(region != null,"Lv3 field creates original real area")
	if region != null:
		region.set_physics_process(false)
		
		expect(enemy.get_status_stack("chilled") == 2,"Lv3 frost field first hit adds two Chilled")
		await physics_frame
		region._damage_body(enemy)
		expect(enemy.get_status_stack("chilled") == 3,"later tick adds only one Chilled")
	var barrier: RefCounted = install(&"holy_cast_divine_barrier")
	barrier.current_level = 3
	var zone: AreaEffect = preload("res://scripts/combat/combat_object_factory.gd").create_area_effect({"parent":root,"position":Vector2.ZERO,"source_id":&"divine_barrier_field","radius":100,"duration":5,"damage":0,"event_bus":bus,"skill_manager":manager,"skill_instance":barrier,"caster":player,"damage_packet":{"source_skill_id":barrier.skill_id}})
	await process_frame
	player.set_meta("fire_passive_shield",0)
	bus.emit_skill_event(&"area_step",{"caster":player,"owner":player,"area":zone,"radius":100,"skill_manager":manager,"skill_instance":barrier,"skill_id":barrier.skill_id,"origin_skill_id":barrier.skill_id})
	expect(int(player.get_meta("fire_passive_shield",0)) == 13,"Lv3 barrier actual recovery is 1.25 percent per second")
	var emp: RefCounted = install(&"thunder_cast_emp_ring")
	emp.current_level = 5
	emp.cooldown_remaining = 5.0
	enemy.apply_status("conductive",{"stacks":5})
	var actions: Array = Adapter.to_events(emp,emp.definition)[0].actions[0].params.actions_on_apply
	var refund: Dictionary = actions.back()
	var refund_context: Dictionary = ctx(enemy,emp)
	refund_context.source_instance_id = "emp-test-cast"
	bus.execute_adapted_actions([refund],refund_context)
	bus.execute_adapted_actions([refund],refund_context)
	expect(is_equal_approx(emp.cooldown_remaining,4.5),"Lv5 EMP actual cooldown refund once per cast")
	var ordinary: int = 0
	for base: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/skills.json")).skills:
		if not base.get("fusion_school") and base.has("school") and not IDS.has(String(base.id)) and String(base.school) in ["fire","frost","thunder","curse","holy","chaos"]:
			ordinary += 1
			expect(profile.resolve_actions(base,1) == profile.resolve_actions(base,5),String(base.id)+" retains original Lv1 mechanics with generic growth")
	expect(ordinary == 66,"all 66 other base skills preserve mechanics")
	print("[verify_skill_level_milestones_v2] "+("PASS" if failed == 0 else "FAIL"))
	finish()

func find_area(id: StringName) -> AreaEffect:
	for child: Node in root.get_children():
		if child is AreaEffect and child.source_id == id: return child
	return null
