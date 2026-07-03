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

const scene = read("scenes/app/app_bootstrap.tscn");
const profiler = read("scripts/debug/real_full_run_profiler.gd");

assert(
  scene.includes("res://scripts/debug/real_full_run_profiler.gd") &&
    scene.includes('name="RealFullRunProfiler"'),
  "AppBootstrap must include the opt-in real full-run profiler node."
);
assert(
  profiler.includes("--real-full-run-profile"),
  "Real profiler must be enabled only by the --real-full-run-profile command-line flag."
);
assert(
  profiler.includes("Engine.time_scale = 1.0"),
  "Real profiler must force normal time scale for the measured run."
);
assert(
  !profiler.includes("autoplay_survival_assist") &&
    !profiler.includes("boss_damage_assist") &&
    !profiler.includes("_finish_death"),
  "Real profiler must not include survival assist or boss damage assist hooks."
);
assert(
  profiler.includes("emit_signal(&\"pressed\")") &&
    profiler.includes("CharacterConfirmButton") &&
    profiler.includes("MapStartButton"),
  "Real profiler should drive startup through UI button signals."
);
assert(
  profiler.includes("Performance.get_monitor(Performance.OBJECT_COUNT)") &&
    profiler.includes("p95_frame_ms") &&
    profiler.includes("p99_frame_ms"),
  "Real profiler must record Godot Performance monitor data and frame percentiles."
);
assert(
  profiler.includes("ATTRIBUTION_PATH") &&
    profiler.includes("latest_attribution.json") &&
    profiler.includes("_write_attribution_output"),
  "Real profiler must write a dedicated latest_attribution.json output."
);
assert(
  profiler.includes("--profile-force-skill=") &&
    profiler.includes("_apply_forced_profile_skills") &&
    profiler.includes("forced_profile_skills") &&
    profiler.includes("final_skills"),
  "Real profiler must support opt-in forced skill learning for reproducible skill-specific profiling and report the forced/final skill build."
);
assert(
  profiler.includes("BOSS_DAMAGE_STOP_AMOUNT") &&
    profiler.includes("BOSS_DAMAGE_RUN_MAX_SECONDS") &&
    profiler.includes("_boss_start_health") &&
    profiler.includes("_boss_damage_done"),
  "Real profiler must support stopping after observed boss damage without modifying boss health."
);
assert(
  profiler.includes("created_by_key") &&
    profiler.includes("destroyed_by_key") &&
    profiler.includes("net_nodes_by_key") &&
    profiler.includes("object_delta_attribution"),
  "Real profiler must attribute created/destroyed/net nodes by scene/script/class key."
);
assert(
  profiler.includes("created_by_source_skill_id") &&
    profiler.includes("destroyed_by_source_skill_id") &&
    profiler.includes("created_by_source_id") &&
    profiler.includes("destroyed_by_source_id") &&
    profiler.includes("status_events_by_status_id") &&
    profiler.includes("status_events_by_source_skill_id"),
  "Real profiler must attribute runtime churn and status events by source_skill_id/source_id/status_id."
);
assert(
  profiler.includes("_refresh_node_record_source_attribution") &&
    profiler.includes("_source_attribution_record") &&
    profiler.includes("source_skill_id") &&
    profiler.includes("status_id"),
  "Real profiler must defer-enrich node records after setup metadata is available."
);
assert(
  profiler.includes("created_by_source_skill_id") &&
    profiler.includes("chaos_attack_chaotic") &&
    profiler.includes("chaos_cast_singularity_barrage"),
  "Real profiler attribution schema must separate chaos_attack_chaotic and chaos_cast_singularity_barrage source_skill_id buckets."
);
assert(
  profiler.includes("spike_frames_over_50ms") &&
    profiler.includes("spike_frames_over_100ms") &&
    profiler.includes("frame_event_buckets") &&
    profiler.includes("status_tick") &&
    profiler.includes("reaction"),
  "Real profiler must keep spike-frame attribution buckets for create/destroy/tick/reaction pressure."
);
assert(
  profiler.includes("damage_number_diagnosis") &&
    profiler.includes("damage_number_selector_candidates") &&
    profiler.includes("damage_number_popup.gd"),
  "Real profiler must diagnose whether damage number count is disabled or selector-related."
);
assert(
  !profiler.includes("boss.set(") &&
    !profiler.includes("boss.call(\"take_damage\"") &&
    !profiler.includes("boss.call(&\"take_damage\""),
  "Real profiler must not modify or damage the boss to reach the attribution stop condition."
);

console.log("[verify_real_full_run_profile_contract] PASS");
