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

const executor = read("scripts/skills/skill_action_executor.gd");
for (const action of [
  "grant_shield",
  "pull",
  "repeat_skill",
  "transform_area",
  "transfer_status",
  "consume_status_duration",
  "trigger_overload",
  "shatter_frozen",
  "spawn_projectile_burst",
  "repeat_area_path",
  "spawn_area_from_existing_area",
]) {
  assert(executor.includes(`"${action}"`), `SkillActionExecutor must support ${action}`);
}

assert(executor.includes("_resolve_scaled_amount"), "SkillActionExecutor must resolve scaled power damage");
assert(executor.includes('"stat"') && executor.includes('"power"') && executor.includes('"scale"'), "SkillActionExecutor must understand power scale dictionaries");
assert(!/func\s+_add_temporary_modifier\s*\([^)]*\)\s*->\s*bool:\s*\r?\n\s*return\s+false/.test(executor), "SkillActionExecutor add_temporary_modifier must not remain a no-op");
assert(executor.includes("_build_modifier_from_params"), "SkillActionExecutor must translate add_modifier params into runtime modifiers");

console.log("[verify_fire_effect_action_support] PASS");
