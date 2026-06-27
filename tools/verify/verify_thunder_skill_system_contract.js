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

const thunderSkills = (skillsData.skills || []).filter(
  (skill) => skill.school === "thunder" && (skill.fusion_school === null || skill.fusion_school === undefined)
);

const expected = [
  ["thunder_attack_thundering", "雷鸣攻击", "attack", "攻击变强，命中施加 Conductive；每数次攻击额外向附近敌人弹射一道电弧"],
  ["thunder_dash_ball_lightning", "球状闪电", "dash", "冲刺时化作短暂球状闪电，伤害经过敌人，并在终点留下一个放电雷球"],
  ["thunder_cast_chain_lightning", "连锁闪电", "cast", "周期性向最近敌人释放闪电，命中后弹射到多个 Conductive 敌人"],
  ["thunder_cast_storm_circle", "雷暴法阵", "cast", "在怪物密集区域生成雷暴云，随机劈落闪电，优先攻击 Conductive 敌人"],
  ["thunder_cast_emp_ring", "电磁脉冲", "cast", "从玩家周围释放扩散电环，造成伤害并短暂打断敌人行动；对 Conductive 敌人伤害更高"],
  ["thunder_summon_storm_lynx", "雷兽猞猁", "summon", "雷兽在敌人之间跳跃攻击，优先攻击 Conductive 目标，并补充导电层数"],
  ["thunder_summon_storm_crow", "风暴乌鸦", "summon", "乌鸦盘旋在玩家周围，周期性标记远处敌人并召唤落雷"],
  ["thunder_passive_high_frequency_discharge", "高频放电", "passive", "雷电类技能触发间隔降低"],
  ["thunder_passive_superconductor", "超导体", "passive", "Conductive 敌人受到更多雷电伤害，且雷电弹射距离提高"],
  ["thunder_passive_static_charge", "静电蓄能", "passive", "每次雷电命中获得静电层数；满层后短时间提高攻击速度和技能触发频率"],
  ["thunder_power_overload_burst", "过载爆破", "power", "Conductive 达到满层时触发 Overload，造成范围雷爆，并向附近敌人传递 Conductive"],
  ["thunder_power_double_strike", "二重落雷", "power", "雷电技能有概率在命中后追加一次较弱落雷，优先攻击未被命中的敌人"],
  ["thunder_power_magnetic_pull", "雷磁牵引", "power", "雷电命中 Conductive 敌人时，小范围吸附附近轻型敌人，使后续连锁更集中"],
  ["thunder_core_storm_center", "雷暴中枢", "core", "所有雷电命中都会积累雷暴能量；能量满时触发全屏雷暴。Overload 不再完全清除 Conductive，而是保留部分层数继续连锁"],
];

assert(thunderSkills.length === 14, `expected 14 first-version thunder skills, got ${thunderSkills.length}`);

const byId = new Map(thunderSkills.map((skill) => [skill.id, skill]));
for (const [id, name, type, description] of expected) {
  const skill = byId.get(id);
  assert(skill, `missing thunder skill ${id}`);
  assert(skill.name === name, `${id} name mismatch`);
  assert(skill.type === type, `${id} type mismatch`);
  assert(skill.description === description, `${id} description must use the requested description field`);
  assert(Array.isArray(skill.tags) && skill.tags.includes("thunder"), `${id} must be tagged thunder`);
  assert(skill.offer_rule && Array.isArray(skill.offer_rule.required_schools), `${id} must have offer_rule.required_schools`);
  assert(skill.offer_rule.required_schools.includes("thunder"), `${id} must require thunder school`);
}

const thunderGod = (godsData.gods || []).find((god) => god.id === "thunder");
assert(thunderGod && thunderGod.implemented === true, "thunder god must be marked implemented");
assert(Array.isArray(thunderGod.tags) && thunderGod.tags.includes("implemented"), "thunder god tags must include implemented");

const attack = byId.get("thunder_attack_thundering");
assert(attack.exclusive_group === "attack_school", "thunder attack must replace the starting attack slot");
assert((attack.effects || []).some((effect) => effect.type === "add_modifier" && effect.modifier === "attack_damage_multiplier" && effect.value === 0.15), "thunder attack must add exactly +15% attack damage");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && (rule.effects || []).some((effect) => effect.type === "apply_status" && effect.status === "conductive")), "thunder attack must apply Conductive on hit");
assert((attack.trigger_rules || []).some((rule) => rule.trigger === "attack_hit" && rule.threshold === 4 && (rule.effects || []).some((effect) => effect.type === "chain_to_targets")), "thunder attack must release an arc every fourth hit");

const dash = byId.get("thunder_dash_ball_lightning");
assert(dash.exclusive_group === "dash_school", "ball lightning must replace the dash skill slot");
const dashRules = dash.trigger_rules || [];
assert(dashRules.some((rule) => rule.trigger === "dash_start"), "ball lightning must react to dash_start");
assert(dashRules.some((rule) => rule.trigger === "dash_end"), "ball lightning must leave a discharge orb at dash_end");

const chain = byId.get("thunder_cast_chain_lightning");
const chainRule = (chain.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(chainRule && chainRule.cooldown, 3.5, "chain lightning cooldown");
assert((chainRule.effects || []).some((effect) => effect.type === "spawn_projectile" && effect.projectile_id === "chain_lightning_bolt"), "chain lightning must spawn a lightning projectile");

const storm = byId.get("thunder_cast_storm_circle");
const stormRule = (storm.trigger_rules || []).find((rule) => rule.trigger === "cast_skill");
approx(stormRule && stormRule.cooldown, 7.0, "storm circle cooldown");
assert((stormRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.area_id === "thunderstorm_cloud" && effect.targeting === "densest_conductive_or_enemy_cluster"), "storm circle must target the densest cluster with Conductive priority");

const emp = byId.get("thunder_cast_emp_ring");
const empArea = ((emp.trigger_rules || []).flatMap((rule) => rule.effects || [])).find((effect) => effect.type === "spawn_area");
assert(empArea && empArea.radius_r === 2.8, "EMP radius must use configurable R units");
assert((empArea.effects_on_apply || []).some((effect) => effect.type === "damage" && effect.power_scale === 1.2), "EMP must deal 1.2P base damage");

const overload = byId.get("thunder_power_overload_burst");
const overloadRule = (overload.trigger_rules || []).find((rule) => rule.trigger === "status_max_stack_reached");
assert(overloadRule, "overload burst must listen to status_max_stack_reached");
assert((overloadRule.conditions || []).some((condition) => condition.type === "event_status_is" && condition.status === "conductive"), "overload burst must only react to Conductive max stacks");
assert((overloadRule.effects || []).some((effect) => effect.type === "spawn_area" && effect.radius_r === 1.8), "overload burst radius must use R units");

const magnetic = byId.get("thunder_power_magnetic_pull");
assert((magnetic.trigger_rules || []).some((rule) => rule.trigger === "post_damage_hit" && rule.cooldown === 0.5), "magnetic pull must use post_damage_hit with 0.5s ICD");

const core = byId.get("thunder_core_storm_center");
assert(core.exclusive_group === "core_school", "storm center must occupy the core exclusive group");
assert((core.trigger_rules || []).some((rule) => rule.trigger === "post_damage_hit" && rule.threshold === 60), "storm center must count 60 lightning hits through post_damage_hit");
assert((core.effects || []).some((effect) => effect.type === "add_modifier" && effect.modifier === "overload_conductive_stacks_retained" && effect.value === 2), "storm center must retain 2 Conductive stacks after Overload");

for (const objectId of [
  "chain_lightning_bolt",
  "thunder_arc_bolt",
  "ball_lightning_path",
  "ball_lightning_orb",
  "thunderstorm_cloud",
  "lightning_strike_area",
  "emp_ring",
  "overload_burst",
  "magnetic_pull_field",
]) {
  assert(combatObjects.some((object) => object.id === objectId), `missing combat object ${objectId}`);
}

for (const summonId of ["storm_lynx", "storm_crow"]) {
  assert(summons.some((summon) => summon.id === summonId), `missing summon ${summonId}`);
}

console.log("[verify_thunder_skill_system_contract] PASS");
