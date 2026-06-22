const fs = require("fs");
const path = require("path");
const { stripBom } = require("./json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return stripBom(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const displayController = read("scripts/enemies/enemy_debug_display_controller.gd");
const visualCheck = read("scripts/debug/visual_config_check.gd");

assert(displayController.includes("var _hp_bar: ProgressBar"), "enemy HP display must use a visual ProgressBar");
assert(displayController.includes("var _hp_lag_bar: ProgressBar"), "enemy HP display must keep a lighter delayed damage ProgressBar");
assert(!displayController.includes("var _hp_label: Label"), "enemy HP display must not keep a numeric HP label field");
assert(displayController.includes('get_node_or_null("DebugHpLabel")'), "enemy HP display should clean up stale numeric labels");
assert(displayController.includes("queue_free()"), "stale numeric HP labels must be removed");
assert(displayController.includes("create_tween()"), "enemy HP bar updates must use a tween");
assert(displayController.includes('name = "DebugHpLagBar"'), "enemy HP display must name the delayed lighter red bar");
assert(displayController.includes("Color(0.72, 0.72, 0.72, 0.48"), "enemy HP delayed bar must use a semi-transparent gray color");
assert(displayController.includes('tween_property(_hp_lag_bar, "value", target_value, 1.0)'), "enemy HP delayed bar should ease over one second");
assert(displayController.includes("show_percentage = false"), "enemy HP bar must not render numeric percentage text");
assert(visualCheck.includes('enemy.get_node_or_null("DebugHpLabel") == null'), "visual smoke check must expect the numeric HP label to be gone");

console.log("[verify_enemy_visual_health_bar] PASS");
