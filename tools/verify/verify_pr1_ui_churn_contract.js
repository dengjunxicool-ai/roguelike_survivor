const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const modal = readTextFile(path.join(root, "scripts", "ui", "modals", "run_choice_modal_controller.gd"));
const uiManager = readTextFile(path.join(root, "scripts", "ui", "ui_manager.gd"));
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
const prewarmChoiceCardPools = functionBody(modal, "prewarm_choice_card_pools");
assert(prewarmChoiceCardPools.length > 0, "Choice modal must expose prewarm_choice_card_pools() for pre-run UI initialization.");
assert(prewarmChoiceCardPools.includes("_ensure_choice_card_pool(_level_up_options"), "Level-up card pool must be prewarmed before the first level-up modal opens.");
assert(prewarmChoiceCardPools.includes("_ensure_choice_card_pool(_reward_options"), "Reward card pool must be prewarmed before the first reward modal opens.");
assert(prewarmChoiceCardPools.includes("_hide_choice_card_pool(_level_up_options"), "Prewarmed level-up cards must remain hidden until the modal is shown.");
assert(prewarmChoiceCardPools.includes("_hide_choice_card_pool(_reward_options"), "Prewarmed reward cards must remain hidden until the modal is shown.");
assert(!prewarmChoiceCardPools.includes("generate_options"), "Prewarming must not roll level-up options or change gameplay RNG.");
assert(!prewarmChoiceCardPools.includes("generate_reward_options"), "Prewarming must not roll reward options or change reward state.");
assert(!prewarmChoiceCardPools.includes("_bind_choice_card"), "Prewarming must not bind gameplay option data.");
const setupRunChoiceModals = functionBody(uiManager, "_setup_run_choice_modals");
assert(setupRunChoiceModals.includes("prewarm_choice_card_pools"), "UIManager must prewarm run choice card pools after modal containers are set up.");
assert(!/func refresh_level_up_modal\(\)[\s\S]*?_clear_children\(_level_up_options\)/m.test(modal), "Level-up modal refresh must not clear/rebuild all children.");
assert(!/func refresh_reward_modal\(\)[\s\S]*?_clear_children\(_reward_options\)/m.test(modal), "Reward modal refresh must not clear/rebuild all children.");
assert(debugDisplay.includes("_debug_health_display_enabled"), "Enemy debug HP display must be gated by an explicit debug-display predicate.");
assert(debugDisplay.includes("developer_mode_enabled") || debugDisplay.includes("dev_debug_panel"), "Enemy debug HP display gate must be tied to runtime developer/debug state, not only OS.is_debug_build().");
const updateHealth = functionBody(debugDisplay, "update_health");
assert(updateHealth.includes("_debug_health_display_enabled()"), "Enemy debug HP display must call the explicit debug-display predicate.");
assert(!updateHealth.includes("OS.is_debug_build()"), "Enemy debug HP display must not be controlled only by OS.is_debug_build().");

console.log("[verify_pr1_ui_churn_contract] PASS");
