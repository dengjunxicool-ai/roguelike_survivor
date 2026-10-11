## 读取已确认命中与实际增益来源；反馈池有上限，不执行技能动作。
extends Node2D
const FeedbackEffect = preload("res://scripts/effects/fire_feedback_effect.gd")
const StatusEffect = preload("res://scripts/effects/fire_status_effect.gd")
const MAX_HITS := 24
const MAX_BURSTS := 8
var _hits: Array[Node2D] = []
var _bursts: Array[Node2D] = []
var _cooldowns: Dictionary = {}
var _heat: Node2D
var _owner: Node2D
var _store: Node
var _serial := 0
var _refresh_remaining := 0.0
func _ready() -> void:
	var bus: Node = get_parent()
	_owner = bus.get_parent() as Node2D
	_store = _owner.get_node_or_null("ModifierStore") if _owner != null else null
	bus.subscribe(&"post_damage_hit",_on_damage)
func _on_damage(context: Dictionary) -> void:
	if int(context.get("damage_amount",0)) <= 0: return
	var packet: Dictionary = context.get("damage_packet",{})
	var manager: Node = context.get("skill_manager") as Node
	var searing: bool = String(context.get("damage_origin",packet.get("damage_origin","")))=="primary_attack" and manager != null and manager.has_skill(&"fire_attack_searing")
	if String(context.get("element",packet.get("element","")))!="fire" and not searing: return
	var target: Node2D = context.get("target") as Node2D
	var id := target.get_instance_id() if is_instance_valid(target) else 0
	var now := float(context.get("combat_seconds",0.0))
	if id > 0 and now < float(_cooldowns.get(id,-1.0)): return
	if id > 0: _cooldowns[id] = now+0.12
	if _cooldowns.size()>128: _cooldowns.clear()
	var point_variant: Variant = context.get("position")
	var point: Vector2 = point_variant if point_variant is Vector2 else (target.global_position if is_instance_valid(target) else Vector2.ZERO)
	var effect := _available(_hits,MAX_HITS,"FireHit")
	if effect != null:
		_serial += 1
		effect.configure(point+Vector2(0,-18),26.0,0,float(_serial)*0.618)
func _available(items: Array[Node2D], maximum: int, prefix: String) -> Node2D:
	for item: Node2D in items:
		if not item.visible: return item
	if items.size() >= maximum: return null
	var effect := FeedbackEffect.new()
	effect.name = prefix+str(items.size())
	effect.z_index = 7
	add_child(effect)
	items.append(effect)
	return effect
func play_burst(point: Vector2, radius: float, kind: String) -> Node2D:
	var effect := _available(_bursts,MAX_BURSTS,"FireBurst")
	if effect != null:
		_serial += 1
		effect.set_meta("fire_burst_kind",kind)
		effect.configure(point,radius,2 if kind!="ignite" else 1,float(_serial)*0.618)
	return effect
func _process(delta: float) -> void:
	if _heat != null and _heat.visible and is_instance_valid(_owner):
		_heat.global_position = _owner.global_position
	_refresh_remaining -= delta
	if _refresh_remaining > 0.0: return
	_refresh_remaining = 0.1
	if not is_instance_valid(_store) and is_instance_valid(_owner): _store = _owner.get_node_or_null("ModifierStore")
	var remaining := float(_store.get_timed_source_remaining("skill:fire_passive_overheated_casting:cast_damage")) if is_instance_valid(_store) else 0.0
	if remaining <= 0.0:
		if _heat != null: _heat.deactivate()
		return
	if _heat == null:
		_heat = StatusEffect.new()
		_heat.name = "OverheatAura"
		_heat.z_index = 5
		add_child(_heat)
	_heat.top_level = true
	_heat.global_position = _owner.global_position
	_heat.configure_status({"status_id":"overheated","stacks":2,"duration_remaining":remaining})
func reset_presentation() -> void:
	for effect: Node2D in _hits: effect.deactivate()
	for effect: Node2D in _bursts: effect.deactivate()
	if _heat != null: _heat.deactivate()
	_cooldowns.clear()
	_refresh_remaining = 0.0
	_serial = 0
