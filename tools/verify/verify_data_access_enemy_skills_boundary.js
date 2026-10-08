const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const repository = readTextFile(path.join(root, "scripts", "enemies", "skills", "enemy_skill_repository.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const loader = functionBody(repository, "_load_skill_data");
assert(loader, "EnemySkillRepository._load_skill_data must remain available.");
assert(
  repository.includes('preload("res://scripts/game/game_data.gd")'),
  "EnemySkillRepository must preload GameData explicitly.",
);
assert(
  loader.includes("return GameDataScript.get_enemy_skill_pool()"),
  "EnemySkillRepository must delegate pool loading to GameData.",
);

for (const forbidden of [
  "DataPathsScript",
  "JsonDataLoaderScript",
  "ENEMY_SKILLS_PATH",
  "get_enemy_skill_definitions",
  "_get_data_manager",
  "_to_dictionary_array",
]) {
  assert(!repository.includes(forbidden), `EnemySkillRepository retains forbidden data dependency: ${forbidden}`);
}

for (const contract of [
  "func get_skill(skill_id: Variant) -> RefCounted:",
  "func get_all_skills() -> Array[RefCounted]:",
  "func _ensure_loaded() -> void:",
]) {
  assert(repository.includes(contract), `EnemySkillRepository contract missing: ${contract}`);
}

console.log("[verify_data_access_enemy_skills_boundary] PASS");
