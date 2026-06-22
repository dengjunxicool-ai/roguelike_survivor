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
    ["holy_mark", "Hol"],
    ["judgment", "Jdg"],
    ["impurity", "Imp"],
  ]) {
    assertStatusLabel(enemyDisplay, statusId, label, "EnemyStatusDisplayController");
    assertStatusLabel(playerDisplay, statusId, label, "PlayerStatusDisplayController");
    assert(debugPanel.includes(statusId), `DevDebugPanel status summary must know ${statusId}`);
  }

  for (const [sourceId, label] of [
    ["holy_counter_on_marked_break_hit", "\u5723\u88c1\u53cd\u51fb"],
    ["holy_judgement_beam", "\u88c1\u51b3\u5149\u675f"],
    ["warhammer_judgement_shock", "\u88c1\u51b3\u9707\u8361"],
    ["warhammer_boss_poise_judgement_bonus", "\u5f3a\u5316\u88c1\u51b3"],
    ["warhammer_execution_shockwave", "\u65a9\u6740\u9707\u6ce2"],
    ["cross_relic_echo", "\u4fe1\u4ef0\u56de\u54cd"],
    ["cross_relic_faith_judgement", "\u4fe1\u4ef0\u88c1\u51b3"],
    ["cross_relic_purify_impurity", "\u51c0\u5316\u53cd\u5e94"],
    ["cross_relic_purify_small_pulse", "\u5c0f\u5723\u5149\u8109\u51b2"],
  ]) {
    assert(debugPanel.includes(sourceId), `DevDebugPanel damage card must expose ${sourceId}`);
    assert(debugPanel.includes(label), `DevDebugPanel damage card must label ${sourceId} as ${label}`);
  }

  console.log("Debug paladin branch display verified.");
}

main();
