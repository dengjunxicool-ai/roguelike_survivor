const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertStatusLabel(source, statusId, label, fileLabel) {
  assert(source.includes(`"${statusId}":`), `${fileLabel} must map ${statusId}`);
  assert(source.includes(`return "${label}"`), `${fileLabel} must display ${statusId} as ${label}`);
}

function main() {
  const enemyDisplay = read("scripts/enemies/enemy_status_display_controller.gd");
  const playerDisplay = read("scripts/player/player_status_display_controller.gd");
  const debugPanel = read("scripts/debug/dev_debug_panel.gd");

  for (const [statusId, label] of [
    ["soul_ember", "Embr"],
    ["frost_lock", "Lock"],
    ["frostbite", "Fbt"],
    ["voltage", "Volt"],
    ["arcane_seal", "Seal"],
  ]) {
    assertStatusLabel(enemyDisplay, statusId, label, "EnemyStatusDisplayController");
    assertStatusLabel(playerDisplay, statusId, label, "PlayerStatusDisplayController");
  }

  assert(debugPanel.includes("soul_ember"), "DevDebugPanel status summary must know soul_ember");
  assert(debugPanel.includes("frost_lock"), "DevDebugPanel status summary must know frost_lock");
  assert(debugPanel.includes("frostbite"), "DevDebugPanel status summary must know frostbite");
  assert(debugPanel.includes("voltage"), "DevDebugPanel status summary must know voltage");
  assert(debugPanel.includes("arcane_seal"), "DevDebugPanel status summary must know arcane_seal");

  for (const snippet of [
    "soulburn_burst",
    "flame_core_burst",
    "frost_lock_bonus_hit",
    "lightning_overload",
    "arcane_seal_burst",
    "灼魂爆发",
    "聚核爆发",
    "碎冰伤害",
    "过载伤害",
    "爆印伤害",
  ]) {
    assert(debugPanel.includes(snippet), `DevDebugPanel damage card must expose ${snippet}`);
  }

  console.log("Debug mage branch display verified.");
}

main();
