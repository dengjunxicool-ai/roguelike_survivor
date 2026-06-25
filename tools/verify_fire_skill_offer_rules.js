const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const service = read("scripts/skills/skill_offer_service.gd");
const pool = read("scripts/upgrades/upgrade_pool.gd");
const gameData = read("scripts/game/game_data.gd");
const skillManager = read("scripts/skills/skill_manager.gd");

for (const token of [
  "required_schools",
  "required_min_skill_count",
  "blocked_by_exclusive_group",
  "exclusive_group",
  "fusion",
  "attack_school",
  "dash_school",
  "core_school",
]) {
  assert(service.includes(token), `SkillOfferService must handle ${token}`);
}

assert(pool.includes("SkillOfferServiceScript"), "UpgradePool must preload SkillOfferService");
assert(pool.includes("_skill_offer_service"), "UpgradePool must own SkillOfferService");
assert(pool.includes("is_skill_available"), "UpgradePool must ask SkillOfferService before offering learn cards");
assert(gameData.includes("offer_rule"), "GameData synthetic learn upgrades must accept offer_rule skills");
assert(gameData.includes("_is_fire_related_skill"), "GameData must identify fire-related synthetic learn skills without legacy god_id");
assert(skillManager.includes("_category_from_skill_type"), "SkillManager must map new skill type values to learnable categories");
assert(skillManager.includes('data.get("type"'), "SkillManager must inspect the new skill type field when learning skills");
assert(skillManager.includes('skill_data.get("offer_rule"'), "SkillManager must allow offer_rule skills to be learned from the pool");
assert(service.includes("func _string_or"), "SkillOfferService must use a null-safe string helper");
assert(service.includes('_string_or(skill.get("exclusive_group"'), "SkillOfferService must tolerate null exclusive_group values");
assert(service.includes('_string_or(skill_instance.get("fusion_school")'), "SkillOfferService must tolerate null fusion_school values");

console.log("[verify_fire_skill_offer_rules] PASS");
