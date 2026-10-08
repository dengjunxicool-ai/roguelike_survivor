const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const relicManager = readTextFile(path.join(root, "scripts", "relics", "relic_manager.gd"));
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const pool = functionBody(gameData, "get_relic_pool", "static func ");
for (const marker of [
  '_get_pool_from_data_manager("get_relic_definitions")',
  "if not data.is_empty()",
  "return data",
  '_get_dictionary_array(RELICS_PATH, "relics").duplicate(true)',
]) assert(pool.includes(marker), `relic pool facade missing ${marker}`);

const lookup = functionBody(gameData, "get_relic", "static func ");
for (const marker of [
  '_get_definition_from_data_manager("get_relic_definition", relic_id)',
  "if not data.is_empty()",
  "return data",
  '_find_by_id(_get_array(RELICS_PATH, "relics"), relic_id).duplicate(true)',
]) assert(lookup.includes(marker), `single relic facade missing ${marker}`);

assert(dataManager.includes("func get_relic_definition(relic_id: Variant) -> Dictionary:"), "owner lookup must remain available");
assert(dataManager.includes("func get_relic_definitions() -> Array[Dictionary]:"), "owner pool must remain available");
assert(relicManager.includes("signal relic_added(relic_id: StringName)"), "relic_added contract must remain");
assert(relicManager.includes("signal relics_changed"), "relics_changed contract must remain");

const loadRelics = functionBody(relicManager, "_load_relic_definitions");
const getRelic = functionBody(relicManager, "_get_relic_definition");

assert(relicManager.includes('preload("res://scripts/game/game_data.gd")'), "RelicManager must preload GameData");
assert(loadRelics.includes("GameDataScript.get_relic_pool()"), "initial relic load must use GameData pool facade");
assert(getRelic.includes("GameDataScript.get_relic(relic_id)"), "local miss must use GameData lookup facade");
for (const forbidden of [
  "DataManager",
  "DataPathsScript",
  "JsonDataLoaderScript",
  "RELIC_DATA_PATH",
  "_load_relics_from_file",
]) assert(!relicManager.includes(forbidden), `RelicManager retains forbidden data dependency ${forbidden}`);

for (const marker of [
  "var owned_relics: Array[StringName] = []",
  "var _relic_definitions: Dictionary = {}",
  "var _trigger_counts: Dictionary = {}",
  "var _cooldown_until: Dictionary = {}",
  "func add_relic(relic_id: Variant) -> bool:",
  "func get_relic_definition(relic_id: Variant) -> Dictionary:",
  "func handle_combat_event(event_name: Variant, payload: Dictionary = {}) -> void:",
  "const ModifierSourceScript: Script",
]) assert(relicManager.includes(marker), `RelicManager public/runtime contract missing ${marker}`);

console.log("[verify_data_access_relics_boundary] PASS");
