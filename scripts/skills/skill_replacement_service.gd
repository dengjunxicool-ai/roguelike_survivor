extends RefCounted
class_name SkillReplacementService
const Slots = preload("res://scripts/skills/skill_slot_policy.gd")
const Offers = preload("res://scripts/skills/skill_offer_service.gd")
var _transactions: Dictionary = {}
var _nonce: int = 0
func begin(player: Node, new_skill_id: StringName, rarity: String) -> Dictionary:
	if not is_instance_valid(player) or bool(player.get_meta("ordinary_replacement_used", false)): return {}
	var manager: Node = player.get_node_or_null("SkillManager")
	var data: Dictionary = GameData.get_skill(new_skill_id)
	if manager == null or data.is_empty() or not Slots.counts_active_capacity(data) or not manager.is_active_skill_full() or manager.has_learned_skill(new_skill_id): return {}
	# Evaluate offers with capacity temporarily raised; no skill/school mutation.
	var limit: int = manager.max_active_skills
	manager.max_active_skills = limit + 1
	var available: bool = Offers.new().is_skill_available(player, data)
	manager.max_active_skills = limit
	if not available: return {}
	_nonce += 1
	var tx := {"id": str(player.get_instance_id()) + ":" + str(_nonce), "player": weakref(player), "skill_id": new_skill_id, "rarity": rarity}
	_transactions[tx.id] = tx
	return {"id": tx.id, "skill_id": new_skill_id, "rarity": rarity}
func confirm(player: Node, transaction_id: String, old_skill_id: StringName) -> bool:
	var tx: Dictionary = _transactions.get(transaction_id, {})
	if tx.is_empty() or tx.player.get_ref() != player or bool(player.get_meta("ordinary_replacement_used", false)): return false
	var manager: Node = player.get_node_or_null("SkillManager")
	if manager == null or not manager.replace_ordinary_skill(old_skill_id, tx.skill_id, tx.rarity): return false
	player.set_meta("ordinary_replacement_used", true)
	_transactions.erase(transaction_id)
	return true
func cancel(transaction_id: String) -> void:
	_transactions.erase(transaction_id)
