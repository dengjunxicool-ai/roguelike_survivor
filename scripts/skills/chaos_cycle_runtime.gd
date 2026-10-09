## 混沌轮换、下一次充能和奇点延时都消费局内战斗时间。
extends RefCounted
const Query = preload("res://scripts/modifiers/modifier_query.gd")
var entropy: Array[Dictionary] = []
var entropy_next: int = 0
var stability_count: int = 0
var stability_ready: bool = false
var echo_count: int = 0
var fissions: int = 0
var geometry_next: int = 0
var pending: Array[Dictionary] = []
func state() -> Dictionary:
	return {"entropy":entropy.duplicate(true),"entropy_next":entropy_next,"stability_ready":stability_ready,"echo_count":echo_count,"pending":pending.size()}
func reset() -> void:
	entropy.clear()
	entropy_next = 0
	stability_count = 0
	stability_ready = false
	echo_count = 0
	fissions = 0
	geometry_next = 0
	pending.clear()
func clear_origin(id: StringName) -> void:
	pending = pending.filter(func(x: Dictionary) -> bool: return x.origin != id)
	for item: Dictionary in pending:
		if String(item.snapshot.get("origin_skill_id","")) == String(id): item.snapshot = {}
	if id == &"chaos_passive_anomalous_stability": stability_ready = false; stability_count = 0
	if id == &"chaos_power_echo_cast": echo_count = 0
	if id == &"chaos_passive_entropy_growth": entropy.clear()
func prepare(context: Dictionary) -> void:
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	if stability_ready and skill != null and String(skill.school) == "chaos" and String(skill.skill_type) == "cast" and not context.get("is_copy",false):
		context["cast_damage_multiplier"] = float(context.get("cast_damage_multiplier",1.0))*1.25
		context["chaos_stability_consumed"] = true
func handle(bus: Node, name: StringName, context: Dictionary) -> void:
	var manager: Node = context.get("skill_manager") as Node
	if manager == null: return
	var skill: RefCounted = context.get("skill_instance") as RefCounted
	if bool(context.get("is_copy",false)): return
	if name == &"skill_cast_succeeded" and skill != null and String(skill.skill_type) == "cast" and int(context.get("proc_depth",0)) == 0:
		if String(skill.school) == "chaos" and manager.has_skill(&"chaos_passive_anomalous_stability"):
			if context.get("chaos_stability_consumed",false): stability_ready = false; stability_count = 0
			elif not stability_ready:
				stability_count += 1
				stability_ready = stability_count >= 5
		if manager.has_skill(&"chaos_power_echo_cast"):
			echo_count = mini(echo_count+1,4)
			if echo_count >= 4 and bus.replay_cast(bus.get_cast_snapshot({"skill_type":"cast"}),context,0.4): echo_count = 0
	if name != &"status_max_stack_reached" or String(context.get("status_id","")) != "instability" or not manager.has_skill(&"chaos_power_fission_burst"): return
	if int(context.get("proc_depth",0)) >= 2: return
	if manager.has_skill(&"chaos_passive_entropy_growth"):
		if entropy.size() == 2:
			var old: Dictionary = entropy.pop_front()
			context.caster.get_node("ModifierStore").clear_source(old.source)
		var source: String = "skill:chaos_passive_entropy_growth:branch:%d" % entropy_next
		var stat: String = ["damage","range","cooldown","move_speed"][entropy_next]
		var entry: Dictionary = {"stat":stat,"op":"multiplier_add","value":-0.12 if stat == "cooldown" else 0.12,"scope":{}}
		context.caster.get_node("ModifierStore").set_timed_source(source,[entry],[],5.0)
		entropy.append({"source":source,"expires":bus.combat_seconds()+5.0,"branch":entropy_next})
		entropy_next = (entropy_next+1)%4
	if manager.has_skill(&"chaos_core_chaos_singularity"):
		fissions += 1
		if fissions >= 25:
			fissions -= 25
			var child: Dictionary = context.duplicate(true)
			child.skill_instance = manager.get_skill(&"chaos_core_chaos_singularity")
			child.skill_id = &"chaos_core_chaos_singularity"
			child.origin_skill_id = child.skill_id
			child.can_generate_secondary_proc = false
			bus.execute_adapted_actions([{"type":"spawn_area","params":{"area_id":"chaos_singularity_field","position_mode":"caster","radius_r":6,"duration":2,"tick_interval":1,"actions_on_tick":[{"type":"pull","params":{"pull_radius_r":6,"strength":0.32}}]}}],child)
			pending.append({"at":bus.combat_seconds()+2.0,"origin":child.skill_id,"context":child,"snapshot":bus.get_cast_snapshot({"skill_type":"cast","exclude_school":"chaos"})})
func update(bus: Node) -> void:
	var now: float = bus.combat_seconds()
	entropy = entropy.filter(func(x: Dictionary) -> bool: return x.expires > now)
	for item: Dictionary in pending.duplicate():
		if item.at > now: continue
		pending.erase(item)
		var c: Dictionary = item.context
		var caster: Node = c.get("caster") as Node
		if caster == null or not is_instance_valid(caster) or not c.skill_manager.has_skill(item.origin): continue
		bus.execute_adapted_actions([{"type":"spawn_area","params":{"area_id":"chaos_singularity_burst","position_mode":"caster","radius_r":6,"duration":0.28,"actions_on_apply":[{"type":"deal_damage","params":{"amount":{"stat":"power","scale":3.0},"damage_type":"arcane","source_type":"core"}}]}}],c)
		bus.replay_cast(item.snapshot,c,0.5)

func geometry(params: Dictionary, context: Dictionary) -> Dictionary:
	var manager: Node = context.get("skill_manager") as Node
	if manager == null or not manager.has_skill(&"chaos_passive_geometric_imbalance") or context.get("is_copy",false) or not context.get("can_generate_secondary_proc",true) or params.has("chaos_geometry_branch"): return params
	var result: Dictionary = params.duplicate(true)
	preload("res://scripts/skills/skill_replay_service.gd").scale_damage(result,0.9)
	result["chaos_geometry_branch"] = geometry_next
	geometry_next = (geometry_next+1)%3
	return result
