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
const dailyManagerBody = functionBody(dataManager, "get_daily_challenge_definitions");
const weeklyManagerBody = functionBody(dataManager, "get_weekly_challenge_definitions");
const dailyFacadeBody = functionBody(gameData, "get_daily_challenge_pool", "static func ");
const weeklyFacadeBody = functionBody(gameData, "get_weekly_challenge_pool", "static func ");

assert(
  dataManager.includes("const CHALLENGES_PATH: String = DataPathsScript.CHALLENGES_PATH"),
  "DataManager must register the canonical challenge path.",
);
assert(dataManager.includes('const DAILY_CHALLENGES_KEY: String = "daily_challenges"'), "Daily key must stay canonical.");
assert(dataManager.includes('const WEEKLY_CHALLENGES_KEY: String = "weekly_challenges"'), "Weekly key must stay canonical.");
assert(dataManager.includes("var _daily_challenge_definitions: Array[Dictionary] = []"), "DataManager must own the daily pool.");
assert(dataManager.includes("var _weekly_challenge_definitions: Array[Dictionary] = []"), "DataManager must own the weekly pool.");
assert(loadAllBody.includes("_daily_challenge_definitions.clear()"), "Reload must clear the daily pool.");
assert(loadAllBody.includes("_weekly_challenge_definitions.clear()"), "Reload must clear the weekly pool.");
const challengeLoads = loadAllBody.match(/_load_json_document\(CHALLENGES_PATH\)/g) || [];
assert(challengeLoads.length === 1, "DataManager must load the challenge document exactly once.");
assert(
  loadAllBody.includes("_daily_challenge_definitions = _get_dictionary_array(challenges_document, DAILY_CHALLENGES_KEY, CHALLENGES_PATH)"),
  "DataManager must extract the ordered daily pool.",
);
assert(
  loadAllBody.includes("_weekly_challenge_definitions = _get_dictionary_array(challenges_document, WEEKLY_CHALLENGES_KEY, CHALLENGES_PATH)"),
  "DataManager must extract the ordered weekly pool.",
);
assert(
  dailyManagerBody.includes("return _daily_challenge_definitions.duplicate(true)"),
  "Daily manager accessor must deeply isolate its pool.",
);
assert(
  weeklyManagerBody.includes("return _weekly_challenge_definitions.duplicate(true)"),
  "Weekly manager accessor must deeply isolate its pool.",
);

function verifyFacade(body, managerMethod, key, label) {
  assert(body, `GameData ${label} facade must exist.`);
  for (const marker of [
    `_get_pool_from_data_manager("${managerMethod}")`,
    "if not data.is_empty()",
    "return data",
    `return _get_dictionary_array(CHALLENGES_PATH, "${key}").duplicate(true)`,
  ]) {
    assert(body.includes(marker), `GameData ${label} facade is missing: ${marker}`);
  }
  assert(
    body.indexOf(`_get_pool_from_data_manager("${managerMethod}")`) <
      body.indexOf(`return _get_dictionary_array(CHALLENGES_PATH, "${key}").duplicate(true)`),
    `GameData ${label} facade must keep manager-first ordering.`,
  );
  for (const forbiddenSource of ["JsonDataLoader", "FileAccess", "JSON.new", "load_dictionary("]) {
    assert(!body.includes(forbiddenSource), `GameData ${label} facade must not add a third source: ${forbiddenSource}`);
  }
}

verifyFacade(dailyFacadeBody, "get_daily_challenge_definitions", "daily_challenges", "daily challenge");
verifyFacade(weeklyFacadeBody, "get_weekly_challenge_definitions", "weekly_challenges", "weekly challenge");
assert(progression.includes("GameData.get_daily_challenge_pool()"), "Progression must keep the daily GameData facade.");
assert(progression.includes("GameData.get_weekly_challenge_pool()"), "Progression must keep the weekly GameData facade.");
assert(!progression.includes("DataManager"), "RunProgressionService must not depend directly on DataManager.");
assert(!saveManager.includes("DataManager"), "SaveManager must not depend directly on DataManager.");

console.log("[verify_data_access_challenge_pools_boundary] PASS");
