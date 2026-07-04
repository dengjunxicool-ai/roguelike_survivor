const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function extractFunction(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  assert(start >= 0, `Missing function ${name}`);
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next >= 0 ? next : source.length);
}

const statusManager = read("scripts/combat/status_effect_manager.gd");
const profiler = read("scripts/debug/real_full_run_profiler.gd");

for (const eventName of [
  "status_tick_due",
  "status_tick_applied",
  "status_expired",
  "status_visual_spawn",
  "status_visual_update",
  "status_reaction_triggered",
]) {
  assert(statusManager.includes(eventName), `StatusEffectManager must emit profiler-only ${eventName} events.`);
  assert(profiler.includes(eventName), `RealFullRunProfiler must collect ${eventName} events.`);
}

assert(
  statusManager.includes("real_full_run_profiler_enabled") &&
    statusManager.includes("_emit_profiler_status_event") &&
    statusManager.includes("real_full_run_profiler_status_event"),
  "StatusEffectManager profiler events must be gated by the real profiler and routed through a profiler-only callback."
);
assert(
  extractFunction(statusManager, "_update_damage_over_time_profiled").includes("status_tick_due") &&
    extractFunction(statusManager, "_update_damage_over_time_profiled").includes("status_tick_applied"),
  "StatusEffectManager must count due and applied status ticks inside the DOT tick loop."
);
assert(
  extractFunction(statusManager, "_expire_statuses").includes("status_expired") &&
    extractFunction(statusManager, "consume_status_duration").includes("status_expired"),
  "StatusEffectManager must count normal and consumed status expiration events."
);
assert(
  extractFunction(statusManager, "_get_or_create_status_visual_overlay").includes("status_visual_spawn") &&
    extractFunction(statusManager, "_refresh_status_visual").includes("status_visual_update"),
  "StatusEffectManager must count status visual spawn and update events."
);
assert(
  statusManager.includes("_status_visual_refresh_needed_after_apply") &&
    statusManager.includes("_status_visual_priority"),
  "StatusEffectManager must skip status visual refresh work when repeated status application cannot change the visible overlay."
);
assert(
  extractFunction(statusManager, "_apply_status_profiled").includes("_status_visual_refresh_needed_after_apply(id, definition)") &&
    !extractFunction(statusManager, "_apply_status_profiled").includes("\n\t_refresh_status_visual()\n\n\t_notify_status_applied"),
  "apply_status must not unconditionally refresh status visuals after every repeated status application."
);
assert(
  extractFunction(statusManager, "_get_or_create_status_visual_overlay").includes("get_node_or_null(STATUS_VISUAL_NODE_NAME)") &&
    extractFunction(statusManager, "_get_or_create_status_visual_overlay").includes("existing_overlay"),
  "StatusVisualOverlay must be reused when an owner already has one."
);
assert(
  extractFunction(statusManager, "_execute_status_reaction").includes("status_reaction_triggered"),
  "StatusEffectManager must count status reaction triggers from max-stack status/event paths."
);

assert(
  profiler.includes("normal_status_tick_events_observable") &&
    !profiler.includes("observability_gap"),
  "RealFullRunProfiler status_tick_observation must no longer report observability_gap for normal status ticks."
);
assert(
  extractFunction(profiler, "_new_frame_bucket").includes("status_tick_due") &&
    extractFunction(profiler, "_new_frame_bucket").includes("status_tick_applied") &&
    extractFunction(profiler, "_new_frame_bucket").includes("status_reaction_triggered"),
  "RealFullRunProfiler frame buckets must include explicit status tick/reaction counters."
);
assert(
  extractFunction(profiler, "_spike_category_activity").includes("tick_due") &&
    extractFunction(profiler, "_spike_category_activity").includes("tick_applied") &&
    extractFunction(profiler, "_spike_category_activity").includes("reaction_triggered"),
  "RealFullRunProfiler spike category activity must expose status tick/reaction details."
);
assert(
  profiler.includes("PROFILER_STATUS_EVENT_META") &&
    profiler.includes('Callable(self, "_on_profiler_status_event")') &&
    extractFunction(profiler, "_on_profiler_status_event").includes("_record_profiler_status_event") &&
    extractFunction(profiler, "_is_profiler_status_event").includes("status_tick_due") &&
    extractFunction(profiler, "_is_profiler_status_event").includes("status_visual_update"),
  "RealFullRunProfiler must collect profiler-only status events from the root metadata callback."
);
assert(
  !profiler.includes("DevDebugPanel") &&
    !profiler.includes("pickup_count.text") &&
    !profiler.includes("debug_labels"),
  "PR-5 observability must not add high-frequency debug panel UI refreshes."
);

console.log("[verify_pr5_status_tick_observability_contract] PASS");
