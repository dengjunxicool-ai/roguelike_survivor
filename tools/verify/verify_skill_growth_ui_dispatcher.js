const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const source = readTextFile(path.join(root, "scripts", "ui", "ui_command_dispatcher.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const optionIdIndex = source.indexOf('var option_id: String = String(option.get("id", ""))');
const payloadUpgradeIndex = source.indexOf('String(payload.get("upgrade_id", ""))', optionIdIndex);
assert(optionIdIndex >= 0, "dispatcher must read option id");
assert(payloadUpgradeIndex >= 0, "dispatcher must still support payload upgrade_id");
assert(optionIdIndex < payloadUpgradeIndex, "dispatcher must prefer option id so skill-card rarity suffix is preserved");
assert(source.includes('return StringName(option_id)'), "dispatcher must preserve full option id including rarity");
assert(source.includes('player.call(&"apply_upgrade", upgrade_id)'), "dispatcher must apply the resolved full upgrade id");

console.log("[verify_skill_growth_ui_dispatcher] PASS");
