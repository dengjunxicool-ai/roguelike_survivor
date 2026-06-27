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

const skillsData = readJson("data/skills.json");
const godsData = readJson("data/gods.json");
const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
const summons = readJson("data/summons.json").summons || [];

const chaosSkills = (skillsData.skills || []).filter(
  (skill) => skill.school === "chaos" && (skill.fusion_school === null || skill.fusion_school === undefined)
);

const expected = [
  ["chaos_attack_chaotic", "混沌攻击", "attack", "攻击变强，命中施加 Instability；命中时有概率使弹体分裂、偏转或追加一次弱化命中"],
  ["chaos_dash_rift_step", "裂隙步", "dash", "冲刺时在起点和终点留下虚空裂隙，敌人经过裂隙时受到伤害并获得 Instability"],
  ["chaos_cast_void_rift", "虚空裂缝", "cast", "在怪物密集区域打开裂缝，持续吸附附近敌人并造成虚空伤害"],
  ["chaos_cast_singularity_barrage", "奇点弹幕", "cast", "发射数个会弹跳的混沌球，命中 Instability 敌人时有概率分裂"],
  ["chaos_cast_mutation_pulse", "异变脉冲", "cast", "周期性释放脉冲，使敌人随机获得减速、易伤、缩小、沉默中的一种负面异变"],
  ["chaos_summon_chaos_clone", "混沌分身", "summon", "召唤一个分身，模仿玩家最近一次普攻或技能，但伤害降低"],
  ["chaos_summon_void_maw", "虚空巨口", "summon", "召唤固定虚空巨口，持续吸附附近敌人，并吞噬低生命小怪"],
  ["chaos_passive_entropy_growth", "熵增", "passive", "每次 Instability 裂变后，玩家获得一层随机强化，强化从伤害、范围、冷却、速度中抽取"],
  ["chaos_passive_geometric_imbalance", "几何失衡", "passive", "弹体类攻击有概率发生分裂、回旋或折返，但单次伤害略微降低"],
  ["chaos_passive_anomalous_stability", "反常稳定", "passive", "连续触发若干次混沌效果后，下一次混沌效果必定触发最高收益版本"],
  ["chaos_power_fission_burst", "裂变爆发", "power", "Instability 达到满层时，目标发生裂变，造成范围伤害，并在原地生成短暂小裂隙"],
  ["chaos_power_echo_cast", "回声施法", "power", "每释放若干次技能类效果后，重复上一次技能，重复版本伤害降低"],
  ["chaos_power_chaos_exchange", "混沌交换", "power", "周期性标记两个 Instability 敌人并交换位置，交换时对路径敌人造成撕裂伤害"],
  ["chaos_core_chaos_singularity", "混沌奇点", "core", "Instability 裂变后不再完全消失，而是为全局奇点充能；奇点满时吸附大范围敌人，复制最近一次非混沌技能，并造成高额虚空爆发"],
];

assert(chaosSkills.length === 14, `expected 14 first-version chaos skills, got ${chaosSkills.length}`);

const byId = new Map(chaosSkills.map((skill) => [skill.id, skill]));
for (const [id, name, type, description] of expected) {
  const skill = byId.get(id);
  assert(skill, `missing chaos skill ${id}`);
  assert(skill.name === name, `${id} name mismatch`);
  assert(skill.type === type, `${id} type mismatch`);
  assert(skill.description === description, `${id} description must use the requested description field`);
  assert(Array.isArray(skill.tags) && skill.tags.includes("chaos"), `${id} must be tagged chaos`);
  assert(skill.offer_rule && Array.isArray(skill.offer_rule.required_schools), `${id} must have offer_rule.required_schools`);
  assert(skill.offer_rule.required_schools.includes("chaos"), `${id} must require chaos school`);
}

const chaosGod = (godsData.gods || []).find((god) => god.id === "chaos");
assert(chaosGod && chaosGod.implemented === true, "chaos god must be marked implemented");
assert(Array.isArray(chaosGod.tags) && chaosGod.tags.includes("implemented"), "chaos god tags must include implemented");

const attack = byId.get("chaos_attack_chaotic");
assert(attack.exclusive_group === "attack_school", "chaos attack must replace the starting attack slot");
assert((attack.effects || []).some((effect) => effect.type === "add_modifier" && effect.modifier === "attack_damage_multiplier" && effect.value === 0.14), "chaos attack must add exactly +14% attack damage");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && (rule.effects || []).some((effect) => effect.type === "apply_status" && effect.status === "instability")), "chaos attack must apply Instability on hit");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && rule.threshold === 3 && (rule.effects || []).some((effect) => effect.type === "spawn_projectile_burst")), "chaos attack must trigger a chaos mutation every third hit");

const dash = byId.get("chaos_dash_rift_step");
assert(dash.exclusive_group === "dash_school", "rift step must replace the dash skill slot");
const dashAreas = (dash.trigger_rules || []).flatMap((rule) => rule.effects || []).filter((effect) => effect.type === "spawn_area" && effect.area_id === "chaos_rift");
assert(dashAreas.length >= 2, "rift step must create void rifts at dash start and dash end");

const voidRift = byId.get("chaos_cast_void_rift");
const voidRiftRule = (voidRift.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(voidRiftRule && voidRiftRule.cooldown, 8.0, "void rift cooldown");
assert((voidRiftRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "void_rift_field" && effect.targeting === "densest_enemy_cluster"), "void rift must target the densest enemy cluster");

const barrage = byId.get("chaos_cast_singularity_barrage");
const barrageRule = (barrage.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(barrageRule && barrageRule.cooldown, 5.0, "singularity barrage cooldown");
assert((barrageRule.effects || []).some((effect) => effect.type === "spawn_projectile_burst" && effect.projectile_id === "chaos_orb" && effect.count === 5), "singularity barrage must fire 5 chaos orbs");

const mutation = byId.get("chaos_cast_mutation_pulse");
const mutationArea = ((mutation.trigger_rules || []).flatMap((rule) => rule.effects || [])).find((effect) => effect.type === "spawn_area" && effect.area_id === "mutation_pulse_area");
assert(mutationArea && mutationArea.radius_r === 3.0, "mutation pulse radius must use R3.0");
assert((mutationArea.effects_on_apply || []).some((effect) => effect.type === "apply_status" && effect.status === "instability" && effect.stacks === 2), "mutation pulse must apply Instability +2");

const fission = byId.get("chaos_power_fission_burst");
const fissionRule = (fission.trigger_rules || []).find((rule) => rule.trigger === "status_max_stack_reached");
assert(fissionRule, "fission burst must listen to status_max_stack_reached");
assert((fissionRule.conditions || []).some((condition) => condition.type === "event_status_is" && condition.status === "instability"), "fission burst must only react to Instability max stacks");
assert((fissionRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "instability_fission_burst" && effect.radius_r === 1.8), "fission burst must create an R1.8 void burst");

const exchange = byId.get("chaos_power_chaos_exchange");
const exchangeRule = (exchange.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(exchangeRule && exchangeRule.cooldown, 6.0, "chaos exchange cooldown");
assert((exchangeRule.effects || []).some((effect) => effect.type === "swap_targets" && effect.targeting === "instability_stack_highest"), "chaos exchange must swap two Instability enemies");

const core = byId.get("chaos_core_chaos_singularity");
assert(core.exclusive_group === "core_school", "chaos singularity must occupy the core exclusive group");
assert((core.trigger_rules || []).some((rule) => rule.trigger === "status_max_stack_reached" && rule.threshold === 25), "chaos singularity must count 25 Instability fissions");
assert((core.effects || []).some((effect) => effect.type === "add_modifier" && effect.modifier === "instability_fission_stacks_retained" && effect.value === 1), "chaos singularity must retain 1 Instability stack after fission");

for (const objectId of [
  "chaos_rift",
  "void_rift_field",
  "chaos_orb",
  "mutation_pulse_area",
  "instability_fission_burst",
  "chaos_exchange_line",
  "chaos_singularity_field",
  "chaos_singularity_burst",
]) {
  assert(combatObjects.some((object) => object.id === objectId), `missing combat object ${objectId}`);
}

for (const summonId of ["chaos_clone", "void_maw"]) {
  assert(summons.some((summon) => summon.id === summonId), `missing summon ${summonId}`);
}

console.log("[verify_chaos_skill_system_contract] PASS");
