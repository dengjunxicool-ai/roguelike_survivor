const path = require("path");
const { readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function main() {
  const panel = read("scripts/debug/dev_debug_panel.gd");
  assert(panel.includes("func _get_attack_damage_records() -> Array[Dictionary]:"), "DevDebugPanel must expose a damage-record-only helper");
  assert(panel.includes('String(record.get("type", "")) != "damage"'), "damage record helper must filter out non-damage trace records");
  assert(panel.includes("return _get_attack_damage_records().size()"), "damage card count must use damage records only");
  assert(panel.includes("var display_records: Array[Dictionary] = _get_attack_damage_records()"), "damage cards must display damage records only");
  assert(!panel.includes("display_records.append(record)"), "damage cards must not append every trace record to display records");
  console.log("Debug attack damage cards verified.");
}

main();
