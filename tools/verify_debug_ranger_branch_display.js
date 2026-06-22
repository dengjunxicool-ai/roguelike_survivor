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
    ["eagle_mark", "Egl"],
    ["burst_mark", "Bst"],
    ["prey_mark", "Prey"],
  ]) {
    assertStatusLabel(enemyDisplay, statusId, label, "EnemyStatusDisplayController");
    assertStatusLabel(playerDisplay, statusId, label, "PlayerStatusDisplayController");
    assert(debugPanel.includes(statusId), `DevDebugPanel status summary must know ${statusId}`);
  }

  for (const [sourceId, label] of [
    ["throwing_knife_execution_burst", "\u5904\u51b3\u4f24\u5bb3"],
    ["throwing_knife_rupture", "\u5272\u88c2\u4f24\u5bb3"],
    ["hunter_bow_eagle_shot", "\u9e70\u773c\u5c04\u51fb"],
    ["hunter_arrow_hit_explosion", "\u7bad\u77e2\u7206\u70b8"],
    ["hunter_burst_mark_death_explosion", "\u7206\u88c2\u5c0f\u7206\u70b8"],
    ["trap_pincer_reaction", "\u5939\u51fb\u53cd\u5e94"],
    ["boss_core_trap_bonus", "\u730e\u6740\u5939\u4f24\u5bb3"],
    ["decoy_trap_explosion", "\u8bf1\u9975\u7206\u70b8"],
  ]) {
    assert(debugPanel.includes(sourceId), `DevDebugPanel damage card must expose ${sourceId}`);
    assert(debugPanel.includes(label), `DevDebugPanel damage card must label ${sourceId} as ${label}`);
  }

  console.log("Debug ranger branch display verified.");
}

main();
