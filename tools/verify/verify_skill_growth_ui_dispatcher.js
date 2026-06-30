const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const source = readTextFile(path.join(root, "scripts", "ui", "ui_command_dispatcher.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const optionIdIndex = source.indexOf('var option_id: String = String(option.get("id", ""))');
const payloadUpgradeIndex = source.indexOf('var upgrade_id: StringName = StringName(String(payload.get("upgrade_id", "")))');
assert(optionIdIndex >= 0, "dispatcher must read option id");
assert(payloadUpgradeIndex >= 0, "dispatcher must still support payload upgrade_id");
assert(optionIdIndex < payloadUpgradeIndex, "dispatcher must prefer option id so skill-card rarity suffix is preserved");
assert(source.includes('player.call("apply_upgrade", StringName(option_id))'), "dispatcher must pass full option id to player.apply_upgrade");

console.log("[verify_skill_growth_ui_dispatcher] PASS");
