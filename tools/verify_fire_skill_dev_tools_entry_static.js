const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const text = read(relativePath).replace(/^\uFEFF/, "");
  return JSON.parse(text);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractGdFunctionBody(text, functionName) {
  const declarationPattern = new RegExp(`(^|\\n)func\\s+${escapeRegExp(functionName)}\\b[^\\n]*`);
  const match = declarationPattern.exec(text);
  assert(match != null, `DevDebugPanel must declare ${functionName}`);
  const start = match.index + match[1].length;
  const nextFunctionPattern = /\nfunc\s+/g;
  nextFunctionPattern.lastIndex = start + match[0].length - match[1].length;
  const nextMatch = nextFunctionPattern.exec(text);
  const end = nextMatch == null ? text.length : nextMatch.index;
  return text.slice(start, end);
}

const panel = read("scripts/debug/dev_debug_panel.gd");
const pool = read("scripts/upgrades/upgrade_pool.gd");
const skillManager = read("scripts/skills/skill_manager.gd");
const skillExecutor = read("scripts/skills/skill_executor.gd");
const dataManager = read("scripts/core/data_manager.gd");
const gameData = read("scripts/game/game_data.gd");
const smoke = read("tools/verify_fire_skill_dev_tools_entry.gd");
const skills = readJson("data/skills.json");
const skillDefinitions = Array.isArray(skills.skills) ? skills.skills : [];

const fireSkills = skillDefinitions.filter(
  (skill) => skill.god_id === "fire" && skill.offer_in_upgrade_pool === true
);

assert(fireSkills.length > 0, "expected fire upgrade skills from data/skills.json");
assert(fireSkills[0].id === "mars_spark_missile", "mars_spark_missile must remain the first fire learnable skill");

const standaloneFireSkillsCategoryPattern = /_add_category_button\s*\([^)]*"fire_skills"[^)]*"Fire Skills"[^)]*\)/;
assert(!standaloneFireSkillsCategoryPattern.test(panel), "DevDebugPanel must not expose Fire Skills as a standalone category");
assert(!panel.includes('"Runtime Skill Cards"'), "DevDebugPanel must not keep the old Runtime Skill Cards page title");
assert(!panel.includes('"Refresh Cards"'), "DevDebugPanel must not keep the old Refresh Cards button");
assert(!panel.includes('"Clear Skill Cards"'), "DevDebugPanel must not keep the old Clear Skill Cards button");
assert(!panel.includes('"Clear Chart"'), "DevDebugPanel must not keep the old Clear Chart button");
assert(!panel.includes('"Spawn Target"'), "DevDebugPanel must not expose Spawn Target as a Skill Cards button");
assert(!panel.includes('"Run Selected"'), "DevDebugPanel must not expose Run Selected as a Skill Cards button");
assert(!panel.includes('"Refresh Gods"'), "DevDebugPanel must not expose Refresh Gods as a Skill Cards button");
assert(!panel.includes("RuntimeUpgradeCards"), "DevDebugPanel must not keep old runtime upgrade card UI nodes");
assert(!panel.includes("RuntimeUpgradeComparisonChart"), "DevDebugPanel must not keep old runtime upgrade comparison chart");
assert(!/(^|\n)func\s+_run_selected_god_skill_chain\s*\(/.test(panel), "DevDebugPanel must not keep Run Selected button handler");
assert(/func\s+debug_run_god_skill_chain\s*\(/.test(panel), "DevDebugPanel must expose generalized god skill chain");
assert(/func\s+debug_select_god_skill_cards\s*\(/.test(panel), "DevDebugPanel must expose god skill card selection for smoke tests");
assert(/\.name\s*=\s*"GodSkillButtons"/.test(panel), "Skill Cards page must host god skill controls");
assert(panel.includes("func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:"), "DevDebugPanel must expose debug_run_fire_skill_chain");
assert(panel.includes('"button_ids"'), "DevDebugPanel god selection debug result must list god button ids");
assert(panel.includes('"button_tree_count"'), "DevDebugPanel god selection debug result must report buttons in the scene tree");
assert(panel.includes('"selected_button_pressed"'), "DevDebugPanel god selection debug result must report selected button state");
assert(panel.includes("_grant_fire_skill_option"), "DevDebugPanel must grant selected fire skill");
assert(panel.includes("_cast_fire_skill_once"), "DevDebugPanel must cast selected fire skill");
assert(panel.includes("_cast_player_skill_once"), "DevDebugPanel must cast one selected skill, not only all skills");
assert(/GodSkillCardsScroll[\s\S]*custom_minimum_size\s*=\s*Vector2\s*\(\s*440\s*,\s*(5[2-9]\d|[6-9]\d\d|\d{4,})\s*\)/.test(panel), "GodSkillCardsScroll must use the larger card display area");
const godSkillCardRunBody = extractGdFunctionBody(panel, "_run_god_skill_card");
assert(!godSkillCardRunBody.includes("_spawn_fire_skill_debug_target"), "God skill card selection must not spawn a debug target");
assert(!godSkillCardRunBody.includes("_prepare_fire_skill_debug_target"), "God skill card selection must not prepare a spawned target");
const fireCastBody = extractGdFunctionBody(panel, "_cast_fire_skill_once");
const selectedCastBody = extractGdFunctionBody(panel, "_cast_player_skill_once");
assert(
  /var\s+cast_count\s*:\s*int\s*=\s*_cast_player_skill_once\(skill_id,\s*trace_id\)/.test(fireCastBody),
  "DevDebugPanel fire skill chain must invoke selected-skill cast"
);
assert(
  !/var\s+cast_count\s*:\s*int\s*=\s*_cast_player_skills_once\(trace_id\)/.test(fireCastBody),
  "DevDebugPanel fire skill chain must not cast all skills for selected-skill debug"
);
assert(
  !/debug_cast_all_skills/.test(selectedCastBody),
  "DevDebugPanel selected-skill helper must not fall back to cast-all"
);
assert(panel.includes("damage_record_count"), "DevDebugPanel result must include damage_record_count");
assert(panel.includes("particle_count"), "DevDebugPanel result must include particle_count");
assert(panel.includes("damage_popup_count"), "DevDebugPanel result must include damage_popup_count");

assert(pool.includes("func generate_debug_fire_skill_options(player: Node, god_id: StringName = &\"fire\") -> Array:"), "UpgradePool must expose fire debug options");
assert(pool.includes("SKILLS_DATA_PATH"), "UpgradePool must read skills.json for debug fire skills");
assert(pool.includes("_make_god_skill_learn_upgrade"), "UpgradePool must synthesize learn-skill cards from skills.json");
assert(!pool.includes("mars_spark_missile_projectile"), "UpgradePool must not hardcode a single skill implementation");

assert(dataManager.includes('const SKILLS_PATH: String = "res://data/skills.json"'), "DataManager must know data/skills.json");
assert(dataManager.includes("STARTING_SKILLS_KEY"), "DataManager must index starting_skills");
assert(dataManager.includes("SKILLS_KEY"), "DataManager must index skills");
assert(gameData.includes("const SKILLS_PATH"), "GameData must know data/skills.json");
assert(skillManager.includes("offer_in_upgrade_pool"), "SkillManager must allow skills offered from the upgrade pool");
assert(skillExecutor.includes("func debug_cast_skill(skill_id: Variant, debug_attack_trace_id: int = 0) -> int:"), "SkillExecutor must expose selected skill debug casting");

assert(smoke.includes("debug_run_fire_skill_chain"), "Godot smoke must call debug_run_fire_skill_chain");
assert(smoke.includes("debug_select_god_skill_cards"), "Godot smoke must exercise god skill card selection");
assert(smoke.includes("EXPECTED_GOD_IDS"), "Godot smoke must enumerate all six god buttons");
assert(smoke.includes("button_tree_count"), "Godot smoke must assert god buttons are in the scene tree");
assert(smoke.includes("selected_button_pressed"), "Godot smoke must assert selected god button state");
assert(smoke.includes("GodSkillCard_mars_spark_missile"), "Godot smoke must inspect the first fire skill card");
assert(smoke.includes("mars_spark_missile"), "Godot smoke must exercise mars_spark_missile as a fire skill");
assert(smoke.includes("enemy_count_after"), "Godot smoke must assert selecting a skill does not spawn enemies");

const fireEffectPaths = [
  "scripts/effects/fire_tornado_effect.gd",
  "scenes/effects/fire_tornado_effect.tscn",
  "scripts/effects/mars_spark_missile_effect.gd",
  "scenes/effects/mars_spark_missile_effect.tscn",
];
for (const relativePath of fireEffectPaths) {
  const text = read(relativePath);
  assert(!text.includes("CPUParticles2D"), `${relativePath} must not use CPUParticles2D`);
}
assert(!panel.includes("CPUParticles2D"), "DevDebugPanel must not reference CPUParticles2D for fire/debug effects");

console.log("[verify_fire_skill_dev_tools_entry_static] PASS");
