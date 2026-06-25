extends RefCounted
class_name DamageRuleRegistry


const DamageOriginPolicyScript: Script = preload("res://scripts/combat/damage_origin_policy.gd")
const DamageTypePolicyScript: Script = preload("res://scripts/combat/damage_type_policy.gd")
const ModifierKeyRegistryScript: Script = preload("res://scripts/modifiers/modifier_key_registry.gd")

const ELEMENT_NAMES: Array[String] = ["physical", "fire", "ice", "lightning", "poison", "holy", "acid", "arcane", "neutral"]
const ORIGIN_PRIMARY_ATTACK: String = "primary_attack"
const ORIGIN_STATUS_DOT: String = "status_dot"
const ORIGIN_REACTION: String = "reaction"
const ORIGIN_FIELD: String = "field"
const ORIGIN_TRAP: String = "trap"
const ORIGIN_SPECIAL: String = "special"
const ORIGIN_HEALING: String = "healing"
const TYPE_DIRECT_PHYSICAL: String = "direct_physical"
const TYPE_DIRECT_MAGICAL: String = "direct_magical"
const TYPE_PROJECTILE_SMALL: String = "projectile_small"
const TYPE_PROJECTILE_HEAVY: String = "projectile_heavy"
const TYPE_AREA_DIRECT: String = "area_direct"
const TYPE_STATUS_DOT: String = "status_dot"
const TYPE_REACTION_DAMAGE: String = "reaction_damage"
const TYPE_TRAP_DAMAGE: String = "trap_damage"
const TYPE_SUMMON_DAMAGE: String = "summon_damage"
const TYPE_TRUE_DAMAGE: String = "true_damage"
const TYPE_TRUE_PERCENT_DAMAGE: String = "true_percent_damage"

const ALLOWED_DAMAGE_TYPES: Array[String] = [
	TYPE_DIRECT_PHYSICAL,
	TYPE_DIRECT_MAGICAL,
	TYPE_PROJECTILE_SMALL,
	TYPE_PROJECTILE_HEAVY,
	TYPE_AREA_DIRECT,
	TYPE_STATUS_DOT,
	TYPE_REACTION_DAMAGE,
	TYPE_TRAP_DAMAGE,
	TYPE_SUMMON_DAMAGE,
	TYPE_TRUE_DAMAGE,
	TYPE_TRUE_PERCENT_DAMAGE
]
const ALLOWED_ORIGINS: Array[String] = [
	ORIGIN_PRIMARY_ATTACK,
	ORIGIN_STATUS_DOT,
	ORIGIN_REACTION,
	ORIGIN_FIELD,
	ORIGIN_TRAP,
	ORIGIN_SPECIAL,
	ORIGIN_HEALING
]
const ORIGIN_POLICIES: Dictionary = {
	"primary_attack": {
		"default_damage_type": "direct_physical",
		"bonus_keys": ["primary_attack_damage_multiplier_add", "direct_damage_multiplier_add", "starting_skill_damage_add"],
		"uses_skill_level": true,
		"uses_character_damage": true
	},
	"status_dot": {
		"default_damage_type": "status_dot",
		"bonus_keys": ["dot_damage_multiplier_add"],
		"uses_skill_level": false,
		"uses_character_damage": true
	},
	"reaction": {
		"default_damage_type": "reaction_damage",
		"bonus_keys": ["reaction_damage_multiplier_add"],
		"uses_skill_level": false,
		"uses_character_damage": true
	},
	"field": {
		"default_damage_type": "area_direct",
		"bonus_keys": ["field_damage_multiplier_add", "area_damage_multiplier_add"],
		"uses_skill_level": false,
		"uses_character_damage": true
	},
	"trap": {
		"default_damage_type": "trap_damage",
		"bonus_keys": ["trap_damage_multiplier_add"],
		"uses_skill_level": false,
		"uses_character_damage": true
	},
	"special": {
		"default_damage_type": "true_damage",
		"bonus_keys": [],
		"uses_skill_level": false,
		"uses_character_damage": false
	},
	"healing": {
		"default_damage_type": "direct_physical",
		"bonus_keys": [],
		"uses_skill_level": false,
		"uses_character_damage": false
	}
}
const TYPE_POLICIES: Dictionary = {
	"direct_physical": {"defense_rate": 1.0, "can_crit_by_default": true, "allowed_origins": ["primary_attack"]},
	"direct_magical": {"defense_rate": 0.6, "can_crit_by_default": true, "allowed_origins": ["primary_attack", "field"]},
	"projectile_small": {"defense_rate": 0.8, "can_crit_by_default": true, "allowed_origins": ["primary_attack"]},
	"projectile_heavy": {"defense_rate": 1.0, "can_crit_by_default": true, "allowed_origins": ["primary_attack"]},
	"area_direct": {"defense_rate": 0.6, "can_crit_by_default": true, "allowed_origins": ["primary_attack", "reaction", "field", "trap"]},
	"status_dot": {"defense_rate": 0.0, "can_crit_by_default": false, "allowed_origins": ["primary_attack", "status_dot", "field"]},
	"reaction_damage": {"defense_rate": 0.5, "can_crit_by_default": false, "allowed_origins": ["reaction"]},
	"trap_damage": {"defense_rate": 0.8, "can_crit_by_default": false, "allowed_origins": ["trap", "field"]},
	"summon_damage": {"defense_rate": 0.7, "can_crit_by_default": false, "allowed_origins": ["special"]},
	"true_damage": {"defense_rate": 0.0, "ignore_resistance": true, "ignore_vulnerability": true, "can_crit_by_default": false, "allowed_origins": ["special"]},
	"true_percent_damage": {"defense_rate": 0.0, "ignore_resistance": true, "ignore_vulnerability": true, "can_crit_by_default": false, "allowed_origins": ["reaction", "special"]}
}


static func origin_policy(origin: String) -> RefCounted:
	var normalized: String = normalize_origin(origin)
	return DamageOriginPolicyScript.from_dictionary(normalized, ORIGIN_POLICIES.get(normalized, ORIGIN_POLICIES[ORIGIN_PRIMARY_ATTACK]))


static func damage_type_policy(damage_type: String) -> RefCounted:
	var normalized: String = damage_type if ALLOWED_DAMAGE_TYPES.has(damage_type) else TYPE_DIRECT_PHYSICAL
	return DamageTypePolicyScript.from_dictionary(normalized, TYPE_POLICIES.get(normalized, {}))


static func is_element(value: String) -> bool:
	return ELEMENT_NAMES.has(value)


static func normalize_element(value: String) -> String:
	return value if is_element(value) else "physical"


static func normalize_origin(value: String) -> String:
	return value if ALLOWED_ORIGINS.has(value) else ORIGIN_PRIMARY_ATTACK


static func normalize_damage_type(value: String, origin: String) -> String:
	return value if ALLOWED_DAMAGE_TYPES.has(value) else default_damage_type_for_origin(origin)


static func default_damage_type_for_origin(origin: String) -> String:
	return String(origin_policy(origin).get("default_damage_type"))


static func infer_damage_type(element: Variant, source_type: String, damage_origin: String) -> StringName:
	if damage_origin == ORIGIN_STATUS_DOT:
		return &"status_dot"
	if damage_origin == ORIGIN_REACTION:
		return &"reaction_damage"
	if damage_origin == ORIGIN_TRAP:
		return &"trap_damage"
	if source_type == "area" or source_type == "explosion":
		return &"area_direct"
	if source_type == "projectile" and String(element) == "physical":
		return &"direct_physical"
	if String(element) == "physical":
		return &"direct_physical"
	return &"direct_magical"


static func normalize_configured_damage_type(value: String, element: Variant, source_type: String, damage_origin: String, warning_prefix: String = "DamageRuleRegistry") -> StringName:
	if ALLOWED_DAMAGE_TYPES.has(value):
		return StringName(value)
	if ELEMENT_NAMES.has(value):
		push_warning("[%s] damage_type '%s' is an old element value. Use element='%s' with a documented damage_type instead." % [warning_prefix, value, value])
		return infer_damage_type(element, source_type, damage_origin)
	if value != "":
		push_warning("[%s] Unknown damage_type '%s'; using default for damage_origin '%s'." % [warning_prefix, value, damage_origin])
	return infer_damage_type(element, source_type, damage_origin)


static func default_combat_object_origin(source_type: String) -> String:
	if source_type == "reaction":
		return ORIGIN_REACTION
	if source_type == "trap":
		return ORIGIN_TRAP
	if source_type == "area" or source_type == "field":
		return ORIGIN_FIELD
	return ORIGIN_PRIMARY_ATTACK


static func normalize_combat_object_damage_type(value: Variant) -> StringName:
	var text: String = String(value)
	if text == "" or text == "physical":
		return &"direct_physical"
	if ELEMENT_NAMES.has(text):
		return &"direct_magical"
	return StringName(text)


static func defense_rate(damage_type: String) -> float:
	return float(damage_type_policy(damage_type).get("defense_rate"))


static func true_percent_default_cap(target_class: String) -> float:
	if target_class == "elite":
		return 0.01
	if target_class == "boss":
		return 0.0025
	return 1.0


static func vulnerability_bounds(target_class: String) -> Dictionary:
	if target_class == "elite":
		return {"floor": -0.60, "cap": 0.20}
	if target_class == "boss":
		return {"floor": -0.50, "cap": 0.15}
	return {"floor": -0.60, "cap": 0.30}


static func origin_bonus_keys(origin: String) -> Array[String]:
	return origin_policy(origin).get("bonus_keys")


static func enemy_type_bonus_key(target_class: String) -> String:
	return ModifierKeyRegistryScript.enemy_type_bonus_key(target_class)


static func target_class_origin_modifier(target_class: String, origin: String, damage_type: String) -> float:
	return origin_taken_modifier_from_map(target_origin_taken_modifiers(target_class), origin, damage_type)


static func target_origin_taken_modifiers(target_class: String) -> Dictionary:
	if target_class == "elite":
		return {
			ORIGIN_FIELD: 0.90,
			ORIGIN_STATUS_DOT: 0.85,
			ORIGIN_REACTION: 0.85,
			TYPE_REACTION_DAMAGE: 0.85
		}
	if target_class == "boss":
		return {
			ORIGIN_FIELD: 0.85,
			ORIGIN_STATUS_DOT: 0.65,
			ORIGIN_REACTION: 0.75,
			TYPE_REACTION_DAMAGE: 0.75
		}
	return {}


static func origin_taken_modifier_from_map(modifiers: Dictionary, origin: String, damage_type: String) -> float:
	if modifiers.has(origin):
		return float(modifiers.get(origin, 1.0))
	if modifiers.has(damage_type):
		return float(modifiers.get(damage_type, 1.0))
	return 1.0


static func resistance_keys(element: String, resistances: Dictionary = {}) -> Array[String]:
	match element:
		"physical":
			return ["physical_resistance", "physical", "armor"]
		"fire", "ice", "lightning", "arcane":
			return ["%s_resistance" % element, element, "magical_resistance", "magic"]
		"holy":
			return ["holy_resistance", "holy", "magical_resistance", "magic"]
		"poison":
			return ["poison_resistance", "poison"]
		"acid":
			if resistances.has("acid_resistance") or resistances.has("acid"):
				return ["acid_resistance", "acid"]
			return ["poison_resistance", "poison"]
	return [element]


static func resistance_scale(element: String, resistances: Dictionary = {}) -> float:
	if element == "acid" and not resistances.has("acid_resistance") and not resistances.has("acid"):
		return 0.5
	return 1.0


static func default_uses_character_damage(origin: String, damage_type: String) -> bool:
	if damage_type == TYPE_TRUE_PERCENT_DAMAGE or origin == ORIGIN_HEALING:
		return false
	if damage_type == TYPE_TRUE_DAMAGE:
		return false
	return bool(origin_policy(origin).get("uses_character_damage"))


static func default_uses_skill_level(origin: String) -> bool:
	return bool(origin_policy(origin).get("uses_skill_level"))


static func default_ignore_defense(damage_type: String) -> bool:
	return defense_rate(damage_type) <= 0.0


static func default_ignore_resistance(damage_type: String) -> bool:
	return bool(damage_type_policy(damage_type).get("ignores_resistance"))


static func default_ignore_vulnerability(damage_type: String) -> bool:
	return bool(damage_type_policy(damage_type).get("ignores_vulnerability"))


static func uses_fractional_buffer(packet: Dictionary) -> bool:
	if bool(packet.get("ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(packet.get("damage_type", ""))
	var field_damage_model: String = String(packet.get("field_damage_model", ""))
	return damage_type == TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(packet.get("uses_fractional_buffer", false))


static func uses_fractional_buffer_for_context(calculation_context: RefCounted) -> bool:
	if bool(calculation_context.call("packet_value", "ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	var field_damage_model: String = String(calculation_context.call("packet_value", "field_damage_model", ""))
	return damage_type == TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(calculation_context.call("packet_value", "uses_fractional_buffer", false))


static func uses_fractional_buffer_for_packet_object(packet_object: RefCounted) -> bool:
	if packet_object == null:
		return false
	if bool(packet_object.call("get_value", "ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(packet_object.call("get_value", "damage_type", ""))
	var field_damage_model: String = String(packet_object.call("get_value", "field_damage_model", ""))
	return damage_type == TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(packet_object.call("get_value", "uses_fractional_buffer", false))


static func default_can_crit(origin: String, damage_type: String) -> bool:
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT or damage_type == TYPE_REACTION_DAMAGE:
		return false
	if damage_type == TYPE_TRAP_DAMAGE or damage_type == TYPE_SUMMON_DAMAGE:
		return false
	if origin == ORIGIN_FIELD:
		return false
	return origin == ORIGIN_PRIMARY_ATTACK


static func can_crit(packet: Dictionary) -> bool:
	var damage_type: String = String(packet.get("damage_type", ""))
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT:
		return false
	return bool(packet.get("can_crit", false))


static func can_crit_for_context(calculation_context: RefCounted) -> bool:
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT:
		return false
	return bool(calculation_context.call("packet_value", "can_crit", false))


static func can_crit_for_packet_object(packet_object: RefCounted) -> bool:
	var damage_type: String = String(packet_object.call("get_value", "damage_type", ""))
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT:
		return false
	return bool(packet_object.call("get_value", "can_crit", false))


static func is_legal_origin_type(origin: String, damage_type: String) -> bool:
	if origin == ORIGIN_HEALING:
		return false
	if not ALLOWED_ORIGINS.has(origin) or not ALLOWED_DAMAGE_TYPES.has(damage_type):
		return false
	return bool(damage_type_policy(damage_type).call("allows_origin", origin))
