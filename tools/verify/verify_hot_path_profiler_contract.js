const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const sections = [
  "skill_update_total",
  "skill_cast_tick",
  "status_update_total",
  "status_apply",
  "status_tick",
  "status_reaction",
  "area_effect_update",
  "area_effect_tick",
  "projectile_update",
  "projectile_targeting",
  "summon_update",
  "summon_targeting",
  "enemy_update",
  "enemy_movement",
  "enemy_ai_update",
  "enemy_attack_update",
  "enemy_neighbor_check",
  "enemy_animation_update",
  "enemy_status_visual_update",
  "pickup_update",
  "ui_update",
];

const profiler = read("scripts/debug/real_full_run_profiler.gd");
const helper = read("scripts/debug/hot_path_profiler.gd");

assert(
  profiler.includes("HOT_PATH_PATH") &&
    profiler.includes("latest_hot_path.json") &&
    profiler.includes("_write_hot_path_output"),
  "RealFullRunProfiler must write reports/real-full-run-profile/latest_hot_path.json."
);
assert(
  profiler.includes("PROFILER_HOT_PATH_EVENT_META") &&
    profiler.includes("_on_hot_path_event"),
  "RealFullRunProfiler must expose a root-meta hot path event callback."
);
assert(
  profiler.includes("HOT_PATH_SECTIONS") &&
    profiler.includes("top_10_hot_paths") &&
    profiler.includes("calls_per_frame"),
  "Hot path report must include the section schema, calls_per_frame, and top_10_hot_paths."
);
for (const section of sections) {
  assert(profiler.includes(section), `Hot path report schema must include ${section}.`);
}

assert(
  helper.includes("class_name HotPathProfiler") &&
    helper.includes("real_full_run_profiler_hot_path_event") &&
    helper.includes("func begin") &&
    helper.includes("func end"),
  "HotPathProfiler helper must provide begin/end methods routed through root metadata."
);

const instrumentation = {
  "scripts/skills/skill_executor.gd": ["skill_update_total"],
  "scripts/skills/skill_component_runner.gd": ["skill_cast_tick"],
  "scripts/combat/status_effect_manager.gd": [
    "status_apply",
    "status_update_total",
    "status_tick",
    "status_reaction",
  ],
  "scripts/combat/area_effect.gd": ["area_effect_update", "area_effect_tick"],
  "scripts/combat/projectile.gd": ["projectile_update", "projectile_targeting"],
  "scripts/summons/summon_controller.gd": ["summon_update", "summon_targeting"],
  "scripts/enemies/enemy_base.gd": [
    "enemy_update",
    "enemy_movement",
    "enemy_ai_update",
    "enemy_attack_update",
    "enemy_neighbor_check",
    "enemy_animation_update",
    "enemy_status_visual_update",
  ],
  "scripts/drops/pickup_manager.gd": ["pickup_update", "pickup_idle_check", "pickup_active_update", "pickup_reward_flush"],
  "scripts/ui/ui_manager.gd": ["ui_update"],
};

for (const [relativePath, expectedSections] of Object.entries(instrumentation)) {
  const source = read(relativePath);
  assert(
    source.includes("hot_path_profiler.gd"),
    `${relativePath} must preload the hot path profiler helper.`
  );
  for (const section of expectedSections) {
    assert(source.includes(section), `${relativePath} must record ${section}.`);
  }
}

console.log("[verify_hot_path_profiler_contract] PASS");
