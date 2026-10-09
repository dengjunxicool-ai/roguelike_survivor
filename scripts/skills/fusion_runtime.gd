extends RefCounted
const Adapter = preload("res://scripts/skills/skill_effect_adapter.gd")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Geometry = preload("res://scripts/skills/skill_object_geometry.gd")
const Areas = preload("res://scripts/combat/area_effect_manager.gd")
const Registry = preload("res://scripts/combat/combat_target_registry.gd")
const Milestone = preload("res://scripts/skills/skill_milestone_runtime.gd")
var _executor: RefCounted = Executor.new()
var _reserved: Dictionary = {}
var _counts: Dictionary = {}
var _entries: Dictionary = {}
var _charges: Dictionary = {}
var _observed: Dictionary = {}
func reset() -> void:
	_reserved.clear(); _counts.clear(); _entries.clear(); _charges.clear(); _observed.clear()
func clear_origin(id: StringName) -> void:
	for table: Dictionary in [_reserved,_counts,_entries,_charges,_observed]:
		for key: Variant in table.keys():
			if String(key).begins_with(String(id)+":"): table.erase(key)
func count(id: String) -> int: return int(_counts.get(id+":outputs",0))
func handle(bus: Node,event: StringName,context: Dictionary) -> void:
	var manager: Node = context.get("skill_manager") as Node
	if manager == null: return
	if bool(context.get("is_copy",false)): return
	var shield_source: StringName = StringName(context.get("shield_source_skill_id", ""))
	var original_shield: bool = event == &"shield_gained" and shield_source != &"" and manager.has_skill(shield_source) and not String(shield_source).begins_with("fusion_")
	if not bool(context.get("can_generate_secondary_proc",true)) and not original_shield: return
	if int(context.get("proc_depth",0))>=2: return
	for skill: RefCounted in manager.get_all_skills():
		for rule: Dictionary in skill.definition.fusion_rules:
			if String(rule.event) != String(event): continue
			var c: Dictionary = context.duplicate(true)
			if context.has("retarget_result"): c["retarget_result"] = context.retarget_result
			if not matches(rule,c): continue
			var target: Node = c.get("target") as Node
			var scope: String = String(c.get("interaction_key",str(target.get_instance_id()) if target != null else "owner"))
			if String(rule.operation)=="teleport":
				var object: Node = c.get("projectile",c.get("area")) as Node
				if object != null: scope = "%d:%d" % [object.get_instance_id(),object.spawn_generation]
			var key: String = String(rule.rule_id)+":"+scope
			if bool(rule.get("entry",false)) and not _entered(key,c): continue
			if not reserve(key,bus.combat_seconds(),float(rule.get("cooldown",1.0))): continue
			c["listener_skill_id"] = skill.skill_id
			c["origin_skill_id"] = skill.skill_id
			c["skill_id"] = skill.skill_id
			c["skill_instance"] = skill
			c["proc_depth"] = mini(int(c.get("proc_depth",0))+1,2)
			c["can_generate_secondary_proc"] = false
			c["cast_damage_multiplier"] = 1.0
			c.erase("damage_packet")
			c.erase("_cast_result")
			if not c.has("power"): c["power"] = float(c.caster.get("attack_power"))
			if perform(bus,rule,c,skill):
				_counts[String(skill.skill_id)+":outputs"] = count(String(skill.skill_id))+1
			else: _reserved.erase(key)
func reserve(key: String,now: float,seconds: float) -> bool:
	if float(_reserved.get(key,-INF))>now: return false
	_reserved[key] = now+seconds
	if _reserved.size()>4096: _reserved.erase(_reserved.keys()[0])
	return true
func _entered(key: String,c: Dictionary) -> bool:
	var area: Node = c.get("area") as Node
	var target: Node = c.get("target") as Node
	if c.has("interaction_entered"): return bool(c.interaction_entered)
	if area != null and String(c.get("event_name",""))=="area_created":
		var identity: String = "%s:%d:%d" % [key,area.get_instance_id(),area.spawn_generation]
		if _observed.has(identity): return false
		_observed[identity] = true
		return true
	if area == null or target == null: return false
	var serial: String = "%d:%d" % [area.get_instance_id(),area.spawn_generation]
	if _entries.has(key) and String(_entries[key].serial)==serial: return false
	_entries[key]={"serial":serial,"area":weakref(area),"target":weakref(target)}
	return true
func matches(rule: Dictionary,c: Dictionary) -> bool:
	var origin: RefCounted = c.get("origin_skill_instance") as RefCounted
	if rule.has("origin") and String(c.get("origin_skill_id","")) != String(rule.origin): return false
	if rule.has("school") and (origin == null or String(origin.definition.school)!=String(rule.school)): return false
	if rule.has("statuses"):
		for name: String in rule.statuses:
			if Milestone.status_stacks(c,name)<=0: return false
	if rule.has("event_status") and String(c.get("status_id",""))!=String(rule.event_status): return false
	if rule.has("reaction") and String(c.get("reaction_kind",""))!=String(rule.reaction): return false
	if rule.has("source_kind"):
		var source: Node = c.get("projectile",c.get("source")) as Node
		var packet: Dictionary = c.get("damage_packet",{})
		if String(rule.source_kind)=="projectile" and not (source != null and source.has_method("_begin_return")) and String(packet.get("source_type",""))!="projectile": return false
	var area: Node = c.get("area") as Node
	if rule.has("area_kind") and not area_is(area,String(rule.area_kind)): return false
	if rule.has("area_origin") and (area == null or object_origin(area)!=String(rule.area_origin)): return false
	if rule.has("area_id") and (area == null or String(area.source_id)!=String(rule.area_id)): return false
	if rule.has("other_area"):
		var other: Node = c.get("other_area") as Node
		if not area_is(other,String(rule.other_area)) or area == null or not Geometry.overlaps(area.geometry_shape(),other.geometry_shape()): return false
	if String(rule.event)=="area_tick":
		var target: Node2D = c.get("target") as Node2D
		if area == null or target == null or not Geometry.contains(area.geometry_shape(),target.global_position): return false
	if rule.has("target_area"):
		var covering: Node = find_area(c,String(rule.target_area),0.0)
		if covering == null: return false
		c["covering_area"] = covering
	if bool(rule.get("needs_rift",false)):
		var rift: Node = find_area(c,"rift",84.0)
		if rift == null: return false
		c["rift"] = rift
	if String(rule.event)=="shield_gained" and float(c.get("shield_amount",c.get("amount",0.0)))<=0.0: return false
	if String(rule.event)=="post_damage_hit" and float(c.get("damage_amount",1.0))<=0.0: return false
	return true
func object_origin(object: Node) -> String:
	return String(object.damage_packet.get("origin_skill_id",object.damage_packet.get("source_skill_id",""))) if object != null else ""
func area_is(area: Node,kind: String) -> bool:
	if area == null or not is_instance_valid(area) or area.is_queued_for_deletion() or not area.has_method("geometry_shape"): return false
	if bool(area.get("_damage_window_finished")): return false
	if kind=="rift": return object_origin(area)=="chaos_cast_void_rift" and String(area.source_id)=="void_rift_field"
	var skill: RefCounted = area.skill_manager.get_skill(StringName(object_origin(area))) if area.skill_manager!=null else null
	return skill != null and String(skill.definition.school)==kind and not object_origin(area).begins_with("fusion_")
func find_area(c: Dictionary,kind: String,extra: float) -> Node:
	var pos: Vector2 = c.get("position",Vector2.ZERO)
	var target: Node2D = c.get("target") as Node2D
	if target != null: pos=target.global_position
	if String(c.get("event_name",""))=="area_created" and c.get("area")!=null: pos=c.area.global_position
	var query: Rect2 = Rect2(pos-Vector2.ONE*extra,Vector2.ONE*extra*2.0)
	for area: Node in Areas.get_or_create(c.caster).query_areas(query):
		if area.caster != c.caster or not area_is(area,kind): continue
		if Geometry.contains(area.geometry_shape(),pos) or (extra>0.0 and Geometry.overlaps(area.geometry_shape(),{"position":pos,"radius":extra})): return area
	return null
func targets(c: Dictionary,rule: Dictionary) -> Array[Node2D]:
	var player: Node2D = c.caster
	var center: Vector2 = c.get("position",player.global_position)
	var list: Array = Registry.get_or_create(player).get_targets_in_radius(center,float(rule.get("radius",1008.0)),&"enemies")
	var out: Array[Node2D] = []
	for target: Node2D in list:
		if (target==c.get("target") and String(rule.get("operation",""))!="retarget") or target.is_queued_for_deletion() or (target.has_method("is_dead") and target.is_dead()): continue
		if rule.has("select_status") and target.get_status_stack(String(rule.select_status))<=0: continue
		if rule.has("select_not_status") and target.get_status_stack(String(rule.select_not_status))>0: continue
		# Reject offscreen destinations when the real camera is available.
		var camera: Camera2D = player.get_viewport().get_camera_2d()
		if camera != null and not Rect2(camera.get_screen_center_position()-player.get_viewport_rect().size/camera.zoom*0.5,player.get_viewport_rect().size/camera.zoom).has_point(target.global_position): continue
		out.append(target)
	out.sort_custom(func(a: Node2D,b: Node2D) -> bool:
		if String(rule.get("priority",""))=="highest_health": return float(a.get("current_health"))>float(b.get("current_health"))
		return a.global_position.distance_squared_to(center)>b.global_position.distance_squared_to(center) if bool(rule.get("far",false)) else a.global_position.distance_squared_to(center)<b.global_position.distance_squared_to(center))
	return out
func effects(bus: Node,items: Array,c: Dictionary,skill: RefCounted) -> bool:
	var actions: Array = Adapter.to_actions(items,skill)
	var success: bool = false
	for action: Dictionary in actions:
		if String(action.type)=="spawn_area": action.params["hit_all_targets"] = true
		if String(action.type) in ["spawn_projectile","spawn_projectile_burst"]: action.params["spawn_position"] = c.get("position",c.caster.global_position)
		var result: Variant = _executor.execute_action(action,c)
		success = (result is bool and result) or (result is int and result>0) or success
	return success
func perform(bus: Node,r: Dictionary,c: Dictionary,skill: RefCounted) -> bool:
	var op: String = String(r.operation)
	var target: Node = c.get("target") as Node
	var status: Node = target.get_node_or_null("StatusEffectManager") if target != null else null
	var selected: Array[Node2D] = targets(c,r)
	match op:
		"effects":
			if bool(r.get("position_other",false)): c.position=c.other_area.global_position
			if bool(r.get("reverse_path",false)): c.position=c.other_area.global_position; r=r.duplicate(true);r.effects[0]["cone_direction"]=-c.area.cone_direction
			return effects(bus,r.get("effects",[]),c,skill)
		"targets","resolve_targets","at_rift":
			if op=="resolve_targets" and status != null: status.resolve_cursed(&"fusion_overload")
			if op=="at_rift": c.position=c.rift.global_position;return effects(bus,r.effects,c,skill)
			var done: bool = false
			for next: Node2D in selected.slice(0,int(r.get("count",1))):
				var child: Dictionary=c.duplicate(true);child.target=next;child.position=next.global_position;child.erase("target_statuses")
				done=effects(bus,r.effects,child,skill) or done
			return done
		"retarget":
			if selected.is_empty(): return false
			selected.sort_custom(func(a: Node2D,b: Node2D) -> bool: return a.get_status_stack(String(r.select_status))>b.get_status_stack(String(r.select_status)))
			# The outer cast dictionary must receive this target before source actions execute.
			if c.has("retarget_result"): c["retarget_result"]["target"]=selected[0]
			return true
		"curse_charge":
			if status==null: return false
			var snap: Dictionary=status.export_status(&"cursed")
			return status.merge_status_fields(&"cursed",{"fusion_resolve_bonus":minf(float(snap.get("fusion_resolve_bonus",0.0))+float(r.amount),float(r.maximum))})
		"curse_freeze":
			if status==null: return false
			status.pause_status(&"cursed",skill.skill_id)
			return status.merge_status_fields(&"cursed",{"fusion_thaw_origin":String(skill.skill_id)})
		"curse_thaw":
			if status==null or String(status.export_status(&"cursed").get("fusion_thaw_origin",""))!=String(skill.skill_id): return false
			status.resume_status(&"cursed",skill.skill_id)
			var resolved: bool=status.resolve_cursed(&"fusion_thaw")
			return effects(bus,r.effects,c,skill) or resolved
		"interrupt":
			if target==null or not target.has_method("interrupt_preparing_attack") or not target.interrupt_preparing_attack(): return false
			if status!=null: status.resolve_cursed(&"confession_interrupt")
			return effects(bus,r.effects,c,skill)
		"next_charge":
			_charges[String(skill.skill_id)+":owner"]=true;return true
		"consume_charge":
			var k: String=String(skill.skill_id)+":owner"
			if not _charges.has(k): return false
			_charges.erase(k);return effects(bus,r.effects,c,skill)
		"copy_curse":
			if status==null or selected.is_empty(): return false
			var snap: Dictionary=status.export_status(&"cursed")
			snap["duration"]=float(r.duration);snap["power"]=float(snap.get("power",c.power))*float(r.damage_scale)
			snap["can_generate_secondary_proc"]=false;snap["proc_depth"]=1
			return selected[0].apply_status(&"cursed",snap)
		"curse_echo":
			c.position=c.rift.global_position
			var value: float=float(c.get("resolved_raw_damage",0.0))*float(r.damage_scale)
			if value<=0: return false
			return effects(bus,[{"type":"instant_area_hit","radius":151.2,"hit_all_targets":true,"position_mode":"event","effects_on_apply":[{"type":"damage","amount":value,"damage_type":"curse","source_type":"fusion"}]}],c,null)
		"reaction_echo":
			var snapshot: Array=c.get("reaction_actions",[]).duplicate(true)
			if snapshot.is_empty(): return false
			preload("res://scripts/skills/skill_replay_service.gd").scale_damage(snapshot,float(r.damage_scale))
			c.position=c.rift.global_position;c.erase("target")
			for action: Dictionary in snapshot:
				if String(action.type)=="spawn_area": action.params["position_mode"]="event";action.params["hit_all_targets"]=true
			bus.execute_adapted_actions(snapshot,c);return true
		"teleport":
			var object: Node2D=c.get("projectile",c.get("area")) as Node2D
			if object==null or selected.is_empty(): return false
			object.global_position=selected[0].global_position
			if object.has_method("geometry_shape"): object.duration=float(r.duration);object._age=0.0
			else: object.lifetime=float(r.duration);object._age=0.0
			bus.clear_interaction_object(object)
			return true
		"area_clone":
			var object: Node2D=c.get("area") as Node2D
			if object==null or selected.is_empty(): return false
			object.set_effect_radius(object.radius+float(r.radius_add))
			var params: Dictionary={"area_id":"zero_rift_copy","position_mode":"event","radius":object.radius*float(r.radius_scale),"duration":float(r.duration),"tick_interval":object.tick_interval,"damage":0,"actions_on_tick":object.actions_on_tick.duplicate(true)}
			c.position=selected[0].global_position
			return bool(_executor.execute_action({"type":"spawn_area","params":params},c))
		"wire":
			if target==null or selected.is_empty(): return false
			var to: Node2D=selected[0]
			var length: float=(target as Node2D).global_position.distance_to(to.global_position)
			var params: Dictionary={"type":"spawn_area","area_id":"judgment_wire","shape":"line","length":length,"width":25.2,"radius":length,"duration":float(r.duration),"tick_interval":float(r.tick_interval),"damage":0,"position_mode":"event","cone_direction":(target as Node2D).global_position.direction_to(to.global_position),"effects_on_tick":r.effects}
			return effects(bus,[params],c,skill)
		"summon_one":
			# A bounded summon with a single empowered opening attack uses combat time.
			var summon: Node2D=preload("res://scripts/skills/fusion_soul_minion.gd").new()
			c.parent.add_child(summon);summon.setup(c,float(r.duration),Adapter.to_actions([{"type":"damage","power_scale":float(r.power_scale),"damage_type":"curse"},r.status_effect],skill))
			return true
	return false

func update() -> void:
	for key: String in _entries.keys():
		var item: Dictionary=_entries[key]
		var area: Node=item.area.get_ref()
		var target: Node2D=item.target.get_ref() as Node2D
		if area==null or target==null or area.is_queued_for_deletion() or not Geometry.contains(area.geometry_shape(),target.global_position): _entries.erase(key)

func has_interaction(manager: Node,event: StringName) -> bool:
	if manager==null: return false
	for skill: RefCounted in manager.get_all_skills():
		for r: Dictionary in skill.definition.fusion_rules:
			if String(r.event)==String(event): return true
	return false
func area_pair_relevant(manager: Node,area: Node,other: Node) -> bool:
	if manager==null: return false
	if not bool(area.damage_packet.get("can_generate_secondary_proc",true)) or not bool(other.damage_packet.get("can_generate_secondary_proc",true)): return false
	for skill: RefCounted in manager.get_all_skills():
		for r: Dictionary in skill.definition.fusion_rules:
			if String(r.event)!="area_overlap": continue
			if r.has("area_origin") and object_origin(area)!=String(r.area_origin): continue
			if r.has("area_id") and String(area.source_id)!=String(r.area_id): continue
			if r.has("area_kind") and not area_is(area,String(r.area_kind)): continue
			if r.has("other_area") and not area_is(other,String(r.other_area)): continue
			return true
	return false
