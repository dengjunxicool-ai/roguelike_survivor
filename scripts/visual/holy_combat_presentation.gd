## 神圣系只读表现：确认伤害、实际共享盾量、真实虔诚期限与已执行格挡。
extends Node2D
const Feedback=preload("res://scripts/effects/holy_feedback_effect.gd")
const Status=preload("res://scripts/effects/holy_status_effect.gd")
const SHIELD_SKILLS=[&"holy_attack_judgment",&"holy_dash_heavenly_wings",&"holy_cast_divine_barrier",&"holy_summon_seraph",&"holy_passive_sanctuary",&"holy_passive_devotion",&"holy_power_absolution_light",&"holy_core_final_judgment_domain"]
var _hits: Array[Node2D]=[]
var _bursts: Array[Node2D]=[]
var _owner: Node2D
var _shield: Node2D
var _devotion: Node2D
var _serial:=0
var _cooldowns: Dictionary={}
func _ready() -> void:
	var bus: Node=get_parent();_owner=bus.get_parent() as Node2D
	bus.subscribe(&"post_damage_hit",_on_damage);bus.subscribe(&"shield_gained",_on_shield)
func _available(items: Array[Node2D],limit: int,label: String) -> Node2D:
	for item: Node2D in items:
		if not item.visible: return item
	if items.size()>=limit: return null
	var effect:=Feedback.new();effect.name=label+str(items.size());effect.z_index=9;add_child(effect);items.append(effect);return effect
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
	var element:=String(context.get("element",packet.get("element","")))
	var source:=String(context.get("source_skill_id",packet.get("source_skill_id","")))
	var manager: Node=context.get("skill_manager") as Node
	var primary: bool=origin=="primary_attack" and manager!=null and manager.has_skill(&"holy_attack_judgment")
	if element!="holy" and not primary: return
	var target: Node2D=context.get("target") as Node2D
	var id:=target.get_instance_id() if is_instance_valid(target) else 0
	var now:=float(context.get("combat_seconds",0.0))
	if source!="holy_cast_holy_ray" and id>0 and now<float(_cooldowns.get(id,-1.0)): return
	if id>0: _cooldowns[id]=now+0.08
	if _cooldowns.size()>128: _cooldowns.clear()
	var effect:=_available(_hits,24,"HolyHit")
	if effect!=null:
		_serial+=1;effect.configure(_point(context)+Vector2(0,-18),30.0,1 if source=="holy_cast_holy_ray" else 0,float(_serial)*0.618)
func _on_shield(context: Dictionary) -> void:
	if int(context.get("shield_amount",0))<=0 or not String(context.get("shield_source_skill_id","")).begins_with("holy_"): return
	if is_instance_valid(_owner): _play_burst(_owner.global_position+Vector2(0,-20),2)
func _play_burst(point: Vector2,kind: int) -> void:
	var effect:=_available(_bursts,12,"HolyWard")
	if effect!=null:
		_serial+=1;effect.configure(point,38.0,kind,float(_serial)*0.618)
func _owns_holy_shield() -> bool:
	if not is_instance_valid(_owner): return false
	var manager: Node=_owner.get_node_or_null("SkillManager")
	if manager==null: return false
	for id: StringName in SHIELD_SKILLS:
		if manager.has_skill(id): return true
	return false
func play_absorb(point: Vector2,amount: int) -> void:
	if amount>0 and _owns_holy_shield(): _play_burst(point+Vector2(0,-20),3)
func play_guard(guard: Node,amount: int) -> void:
	if amount<=0 or not is_instance_valid(guard): return
	var effect: Node=guard.get("_summon_effect") as Node
	if effect!=null and effect.has_method("play_guard"): effect.play_guard()
func _make_aura(label: String) -> Node2D:
	var effect:=Status.new();effect.name=label;effect.z_index=6;add_child(effect);effect.top_level=true;return effect
func _process(_delta: float) -> void:
	if not is_instance_valid(_owner): return
	var now:=float(get_parent().combat_seconds())
	var expires:=float(_owner.get_meta("fire_passive_shield_expires_at",0.0))
	var amount:=int(_owner.get_meta("fire_passive_shield",0))
	if amount>0 and (expires<=0.0 or now<expires) and _owns_holy_shield():
		if _shield==null: _shield=_make_aura("HolyShield")
		_shield.global_position=_owner.global_position
		_shield.configure_status({"status_id":"holy_shield","shield_fraction":float(amount)/maxf(float(_owner.get("max_health")),1.0),"host_controls_lifetime":true})
	elif _shield!=null: _shield.deactivate()
	var store: Node=_owner.get_node_or_null("ModifierStore")
	var remaining: float=store.get_timed_source_remaining("skill:holy_passive_devotion:damage_multiplier_add") if store!=null else 0.0
	if remaining>0.0 and store.get_source_modifier_value("skill:holy_passive_devotion:damage_multiplier_add", "damage_multiplier_add")>0.0:
		if _devotion==null: _devotion=_make_aura("ActualDevotion")
		_devotion.global_position=_owner.global_position
		_devotion.configure_status({"status_id":"devotion","duration_remaining":remaining,"host_controls_lifetime":true})
	elif _devotion!=null: _devotion.deactivate()
func reset_presentation() -> void:
	for list: Array in [_hits,_bursts]:
		for item: Node2D in list: item.deactivate()
	for aura: Node2D in [_shield,_devotion]:
		if aura!=null: aura.deactivate()
	_cooldowns.clear();_serial=0
