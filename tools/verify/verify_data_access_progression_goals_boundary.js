const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const progression = readTextFile(path.join(root, "scripts", "game", "run_progression_service.gd"));
const saveManager = readTextFile(path.join(root, "scripts", "game", "save_manager.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const loadAllBody = functionBody(dataManager, "load_all");
const managerBody = functionBody(dataManager, "get_progression_goals");
const facadeBody = functionBody(gameData, "get_progression_goals", "static func ");

assert(
  dataManager.includes("const PROGRESSION_GOALS_PATH: String = DataPathsScript.PROGRESSION_GOALS_PATH"),
  "DataManager must register the canonical progression-goals path.",
);
assert(dataManager.includes("var _progression_goals: Dictionary = {}"), "DataManager must own one progression-goals document.");
assert(loadAllBody.includes("_progression_goals.clear()"), "DataManager reload must clear progression goals first.");
assert(
  loadAllBody.includes("_progression_goals = _load_json_document(PROGRESSION_GOALS_PATH)"),
  "DataManager must load the complete progression-goals document.",
);
assert(managerBody, "DataManager.get_progression_goals must exist.");
assert(
  managerBody.includes("return _progression_goals.duplicate(true)"),
  "DataManager must return a deeply isolated progression-goals document.",
);
assert(facadeBody, "GameData.get_progression_goals must exist.");
for (const marker of [
  "_get_data_manager()",
  'has_method("get_progression_goals")',
  'call("get_progression_goals")',
  "not goals_data.is_empty()",
  "return goals_data",
  "return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)",
]) {
  assert(facadeBody.includes(marker), `GameData progression-goals facade is missing: ${marker}`);
}
assert(
  facadeBody.indexOf('call("get_progression_goals")') <
    facadeBody.indexOf("return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)"),
  "GameData progression goals must keep manager-first ordering.",
);
for (const forbiddenSource of ["JsonDataLoader", "FileAccess", "JSON.new", "load_dictionary("]) {
  assert(!facadeBody.includes(forbiddenSource), `GameData progression goals must not add a third source: ${forbiddenSource}`);
}
assert(
  progression.includes("GameData.get_progression_goals()"),
  "RunProgressionService must continue through the GameData facade.",
);
assert(!progression.includes("DataManager"), "RunProgressionService must not depend directly on DataManager.");
assert(!saveManager.includes("DataManager"), "SaveManager must not depend directly on DataManager.");

console.log("[verify_data_access_progression_goals_boundary] PASS");
