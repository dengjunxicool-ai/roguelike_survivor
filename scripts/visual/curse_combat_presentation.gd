## 诅咒系只读表现：确认命中/结算/回血，实际契约与实际灵魂计数。
extends Node2D
const Feedback=preload("res://scripts/effects/curse_feedback_effect.gd")
const Status=preload("res://scripts/effects/curse_status_effect.gd")
const Link=preload("res://scripts/effects/curse_link_effect.gd")
var _hits: Array[Node2D]=[]
var _bursts: Array[Node2D]=[]
var _links: Array[Node2D]=[]
var _contracts: Array[Node2D]=[]
var _contract_targets: Dictionary={}
var _owner: Node2D
var _harvest: Node2D
var _debt: Node2D
var _refresh_remaining:=0.0
var _serial:=0
var _cooldowns: Dictionary={}
func _ready() -> void:
	var bus: Node=get_parent()
	_owner=bus.get_parent() as Node2D
	bus.subscribe(&"post_damage_hit",_on_damage)
	bus.subscribe(&"cursed_resolved",_on_resolved)
	bus.subscribe(&"on_enemy_killed",_on_enemy_death)
func _available(items: Array[Node2D],limit: int,script: Script,label: String) -> Node2D:
	for item: Node2D in items:
		if not item.visible: return item
	if items.size()>=limit: return null
	var effect: Node2D=script.new()
	effect.name=label+str(items.size());effect.z_index=9
	add_child(effect);items.append(effect)
	return effect
func _point(context: Dictionary) -> Vector2:
	var p: Variant=context.get("position")
	if p is Vector2: return p
	var target: Node2D=context.get("target") as Node2D
	return target.global_position if is_instance_valid(target) else Vector2.ZERO
func _on_damage(context: Dictionary) -> void:
	if int(context.get("damage_amount",0))<=0: return
	var packet: Dictionary=context.get("damage_packet",{})
	var origin:=String(context.get("damage_origin",packet.get("damage_origin","")))
	if origin=="status_dot": return
	var source:=String(context.get("source_skill_id",packet.get("source_skill_id","")))
	var manager: Node=context.get("skill_manager") as Node
	var primary: bool=origin=="primary_attack" and manager!=null and manager.has_skill(&"curse_attack_cursing")
	if not source.begins_with("curse_") and not primary: return
	var target: Node2D=context.get("target") as Node2D
	var id:=target.get_instance_id() if is_instance_valid(target) else 0
	var now:=float(context.get("combat_seconds",0.0))
	if id>0 and now<float(_cooldowns.get(id,-1.0)): return
	if id>0: _cooldowns[id]=now+0.08
	if _cooldowns.size()>128: _cooldowns.clear()
	var effect:=_available(_hits,24,Feedback,"CurseHit")
	if effect!=null:
		_serial+=1;effect.configure(_point(context)+Vector2(0,-18),27.0,0,float(_serial)*0.618)
func _on_resolved(context: Dictionary) -> void:
	var damage:=float(context.get("resolved_damage",0.0))
	if damage<=0.0: return
	var effect:=_available(_bursts,12,Feedback,"CurseSettlement")
	if effect!=null:
		_serial+=1;effect.configure(_point(context)+Vector2(0,-18),clampf(32.0+sqrt(damage)*2.0,32.0,68.0),1,float(_serial)*0.618)
func _on_enemy_death(context: Dictionary) -> void:
	var target: Node2D=context.get("target") as Node2D
	if not is_instance_valid(target) or int(target.get("current_health"))>0 or not is_instance_valid(_owner): return
	var snapshot: Variant=context.get("target_statuses",[])
	var cursed:=false
	if snapshot is Array:
		for item: Variant in snapshot:
			if item is Dictionary and String(item.get("id",""))=="cursed" and int(item.get("stacks",0))>0: cursed=true;break
	elif snapshot is Dictionary:
		var item: Variant=snapshot.get("cursed",0)
		cursed=int(item.get("stacks",0))>0 if item is Dictionary else int(item)>0
	if not cursed: return
	var sm: Node=_owner.get_node_or_null("SummonManager")
	if sm==null: return
	var crows: Array=sm._active_by_id.get(&"soul_crow",[])
	var point:=_point(context)
	for crow_variant: Variant in crows:
		if not is_instance_valid(crow_variant): continue
		var crow: Node2D=crow_variant as Node2D
		if crow==null or crow.is_queued_for_deletion() or not crow.visible or crow.global_position.distance_squared_to(point)>540.0*540.0: continue
		play_link(crow.global_position,point,0)
func play_link(from: Vector2,to: Vector2,kind: int=1) -> Node2D:
	var effect:=_available(_links,24,Link,"SoulLink")
	if effect!=null:
		_serial+=1;effect.configure(from,to,float(_serial)*0.618,kind)
	return effect
func play_heal(point: Vector2) -> void:
	var effect:=_available(_bursts,12,Feedback,"SoulRestoration")
	if effect!=null:
		_serial+=1;effect.configure(point+Vector2(0,-22),40.0,2,float(_serial)*0.618)
func mark_contract(target: Node2D,duration: float) -> void:
	if not is_instance_valid(target): return
	var marker: Node2D
	for item: Node2D in _contracts:
		var entry: Dictionary=_contract_targets.get(item.get_instance_id(),{})
		if item.visible and not entry.is_empty() and entry.target.get_ref()==target: marker=item;break
	if marker==null: marker=_available(_contracts,8,Status,"DeathPactMark")
	if marker==null: return
	marker.top_level=true;marker.global_position=target.global_position
	marker.configure_status({"status_id":"death_pact","duration_remaining":duration})
	_contract_targets[marker.get_instance_id()]={"target":weakref(target)}
func _process(delta: float) -> void:
	for marker: Node2D in _contracts:
		if not marker.visible: continue
		var entry: Dictionary=_contract_targets.get(marker.get_instance_id(),{})
		var target: Node2D=entry.target.get_ref() if not entry.is_empty() else null
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not bool(target.get_meta("death_pact",false)):
			marker.deactivate();_contract_targets.erase(marker.get_instance_id())
		else: marker.global_position=target.global_position
	for aura: Node2D in [_harvest,_debt]:
		if aura!=null and aura.visible and is_instance_valid(_owner): aura.global_position=_owner.global_position
	_refresh_remaining-=delta
	if _refresh_remaining>0.0: return
	_refresh_remaining=0.1
	if not is_instance_valid(_owner): return
	var manager: Node=_owner.get_node_or_null("SkillManager")
	var store: Node=_owner.get_node_or_null("ModifierStore")
	var harvest: RefCounted=manager.get_skill(&"curse_power_soul_harvest") if manager!=null else null
	var points:=float(harvest.get_meta("soul_harvest_cursed_kills",0.0)) if harvest!=null else 0.0
	var charged: bool=store!=null and store.get_cast_charge_snapshot().sources.has("skill:curse_power_soul_harvest:next_cast")
	if harvest!=null and (points>0.0 or charged):
		if _harvest==null: _harvest=_make_aura("SoulHarvestCharge",1.08)
		_harvest.configure_status({"status_id":"harvest_ready" if charged else "harvest_charge","charge_fraction":1.0 if charged else points/12.0})
	elif _harvest!=null: _harvest.deactivate()
	var core: RefCounted=manager.get_skill(&"curse_core_grand_coffin") if manager!=null else null
	var debt:=float(core.get_meta("grand_coffin_soul_debt",0.0)) if core!=null else 0.0
	if debt>0.0:
		if _debt==null: _debt=_make_aura("GrandCoffinDebt",1.45)
		_debt.configure_status({"status_id":"soul_debt","charge_fraction":debt/20.0})
	elif _debt!=null: _debt.deactivate()
func _make_aura(label: String,size: float) -> Node2D:
	var effect:=Status.new();effect.name=label;effect.z_index=6
	add_child(effect);effect.top_level=true;effect.global_position=_owner.global_position;effect.scale=Vector2.ONE*size
	return effect
func reset_presentation() -> void:
	for list: Array in [_hits,_bursts,_links,_contracts]:
		for item: Node2D in list: item.deactivate()
	_contract_targets.clear();_cooldowns.clear()
	for aura: Node2D in [_harvest,_debt]:
		if aura!=null: aura.deactivate()
	_refresh_remaining=0.0;_serial=0
