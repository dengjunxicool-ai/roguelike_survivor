extends SceneTree

const Packet: Script = preload("res://scripts/combat/damage_packet.gd")
const System: Script = preload("res://scripts/combat/damage_system.gd")
const Application: Script = preload("res://scripts/combat/damage_application_pipeline.gd")
const Service: Script = preload("res://scripts/combat/damage_application_service.gd")
const Intent: Script = preload("res://scripts/combat/damage_intent.gd")
const QueryFactory: Script = preload("res://scripts/modifiers/damage_modifier_query.gd")
const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")

class ShieldPlayer:
	extends Node
	var current_health: int = 100
	func _is_damage_blocked_by_hit_protection(_packet: DamagePacket) -> bool:
		set_meta("protection_called", true)
		return false

func _init() -> void:
	var target: Node = Node.new()
	root.add_child(target)
	var packet: RefCounted = Packet.from_dictionary({
		"raw_amount": 13.0, "amount": 7.0,
		"source_skill_id": &"contract", "source_instance_id": "contract:1",
		"can_crit": false, "uses_character_damage_multiplier": false,
		"uses_skill_level_coefficient": false,
		"ignore_defense": true, "ignore_resistance": true, "ignore_vulnerability": true
	})
	var result: Variant = System.calculate(packet, target)
	var ok: bool = result is DamageResult
	ok = _expect(ok, "calculate must return DamageResult") and ok
	ok = _expect(packet.get_value("raw_amount") == 13.0 and packet.get_value("amount") == 7.0, "raw formula amount and incoming absorb amount stay distinct") and ok
	var adjusted: DamagePacket = Application.packet_with_amount(packet, 4)
	ok = _expect(adjusted.raw_amount == 4 and adjusted.amount == 4 and packet.raw_amount == 13.0, "absorption creates a separate formula input") and ok
	ok = _expect(adjusted.source_context.source_instance_id == "contract:1" and packet.target_id == "", "application preserves source identity without mutating the input target") and ok
	var invalid: RefCounted = Packet.from_dictionary({"raw_amount": 1, "source_instance_id": "bad:1", "unregistered_extension": 4})
	ok = _expect(not invalid.validate().is_empty(), "unregistered extensions must be rejected") and ok
	var non_finite: RefCounted = Packet.from_dictionary({"raw_amount": INF, "source_instance_id": "bad:2"})
	ok = _expect(not non_finite.validate().is_empty(), "non-finite damage must be rejected") and ok
	var player: ShieldPlayer = ShieldPlayer.new()
	root.add_child(player)
	player.set_meta("fire_passive_shield", 10)
	var invalid_hit: DamagePacket = Packet.from_dictionary({"raw_amount": 7, "source_instance_id": "bad:3", "unregistered_extension": 4})
	var rejected: RefCounted = Service.apply_player_damage(player, invalid_hit)
	ok = _expect(rejected.reason == &"invalid_packet", "invalid packets must be rejected at the application boundary") and ok
	ok = _expect(player.get_meta("fire_passive_shield") == 10 and not player.has_meta("protection_called"), "rejection must precede shield and hit protection side effects") and ok
	var invalid_depth: DamagePacket = Packet.from_dictionary({"raw_amount": 7, "source_instance_id": "bad:depth", "reaction_depth": -1})
	var invalid_intent: RefCounted = Intent.create(player, invalid_depth)
	ok = _expect(not invalid_intent.packet.validate().is_empty(), "intent copies must preserve input validation errors") and ok
	var intent_result: RefCounted = invalid_intent.apply()
	ok = _expect(intent_result.reason == &"invalid_packet" and player.get_meta("fire_passive_shield") == 10, "invalid intent cannot consume a shield") and ok
	var mutated: DamagePacket = packet.clone()
	mutated.set_value("skill_level_coefficient", INF)
	ok = _expect(not mutated.validate().is_empty(), "validation checks current typed scaling") and ok
	ok = _expect(Service.apply_player_damage(player, mutated).reason == &"invalid_packet" and player.get_meta("fire_passive_shield") == 10, "nonfinite scaling cannot consume shields") and ok
	mutated = Packet.from_dictionary({"raw_amount": 7, "source_instance_id": "bad:coefficient", "skill_level_coefficient": -1})
	ok = _expect(not mutated.validate().is_empty(), "negative scaling cannot be clamped into a valid packet") and ok
	mutated = packet.clone()
	mutated.reaction_depth = -1
	ok = _expect(not mutated.validate().is_empty(), "validation checks current typed reaction depth") and ok
	ok = _expect(Service.apply_player_damage(player, mutated).reason == &"invalid_packet" and player.get_meta("fire_passive_shield") == 10, "mutated invalid packet is rejected before absorption") and ok
	ok = _verify_query_contract(target) and ok
	if ok:
		print("[verify_damage_packet_contract] PASS")
	quit(0 if ok else 1)

func _verify_query_contract(owner: Node) -> bool:
	var packet: DamagePacket = Packet.from_dictionary({"raw_amount": 10, "source_skill_id": "canonical", "source_origin_id": "origin", "source_instance_id": "query:1", "source_type": "projectile", "element": "fire", "skill_id": "alias", "object_type": "area"})
	var profile: TargetDamageProfile = TargetDamageProfile.new()
	profile.target_type = &"boss"
	var wrapped: RefCounted = QueryFactory.call("make", packet, owner, profile)
	var query: ModifierQuery = wrapped.to_modifier_query()
	var ok: bool = _expect(query.owner == owner and query.skill_id == &"canonical" and query.source_origin_id == &"origin" and query.object_type == &"projectile", "query reads canonical packet identity and explicit attacker")
	var scoped: Array = [{"stat": "damage", "op": "multiplier_add", "value": 0.25, "scope": {"domain": "damage", "skill_id": "canonical", "source_origin_id": "origin", "element": "fire", "object_type": "projectile", "target_type": "boss"}, "source": "skill"}]
	var bonuses: Dictionary = ModifierSourceScript.flatten_effects(scoped, "skill", query)
	ok = _expect(not bonuses.is_empty() and is_equal_approx(float(bonuses.get("fire_damage_multiplier_add", 0.0)), 0.25), "source and explicit target profile select numeric scope") and ok
	profile.target_type = &"elite"
	var elite_query: ModifierQuery = QueryFactory.call("make", packet, owner, profile).to_modifier_query()
	ok = _expect(ModifierSourceScript.flatten_effects(scoped, "skill", elite_query).is_empty(), "nonmatching target scope filtered") and ok
	packet.set_value("target_type", "boss")
	ok = _expect(QueryFactory.call("make", packet, owner, profile).to_modifier_query().target_type == &"boss", "explicit packet target scope retains priority") and ok
	var independent: DamagePacket = Packet.from_dictionary({"raw_amount": 1, "source_instance_id": "query:2", "source_id": "historical", "skill_id": "alias", "object_type": "area"})
	var independent_query: ModifierQuery = QueryFactory.call("make", independent, owner).to_modifier_query()
	ok = _expect(independent_query.skill_id == &"" and independent_query.object_type == &"", "extension fields never supply canonical source identity") and ok
	return ok

func _expect(value: bool, message: String) -> bool:
	if not value:
		push_error("[verify_damage_packet_contract] " + message)
	return value
