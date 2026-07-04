const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..", "..");

function read(relPath) {
  return fs.readFileSync(path.join(repoRoot, relPath), "utf8");
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
  return next >= 0 ? source.slice(start, next) : source.slice(start);
}

const manager = read("scripts/combat/status_effect_manager.gd");
const scheduler = read("scripts/combat/status_tick_scheduler.gd");
const enemyFacade = read("scripts/enemies/enemy_status_facade.gd");
const enemyBase = read("scripts/enemies/enemy_base.gd");
const player = read("scripts/player/player_controller.gd");
const profiler = read("scripts/debug/real_full_run_profiler.gd");

assert(scheduler.includes("class_name StatusTickScheduler"), "StatusTickScheduler must declare class_name StatusTickScheduler");
assert(scheduler.includes("register_status"), "StatusTickScheduler must register active ticking statuses");
assert(scheduler.includes("unregister_status"), "StatusTickScheduler must unregister cleared statuses");
assert(scheduler.includes("advance_and_is_due"), "StatusTickScheduler must gate tick work to due statuses");

assert(manager.includes("StatusTickSchedulerScript"), "StatusEffectManager must use StatusTickScheduler");
assert(manager.includes("_status_definition_cache"), "StatusEffectManager must cache status definitions");
assert(manager.includes("_apply_coalesce_frame"), "StatusEffectManager must coalesce same-frame duplicate apply");
assert(manager.includes("_status_display_dirty"), "StatusEffectManager must expose status UI dirty state");
assert(manager.includes("_reaction_queue"), "StatusEffectManager must queue reactions");
assert(manager.includes("_processing_reaction_queue"), "StatusEffectManager must avoid recursive reaction processing");
assert(manager.includes("has_active_statuses"), "StatusEffectManager must expose active-status state");
assert(manager.includes("consume_status_display_dirty"), "StatusEffectManager must expose dirty-consume API");

const applyStatus = extractFunction(manager, "apply_status");
assert(
  applyStatus.indexOf("_should_coalesce_status_apply") >= 0 &&
    applyStatus.indexOf("_should_coalesce_status_apply") < applyStatus.indexOf("HotPathProfilerScript.begin"),
  "Status apply coalescing must happen before status_apply hot-path timing starts"
);

const updateProfiled = extractFunction(manager, "_update_status_effects_profiled");
assert(updateProfiled.includes("_statuses.is_empty()"), "Status manager update must return immediately when no statuses are active");
assert(updateProfiled.includes("_status_tick_scheduler"), "Status manager update must delegate tick due checks to StatusTickScheduler");
assert(!extractFunction(manager, "_advance_status_tick").includes("_update_damage_over_time(status, delta)"), "Status tick work must not run every frame for every DOT");

assert(extractFunction(manager, "_handle_max_stack_reached_profiled").includes("_enqueue_status_reaction"), "Max-stack reaction must enqueue instead of executing recursively");
assert(extractFunction(manager, "_refresh_status_visual").includes("status_visual_update"), "Status visual refresh must be hot-path profiled");
assert(manager.includes("_mark_status_display_dirty"), "Status changes must mark status UI dirty");

assert(extractFunction(enemyFacade, "update_status_effects").includes("has_active_statuses"), "EnemyStatusFacade must skip manager update when no statuses are active");
assert(extractFunction(enemyFacade, "consume_status_display_dirty").includes("consume_status_display_dirty"), "EnemyStatusFacade must expose dirty consume");
assert(extractFunction(enemyBase, "_update_status_label").includes("consume_status_display_dirty"), "Enemy status label must update only when dirty");
assert(extractFunction(player, "_update_status_label").includes("consume_status_display_dirty"), "Player status label must update only when dirty");

assert(profiler.includes("\"status_visual_update\""), "RealFullRunProfiler HOT_PATH_SECTIONS must include status_visual_update");
assert(profiler.includes("\"status_reaction\""), "RealFullRunProfiler HOT_PATH_SECTIONS must include status_reaction");

console.log("Status scheduler contract verified.");
