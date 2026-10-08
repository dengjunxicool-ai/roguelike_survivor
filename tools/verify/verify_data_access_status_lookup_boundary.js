const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const statusManager = readTextFile(path.join(root, "scripts", "combat", "status_effect_manager.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const facade = functionBody(gameData, "get_status", "static func ");
assert(facade, "GameData.get_status must exist.");
assert(
  facade.includes('_get_definition_from_data_manager("get_status_definition", status_id)'),
  "GameData status lookup must prefer the DataManager owner accessor.",
);
assert(
  facade.includes('_find_by_id(_get_array(STATUS_EFFECTS_PATH, "statuses"), status_id).duplicate(true)'),
  "GameData status lookup must keep an isolated JSON fallback.",
);

const lookup = functionBody(statusManager, "_get_status_definition");
assert(lookup, "StatusEffectManager._get_status_definition must remain available.");
assert(
  lookup.includes("var status_data: Dictionary = GameData.get_status(status_id)"),
  "StatusEffectManager cache misses must delegate to GameData.",
);
assert(
  lookup.includes("_status_definition_cache.has(cache_key)"),
  "StatusEffectManager must preserve its definition cache hit path.",
);
for (const forbidden of [
  "DataPathsScript",
  'get_node_or_null("/root/DataManager")',
  "GameData._load_document",
  "_get_status_definition_from_game_data",
]) {
  assert(!statusManager.includes(forbidden), `StatusEffectManager retains forbidden data dependency: ${forbidden}`);
}

console.log("[verify_data_access_status_lookup_boundary] PASS");
