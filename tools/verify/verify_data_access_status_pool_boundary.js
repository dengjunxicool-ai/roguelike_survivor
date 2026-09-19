const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const managerBody = functionBody(dataManager, "get_status_definitions");
const facadeBody = functionBody(gameData, "get_status_pool", "static func ");

assert(managerBody, "DataManager.get_status_definitions must exist.");
assert(
  managerBody.includes("return _get_definition_values(_status_definitions)"),
  "DataManager status pool must use the indexed status store and the existing copy helper.",
);
assert(facadeBody, "GameData.get_status_pool must exist.");
assert(
  facadeBody.includes('_get_pool_from_data_manager("get_status_definitions")'),
  "GameData status pool must query DataManager first.",
);
assert(
  facadeBody.includes('return _get_dictionary_array(STATUS_EFFECTS_PATH, "statuses")'),
  "GameData status pool must retain the JSON compatibility fallback.",
);
for (const forbiddenSource of ["JsonDataLoader", "FileAccess", "JSON.new", "load_dictionary("]) {
  assert(!facadeBody.includes(forbiddenSource), `GameData status pool must not add a third source: ${forbiddenSource}`);
}
assert(
  facadeBody.indexOf('_get_pool_from_data_manager("get_status_definitions")') <
    facadeBody.indexOf('return _get_dictionary_array(STATUS_EFFECTS_PATH, "statuses")'),
  "GameData status pool must keep manager-first ordering.",
);

console.log("[verify_data_access_status_pool_boundary] PASS");
