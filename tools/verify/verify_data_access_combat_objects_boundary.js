const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const summaryBuilder = readTextFile(path.join(root, "scripts", "skills", "skill_effect_summary_builder.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const facade = functionBody(gameData, "get_combat_object", "static func ");
assert(facade, "GameData.get_combat_object must exist.");
assert(
  facade.includes('_get_definition_from_data_manager("get_combat_object_definition", object_id)'),
  "GameData combat object lookup must prefer the DataManager owner accessor.",
);
assert(
  facade.includes('_find_by_id(_get_array(COMBAT_OBJECTS_PATH, "combat_objects"), object_id).duplicate(true)'),
  "GameData combat object lookup must keep an isolated JSON fallback.",
);

const combatObjectLookup = functionBody(summaryBuilder, "_get_combat_object", "static func ");
assert(combatObjectLookup, "SkillEffectSummaryBuilder._get_combat_object must remain available.");
assert(
  combatObjectLookup.includes("return GameData.get_combat_object(object_id)"),
  "SkillEffectSummaryBuilder must delegate combat object lookup to GameData.",
);
assert(
  !combatObjectLookup.includes("_load_array") && !combatObjectLookup.includes("COMBAT_OBJECTS_PATH"),
  "SkillEffectSummaryBuilder combat object lookup must not scan JSON arrays.",
);

const summonLookup = functionBody(summaryBuilder, "_get_summon", "static func ");
assert(
  summonLookup.includes('return _find_by_id(_load_array(SUMMONS_PATH, "summons"), summon_id)'),
  "Summon lookup must remain on its existing JSON path.",
);
assert(summaryBuilder.includes("const SUMMONS_PATH:"), "Summon path dependency must remain available.");
assert(summaryBuilder.includes("func _load_array("), "Summon JSON loader helper must remain available.");

console.log("[verify_data_access_combat_objects_boundary] PASS");
