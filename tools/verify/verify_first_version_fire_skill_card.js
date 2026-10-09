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

const skills = readJson("data/skills/skills.json").skills || [];
const firstSkill = findById(skills, "fire_attack_searing", "fire skill");
assert(firstSkill.school === "fire", "fire_attack_searing must be a fire school skill");
assert(firstSkill.skill_type === "attack", "fire_attack_searing must use the new attack type");
assert(firstSkill.exclusive_group === "attack_school", "fire_attack_searing must occupy attack_school");
assert(firstSkill.offer_rule && firstSkill.offer_rule.required_schools?.includes("fire"), "fire_attack_searing must require fire school access");
assert((firstSkill.trigger_rules || []).some((rule) => rule.trigger === "attack_hit"), "fire_attack_searing must react to attack_hit");
assert((firstSkill.effects || []).some((effect) => effect.type === "add_modifier"), "fire_attack_searing must carry its passive attack modifier");

const fireEffectDescriptions = {
  fire_attack_searing: "攻击变强，命中施加 Burning 效果，并有概率在目标脚下生成火焰区域",
  fire_dash_blazing_run: "冲刺会伤害路径上的敌人，并留下一条火焰路径，使经过敌人 Burning",
  fire_cast_meteor_rain: "天空周期性落下陨石，造成范围伤害，并在落点留下燃烧地面",
  fire_cast_lava_rift: "从最近敌人脚下生成一条向外蔓延的熔岩裂缝，造成线形伤害",
  fire_cast_scorching_vortex: "向敌人移动的焚风旋涡，持续伤害并施加燃烧。",
  fire_summon_crimson_dragon: "红龙与你并肩作战，周期性向怪群喷吐龙息，施加 Burning",
  fire_summon_ember_fox_pack: "每当你施加一定次数 Burning，召唤火狐冲向敌人，命中后爆成小火花",
  fire_passive_burning_focus: "Burning 持续时间和伤害提高",
  fire_passive_overheated_casting: "受到伤害或生命首次跌破35%时，cast伤害提高30%、范围提高15%，持续5秒；两个入口共享12秒冷却。",
  fire_passive_scorched_ground_affinity: "仅真实火焰地面中的目标承受更高燃烧伤害。",
  fire_power_combustion_chain: "累计12点燃烧资源引爆2.4P、R2.2；爆炸击杀有25%概率继续引爆，最多2次派生，每次伤害为前次60%；精英/Boss每5次有效燃烧跳伤+1点。",
  fire_power_ember_attachment: "Burning 敌人死亡后留下余烬，余烬会自动飞向附近敌人并点燃目标",
  fire_power_ignite_core: "施法命中燃烧目标时消耗1秒燃烧并造成额外伤害；攻击和召唤命中不触发。",
  fire_core_inferno_cycle: "Burning 敌人死亡必定生成一次小型火焰爆裂；爆裂命中敌人会重新施加 Burning。每触发若干次爆裂，额外召唤一次流星火雨 精英与Boss：每5次有效燃烧跳伤+1点。",
};

for (const [skillId, expectedDescription] of Object.entries(fireEffectDescriptions)) {
  const skill = findById(skills, skillId, "fire skill");
  assert(skill.description === expectedDescription, `${skillId} must expose its fire god skill description`);
  assert(!Object.prototype.hasOwnProperty.call(skill, "effect_description"), `${skillId} must use description instead of effect_description`);
}

const fusion = findById(skills, "fusion_fire_frost_steam_mist", "fire fusion skill");
assert(fusion.skill_type === "fusion", "fusion_fire_frost_steam_mist must use fusion type");
assert(fusion.offer_rule?.required_min_skill_count?.fire >= 2, "fire-led fusions must require at least two fire skills");
assert(fusion.offer_rule?.required_min_skill_count?.frost >= 1, "fire+frost fusion must require frost access");

for (const obsoleteId of ["mars_spark_missile", "fire_tornado", "soulburn"]) {
  assert(!skills.some((skill) => skill.id === obsoleteId), `${obsoleteId} must not remain as a first-version fire skill card`);
}

console.log("[verify_first_version_fire_skill_card] PASS");
