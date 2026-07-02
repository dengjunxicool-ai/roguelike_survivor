const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const modal = readTextFile(path.join(root, "scripts", "ui", "modals", "run_choice_modal_controller.gd"));
const debugDisplay = readTextFile(path.join(root, "scripts", "enemies", "enemy_debug_display_controller.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name) {
  const start = source.indexOf(`func ${name}`);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

assert(modal.includes("_ensure_choice_card_pool"), "Choice modal must pre-create/reuse card nodes.");
assert(modal.includes("_bind_choice_card"), "Choice modal must update existing card content instead of rebuilding it.");
assert(modal.includes("_hide_choice_card_pool"), "Choice modal must hide unused cards instead of queue_free-ing modal children.");
assert(!/func refresh_level_up_modal\(\)[\s\S]*?_clear_children\(_level_up_options\)/m.test(modal), "Level-up modal refresh must not clear/rebuild all children.");
assert(!/func refresh_reward_modal\(\)[\s\S]*?_clear_children\(_reward_options\)/m.test(modal), "Reward modal refresh must not clear/rebuild all children.");
assert(debugDisplay.includes("_debug_health_display_enabled"), "Enemy debug HP display must be gated by an explicit debug-display predicate.");
assert(debugDisplay.includes("developer_mode_enabled") || debugDisplay.includes("dev_debug_panel"), "Enemy debug HP display gate must be tied to runtime developer/debug state, not only OS.is_debug_build().");
const updateHealth = functionBody(debugDisplay, "update_health");
assert(updateHealth.includes("_debug_health_display_enabled()"), "Enemy debug HP display must call the explicit debug-display predicate.");
assert(!updateHealth.includes("OS.is_debug_build()"), "Enemy debug HP display must not be controlled only by OS.is_debug_build().");

console.log("[verify_pr1_ui_churn_contract] PASS");
