const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function findById(items, id, label) {
  const item = items.find((entry) => entry && entry.id === id);
  assert(item, `${label} ${id} must exist`);
  return item;
}

function allEffects(skill) {
  const effects = [];
  for (const rule of skill.trigger_rules || []) {
    effects.push(...(rule.effects || []));
  }
  effects.push(...(skill.effects || []));
  return effects;
}

function firstEffect(skill, type) {
  return allEffects(skill).find((effect) => effect && effect.type === type) || null;
}

const expectedSkills = [
  ["frost_attack_frostbite", "寒霜攻击", "攻击变强，并施加 Chilled；对已 Chilled 敌人额外提高冻结效率", "attack", "attack_school"],
  ["frost_dash_ice_shard_assault", "冰片突袭", "冲刺时向周围投掷冰片，造成伤害并施加 Chilled", "dash", "dash_school"],
  ["frost_cast_frost_field", "冰霜领域", "在敌人脚下生成冰霜区域，造成持续伤害，并留下冰霜路径，使经过敌人 Chilled", "cast", null],
  ["frost_cast_glacial_lance", "极寒冰矛", "向生命最高或最近精英发射穿透冰矛；命中 Frozen 敌人时产生碎冰溅射", "cast", null],
  ["frost_cast_blizzard_cloud", "暴雪云团", "在怪物密集区域生成移动暴雪，持续施加 Chilled，并降低敌人移动速度", "cast", null],
  ["frost_summon_frost_wolf", "霜狼", "冰狼协助作战，攻击命中敌人时施加 Chilled；优先扑击 Frozen 目标", "summon", null],
  ["frost_summon_ice_crystal_guard", "冰晶守卫", "召唤固定冰晶守卫，周期性释放冰脉冲，减速附近敌人", "summon", null],
  ["frost_power_shatter_execute", "碎冰处决", "Chilled / Frozen 敌人低于一定生命阈值时，直接碎裂死亡", "power", null],
  ["frost_passive_frozen_vulnerability", "冰封易伤", "被 Frozen、定身或强控的敌人受到更多伤害", "passive", null],
  ["frost_passive_chill_extension", "寒意延展", "Chilled 和 Frozen 持续时间提高；冰霜区域持续时间提高", "passive", null],
  ["frost_power_frost_ring_counter", "霜环反冲", "周围敌人数量过多或冲刺结束时，有概率从自身释放冰霜环，伤害并冻结敌人", "power", null],
  ["frost_power_ice_crack_chain", "冰裂连锁", "Frozen 敌人受到重击或技能伤害时，向周围发射碎冰片", "power", null],
  ["frost_power_ice_mist_guard", "冰雾护身", "每冻结一定数量敌人，获得一层冰雾护盾；护盾破裂时冻结附近敌人", "power", null],
  ["frost_core_absolute_zero", "绝对零度", "敌人被冻结所需的 Chilled 层数降低；每隔数秒，全场敌人获得一层 Chilled；Frozen 敌人碎裂时会在原地生成小型冰霜领域", "core", "core_school"],
];

const requiredCombatObjects = [
  "frost_field",
  "frost_path",
  "ice_shard_projectile",
  "glacial_lance_projectile",
  "shatter_splash",
  "blizzard_cloud",
  "frost_ring",
  "ice_crack_shard",
  "absolute_zero_field",
];

const gods = readJson("data/gods.json").gods || [];
const frostGod = findById(gods, "frost", "god");
assert(frostGod.implemented === true, "frost god must be implemented");
assert((frostGod.tags || []).includes("implemented"), "frost god tags must include implemented");
assert(!(frostGod.tags || []).includes("planned"), "frost god tags must not include planned after implementation");

const skills = readJson("data/skills.json").skills || [];
const frostSkills = skills.filter((skill) => skill && skill.school === "frost" && (skill.fusion_school ?? null) === null);
assert(frostSkills.length === expectedSkills.length, `expected ${expectedSkills.length} frost skills, found ${frostSkills.length}`);

for (const [id, name, description, type, exclusiveGroup] of expectedSkills) {
  const skill = findById(skills, id, "skill");
  assert(skill.school === "frost", `${id} must belong to frost school`);
  assert(skill.name === name, `${id} name must be ${name}`);
  assert(skill.description === description, `${id} description must match the design table`);
  assert(!Object.prototype.hasOwnProperty.call(skill, "effect_description"), `${id} must not use effect_description`);
  assert(skill.type === type, `${id} type must be ${type}`);
  assert((skill.exclusive_group ?? null) === exclusiveGroup, `${id} exclusive_group must be ${exclusiveGroup}`);
  assert(Array.isArray(skill.tags) && skill.tags.includes("frost"), `${id} tags must include frost`);
  assert(Array.isArray(skill.trigger_rules), `${id} must define trigger_rules`);
  assert(Array.isArray(skill.effects), `${id} must define effects`);
  assert(allEffects(skill).length > 0, `${id} must have runtime trigger effects or passive effects`);
}

const shatterExecute = findById(skills, "frost_power_shatter_execute", "skill");
const shatterExecuteDamage = firstEffect(shatterExecute, "damage");
const shatterExecuteTriggers = (shatterExecute.trigger_rules || []).map((rule) => rule && rule.trigger);
assert(shatterExecuteTriggers.length === 1 && shatterExecuteTriggers[0] === "post_damage_hit", "frost_power_shatter_execute must react through the unified post_damage_hit event");
assert(shatterExecuteDamage, "frost_power_shatter_execute must have a damage effect");
assert(Number(shatterExecuteDamage.low_hp_execute_threshold) === 0.1, "frost_power_shatter_execute execute threshold must be 10%");

const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
for (const id of requiredCombatObjects) {
  const object = findById(combatObjects, id, "combat object");
  assert(object.visual_mode || object.visual || object.visual_style, `${id} must define a visible representation`);
}

console.log("[verify_frost_skill_system_contract] PASS");
