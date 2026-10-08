const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const skillManager = readTextFile(path.join(root, "scripts", "skills", "skill_manager.gd"));
const initializer = readTextFile(path.join(root, "scripts", "characters", "character_run_initializer.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

assert(
  dataManager.includes("var _starting_skill_definitions: Array[Dictionary] = []"),
  "DataManager must own the ordered starting-skill pool.",
);
assert(
  dataManager.includes("_starting_skill_definitions.clear()"),
  "DataManager must clear the ordered starting-skill pool before reload.",
);
assert(
  dataManager.includes("_starting_skill_definitions = _get_dictionary_array(skills_document, STARTING_SKILLS_KEY, SKILLS_PATH)"),
  "DataManager must load the ordered starting-skill pool from skills.json.",
);
const ownerAccessor = functionBody(dataManager, "get_starting_skill_definitions");
assert(ownerAccessor, "DataManager.get_starting_skill_definitions must exist.");
assert(
  ownerAccessor.includes("return _starting_skill_definitions.duplicate(true)"),
  "DataManager starting-skill accessor must return a deep copy.",
);

const facade = functionBody(gameData, "get_starting_skill_pool", "static func ");
assert(facade, "GameData.get_starting_skill_pool must exist.");
assert(
  facade.includes('_get_pool_from_data_manager("get_starting_skill_definitions")'),
  "GameData starting-skill pool must prefer the DataManager owner accessor.",
);
assert(
  facade.includes('_get_dictionary_array(SKILLS_PATH, "starting_skills").duplicate(true)'),
  "GameData starting-skill pool must keep an isolated JSON fallback.",
);

const lookup = functionBody(skillManager, "_get_skill_definition_data");
assert(lookup, "SkillManager._get_skill_definition_data must remain available.");
assert(
  lookup.includes("return GameData.get_skill(skill_id)"),
  "SkillManager definition lookup must delegate to GameData.",
);
const primary = functionBody(skillManager, "_get_primary_starting_skill_data");
assert(
  primary.includes("GameData.get_starting_skill_pool()"),
  "SkillManager primary starting skill must use the ordered GameData pool.",
);
for (const forbidden of [
  "DataPathsScript",
  "JsonDataLoaderScript",
  "SKILLS_DATA_PATH",
  'get_node_or_null("/root/DataManager")',
  "_load_skills_document",
]) {
  assert(!skillManager.includes(forbidden), `SkillManager retains forbidden data dependency: ${forbidden}`);
}

const firstConfigured = functionBody(initializer, "_first_configured_starting_skill_id");
assert(firstConfigured, "CharacterRunInitializer starting-skill fallback must remain available.");
assert(
  firstConfigured.includes("GameData.get_starting_skill_pool()"),
  "CharacterRunInitializer must read the ordered starting-skill pool through GameData.",
);
for (const forbidden of ["GameData._load_document", "DataPathsScript", "SKILLS_PATH"]) {
  assert(!initializer.includes(forbidden), `CharacterRunInitializer retains forbidden data dependency: ${forbidden}`);
}

console.log("[verify_data_access_skills_boundary] PASS");
