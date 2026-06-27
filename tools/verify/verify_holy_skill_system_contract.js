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

const skillsData = readJson("data/skills/skills.json");
const godsData = readJson("data/skills/gods.json");
const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
const summons = readJson("data/summons.json").summons || [];

const holySkills = (skillsData.skills || []).filter(
  (skill) => skill.school === "holy" && (skill.fusion_school === null || skill.fusion_school === undefined)
);

const expected = [
  ["holy_attack_judgment", "裁决攻击", "attack", "攻击变强，命中施加 Judgment；攻击带有 Judgment 的敌人时，额外获得少量护盾值"],
  ["holy_dash_heavenly_wings", "天翼冲刺", "dash", "冲刺时获得短暂无敌或护盾，并对路径敌人造成神圣伤害，施加 Judgment"],
  ["holy_cast_holy_ray", "圣光射线", "cast", "周期性从天而降数道圣光，优先攻击 Judgment 层数高的敌人"],
  ["holy_cast_divine_barrier", "神圣结界", "cast", "在玩家周围生成结界，伤害敌人并为玩家提供持续护盾恢复"],
  ["holy_cast_judgment_hammer", "审判圣锤", "cast", "对生命最高的敌人降下圣锤，造成高额伤害并短暂眩晕"],
  ["holy_summon_seraph", "炽天使", "summon", "炽天使协助作战，发射圣光弹，并周期性为玩家恢复护盾"],
  ["holy_summon_shield_guardian", "圣盾卫士", "summon", "召唤卫士守护玩家，格挡部分近身伤害，并反击攻击者"],
  ["holy_passive_sanctuary", "庇护", "passive", "护盾上限和护盾恢复提高；拥有护盾时神圣伤害提高"],
  ["holy_passive_devotion", "虔诚", "passive", "治疗和护盾溢出会转化为短时间伤害加成"],
  ["holy_passive_weakening_judgment", "弱化审判", "passive", "Judgment 敌人造成的伤害降低，并受到更多神圣伤害"],
  ["holy_power_divine_punishment", "神罚", "power", "Judgment 达到满层时触发落雷式圣光打击，造成伤害并眩晕目标"],
  ["holy_power_counter_seal", "反击圣印", "power", "护盾破裂或受到重击时，释放圣光冲击波，并给附近敌人施加 Judgment"],
  ["holy_power_absolution_light", "赦免之光", "power", "击杀 Judgment 敌人时恢复护盾；若护盾已满，则产生一次小型圣光爆炸"],
  ["holy_core_final_judgment_domain", "终裁神域", "core", "Judgment 触发神罚时不再完全清空层数，而是保留部分层数；每次神罚都会为玩家生成护盾，并使附近敌人进入短暂虚弱"],
];

assert(holySkills.length === 14, `expected 14 first-version holy skills, got ${holySkills.length}`);

const byId = new Map(holySkills.map((skill) => [skill.id, skill]));
for (const [id, name, type, description] of expected) {
  const skill = byId.get(id);
  assert(skill, `missing holy skill ${id}`);
  assert(skill.name === name, `${id} name mismatch`);
  assert(skill.type === type, `${id} type mismatch`);
  assert(skill.description === description, `${id} description must use the requested description field`);
  assert(Array.isArray(skill.tags) && skill.tags.includes("holy"), `${id} must be tagged holy`);
  assert(skill.offer_rule && Array.isArray(skill.offer_rule.required_schools), `${id} must have offer_rule.required_schools`);
  assert(skill.offer_rule.required_schools.includes("holy"), `${id} must require holy school`);
}

const holyGod = (godsData.gods || []).find((god) => god.id === "holy");
assert(holyGod && holyGod.implemented === true, "holy god must be marked implemented");
assert(Array.isArray(holyGod.tags) && holyGod.tags.includes("implemented"), "holy god tags must include implemented");

const attack = byId.get("holy_attack_judgment");
assert(attack.exclusive_group === "attack_school", "holy attack must replace the starting attack slot");
assert(hasEffect(attack, (effect) => effect.type === "add_modifier" && effect.modifier === "attack_damage_multiplier" && effect.value === 0.16), "holy attack must add exactly +16% attack damage");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && (rule.effects || []).some((effect) => effect.type === "apply_status" && effect.status === "judgment")), "holy attack must apply Judgment on hit");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && rule.cooldown === 0.2 && (rule.conditions || []).some((condition) => condition.type === "target_has_status" && condition.status === "judgment") && (rule.effects || []).some((effect) => effect.type === "grant_shield" && effect.max_health_ratio === 0.005)), "holy attack must grant a small shield when hitting Judgment targets");

const dash = byId.get("holy_dash_heavenly_wings");
assert(dash.exclusive_group === "dash_school", "heavenly wings must replace the dash skill slot");
assert((dash.trigger_rules || []).some((rule) => rule.trigger === "dash_start" && (rule.effects || []).some((effect) => effect.type === "grant_shield" && effect.max_health_ratio === 0.08 && effect.duration === 1.2)), "heavenly wings must grant an 8% max-health shield for 1.2s");
assert((dash.trigger_rules || []).some((rule) => rule.trigger === "dash_start" && (rule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "heavenly_wings_path")), "heavenly wings must create a visible damaging dash path");

const ray = byId.get("holy_cast_holy_ray");
const rayRule = (ray.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(rayRule && rayRule.cooldown, 5.5, "holy ray cooldown");
assert((rayRule.effects || []).some((effect) => effect.type === "spawn_projectiles_at_targets" && effect.projectile_id === "holy_ray_beam" && effect.count === 3 && effect.targeting === "judgment_stack_highest"), "holy ray must drop 3 beams prioritizing high Judgment stacks");

const barrier = byId.get("holy_cast_divine_barrier");
const barrierRule = (barrier.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(barrierRule && barrierRule.cooldown, 10.0, "divine barrier cooldown");
const barrierEffect = (barrierRule.effects || []).find((effect) => effect.type === "spawn_area" && effect.area_id === "divine_barrier_field");
assert(barrierEffect && barrierEffect.radius_r === 2.3 && barrierEffect.duration === 5.0 && barrierEffect.tick_interval === 0.5, "divine barrier must use R2.3, 5s duration, 0.5s ticks");

const hammer = byId.get("holy_cast_judgment_hammer");
const hammerRule = (hammer.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(hammerRule && hammerRule.cooldown, 7.0, "judgment hammer cooldown");
assert((hammerRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "judgment_hammer_area" && effect.targeting === "highest_hp_enemy" && effect.radius_r === 1.4), "judgment hammer must target the highest HP enemy with R1.4");

const divinePunishment = byId.get("holy_power_divine_punishment");
const punishmentRule = (divinePunishment.trigger_rules || []).find((rule) => rule.trigger === "status_max_stack_reached");
assert(punishmentRule, "divine punishment must listen to status_max_stack_reached");
assert((punishmentRule.conditions || []).some((condition) => condition.type === "event_status_is" && condition.status === "judgment"), "divine punishment must only react to Judgment max stacks");
assert((punishmentRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "divine_punishment_strike" && effect.radius_r === 1.2), "divine punishment must create an R1.2 holy strike");

const counterSeal = byId.get("holy_power_counter_seal");
assert((counterSeal.trigger_rules || []).some((rule) => rule.trigger === "shield_broken" && rule.cooldown === 8.0), "counter seal must react to shield_broken with 8s CD");
assert((counterSeal.trigger_rules || []).some((rule) => rule.trigger === "player_damage_taken" && rule.cooldown === 8.0), "counter seal must also react to heavy player damage");

const absolution = byId.get("holy_power_absolution_light");
assert((absolution.trigger_rules || []).some((rule) => rule.trigger === "enemy_death" && (rule.conditions || []).some((condition) => condition.type === "target_has_status" && condition.status === "judgment")), "absolution light must react to Judgment enemy deaths");

const core = byId.get("holy_core_final_judgment_domain");
assert(core.exclusive_group === "core_school", "final judgment domain must occupy the core exclusive group");
assert((core.effects || []).some((effect) => effect.type === "add_modifier" && effect.modifier === "divine_punishment_judgment_stacks_retained" && effect.value === 2), "final judgment domain must retain 2 Judgment stacks after divine punishment");

for (const objectId of [
  "heavenly_wings_path",
  "holy_ray_beam",
  "divine_barrier_field",
  "judgment_hammer_area",
  "seraph_holy_bolt",
  "shield_guardian_counter_wave",
  "divine_punishment_strike",
  "counter_seal_wave",
  "absolution_light_burst",
]) {
  assert(combatObjects.some((object) => object.id === objectId), `missing combat object ${objectId}`);
}

for (const summonId of ["seraph", "holy_shield_guardian"]) {
  assert(summons.some((summon) => summon.id === summonId), `missing summon ${summonId}`);
}

console.log("[verify_holy_skill_system_contract] PASS");
