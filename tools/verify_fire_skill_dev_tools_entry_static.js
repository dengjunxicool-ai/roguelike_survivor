const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const panel = read("scripts/debug/dev_debug_panel.gd");
const pool = read("scripts/upgrades/upgrade_pool.gd");
const skillManager = read("scripts/skills/skill_manager.gd");
const skillExecutor = read("scripts/skills/skill_executor.gd");
const dataManager = read("scripts/core/data_manager.gd");
const gameData = read("scripts/game/game_data.gd");
const smoke = read("tools/verify_fire_skill_dev_tools_entry.gd");
const skills = JSON.parse(read("data/skills.json"));

const fireSkills = skills.skills.filter(
  (skill) => skill.god_id === "fire" && skill.offer_in_upgrade_pool === true
);

assert(fireSkills.length > 0, "expected fire upgrade skills from data/skills.json");
assert(fireSkills[0].id === "mars_spark_missile", "mars_spark_missile must remain the first fire learnable skill");

assert(!panel.includes('_add_category_button(category_grid, "fire_skills", "Fire Skills")'), "DevDebugPanel must not expose Fire Skills as a standalone category");
assert(panel.includes("debug_run_god_skill_chain"), "DevDebugPanel must expose generalized god skill chain");
assert(panel.includes("GodSkillButtons"), "Skill Cards page must host god skill controls");
assert(panel.includes("func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:"), "DevDebugPanel must expose debug_run_fire_skill_chain");
assert(panel.includes("_grant_fire_skill_option"), "DevDebugPanel must grant selected fire skill");
assert(panel.includes("_spawn_fire_skill_debug_target"), "DevDebugPanel must spawn a debug target");
assert(panel.includes("_cast_fire_skill_once"), "DevDebugPanel must cast selected fire skill");
assert(panel.includes("_cast_player_skill_once"), "DevDebugPanel must cast one selected skill, not only all skills");
const fireCastBody = panel.slice(
  panel.indexOf("func _cast_fire_skill_once"),
  panel.indexOf("func _cast_player_skill_once")
);
const selectedCastBody = panel.slice(
  panel.indexOf("func _cast_player_skill_once"),
  panel.indexOf("func _wait_for_fire_skill_damage_record")
);
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
assert(pool.includes("_make_debug_learn_skill_upgrade"), "UpgradePool must synthesize learn-skill cards from skills.json");
assert(!pool.includes("mars_spark_missile_projectile"), "UpgradePool must not hardcode a single skill implementation");

assert(dataManager.includes('const SKILLS_PATH: String = "res://data/skills.json"'), "DataManager must know data/skills.json");
assert(dataManager.includes("STARTING_SKILLS_KEY"), "DataManager must index starting_skills");
assert(dataManager.includes("SKILLS_KEY"), "DataManager must index skills");
assert(gameData.includes("const SKILLS_PATH"), "GameData must know data/skills.json");
assert(skillManager.includes("offer_in_upgrade_pool"), "SkillManager must allow skills offered from the upgrade pool");
assert(skillExecutor.includes("func debug_cast_skill(skill_id: Variant, debug_attack_trace_id: int = 0) -> int:"), "SkillExecutor must expose selected skill debug casting");

assert(smoke.includes("debug_run_fire_skill_chain"), "Godot smoke must call debug_run_fire_skill_chain");
assert(smoke.includes("mars_spark_missile"), "Godot smoke must exercise mars_spark_missile as a fire skill");
assert(smoke.includes("damage_popup_count"), "Godot smoke must assert damage popup feedback");

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
