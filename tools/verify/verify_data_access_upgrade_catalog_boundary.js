const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const upgradePool = readTextFile(path.join(root, "scripts", "upgrades", "upgrade_pool.gd"));
const saveManager = readTextFile(path.join(root, "scripts", "game", "save_manager.gd"));
const curseModal = readTextFile(path.join(root, "scripts", "ui", "modals", "run_choice_modal_controller.gd"));
const metaBuilder = readTextFile(path.join(root, "scripts", "ui", "screens", "meta_upgrade_view_model_builder.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const loadAll = functionBody(dataManager, "load_all");
const ownerCases = [
  ["_curse_choice_pool", "get_curse_choice_definitions"],
  ["_level_up_upgrade_pool", "get_level_up_upgrade_definitions"],
  ["_permanent_upgrade_pool", "get_permanent_upgrade_definitions"],
];

for (const [field, method] of ownerCases) {
  assert(dataManager.includes(`var ${field}: Array[Dictionary] = []`), `missing owner field ${field}`);
  assert(loadAll.includes(`${field}.clear()`), `reload must clear ${field}`);
  assert(functionBody(dataManager, method).includes(`return ${field}.duplicate(true)`), `${method} must deep-copy ${field}`);
}
assert(dataManager.includes("var _rarity_weights: Dictionary = {}"), "missing rarity owner field");
assert(loadAll.includes("_rarity_weights.clear()"), "reload must clear rarity weights");
assert(functionBody(dataManager, "get_rarity_weights").includes("return _rarity_weights.duplicate(true)"), "rarity accessor must deep-copy");
assert((loadAll.match(/_load_json_document\(UPGRADES_PATH\)/g) || []).length === 1, "upgrade document must load exactly once");
for (const marker of [
  "_curse_choice_pool = _get_dictionary_array(upgrades_document, CURSE_CHOICES_KEY, UPGRADES_PATH)",
  "_level_up_upgrade_pool = _get_dictionary_array(upgrades_document, LEVEL_UP_UPGRADES_KEY, UPGRADES_PATH)",
  "_permanent_upgrade_pool = _get_dictionary_array(upgrades_document, PERMANENT_UPGRADES_KEY, UPGRADES_PATH)",
  "_rarity_weights = rarity_weights_data.duplicate(true)",
  "_index_upgrade_definitions(upgrades_document, upgrade_key, UPGRADES_PATH)",
]) assert(loadAll.includes(marker), `load_all missing ${marker}`);
assert(!dataManager.includes("func get_upgrade_pool("), "do not introduce a string-keyed category facade");

const poolFacades = [
  ["get_curse_choice_pool", "get_curse_choice_definitions", "curse_choices"],
  ["get_level_up_upgrade_pool", "get_level_up_upgrade_definitions", "level_up_upgrades"],
  ["get_permanent_upgrade_pool", "get_permanent_upgrade_definitions", "permanent_upgrades"],
];
for (const [facade, owner, key] of poolFacades) {
  const body = functionBody(gameData, facade, "static func ");
  const manager = `_get_pool_from_data_manager("${owner}")`;
  const fallback = `_get_dictionary_array(UPGRADES_PATH, "${key}").duplicate(true)`;
  for (const marker of [manager, "if not data.is_empty()", "return data", fallback]) {
    assert(body.includes(marker), `${facade} missing ${marker}`);
  }
  assert(body.indexOf(manager) < body.indexOf(fallback), `${facade} must be manager-first`);
}

const permanent = functionBody(gameData, "get_permanent_upgrade", "static func ");
assert(permanent.includes('_get_pool_from_data_manager("get_permanent_upgrade_definitions")'), "permanent lookup must use the category-restricted manager pool");
assert(permanent.includes('return _find_by_id(data, upgrade_id)'), "permanent manager lookup must remain category-restricted");
assert(permanent.includes('_find_by_id(_get_array(UPGRADES_PATH, "permanent_upgrades"), upgrade_id).duplicate(true)'), "permanent fallback must stay category-scoped and isolated");

const rarity = functionBody(gameData, "get_rarity_weights", "static func ");
for (const marker of [
  '_get_data_manager()',
  'has_method("get_rarity_weights")',
  'data_manager.call("get_rarity_weights")',
  'if not weight_data.is_empty()',
  'return weight_data',
  '_load_document(UPGRADES_PATH)',
  'return fallback_weights.duplicate(true)',
]) assert(rarity.includes(marker), `rarity facade missing ${marker}`);

assert(upgradePool.includes("GameData.get_level_up_upgrade_pool()"), "UpgradePool must keep the level-up facade");
assert(upgradePool.includes("GameData.get_rarity_weights()"), "UpgradePool must keep the rarity facade");
assert(saveManager.includes("GameData.get_permanent_upgrade_pool()"), "SaveManager must keep the permanent pool facade");
assert(saveManager.includes("GameData.get_permanent_upgrade(upgrade_id)"), "SaveManager must keep the permanent lookup facade");
assert(curseModal.includes("GameData.get_curse_choice_pool()"), "curse UI must keep its facade");
assert(metaBuilder.includes("GameData.get_permanent_upgrade_pool()"), "meta UI must keep its facade");
for (const source of [upgradePool, saveManager, curseModal, metaBuilder]) {
  assert(!source.includes("DataManager"), "consumers must not depend directly on DataManager");
}

console.log("[verify_data_access_upgrade_catalog_boundary] PASS");
