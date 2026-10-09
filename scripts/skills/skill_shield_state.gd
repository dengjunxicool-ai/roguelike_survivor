extends RefCounted
static func amount(owner: Node) -> int:
	if owner == null: return 0
	var bus: Node = owner.get_node_or_null("SkillEventBus")
	var now: float = bus.combat_seconds() if bus != null else float(Time.get_ticks_msec()) / 1000.0
	var expires: float = float(owner.get_meta("fire_passive_shield_expires_at", 0.0))
	if expires > 0.0 and expires <= now:
		owner.set_meta("fire_passive_shield",0)
		owner.set_meta("fire_passive_shield_expires_at",0.0)
		return 0
	return maxi(int(owner.get_meta("fire_passive_shield",0)),0)
