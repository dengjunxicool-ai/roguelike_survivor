const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function approx(actual, expected, message) {
  assert(Math.abs(Number(actual) - expected) < 0.0001, `${message}: expected ${expected}, got ${actual}`);
}

function hasEffect(skill, predicate) {
  return (skill.effects || []).some(predicate)
    || (skill.trigger_rules || []).some((rule) => (rule.effects || []).some(predicate));
}

const skillsData = readJson("data/skills.json");
const godsData = readJson("data/gods.json");
const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
const summons = readJson("data/summons.json").summons || [];

const curseSkills = (skillsData.skills || []).filter(
  (skill) => skill.school === "curse" && (skill.fusion_school === null || skill.fusion_school === undefined)
);

const expected = [
  ["curse_attack_cursing", "诅咒攻击", "attack", "攻击变强，命中施加 Cursed；对低生命敌人施加额外诅咒伤害"],
  ["curse_dash_soul_chain", "魂链疾行", "dash", "冲刺时向附近 Cursed 敌人连接魂链，造成伤害并吸取少量生命"],
  ["curse_cast_black_serpent_hunt", "黑蛇追猎", "cast", "周期性召唤黑蛇追踪敌人，优先攻击未被诅咒的目标，命中施加 Cursed"],
  ["curse_cast_death_scythe", "死镰回旋", "cast", "召唤镰刀围绕玩家旋转后飞出并返回，对 Cursed 敌人造成额外伤害"],
  ["curse_cast_doom_circle", "终末法阵", "cast", "在精英或怪群脚下生成延迟法阵，数秒后爆发；目标身上 Cursed 层数越高，伤害越高"],
  ["curse_summon_bone_servant", "亡骸仆从", "summon", "Cursed 敌人死亡时有概率召唤骷髅仆从，持续一段时间"],
  ["curse_summon_soul_crow", "魂鸦", "summon", "魂鸦收集 Cursed 敌人死亡后的灵魂，并发射灵魂弹攻击远处敌人"],
  ["curse_passive_vampiric_ritual", "吸血仪式", "passive", "Cursed 造成伤害或击杀时，为玩家恢复少量生命"],
  ["curse_passive_plague_spread", "疫咒扩散", "passive", "Cursed 敌人死亡时，将自身部分负面状态传播给附近敌人"],
  ["curse_passive_deathbed_deepen", "临终加深", "passive", "敌人生命越低，受到的 Cursed 延迟伤害越高；Boss 效果降低"],
  ["curse_power_fear_whisper", "恐惧低语", "power", "Cursed 敌人靠近玩家时，有概率陷入恐惧并向外逃离"],
  ["curse_power_soul_harvest", "灵魂收割", "power", "击杀 Cursed 敌人会储存灵魂；灵魂满时强化下一次技能类伤害"],
  ["curse_power_death_pact", "死亡契约", "power", "周期性标记附近生命最高的敌人；若其在持续时间内死亡，则产生灵魂爆炸"],
  ["curse_core_grand_coffin", "万咒归棺", "core", "Cursed 敌人死亡时必定传播负面状态，并将部分未结算诅咒伤害转化为灵魂债务。灵魂债务满时释放灵魂风暴，攻击全场低生命敌人"],
];

assert(curseSkills.length === 14, `expected 14 first-version curse skills, got ${curseSkills.length}`);

const byId = new Map(curseSkills.map((skill) => [skill.id, skill]));
for (const [id, name, type, description] of expected) {
  const skill = byId.get(id);
  assert(skill, `missing curse skill ${id}`);
  assert(skill.name === name, `${id} name mismatch`);
  assert(skill.type === type, `${id} type mismatch`);
  assert(skill.description === description, `${id} description must use the requested description field`);
  assert(Array.isArray(skill.tags) && skill.tags.includes("curse"), `${id} must be tagged curse`);
  assert(skill.offer_rule && Array.isArray(skill.offer_rule.required_schools), `${id} must have offer_rule.required_schools`);
  assert(skill.offer_rule.required_schools.includes("curse"), `${id} must require curse school`);
}

const curseGod = (godsData.gods || []).find((god) => god.id === "curse");
assert(curseGod && curseGod.implemented === true, "curse god must be marked implemented");
assert(Array.isArray(curseGod.tags) && curseGod.tags.includes("implemented"), "curse god tags must include implemented");

const attack = byId.get("curse_attack_cursing");
assert(attack.exclusive_group === "attack_school", "curse attack must replace the starting attack slot");
assert(hasEffect(attack, (effect) => effect.type === "add_modifier" && effect.modifier === "attack_damage_multiplier" && effect.value === 0.18), "curse attack must add exactly +18% attack damage");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && (rule.effects || []).some((effect) => effect.type === "apply_status" && effect.status === "cursed")), "curse attack must apply Cursed on hit");

const dash = byId.get("curse_dash_soul_chain");
assert(dash.exclusive_group === "dash_school", "soul chain dash must replace the dash skill slot");
const dashRule = (dash.trigger_rules || []).find((rule) => rule.trigger === "dash_start");
assert(dashRule, "soul chain dash must react to dash_start");
assert((dashRule.effects || []).some((effect) => effect.type === "chain_to_targets" && effect.targeting === "cursed_first_nearest" && effect.count === 3), "soul chain dash must connect up to 3 Cursed enemies");
assert((dashRule.effects || []).some((effect) => {
  return effect.type === "chain_to_targets" && (effect.actions || []).some((action) => action.type === "heal" && action.max_health_ratio === 0.01);
}), "soul chain dash must heal 1% max health per linked target");

const serpent = byId.get("curse_cast_black_serpent_hunt");
const serpentRule = (serpent.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(serpentRule && serpentRule.cooldown, 4.5, "black serpent cooldown");
assert((serpentRule.effects || []).some((effect) => effect.type === "spawn_projectile_burst" && effect.projectile_id === "black_serpent_projectile" && effect.count === 2), "black serpent must launch 2 serpents");

const scythe = byId.get("curse_cast_death_scythe");
const scytheRule = (scythe.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(scytheRule && scytheRule.cooldown, 6.0, "death scythe cooldown");
assert((scytheRule.effects || []).some((effect) => effect.type === "spawn_projectile_burst" && effect.projectile_id === "death_scythe_projectile" && effect.count === 2), "death scythe must hit on outbound and return paths");

const doom = byId.get("curse_cast_doom_circle");
const doomRule = (doom.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(doomRule && doomRule.cooldown, 7.5, "doom circle cooldown");
assert((doomRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "doom_circle_delay" && effect.targeting === "highest_health_or_nearest_elite"), "doom circle must target elite/highest health enemies");

const plague = byId.get("curse_passive_plague_spread");
assert((plague.trigger_rules || []).some((rule) => rule.trigger === "enemy_death" && (rule.conditions || []).some((condition) => condition.type === "target_has_status" && condition.status === "cursed")), "plague spread must react to Cursed enemy deaths");

const ritual = byId.get("curse_passive_vampiric_ritual");
assert((ritual.trigger_rules || []).some((rule) => rule.trigger === "post_damage_hit" && rule.cooldown === 0.5), "vampiric ritual must heal from Cursed damage through post_damage_hit with ICD");
assert((ritual.trigger_rules || []).some((rule) => rule.trigger === "enemy_death"), "vampiric ritual must heal from Cursed kills");

const harvest = byId.get("curse_power_soul_harvest");
assert((harvest.trigger_rules || []).some((rule) => rule.trigger === "enemy_death" && rule.threshold === 12), "soul harvest must count 12 Cursed kills");

const pact = byId.get("curse_power_death_pact");
const pactRule = (pact.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(pactRule && pactRule.cooldown, 8.0, "death pact cooldown");
assert((pactRule.effects || []).some((effect) => effect.type === "mark_target" && effect.mark === "death_pact"), "death pact must mark the highest HP enemy");

const core = byId.get("curse_core_grand_coffin");
assert(core.exclusive_group === "core_school", "grand coffin must occupy the core exclusive group");
assert((core.trigger_rules || []).some((rule) => rule.trigger === "enemy_death" && rule.threshold === 20), "grand coffin must build soul debt from Cursed deaths");

for (const objectId of [
  "soul_chain_link",
  "black_serpent_projectile",
  "death_scythe_projectile",
  "doom_circle_delay",
  "doom_circle_burst",
  "curse_whisper_burst",
  "soul_bolt_projectile",
  "soul_explosion_area",
  "soul_storm_bolt",
]) {
  assert(combatObjects.some((object) => object.id === objectId), `missing combat object ${objectId}`);
}

for (const summonId of ["bone_servant", "soul_crow"]) {
  assert(summons.some((summon) => summon.id === summonId), `missing summon ${summonId}`);
}

console.log("[verify_curse_skill_system_contract] PASS");
