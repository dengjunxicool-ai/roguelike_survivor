const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const manager = readTextFile(path.join(root, "scripts", "skills", "synergy_manager.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const facade = functionBody(gameData, "get_synergy_pool", "static func ");
assert(facade, "GameData.get_synergy_pool must exist.");
assert(
  facade.includes('_get_pool_from_data_manager("get_synergy_definitions")'),
  "GameData synergy pool must prefer the DataManager owner accessor.",
);
assert(
  facade.includes('_get_dictionary_array(SYNERGIES_PATH, "synergies").duplicate(true)'),
  "GameData synergy pool must keep an isolated JSON fallback.",
);

const loader = functionBody(manager, "_load_synergy_definitions");
assert(loader, "SynergyManager._load_synergy_definitions must remain available.");
assert(
  manager.includes('preload("res://scripts/game/game_data.gd")'),
  "SynergyManager must preload GameData explicitly.",
);
assert(
  loader.includes("_index_synergy_definitions(GameDataScript.get_synergy_pool())"),
  "SynergyManager must index definitions supplied by GameData.",
);

for (const forbidden of [
  "DataPathsScript",
  "JsonDataLoaderScript",
  "SYNERGY_DATA_PATH",
  'get_node_or_null("/root/DataManager")',
  "get_synergy_definitions",
  "_load_synergies_from_file",
]) {
  assert(!manager.includes(forbidden), `SynergyManager retains forbidden data dependency: ${forbidden}`);
}

assert(
  manager.includes("func _index_synergy_definitions(synergies: Array) -> void:"),
  "SynergyManager must preserve its definition indexing contract.",
);

console.log("[verify_data_access_synergies_boundary] PASS");
