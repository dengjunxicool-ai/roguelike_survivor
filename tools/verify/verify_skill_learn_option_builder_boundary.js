const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const pool = readTextFile(path.join(root, "scripts", "upgrades", "upgrade_pool.gd"));
const builder = readTextFile(path.join(root, "scripts", "upgrades", "skill_learn_option_builder.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const body = functionBody(pool, "_build_god_skill_learn_options");
const builderBody = functionBody(builder, "build_option_data", "static func ");

assert(builderBody, "SkillLearnOptionBuilder.build_option_data must exist.");
assert(
  pool.includes('const SkillLearnOptionBuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")'),
  "UpgradePool must preload SkillLearnOptionBuilder.",
);
assert(body, "UpgradePool must keep _build_god_skill_learn_options.");
for (const marker of [
  "_is_learn_skill_upgrade_available(player, skill_id)",
  '_skill_offer_service.call("is_skill_available", player, skill)',
  "_make_god_skill_learn_upgrade(skill, _get_skill_god_id(skill))",
  "SkillGrowthScalingScript.pick_rarity_for_max_level(max_level, _rng)",
]) {
  assert(body.includes(marker), `_build_god_skill_learn_options must retain runtime decision: ${marker}`);
}
assert(body.includes("SkillLearnOptionBuilderScript.build_option_data(skill, upgrade, rarity)"), "UpgradePool must delegate learn-card data construction.");
assert(body.includes("option_data.is_empty()"), "UpgradePool must skip an invalid empty Builder result.");
assert(body.includes("_make_option(option_data)"), "UpgradePool must retain final UpgradeOption construction.");

const eligibilityIndex = body.indexOf("_is_learn_skill_upgrade_available(player, skill_id)");
const serviceIndex = body.indexOf('_skill_offer_service.call("is_skill_available", player, skill)');
const rarityIndex = body.indexOf("SkillGrowthScalingScript.pick_rarity_for_max_level(max_level, _rng)");
const builderIndex = body.indexOf("SkillLearnOptionBuilderScript.build_option_data(skill, upgrade, rarity)");
assert(eligibilityIndex < serviceIndex && serviceIndex < rarityIndex && rarityIndex < builderIndex, "Eligibility and rarity selection must remain ordered before Builder delegation.");

for (const movedMarker of ['"affected_origin": "神系技能"', '"learn_skill_id": skill_id', '"level_text": "Lv1 / %d"']) {
  assert(!body.includes(movedMarker), `UpgradePool must not retain moved data marker: ${movedMarker}`);
  assert(builderBody.includes(movedMarker), `Builder must own moved data marker: ${movedMarker}`);
}

for (const retainedMethod of [
  "_build_fire_skill_learn_options",
  "_fill_from_weighted_pool",
  "_enforce_guaranteed_options",
  "_enforce_god_skill_learn_option",
  "_enforce_ordinary_active_learn_option",
  "_make_debug_god_skill_option",
  "_make_option",
]) {
  assert(functionBody(pool, retainedMethod), `UpgradePool must retain ${retainedMethod}.`);
}

for (const forbiddenDependency of ["GameData", "SkillOfferService", "UpgradeOfferPolicy", "SkillGrowthScaling", "UpgradeSelectionHelper", "UpgradeOption", "get_tree(", "print(", "push_error("]) {
  assert(!builder.includes(forbiddenDependency), `Builder must not depend on ${forbiddenDependency}.`);
}

console.log("[verify_skill_learn_option_builder_boundary] PASS");
