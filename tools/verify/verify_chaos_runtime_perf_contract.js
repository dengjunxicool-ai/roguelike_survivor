const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name) {
  const start = source.indexOf(`func ${name}`);
  assert(start >= 0, `missing function ${name}`);
  const next = source.indexOf("\nfunc ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

function findSkill(skills, id) {
  const skill = skills.find((entry) => entry && entry.id === id);
  assert(skill, `missing skill ${id}`);
  return skill;
}

function allEffects(skill) {
  return (skill.trigger_rules || []).flatMap((rule) => rule.effects || []);
}

const skills = readJsonFile(path.join(root, "data", "skills", "skills.json")).skills || [];
const chaosAttack = findSkill(skills, "chaos_attack_chaotic");
const chaosAttackEffects = allEffects(chaosAttack);
assert(
  !chaosAttackEffects.some((effect) => effect.type === "spawn_area" && effect.area_id === "chaos_weak_hit"),
  "chaos_attack_chaotic must not create a 0.12s AreaEffect for chaos_weak_hit."
);
assert(
  chaosAttackEffects.some((effect) => effect.type === "instant_area_hit" && effect.area_id === "chaos_weak_hit"),
  "chaos_attack_chaotic must use instant_area_hit for chaos_weak_hit."
);

const adapter = read("scripts/skills/skill_effect_adapter.gd");
assert(adapter.includes('"instant_area_hit"'), "SkillEffectAdapter must adapt instant_area_hit effects.");

const executor = read("scripts/skills/skill_action_executor.gd");
assert(executor.includes('"instant_area_hit"'), "SkillActionExecutor must dispatch instant_area_hit.");
assert(executor.includes("func _instant_area_hit"), "SkillActionExecutor must implement instant area hit execution.");
assert(
  executor.includes("_play_instant_area_hit_visual") &&
    executor.includes("RuntimePoolRegistryScript") &&
    executor.includes("InstantAreaHitVisualScript"),
  "instant_area_hit must use a pooled lightweight visual instead of rebuilding AreaEffect nodes."
);
assert(
  !functionBody(executor, "_instant_area_hit").includes("CombatObjectFactoryScript.create_area_effect"),
  "instant_area_hit must not call CombatObjectFactory.create_area_effect."
);

const visual = read("scripts/combat/instant_area_hit_visual.gd");
assert(visual.includes("despawn_or_free"), "InstantAreaHitVisual must return to the runtime pool after its short visual lifetime.");

console.log("[verify_chaos_runtime_perf_contract] PASS");
