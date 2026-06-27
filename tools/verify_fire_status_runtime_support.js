const path = require("path");
const { readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const manager = read("scripts/combat/status_effect_manager.gd");
for (const token of [
  "status_applied",
  "status_tick",
  "status_expired",
  "status_max_stack_reached",
  "consume_status_duration",
  "on_tick_effects",
  "max_stack_status",
]) {
  assert(manager.includes(token), `StatusEffectManager must support ${token}`);
}

console.log("[verify_fire_status_runtime_support] PASS");
