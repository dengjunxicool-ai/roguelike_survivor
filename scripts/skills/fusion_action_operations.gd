extends RefCounted
# Additional action families share the same fusion runtime state and executor.
const Adapter=preload("res://scripts/skills/skill_effect_adapter.gd")
const Geometry=preload("res://scripts/skills/skill_object_geometry.gd")
const Areas=preload("res://scripts/combat/area_effect_manager.gd")
static func perform(rt: RefCounted,bus: Node,r: Dictionary,c: Dictionary,skill: RefCounted) -> bool:
	var op: String=String(r.operation)
	var target: Node=c.get("target") as Node
	var status: Node=target.get_node_or_null("StatusEffectManager") if target!=null else null
	var selected: Array[Node2D]=rt.targets(c,r)
	var key: String=String(skill.skill_id)+":"
	match op:
		"curse_shorten_mark":
			if status==null: return false
			status.merge_status_fields(&"cursed",{"fusion_ground_origin":String(skill.skill_id)})
			return status.consume_status_duration(&"cursed",float(r.seconds))
		"marked_effects":
			if String(c.get("resolved_status",{}).get("fusion_ground_origin",""))!=String(skill.skill_id): return false
			return rt.effects(bus,r.effects,c,skill)
		"consume_effects":
			if status==null or not status.consume_status_duration(StringName(r.consume_status),float(r.seconds)): return false
			return rt.effects(bus,oriented(r.effects,c,r),c,skill)
		"caster_effects":
			c.position=c.caster.global_position
			return rt.effects(bus,r.effects,c,skill)
		"reverse_echo":
			var actions: Array=Adapter.to_actions(oriented(r.effects,c,{"reverse_path":true}),skill)
			for a: Dictionary in actions:
				if String(a.type)=="spawn_area": a.params.hit_all_targets=true
			c.position=c.other_area.global_position
			return bus.schedule_output(actions,c,float(r.delay))
		"preferred_projectiles","rift_projectile":
			if selected.is_empty() and op=="preferred_projectiles":
				var fallback: Dictionary=r.duplicate(true)
				fallback.erase("select_status")
				selected=rt.targets(c,fallback)
			if selected.is_empty(): return false
			if op=="rift_projectile": c.position=c.rift.global_position
			c.target=selected[0]
			var payload: Array=r.effects.duplicate(true)
			for e: Dictionary in payload:
				e.targeting="nearest_enemy";e.homing=true;e.homing_enabled=true;e.spawn_position=c.position;e.direction=(c.position as Vector2).direction_to(selected[0].global_position)
			return rt.effects(bus,payload,c,skill)
		"beam":
			if target==null or selected.is_empty(): return false
			var start: Vector2=(target as Node2D).global_position
			var end: Vector2=selected[0].global_position
			var payload: Dictionary={"type":"spawn_area","area_id":r.output_area_id,"position_mode":"event","shape":"line","length":start.distance_to(end),"width":25.2,"radius":start.distance_to(end),"duration":.2,"tick_interval":1,"cone_direction":start.direction_to(end),"effects_on_apply":r.effects}
			c.position=start
			return rt.effects(bus,[payload],c,skill)
		"path_jump":
			var path: Node=c.covering_area
			selected=selected.filter(func(e: Node2D)->bool:return Geometry.contains(path.geometry_shape(),e.global_position))
			selected.sort_custom(func(a: Node2D,b: Node2D)->bool:
				if a.has_status(&"conductive")!=b.has_status(&"conductive"): return a.has_status(&"conductive")
				return a.global_position.distance_squared_to(c.position)<b.global_position.distance_squared_to(c.position))
			if selected.is_empty(): return false
			c.target=selected[0];c.position=selected[0].global_position
			return rt.effects(bus,r.effects,c,skill)
		"store_area_charge":
			var area: Node=c.covering_area
			if rt._charges.has(key+object_key(area)): return false
			rt._charges[key+object_key(area)]={"area":weakref(area),"charged":true}
			return true
		"consume_area_charge":
			var k: String=key+object_key(c.area)
			if not rt._charges.has(k): return false
			rt._charges.erase(k)
			return rt.effects(bus,r.effects,c,skill)
		"shatter_targets":
			if target==null: return false
			rt._executor.execute_action({"type":"shatter_frozen","params":{"amount":0,"low_hp_execute_threshold":.1,"damage_type":"thunder"}},c)
			var done: bool=false
			for next: Node2D in selected.slice(0,int(r.count)):
				var child: Dictionary=c.duplicate(true);child.target=next;child.position=next.global_position;child.erase("target_statuses")
				done=rt.effects(bus,r.effects,child,skill) or done
			return done
		"chain_priority":
			var candidates: Array=c.get("chain_candidates",[])
			var eligible: Array=candidates.filter(func(e: Node2D)->bool:return is_instance_valid(e) and not e.is_dead() and e.has_status(&"cursed"))
			if eligible.is_empty(): return status!=null and status.consume_status_duration(&"cursed",float(r.seconds))
			eligible.sort_custom(func(a: Node2D,b: Node2D)->bool:return a.global_position.distance_squared_to(c.position)<b.global_position.distance_squared_to(c.position))
			c.chain_result.target=eligible[0]
			return true
		"count_targets":
			var parent_id: String=String(c.get("source_instance_id",object_key(c.area)))
			if c.area.damage_packet.has("source_object_id"): parent_id="%d:%d" % [c.area.damage_packet.source_object_id,c.area.damage_packet.source_generation]
			var identity: String=key+parent_id
			var strike: String=key+"strike:"+String(c.get("strike_id",object_key(c.area)))
			if rt._observed.has(strike): return false
			rt._observed[strike]=true
			rt._counts[identity]=int(rt._counts.get(identity,0))+1
			if int(rt._counts[identity])%int(r.every)!=0 or selected.is_empty(): return false
			c.target=selected[0];c.position=selected[0].global_position;c.erase("target_statuses")
			var done: bool=rt.effects(bus,r.effects,c,skill)
			if bool(r.get("resolve_last",false)): selected[0].get_node("StatusEffectManager").resolve_cursed(&"storm_convergence")
			return done
		"transfer_curse":
			if status==null or selected.is_empty(): return false
			var snapshot: Dictionary=c.get("cursed_snapshot",status.export_status(&"cursed")).duplicate(true)
			if snapshot.is_empty(): return false
			status.consume_status_stack(&"cursed",int(snapshot.get("stacks",1)))
			snapshot.erase("pause_sources");snapshot.erase("fusion_thaw_origin")
			snapshot.duration=float(snapshot.get("duration_remaining",6));snapshot.can_generate_secondary_proc=false;snapshot.proc_depth=1
			return selected[0].apply_status(&"cursed",snapshot)
		"curse_resume":
			if status==null: return false
			status.resume_status(&"cursed",skill.skill_id)
			return true
		"death_effects":
			var done: bool=rt.effects(bus,r.effects,c,skill)
			var p: Dictionary=c.get("damage_packet",{})
			if String(c.get("incoming_status_id",""))=="cursed": done=rt.effects(bus,oriented(r.curse_kill_effects,c,{"from_caster":true}),c,skill) or done
			return done
		"full_shield_effects":
			var full: bool=preload("res://scripts/skills/skill_shield_state.gd").amount(c.caster)>=roundi(float(c.caster.max_health)*.35)
			var done: bool=rt.effects(bus,r.effects,c,skill)
			return rt.effects(bus,r.full_effects,c,skill) or done if full else done
		"projectile_path":
			var object: Node2D=c.get("projectile") as Node2D
			if object==null: return false
			if target!=null and target.has_status(&"frozen"): object.lifetime+=float(r.frozen_lifetime_add)
			c.position=c.caster.global_position
			var payload: Array=r.effects.duplicate(true)
			for e: Dictionary in payload:
				e.cone_direction=object.direction;e.length=c.caster.global_position.distance_to((target as Node2D).global_position);e.radius=e.length
			return rt.effects(bus,payload,c,skill)
		"holy_overload":
			if not rt._executor.execute_action({"type":"trigger_overload","params":{}},c): return false
			return rt.effects(bus,[{"type":"apply_status","status":"judgment","stacks":1,"duration":6}],c,skill)
		"dual_burst":
			if selected.is_empty(): return false
			var done: bool=rt.effects(bus,r.effects,c,skill)
			c.target=selected[0];c.position=selected[0].global_position;c.erase("target_statuses")
			return rt.effects(bus,r.effects,c,skill) or done
		"extend_area":
			var a: Node=c.covering_area
			a.extend_duration(float(a.duration-a._age)+float(r.seconds),float(a.duration-a._age)+float(r.seconds))
			return true
		"area_edge","area_curse_shorten","area_curse_exchange":
			var a: Node=c.area
			var elapsed: float=float(c.get("elapsed",0))
			var interval: float=float(r.interval)
			if elapsed<=0 or not is_equal_approx(fmod(elapsed,interval),0): return false
			var serial: String=key+object_key(a)+":"+str(roundi(elapsed/interval))
			if rt._observed.has(serial): return false
			rt._observed[serial]=true
			var inside: Array[Node2D]=rt.targets(c,{"radius":a.geometry_query_radius(),"operation":"retarget"})
			inside=inside.filter(func(e: Node2D)->bool:return Geometry.contains(a.geometry_shape(),e.global_position))
			if op=="area_curse_exchange":
				inside=inside.filter(func(e: Node2D)->bool:return e.has_status(&"cursed"))
				if inside.is_empty() or selected.is_empty(): return false
				var snapshot: Dictionary=inside[0].get_node("StatusEffectManager").export_status(&"cursed")
				snapshot.stacks=1;snapshot.duration=snapshot.duration_remaining;snapshot.proc_depth=1;snapshot.can_generate_secondary_proc=false
				return selected[0].apply_status(&"cursed",snapshot)
			var done: bool=false
			for e: Node2D in inside:
				if op=="area_curse_shorten":
					done=e.get_node("StatusEffectManager").consume_status_duration(&"cursed",float(r.seconds)) or done
				elif e.global_position.distance_to(a.global_position)>=maxf(a.radius-29.4,0):
					var child: Dictionary=c.duplicate(true);child.target=e;child.position=e.global_position;child.erase("target_statuses")
					done=rt.effects(bus,r.effects,child,skill) or done
			return done
		"teleport_shard":
			var object: Node2D=c.get("projectile") as Node2D
			if object==null or selected.is_empty(): return false
			var next: Node2D=selected[0]
			object.global_position=next.global_position+object.direction*42
			object.direction=object.global_position.direction_to(next.global_position)
			var scale: float=float(r.get("damage_scale",0))
			object.damage=roundi(float(object.damage)*scale if scale>0 else c.power*float(r.power_scale))
			object.damage_packet.raw_amount=object.damage;object.damage_packet.amount=object.damage
			object.damage_packet.can_generate_secondary_proc=false;object.damage_packet.proc_depth=mini(int(object.damage_packet.get("proc_depth",0))+1,2)
			var actions: Array=Adapter.to_actions(r.effects,skill)
			for a: Dictionary in object.actions_on_hit:
				if String(a.type)=="deal_damage": a.params.amount=object.damage
			object.actions_on_hit.append_array(actions)
			bus.clear_interaction_object(object)
			return true
	return false
static func object_key(object: Node) -> String:
	return "%d:%d" % [object.get_instance_id(),int(object.get("spawn_generation"))]
static func oriented(items: Array,c: Dictionary,r: Dictionary) -> Array:
	var payload: Array=items.duplicate(true)
	var direction: Vector2=Vector2.RIGHT
	if bool(r.get("from_caster",false)):
		direction=c.caster.global_position.direction_to(c.position);c.position=c.caster.global_position
	elif c.get("projectile")!=null: direction=c.projectile.direction
	elif c.get("area")!=null: direction=c.area.cone_direction
	if bool(r.get("reverse_path",false)): direction=-direction
	for e: Dictionary in payload:
		if String(e.type)=="spawn_area": e.cone_direction=direction
	return payload
