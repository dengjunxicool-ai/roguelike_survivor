## 监听已确认的战斗事件，提供有上限的冰晶命中池与只读冰雾盾表现。
## 不执行动作、伤害或状态；反馈挂在角色事件总线下，随 run 释放。
extends Node2D
const HitEffect = preload("res://scripts/effects/frost_hit_effect.gd")
const ShieldEffect = preload("res://scripts/effects/ice_mist_shield_effect.gd")
const MAX_HIT_EFFECTS := 32
var _hits: Array[Node2D] = []
var _shield: Node2D
var _owner: Node
var _bus: Node
var _cold_grants: Array[Dictionary] = []
var _serial := 0
var _cooldowns: Dictionary = {}
var _refresh_remaining := 0.0

func _ready() -> void:
	_bus = get_parent()
	_owner = _bus.get_parent()
	_bus.subscribe(&"post_damage_hit", _on_damage)
	_bus.subscribe(&"shield_gained", _on_shield_gained)
	_bus.subscribe(&"shield_broken", _on_shield_broken)
	set_process(false)

func _on_damage(context: Dictionary) -> void:
	if int(context.get("damage_amount",0)) <= 0:
		return
	var packet: Dictionary = context.get("damage_packet",{})
	var origin := String(context.get("damage_origin",packet.get("damage_origin","")))
	var skill := String(context.get("source_skill_id",packet.get("source_skill_id","")))
	var manager: Node = context.get("skill_manager") as Node
	var kind := -1
	if skill == "frost_power_shatter_execute":
		kind = 2
	elif manager != null and manager.has_skill(&"frost_passive_frozen_vulnerability") and _was_controlled(context.get("target_statuses",[])):
		kind = 1
	elif origin == "primary_attack" and manager != null and manager.has_skill(&"frost_attack_frostbite"):
		kind = 0
	elif String(context.get("element",packet.get("element",""))) in ["ice", "frost"]:
		kind = 0
	if kind < 0:
		return
	var position_variant: Variant = context.get("position")
	var target: Node2D = context.get("target") as Node2D
	var point: Vector2 = position_variant if position_variant is Vector2 else (target.global_position if is_instance_valid(target) else Vector2.ZERO)
	var target_id := int(target.get_instance_id()) if is_instance_valid(target) else 0
	var now := float(context.get("combat_seconds",0.0))
	if target_id > 0 and now < float(_cooldowns.get(target_id,-1.0)) and kind != 2:
		return
	if target_id > 0:
		_cooldowns[target_id] = now+0.1
	# Keep bounded IDs even when many dead enemies have passed through the pool.
	if _cooldowns.size() > 128:
		_cooldowns.clear()
	play_hit(point+Vector2(0,-20),kind)

func play_hit(point: Vector2, kind: int) -> Node2D:
	var effect: Node2D
	for item: Node2D in _hits:
		if not item.visible:
			effect = item
			break
	if effect == null:
		if _hits.size() >= MAX_HIT_EFFECTS:
			return null
		effect = HitEffect.new()
		effect.name = "FrostHit%d" % _hits.size()
		add_child(effect)
		_hits.append(effect)
	_serial += 1
	effect.configure(point,kind,float(_serial)*0.618)
	return effect

func _was_controlled(statuses: Array) -> bool:
	for status: Dictionary in statuses:
		if String(status.get("id","")) in ["frozen","root","stun"] and int(status.get("stacks",0)) > 0:
			return true
	return false

func _on_shield_gained(context: Dictionary) -> void:
	if String(context.get("shield_type","")) != "ice_mist" or int(context.get("shield_amount",0)) <= 0:
		return
	if _shield == null:
		_shield = ShieldEffect.new()
		_shield.name = "IceMistShield"
		add_child(_shield)
		_shield.top_level = true
		_shield.global_position = (_owner as Node2D).global_position
	_cold_grants.append({"amount":float(context.get("shield_amount",0))})
	# At most three visual layers; merge overflow without creating extra nodes.
	if _cold_grants.size() > 3:
		var first: Dictionary = _cold_grants.pop_front()
		_cold_grants[0]["amount"] += first.amount
	set_process(true)
	_refresh_shield()

func _process(delta: float) -> void:
	if _shield != null and is_instance_valid(_owner) and _owner is Node2D:
		_shield.global_position = (_owner as Node2D).global_position
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = 0.05
		_refresh_shield()

func _refresh_shield() -> void:
	if _shield == null or not is_instance_valid(_owner):
		return
	var now := float(_bus.combat_seconds())
	var total := float(_owner.get_meta("fire_passive_shield",0))
	var total_expiry := float(_owner.get_meta("fire_passive_shield_expires_at",0.0))
	if total_expiry <= now:
		total = 0.0
	var cold := 0.0
	for grant: Dictionary in _cold_grants:
		cold += float(grant.amount)
	# Runtime currently shares a shield pool: never display more cold protection than its actual remaining total.
	var fraction := clampf(total/maxf(cold,1.0),0.0,1.0)
	_shield.update_shield(_cold_grants.size(),fraction)
	if total <= 0.0 or _cold_grants.is_empty():
		_cold_grants.clear()
		_shield.deactivate()
		set_process(false)

func _on_shield_broken(_context: Dictionary) -> void:
	if _shield != null and _shield.visible:
		play_hit((_owner as Node2D).global_position+Vector2(0,-20),2)
	_cold_grants.clear()
	if _shield != null:
		_shield.deactivate()
	set_process(false)

func reset_presentation() -> void:
	for item: Node2D in _hits:
		item.deactivate()
	_cold_grants.clear()
	_cooldowns.clear()
	if _shield != null:
		_shield.deactivate()
	set_process(false)
