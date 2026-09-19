const fs = require("fs");
const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function bodyOf(source, functionName) {
  const marker = `func ${functionName}`;
  const start = source.indexOf(marker);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next < 0 ? source.length : next);
}

const skillsDocument = readJsonFile(path.join(root, "data", "skills", "skills.json"));
const upgradePool = read("scripts/upgrades/upgrade_pool.gd");
const skillLearnOptionBuilder = read("scripts/upgrades/skill_learn_option_builder.gd");
const skillManager = read("scripts/skills/skill_manager.gd");
const gameData = read("scripts/game/game_data.gd");
const offerService = read("scripts/skills/skill_offer_service.gd");

const fireSkills = (skillsDocument.skills || []).filter(
  (skill) => skill && (skill.school === "fire" || skill.fusion_school === "fire" || (skill.tags || []).includes("fire"))
);

assert(fireSkills.length === 34, `expected 34 first-version fire-related skills, got ${fireSkills.length}`);
assert(fireSkills.some((skill) => skill.id === "fire_attack_searing"), "fire skill pool must include fire_attack_searing");
assert(fireSkills.some((skill) => skill.id === "fusion_fire_frost_steam_mist"), "fire skill pool must include fire fusion skills");
assert(!fireSkills.some((skill) => skill.id === "mars_spark_missile"), "old mars_spark_missile card must not remain in skills.json");

for (const skill of fireSkills) {
  assert(typeof skill.id === "string" && skill.id.trim() !== "", "fire skill source must have an id");
  assert(typeof skill.type === "string" && skill.type.trim() !== "", `${skill.id} must use the new type field`);
  assert(skill.offer_rule && typeof skill.offer_rule === "object", `${skill.id} must define offer_rule`);
}

const growthBody = bodyOf(upgradePool, "_select_growth_stage_options");
const formalBuilderBody = bodyOf(upgradePool, "_build_god_skill_learn_options");
const definitionBody = bodyOf(upgradePool, "_get_skill_learn_definitions");

assert(formalBuilderBody, "UpgradePool must define a learn option builder");
assert(growthBody.includes("_build_god_skill_learn_options(player)"), "generate_options growth stage must include god skill learn cards");
assert(definitionBody.includes("GameData.get_skill_pool()"), "learn options must read the unified skill pool");
assert(definitionBody.includes("offer_rule"), "learn options must include new offer_rule skills");
assert(formalBuilderBody.includes("is_skill_available"), "learn options must ask SkillOfferService before offering cards");
assert(!formalBuilderBody.includes("mars_spark_missile_projectile"), "formal learn options must not hardcode a single old skill implementation");
assert(formalBuilderBody.includes("SkillLearnOptionBuilderScript.build_option_data"), "learn options must delegate card data to SkillLearnOptionBuilder");
assert(skillLearnOptionBuilder.includes('"id": "level_up_upgrade:%s:%s"'), "learn cards must use level_up_upgrade option ids with rarity suffix");
assert(skillLearnOptionBuilder.includes('"learn_skill_id"'), "learn card payload must carry learn_skill_id");
assert(upgradePool.includes("func _build_fire_skill_learn_options"), "UpgradePool must keep fire debug learn option compatibility");

for (const token of ["required_schools", "required_min_skill_count", "blocked_by_exclusive_group", "fusion"]) {
  assert(offerService.includes(token), `SkillOfferService must enforce ${token}`);
}

assert(gameData.includes("SKILL_LEARN_UPGRADE_PREFIX"), "GameData must synthesize generic god skill learn upgrades");
assert(gameData.includes("_is_fire_related_skill"), "GameData must keep legacy fire learn upgrade compatibility");
assert(gameData.includes("offer_rule"), "GameData synthetic learn upgrades must accept offer_rule skills");
assert(skillManager.includes("_category_from_skill_type"), "SkillManager must map new type values to active/passive buckets");
assert(skillManager.includes('skill_data.get("offer_rule"'), "SkillManager must treat offer_rule skills as pool-learnable");

console.log("[verify_fire_skill_upgrade_pool] PASS");
