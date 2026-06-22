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
    ["toxin_seed", "Seed"],
    ["toxic_core", "TCore"],
    ["flammable_mark", "Fla"],
    ["oil_stack", "Oil"],
    ["acid_mark", "Acid"],
    ["acid_residue", "ARes"],
  ]) {
    assertStatusLabel(enemyDisplay, statusId, label, "EnemyStatusDisplayController");
    assertStatusLabel(playerDisplay, statusId, label, "PlayerStatusDisplayController");
    assert(debugPanel.includes(statusId), `DevDebugPanel status summary must know ${statusId}`);
  }

  for (const [sourceId, label] of [
    ["toxic_core_boss_pulse", "\u5267\u6bd2\u8109\u51b2"],
    ["poison_death_explosion", "\u6bd2\u7206"],
    ["fire_oil_flammable_burst", "\u6613\u71c3\u7206\u53d1"],
    ["fire_oil_deflagration", "\u7206\u71c3"],
    ["fire_oil_secondary_deflagration", "\u4e8c\u6b21\u7206\u71c3"],
    ["acid_burst", "\u9178\u7206"],
  ]) {
    assert(debugPanel.includes(sourceId), `DevDebugPanel damage card must expose ${sourceId}`);
    assert(debugPanel.includes(label), `DevDebugPanel damage card must label ${sourceId} as ${label}`);
  }

  console.log("Debug alchemist branch display verified.");
}

main();
