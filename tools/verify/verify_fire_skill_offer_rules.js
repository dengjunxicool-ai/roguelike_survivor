const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const service = read("scripts/skills/skill_offer_service.gd");
const pool = read("scripts/upgrades/upgrade_pool.gd");
const gameData = read("scripts/game/game_data.gd");
const repository = read("scripts/upgrades/skill_learn_definition_repository.gd");
const learningPolicy = read("scripts/skills/skill_learning_policy.gd");
const slotPolicy = read("scripts/skills/skill_slot_policy.gd");
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
assert(repository.includes("offer_rule"), "GameData synthetic learn upgrades must accept offer_rule skills");
assert(repository.includes('skill.get("school"') && repository.includes('skill.get("fusion_school"'), "Learn repository identifies both explicit schools");
assert(skillManager.includes("_category_from_skill_type"), "SkillManager must map new skill type values to learnable categories");
assert(slotPolicy.includes('definition.get("slot_category"'), "SkillManager slot policy reads explicit slot category");
assert(learningPolicy.includes('skill_data.get("offer_rule"'), "SkillManager must allow offer_rule skills to be learned from the pool");
assert(skillManager.includes("_apply_skill_effect_payload"), "SkillManager must adapt top-level skill effects into runtime modifiers when learning skills");
assert(skillManager.includes("set_run_modifier_source"), "SkillManager learned skill effects must enter the player's runtime modifier store");
assert(skillManager.includes("_clear_skill_effect_modifier_sources"), "SkillManager must clear learned-skill runtime modifier sources when skills are reset");
assert(skillManager.includes('source.get("stat"') && skillManager.includes('source["value"] = _scale_modifier_value'), "SkillManager scales explicit modifier stat/value records");
const skills = require("../../data/skills/skills.json").skills;
const burning = skills.find(skill => skill.id === "fire_passive_burning_focus");
assert(burning.effects.some(effect => effect.stat === "dot_damage" && effect.op === "multiplier_add" && effect.value === 0.25), "Burning focus preserves +25% DOT damage");
assert(burning.effects.some(effect => effect.stat === "status_duration" && effect.op === "multiplier_add" && effect.value === 0.20), "Burning focus preserves +20% status duration");
assert(service.includes("func _string_or"), "SkillOfferService must use a null-safe string helper");
assert(service.includes('_string_or(skill.get("exclusive_group"'), "SkillOfferService must tolerate null exclusive_group values");
assert(service.includes('_string_or(skill_instance.get("fusion_school")'), "SkillOfferService must tolerate null fusion_school values");

console.log("[verify_fire_skill_offer_rules] PASS");
