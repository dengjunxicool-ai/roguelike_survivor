## 文件用途：集中登记伤害来源、类型、元素及默认防御、暴击、缩放和目标阶级规则。
## 使用方式：构建器、计算器和校验器通过静态查询共用规则，不在调用方复制类型分支。
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


## 作用：取得来源策略对象，未知来源回退主攻击。
## 使用：origin 是来源类别，返回含默认类型、加成键及缩放开关的策略。
static func origin_policy(origin: String) -> RefCounted:
	var normalized: String = normalize_origin(origin)
	return DamageOriginPolicyScript.from_dictionary(normalized, ORIGIN_POLICIES.get(normalized, ORIGIN_POLICIES[ORIGIN_PRIMARY_ATTACK]))


## 作用：取得伤害类型策略对象，未知类型回退物理直伤。
## 使用：返回防御权重、忽略标记和允许来源集合。
static func damage_type_policy(damage_type: String) -> RefCounted:
	var normalized: String = damage_type if ALLOWED_DAMAGE_TYPES.has(damage_type) else TYPE_DIRECT_PHYSICAL
	return DamageTypePolicyScript.from_dictionary(normalized, TYPE_POLICIES.get(normalized, {}))


## 作用：检查元素是否在登记列表中。
## 使用：value 为元素ID；不自动转换别名。
static func is_element(value: String) -> bool:
	return ELEMENT_NAMES.has(value)


## 作用：保留登记元素，否则返回 physical。
## 使用：供需要默认回退的构建/配置入口使用。
static func normalize_element(value: String) -> String:
	return value if is_element(value) else "physical"


## 作用：保留登记来源，否则返回 primary_attack。
## 使用：返回标准来源字符串。
static func normalize_origin(value: String) -> String:
	return value if ALLOWED_ORIGINS.has(value) else ORIGIN_PRIMARY_ATTACK


## 作用：保留登记类型，否则按来源返回默认类型。
## 使用：origin 决定回退规则。
static func normalize_damage_type(value: String, origin: String) -> String:
	return value if ALLOWED_DAMAGE_TYPES.has(value) else default_damage_type_for_origin(origin)


## 作用：读取来源策略中的默认伤害类型。
## 使用：未知来源经过来源策略回退。
static func default_damage_type_for_origin(origin: String) -> String:
	return String(origin_policy(origin).get("default_damage_type"))


## 作用：依据状态/反应/陷阱来源、区域动作和物理元素推断类型。
## 使用：element、source_type、damage_origin 必须分开传入，返回 StringName。
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


## 作用：保留合法类型；旧元素值或未知类型警告并按语义推断。
## 使用：warning_prefix 标明消费方，返回推断的伤害类型。
static func normalize_configured_damage_type(value: String, element: Variant, source_type: String, damage_origin: String, warning_prefix: String = "DamageRuleRegistry") -> StringName:
	if ALLOWED_DAMAGE_TYPES.has(value):
		return StringName(value)
	if ELEMENT_NAMES.has(value):
		push_warning("[%s] damage_type '%s' is an old element value. Use element='%s' with a documented damage_type instead." % [warning_prefix, value, value])
		return infer_damage_type(element, source_type, damage_origin)
	if value != "":
		push_warning("[%s] Unknown damage_type '%s'; using default for damage_origin '%s'." % [warning_prefix, value, damage_origin])
	return infer_damage_type(element, source_type, damage_origin)


## 作用：按反应、陷阱、区域/场地或其他对象选择默认来源。
## 使用：source_type 为对象种类，其余回退主攻击。
static func default_combat_object_origin(source_type: String) -> String:
	if source_type == "reaction":
		return ORIGIN_REACTION
	if source_type == "trap":
		return ORIGIN_TRAP
	if source_type == "area" or source_type == "field":
		return ORIGIN_FIELD
	return ORIGIN_PRIMARY_ATTACK


## 作用：把空值/physical转为物理直伤，其他元素转为魔法直伤。
## 使用：非元素字符串保留为 StringName。
static func normalize_combat_object_damage_type(value: Variant) -> StringName:
	var text: String = String(value)
	if text == "" or text == "physical":
		return &"direct_physical"
	if ELEMENT_NAMES.has(text):
		return &"direct_magical"
	return StringName(text)


## 作用：读取伤害类型的固定防御权重。
## 使用：零表示不受此类固定防御抵扣。
static func defense_rate(damage_type: String) -> float:
	return float(damage_type_policy(damage_type).get("defense_rate"))


## 作用：按普通、精英和Boss目标返回最大生命比例上限。
## 使用：精英1%、Boss0.25%，普通为100%。
static func true_percent_default_cap(target_class: String) -> float:
	if target_class == "elite":
		return 0.01
	if target_class == "boss":
		return 0.0025
	return 1.0


## 作用：返回目标阶级的易伤上下限。
## 使用：普通/精英/Boss有不同上限，返回 floor/cap 字典。
static func vulnerability_bounds(target_class: String) -> Dictionary:
	if target_class == "elite":
		return {"floor": -0.60, "cap": 0.20}
	if target_class == "boss":
		return {"floor": -0.50, "cap": 0.15}
	return {"floor": -0.60, "cap": 0.30}


## 作用：返回来源策略允许累加的modifier键。
## 使用：用于输出阶段，顺序来自登记策略。
static func origin_bonus_keys(origin: String) -> Array[String]:
	return origin_policy(origin).get("bonus_keys")


## 作用：查询目标阶级对应的输出加成键。
## 使用：target_class 来自 enemy_rank，委托 ModifierKeyRegistry。
static func enemy_type_bonus_key(target_class: String) -> String:
	return ModifierKeyRegistryScript.enemy_type_bonus_key(target_class)


## 作用：依据目标阶级及伤害来源/类型计算承伤系数。
## 使用：来源优先于类型键，默认1。
static func target_class_origin_modifier(target_class: String, origin: String, damage_type: String) -> float:
	return origin_taken_modifier_from_map(target_origin_taken_modifiers(target_class), origin, damage_type)


## 作用：返回精英或Boss的场地、DOT和反应承伤系数表。
## 使用：普通目标返回空表，由查表入口回退1。
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


## 作用：优先查询来源键，缺失再查伤害类型键。
## 使用：两项都缺失返回1，供目标快照系数查询。
static func origin_taken_modifier_from_map(modifiers: Dictionary, origin: String, damage_type: String) -> float:
	if modifiers.has(origin):
		return float(modifiers.get(origin, 1.0))
	if modifiers.has(damage_type):
		return float(modifiers.get(damage_type, 1.0))
	return 1.0


## 作用：返回元素抗性字段的优先查找顺序。
## 使用：酸无专属字段时借毒抗；魔法元素可借通用魔抗。
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


## 作用：酸元素缺专属抗性时将借用毒抗减半。
## 使用：其余情况返回1。
static func resistance_scale(element: String, resistances: Dictionary = {}) -> float:
	if element == "acid" and not resistances.has("acid_resistance") and not resistances.has("acid"):
		return 0.5
	return 1.0


## 作用：根据来源和类型决定是否默认使用角色倍率。
## 使用：真伤、百分比真伤和治疗关闭，其余查询来源策略。
static func default_uses_character_damage(origin: String, damage_type: String) -> bool:
	if damage_type == TYPE_TRUE_PERCENT_DAMAGE or origin == ORIGIN_HEALING:
		return false
	if damage_type == TYPE_TRUE_DAMAGE:
		return false
	return bool(origin_policy(origin).get("uses_character_damage"))


## 作用：返回来源策略是否使用技能等级缩放。
## 使用：主攻击启用，其他登记来源默认关闭。
static func default_uses_skill_level(origin: String) -> bool:
	return bool(origin_policy(origin).get("uses_skill_level"))


## 作用：判断类型防御权重是否为零。
## 使用：用于包构建默认 ignore_defense。
static func default_ignore_defense(damage_type: String) -> bool:
	return defense_rate(damage_type) <= 0.0


## 作用：查询类型是否默认忽略元素抗性。
## 使用：用于真伤等包默认规则。
static func default_ignore_resistance(damage_type: String) -> bool:
	return bool(damage_type_policy(damage_type).get("ignores_resistance"))


## 作用：查询类型是否默认忽略易伤。
## 使用：用于真伤等包默认规则。
static func default_ignore_vulnerability(damage_type: String) -> bool:
	return bool(damage_type_policy(damage_type).get("ignores_vulnerability"))


## 作用：按状态DOT、dot_tick或显式开关选择小数累计。
## 使用：ignore_fractional_buffer 优先关闭。
static func uses_fractional_buffer(packet: Dictionary) -> bool:
	if bool(packet.get("ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(packet.get("damage_type", ""))
	var field_damage_model: String = String(packet.get("field_damage_model", ""))
	return damage_type == TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(packet.get("uses_fractional_buffer", false))


## 作用：从上下文选择DOT小数累计策略。
## 使用：读取 typed 字段，不创建新字典。
static func uses_fractional_buffer_for_context(calculation_context: RefCounted) -> bool:
	if bool(calculation_context.call("packet_value", "ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	var field_damage_model: String = String(calculation_context.call("packet_value", "field_damage_model", ""))
	return damage_type == TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(calculation_context.call("packet_value", "uses_fractional_buffer", false))


## 作用：从包对象选择DOT小数累计策略。
## 使用：空对象返回 false，ignore 开关优先。
static func uses_fractional_buffer_for_packet_object(packet_object: RefCounted) -> bool:
	if packet_object == null:
		return false
	if bool(packet_object.call("get_value", "ignore_fractional_buffer", false)):
		return false
	var damage_type: String = String(packet_object.call("get_value", "damage_type", ""))
	var field_damage_model: String = String(packet_object.call("get_value", "field_damage_model", ""))
	return damage_type == TYPE_STATUS_DOT or field_damage_model == "dot_tick" or bool(packet_object.call("get_value", "uses_fractional_buffer", false))


## 作用：为主攻击类型决定默认暴击，排除持续、反应、陷阱、召唤和真伤。
## 使用：field来源默认关闭，即便区域类型允许显式暴击。
static func default_can_crit(origin: String, damage_type: String) -> bool:
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT or damage_type == TYPE_REACTION_DAMAGE:
		return false
	if damage_type == TYPE_TRAP_DAMAGE or damage_type == TYPE_SUMMON_DAMAGE:
		return false
	if origin == ORIGIN_FIELD:
		return false
	return origin == ORIGIN_PRIMARY_ATTACK


## 作用：检查包暴击开关并强制禁止真伤、百分比真伤和状态DOT。
## 使用：显式开关只对剩余类型生效。
static func can_crit(packet: Dictionary) -> bool:
	var damage_type: String = String(packet.get("damage_type", ""))
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT:
		return false
	return bool(packet.get("can_crit", false))


## 作用：从上下文检查强制禁止类型和暴击开关。
## 使用：仅查询，不判定随机暴击。
static func can_crit_for_context(calculation_context: RefCounted) -> bool:
	var damage_type: String = String(calculation_context.call("packet_value", "damage_type", ""))
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT:
		return false
	return bool(calculation_context.call("packet_value", "can_crit", false))


## 作用：从typed包检查强制禁止类型和暴击开关。
## 使用：仅查询，不消耗随机数。
static func can_crit_for_packet_object(packet_object: RefCounted) -> bool:
	var damage_type: String = String(packet_object.call("get_value", "damage_type", ""))
	if damage_type == TYPE_TRUE_DAMAGE or damage_type == TYPE_TRUE_PERCENT_DAMAGE or damage_type == TYPE_STATUS_DOT:
		return false
	return bool(packet_object.call("get_value", "can_crit", false))


## 作用：判断来源/类型均登记且类型允许该来源。
## 使用：healing不属于合法伤害组合；返回布尔值。
static func is_legal_origin_type(origin: String, damage_type: String) -> bool:
	if origin == ORIGIN_HEALING:
		return false
	if not ALLOWED_ORIGINS.has(origin) or not ALLOWED_DAMAGE_TYPES.has(damage_type):
		return false
	return bool(damage_type_policy(damage_type).call("allows_origin", origin))
