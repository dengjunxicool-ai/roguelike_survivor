const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "..");

function read(relPath) {
  return fs.readFileSync(path.join(root, relPath), "utf8");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function extractFunction(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  assert(start >= 0, `Missing function ${name}`);
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next >= 0 ? next : source.length);
}

const managerPath = "scripts/drops/pickup_manager.gd";
assert(fs.existsSync(path.join(root, managerPath)), "PickupManager script must exist");

const manager = read(managerPath);
const expGem = read("scripts/drops/exp_gem.gd");
const player = read("scripts/player/player_controller.gd");
const profiler = read("scripts/debug/real_full_run_profiler.gd");

[
  "class_name PickupManager",
  "static func get_or_create",
  "func register_pickup",
  "func unregister_pickup",
  "func notify_state_changed",
  "func queue_experience_reward",
  "func flush_rewards",
  "_cache_player_state",
  "_process_idle_bucket",
  "_process_active_pickups",
  "IDLE_SCAN_INTERVAL: float = 0.1",
  "IDLE_BUCKET_COUNT: int = 10",
  "MAX_REWARD_AMOUNTS_PER_FRAME",
].forEach((needle) => assert(manager.includes(needle), `PickupManager missing ${needle}`));

const managerPhysics = extractFunction(manager, "_physics_process");
assert(managerPhysics.includes("pickup_update"), "PickupManager must own pickup_update hot-path profiling");
assert(managerPhysics.includes("pickup_idle_check"), "PickupManager must profile idle pickup checks");
assert(managerPhysics.includes("pickup_active_update"), "PickupManager must profile active pickup movement");
assert(managerPhysics.includes("pickup_reward_flush"), "PickupManager must profile reward flush");
assert(managerPhysics.includes("_cache_player_state"), "PickupManager must cache player state once per frame");
assert(managerPhysics.includes("_process_idle_bucket"), "PickupManager must process idle pickups in buckets");
assert(managerPhysics.includes("_process_active_pickups"), "PickupManager must update magnetized/collecting pickups every frame");
assert(managerPhysics.includes("flush_rewards"), "PickupManager must flush queued rewards in batches");

for (const stateToken of ["PICKUP_STATE_IDLE", "PICKUP_STATE_MAGNETIZED", "PICKUP_STATE_COLLECTING"]) {
  assert(expGem.includes(stateToken), `ExpGem must define ${stateToken}`);
}

assert(expGem.includes("PickupManagerScript"), "ExpGem must use PickupManager");
assert(expGem.includes("manager_idle_check"), "ExpGem must expose manager_idle_check");
assert(expGem.includes("manager_active_update"), "ExpGem must expose manager_active_update");
assert(expGem.includes("_set_pickup_state"), "ExpGem must transition pickup states through a helper");
assert(expGem.includes("register_pickup"), "ExpGem must register with PickupManager");
assert(expGem.includes("unregister_pickup"), "ExpGem must unregister from PickupManager");
assert(expGem.includes("queue_experience_reward"), "ExpGem collection must queue rewards through PickupManager");

const expPhysics = extractFunction(expGem, "_physics_process");
assert(!expPhysics.includes("pickup_update"), "ExpGem must not profile/update every pickup independently");
assert(!expPhysics.includes("_physics_process_profiled"), "ExpGem physics process must not run full pickup logic");

assert(player.includes("func add_experience_batch"), "PlayerController must expose add_experience_batch for batched pickup rewards");
assert(player.includes("_calculate_experience_gain"), "PlayerController must share single-pickup experience gain calculation");
assert(player.includes("_apply_experience_total"), "PlayerController must apply batched final experience with one experience_changed emit");
assert(profiler.includes("\"pickup_update\""), "RealFullRunProfiler must continue collecting pickup_update");

console.log("Pickup manager contract verified.");
