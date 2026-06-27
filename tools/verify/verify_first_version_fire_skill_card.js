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

function findById(items, id, label) {
  const item = (items || []).find((entry) => entry && entry.id === id);
  assert(item, `${label} ${id} must exist`);
  return item;
}

const skills = readJson("data/skills.json").skills || [];
const firstSkill = findById(skills, "fire_attack_searing", "fire skill");
assert(firstSkill.school === "fire", "fire_attack_searing must be a fire school skill");
assert(firstSkill.type === "attack", "fire_attack_searing must use the new attack type");
assert(firstSkill.exclusive_group === "attack_school", "fire_attack_searing must occupy attack_school");
assert(firstSkill.offer_rule && firstSkill.offer_rule.required_schools?.includes("fire"), "fire_attack_searing must require fire school access");
assert((firstSkill.trigger_rules || []).some((rule) => rule.trigger === "attack_hit"), "fire_attack_searing must react to attack_hit");
assert((firstSkill.effects || []).some((effect) => effect.type === "add_modifier"), "fire_attack_searing must carry its passive attack modifier");

const fireEffectDescriptions = {
  fire_attack_searing: "攻击变强，命中施加 Burning，并有概率在目标脚下生成短暂火焰路径",
  fire_dash_blazing_run: "冲刺会伤害路径上的敌人，并留下一条火焰路径，使经过敌人 Burning",
  fire_cast_meteor_rain: "天空周期性落下陨石，造成范围伤害，并在落点留下燃烧地面",
  fire_cast_lava_rift: "从最近敌人脚下生成一条向外蔓延的熔岩裂缝，造成线形伤害",
  fire_cast_scorching_vortex: "在玩家周围生成缓慢旋转的火焰风暴，持续伤害近身敌人",
  fire_summon_crimson_dragon: "红龙与你并肩作战，周期性向怪群喷吐龙息，施加 Burning",
  fire_summon_ember_fox_pack: "每当你施加一定次数 Burning，召唤火狐冲向敌人，命中后爆成小火花",
  fire_passive_burning_focus: "Burning 持续时间和伤害提高",
  fire_passive_overheated_casting: "受到伤害或生命值降低时，短时间提高技能类伤害和范围",
  fire_passive_scorched_ground_affinity: "敌人站在火焰路径或燃烧地面上时，受到的 Burning 伤害提高",
  fire_power_combustion_chain: "击杀一定数量 Burning 敌人后，最后一个目标爆炸；爆炸击杀有概率继续引爆",
  fire_power_ember_attachment: "Burning 敌人死亡后留下余烬，余烬会自动飞向附近敌人并点燃目标",
  fire_power_ignite_core: "技能类伤害命中 Burning 敌人时，消耗部分 Burning 持续时间，造成一次额外火焰爆发",
  fire_core_inferno_cycle: "Burning 敌人死亡必定生成一次小型火焰爆裂；爆裂命中敌人会重新施加 Burning。每触发若干次爆裂，额外召唤一次流星火雨",
};

for (const [skillId, expectedDescription] of Object.entries(fireEffectDescriptions)) {
  const skill = findById(skills, skillId, "fire skill");
  assert(skill.description === expectedDescription, `${skillId} must expose its fire god skill description`);
  assert(!Object.prototype.hasOwnProperty.call(skill, "effect_description"), `${skillId} must use description instead of effect_description`);
}

const fusion = findById(skills, "fusion_fire_frost_steam_mist", "fire fusion skill");
assert(fusion.type === "fusion", "fusion_fire_frost_steam_mist must use fusion type");
assert(fusion.offer_rule?.required_min_skill_count?.fire >= 2, "fire-led fusions must require at least two fire skills");
assert(fusion.offer_rule?.required_min_skill_count?.frost >= 1, "fire+frost fusion must require frost access");

for (const obsoleteId of ["mars_spark_missile", "fire_tornado", "soulburn"]) {
  assert(!skills.some((skill) => skill.id === obsoleteId), `${obsoleteId} must not remain as a first-version fire skill card`);
}

console.log("[verify_first_version_fire_skill_card] PASS");
