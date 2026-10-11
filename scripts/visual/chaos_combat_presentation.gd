## 只读真实混沌伤害、交换、复制与来源/计数状态；反馈池有界。
extends Node2D
const Feedback=preload("res://scripts/effects/chaos_feedback_effect.gd")
const Status=preload("res://scripts/effects/chaos_status_effect.gd")
const ENTROPY_STATS=["damage_multiplier_add","range_multiplier_add","cooldown_multiplier_add","move_speed_multiplier_add"]
var _hits: Array[Node2D]=[]
var _bursts: Array[Node2D]=[]
var _links: Array[Node2D]=[]
var _auras: Dictionary={}
var _owner: Node2D
var _serial:=0
var _cooldowns: Dictionary={}
func _ready() -> void:
	_owner=get_parent().get_parent() as Node2D
	get_parent().subscribe(&"post_damage_hit",_on_damage)
func _available(items: Array[Node2D],limit: int,label: String) -> Node2D:
	for item: Node2D in items:
		if not item.visible: return item
	if items.size()>=limit: return null
	var effect:=Feedback.new();effect.name=label+str(items.size());effect.z_index=9;add_child(effect);items.append(effect);return effect
func _on_damage(context: Dictionary) -> void:
	if int(context.get("damage_amount",0))<=0: return
	var packet: Dictionary=context.get("damage_packet",{})
	var origin:=String(context.get("damage_origin",packet.get("damage_origin","")))
	if origin=="status_dot": return
	var source:=String(context.get("source_skill_id",packet.get("source_skill_id","")))
	var manager: Node=context.get("skill_manager") as Node
	if not source.begins_with("chaos_") and not (origin=="primary_attack" and manager!=null and manager.has_skill(&"chaos_attack_chaotic")): return
	var target: Node2D=context.get("target") as Node2D
	var id:=target.get_instance_id() if is_instance_valid(target) else 0
	var now:=float(get_parent().combat_seconds())
	if id>0 and now<float(_cooldowns.get(id,-1.0)): return
	if id>0: _cooldowns[id]=now+0.06
	if _cooldowns.size()>128: _cooldowns.clear()
	var point: Vector2=context.get("position",target.global_position if is_instance_valid(target) else Vector2.ZERO)
	var effect:=_available(_hits,24,"ChaosHit")
	if effect!=null:
		_serial+=1;effect.configure(point+Vector2(0,-18),30.0,0,float(_serial)*0.618)
func play_replay(point: Vector2) -> void:
	var effect:=_available(_bursts,12,"ActualReplay")
	if effect!=null:
		_serial+=1;effect.configure(point+Vector2(0,-20),42.0,1,float(_serial)*0.618)
func play_swap(from: Vector2,to: Vector2) -> void:
	var effect:=_available(_links,12,"ActualExchange")
	if effect!=null:
		_serial+=1;effect.configure_link(from,to,float(_serial)*0.618)
func _aura(key: String,snapshot: Dictionary) -> void:
	if not _auras.has(key):
		var effect:=Status.new();effect.name=key;effect.z_index=6;add_child(effect);effect.top_level=true;_auras[key]=effect
	var aura: Node2D=_auras[key];aura.global_position=_owner.global_position;aura.configure_status(snapshot)
func _process(_delta: float) -> void:
	if not is_instance_valid(_owner): return
	var manager: Node=_owner.get_node_or_null("SkillManager")
	var store: Node=_owner.get_node_or_null("ModifierStore")
	var state: Dictionary=get_parent().chaos_state()
	var live: Dictionary={}
	if manager!=null and store!=null and manager.has_skill(&"chaos_passive_entropy_growth"):
		for entry: Dictionary in state.get("entropy",[]):
			var branch:=clampi(int(entry.get("branch",0)),0,3)
			var source:=String(entry.get("source",""));var remaining: float=store.get_timed_source_remaining(source)
			var value: float=store.get_source_modifier_value(source,ENTROPY_STATS[branch])
			if remaining<=0.0 or (value>=0.0 if branch==2 else value<=0.0): continue
			var key: String="entropy_%d"%branch;live[key]=true
			_aura(key,{"status_id":"entropy","branch":branch,"duration_remaining":remaining,"host_controls_lifetime":true})
	for spec: Array in [["stability",&"chaos_passive_anomalous_stability","stability_count",5.0],["echo",&"chaos_power_echo_cast","echo_count",4.0],["singularity",&"chaos_core_chaos_singularity","fissions",25.0]]:
		var ready: bool=spec[0]=="stability" and bool(state.get("stability_ready",false))
		var count:=float(state.get(spec[2],0))
		if manager!=null and manager.has_skill(spec[1]) and (count>0.0 or ready):
			live[spec[0]]=true;_aura(spec[0],{"status_id":spec[0],"charge_fraction":1.0 if ready else count/float(spec[3]),"ready":ready,"host_controls_lifetime":true})
	for key: String in _auras:
		if not live.has(key): _auras[key].deactivate()
func reset_presentation() -> void:
	for list: Array in [_hits,_bursts,_links]:
		for item: Node2D in list: item.deactivate()
	for key: String in _auras: _auras[key].deactivate()
	_cooldowns.clear();_serial=0
