## 雷霆只读反馈：真实命中、连锁端点和限时增益；池满时省略装饰。
extends Node2D
const HitEffect = preload("res://scripts/effects/thunder_hit_effect.gd")
const StatusEffect = preload("res://scripts/effects/thunder_status_effect.gd")
const MAX_HITS := 24
const MAX_ARCS := 24
var _hits: Array[Node2D] = []
var _arcs: Array[Node2D] = []
var _markers: Array[Node2D] = []
var _marker_targets: Dictionary = {}
var _cooldowns: Dictionary = {}
var _owner: Node2D
var _store: Node
var _charge: Node2D
var _core: Node2D
var _serial := 0
var _refresh_remaining := 0.0
func _ready() -> void:
	var bus: Node=get_parent()
	_owner=bus.get_parent() as Node2D
	_store=_owner.get_node_or_null("ModifierStore") if _owner!=null else null
	bus.subscribe(&"post_damage_hit",_on_damage)
func _on_damage(context: Dictionary) -> void:
	if int(context.get("damage_amount",0))<=0: return
	var packet: Dictionary=context.get("damage_packet",{})
	var manager: Node=context.get("skill_manager") as Node
	var thundering: bool=String(context.get("damage_origin",packet.get("damage_origin","")))=="primary_attack" and manager!=null and manager.has_skill(&"thunder_attack_thundering")
	if String(context.get("element",packet.get("element","")))!="lightning" and not thundering: return
	var source:=String(context.get("source_skill_id",packet.get("source_skill_id","")))
	var crow:=source=="thunder_summon_storm_crow"
	var target: Node2D=context.get("target") as Node2D
	var id:=target.get_instance_id() if is_instance_valid(target) else 0
	var now:=float(context.get("combat_seconds",0.0))
	if id>0 and now<float(_cooldowns.get(id,-1.0)) and not crow: return
	if id>0: _cooldowns[id]=now+0.08
	if _cooldowns.size()>128: _cooldowns.clear()
	var position_variant: Variant=context.get("position")
	var point: Vector2=position_variant if position_variant is Vector2 else (target.global_position if is_instance_valid(target) else Vector2.ZERO)
	var effect:=_available(_hits,MAX_HITS,HitEffect,"ThunderHit")
	if effect!=null:
		_serial+=1
		effect.configure(point+Vector2(0,-20),44.0 if source=="thunder_core_storm_center" else (38.0 if crow else 27.0),float(_serial)*0.618,crow)
func _available(items: Array[Node2D], maximum: int, script: Script, prefix: String) -> Node2D:
	for item: Node2D in items:
		if not item.visible: return item
	if items.size()>=maximum: return null
	var effect: Node2D=script.new()
	effect.name=prefix+str(items.size())
	effect.z_index=8
	add_child(effect)
	items.append(effect)
	return effect
func play_chain(from: Vector2, to: Vector2, seed: float = 0.0) -> Node2D:
	var script: Script=load("res://scripts/effects/thunder_arc_effect.gd")
	var arc:=_available(_arcs,MAX_ARCS,script,"ThunderArc")
	if arc!=null: arc.configure(from,to,seed)
	return arc
func mark_crow_target(target: Node2D, projectile: Node2D) -> void:
	var marker:=_available(_markers,8,StatusEffect,"CrowTargetMark")
	if marker==null: return
	marker.top_level=true
	marker.global_position=target.global_position
	marker.scale=Vector2.ONE*0.78
	marker.configure_status({"status_id":"static_charge","stacks":1})
	_marker_targets[marker.get_instance_id()]={"target":weakref(target),"projectile":weakref(projectile),"generation":projectile.get("spawn_generation")}
func _process(delta: float) -> void:
	for marker: Node2D in _markers:
		if not marker.visible: continue
		var tracking: Dictionary=_marker_targets.get(marker.get_instance_id(),{})
		var target: Node2D=tracking.target.get_ref()
		var projectile: Node2D=tracking.projectile.get_ref()
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not is_instance_valid(projectile) or not projectile.visible or projectile.get("spawn_generation")!=tracking.generation:
			marker.deactivate()
		else: marker.global_position=target.global_position
	for aura: Node2D in [_charge,_core]:
		if aura!=null and aura.visible and is_instance_valid(_owner): aura.global_position=_owner.global_position
	_refresh_remaining-=delta
	if _refresh_remaining>0.0: return
	_refresh_remaining=0.1
	if not is_instance_valid(_owner): return
	if not is_instance_valid(_store): _store=_owner.get_node_or_null("ModifierStore")
	var remaining:=float(_store.get_timed_source_remaining("skill:thunder_passive_static_charge:attack_speed_multiplier_add")) if is_instance_valid(_store) else 0.0
	if remaining>0.0:
		if _charge==null: _charge=_make_aura("StaticChargeAura")
		_charge.configure_status({"status_id":"static_charge","stacks":3,"duration_remaining":remaining})
	elif _charge!=null: _charge.deactivate()
	var manager: Node=_owner.get_node_or_null("SkillManager")
	var skill: RefCounted=manager.get_skill(&"thunder_core_storm_center") if manager!=null else null
	var charge:=float(skill.get_meta("storm_center_lightning_hits",0.0)) if skill!=null else 0.0
	if charge>0.0:
		if _core==null: _core=_make_aura("StormCenterCharge")
		_core.configure_status({"status_id":"storm_charge","stacks":1,"charge_fraction":charge/60.0})
	elif _core!=null: _core.deactivate()
func _make_aura(label: String) -> Node2D:
	var effect:=StatusEffect.new()
	effect.name=label
	effect.z_index=6
	add_child(effect)
	effect.top_level=true
	effect.global_position=_owner.global_position
	if label=="StormCenterCharge": effect.scale=Vector2.ONE*1.32
	return effect
func reset_presentation() -> void:
	for item: Node2D in _hits: item.deactivate()
	for item: Node2D in _arcs: item.deactivate()
	for marker: Node2D in _markers: marker.deactivate()
	_marker_targets.clear()
	for aura: Node2D in [_charge,_core]:
		if aura!=null: aura.deactivate()
	_cooldowns.clear()
	_refresh_remaining=0.0
	_serial=0
