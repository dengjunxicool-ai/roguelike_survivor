const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

const configPath = path.join(root, "data", "skill_system_config.json");
assert(fs.existsSync(configPath), "data/skill_system_config.json must exist");
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
assert(typeof config.range_unit_px === "number" && config.range_unit_px > 0, "skill_system_config.range_unit_px must be a positive number");
assert(config.range_unit_px === 84, "default range_unit_px must remain 84");

const rangeUnitPath = path.join(root, "scripts", "skills", "skill_range_unit.gd");
assert(fs.existsSync(rangeUnitPath), "scripts/skills/skill_range_unit.gd must exist");
const rangeUnitSource = read("scripts/skills/skill_range_unit.gd");
for (const token of ["range_unit_px", "resolve_action_params", "radius_r", "length_r", "width_r", "range_r", "pull_radius_r"]) {
  assert(rangeUnitSource.includes(token), `SkillRangeUnit must support ${token}`);
}

const executor = read("scripts/skills/skill_action_executor.gd");
assert(executor.includes("SkillRangeUnitScript"), "SkillActionExecutor must preload SkillRangeUnit");
assert(executor.includes("resolve_action_params"), "SkillActionExecutor must resolve *_r fields before execution");

const summary = read("scripts/skills/skill_effect_summary_builder.gd");
assert(summary.includes("SkillRangeUnitScript"), "skill card summary must use SkillRangeUnit");

const skills = JSON.parse(read("data/skills.json"));
const thunderSkills = (skills.skills || []).filter((skill) => skill.school === "thunder" && (skill.fusion_school === null || skill.fusion_school === undefined));
assert(thunderSkills.length === 14, "thunder skills must exist before range-unit validation");

const serializedThunder = JSON.stringify(thunderSkills);
for (const key of ["radius_r", "range_r", "pull_radius_r"]) {
  assert(serializedThunder.includes(key), `thunder data should use configurable ${key} where ranges come from R`);
}

console.log("[verify_skill_range_unit_contract] PASS");
