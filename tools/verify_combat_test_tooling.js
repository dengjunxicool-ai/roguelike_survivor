const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertScript(scripts, name, expectedSnippet) {
  assert(Object.prototype.hasOwnProperty.call(scripts, name), `Missing npm script ${name}`);
  assert(String(scripts[name]).includes(expectedSnippet), `npm script ${name} must include ${expectedSnippet}`);
}

const packageJson = readJson("package.json");
const scripts = packageJson.scripts || {};

assertScript(scripts, "validate:combat", "tools\\validate_weapon_authoring_pipeline.js");
assertScript(scripts, "test:combat:smoke", "tools\\run_full_weapon_branch_matrix_runtime.js smoke");
assertScript(scripts, "test:combat:rules", "tools\\run_full_weapon_branch_matrix_runtime.js rules");
assertScript(scripts, "report:combat:spotlights", "tools\\generate_combat_scene_spotlight_report.js");

const runnerSource = read("tools/run_full_weapon_branch_matrix_runtime.js");
assert(runnerSource.includes("full_weapon_branch_matrix_smoke_console.log"), "runtime wrapper must write smoke console log");
assert(runnerSource.includes("full_weapon_branch_matrix_rules_console.log"), "runtime wrapper must write rules console log");
assert(runnerSource.includes("GODOT_BIN"), "runtime wrapper must allow GODOT_BIN override");

const godotRunnerSource = read("scripts/debug/full_weapon_branch_matrix_check.gd");
assert(godotRunnerSource.includes("full_weapon_branch_matrix_%s.json"), "Godot runner must write mode-specific JSON report");
assert(godotRunnerSource.includes("full_weapon_branch_matrix_%s.txt"), "Godot runner must write mode-specific text report");

const spotlightSource = read("tools/generate_combat_scene_spotlight_report.js");
assert(spotlightSource.includes("full_weapon_branch_matrix_smoke.json"), "spotlight report must read smoke report");
assert(spotlightSource.includes("full_weapon_branch_matrix_rules.json"), "spotlight report must read rules report");
assert(spotlightSource.includes("combat_scene_spotlights.md"), "spotlight report must write markdown output");
assert(spotlightSource.includes("mage__fire_staff__fire_staff_branch_burst__lv2"), "spotlight report must include fire staff burst Lv2 scene");

console.log("Combat test tooling verified.");
