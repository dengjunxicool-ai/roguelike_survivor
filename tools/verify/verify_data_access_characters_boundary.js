const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const characterRuntime = readTextFile(path.join(root, "scripts", "characters", "character_runtime.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const lookup = functionBody(characterRuntime, "_get_character_data");
assert(lookup, "CharacterRuntime._get_character_data must remain available.");
assert(
  lookup.includes("return GameData.get_character(character_id)"),
  "CharacterRuntime must delegate character definition lookup to GameData.",
);

for (const forbidden of [
  "/root/DataManager",
  "get_character_definition",
  "JsonDataLoader",
  "DataPaths",
]) {
  assert(
    !characterRuntime.includes(forbidden),
    `CharacterRuntime retains forbidden character data dependency: ${forbidden}`,
  );
}

for (const contract of [
  "func initialize(character_id: String) -> bool:",
  "func get_character_id() -> String:",
  "func get_starting_skill_id() -> String:",
  "func get_stat(stat_name: String, default_value: Variant = 0) -> Variant:",
]) {
  assert(characterRuntime.includes(contract), `CharacterRuntime public contract missing: ${contract}`);
}

console.log("[verify_data_access_characters_boundary] PASS");
