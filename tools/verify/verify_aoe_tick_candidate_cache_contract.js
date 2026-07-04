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

const areaEffect = read("scripts/combat/area_effect.gd");
const vortex = read("scripts/combat/scorching_vortex_area.gd");
const profiler = read("scripts/debug/real_full_run_profiler.gd");
const manager = read("scripts/combat/area_effect_manager.gd");

assert(areaEffect.includes("AreaEffectManager"), "AreaEffect must use AreaEffectManager");
assert(areaEffect.includes("_candidate_body_ids"), "AreaEffect must keep candidate ids");
assert(areaEffect.includes("_candidate_body_order"), "AreaEffect must keep candidate order");
assert(areaEffect.includes("_pending_tick_target_ids"), "AreaEffect pending tick damage must store target ids");
assert(areaEffect.includes("instance_from_id"), "AreaEffect must resolve cached candidates from instance ids");
assert(!areaEffect.includes("_pending_tick_targets: Array[Node]"), "AreaEffect pending tick queue must not retain Node references");
assert(!areaEffect.includes("_candidate_body_order: Array[Node]"), "AreaEffect candidate order must not retain Node references");
assert(areaEffect.includes("_candidate_cache_seeded"), "AreaEffect must seed candidate cache before ticking");
assert(areaEffect.includes("body_entered.connect"), "AreaEffect must connect body_entered");
assert(areaEffect.includes("body_exited.connect"), "AreaEffect must connect body_exited");
assert(areaEffect.includes("_on_body_entered"), "AreaEffect must add candidates on body_entered");
assert(areaEffect.includes("_on_body_exited"), "AreaEffect must remove candidates on body_exited");
assert(areaEffect.includes("_prune_candidate"), "AreaEffect must lazily prune invalid/dead candidates");
assert(areaEffect.includes("record_tick"), "AreaEffect must record tick attribution");
assert(areaEffect.includes("candidate_count"), "AreaEffect tick stats must include candidate_count");
assert(areaEffect.includes("hit_count"), "AreaEffect tick stats must include hit_count");
assert(areaEffect.includes("status_apply_count"), "AreaEffect tick stats must include status_apply_count");

const collectTickTargets = extractFunction(areaEffect, "_collect_tick_damage_targets");
assert(!collectTickTargets.includes("get_nodes_in_group"), "AreaEffect tick target collection must not scan the enemies group");
assert(collectTickTargets.includes("_candidate_body_order"), "AreaEffect tick target collection must iterate cached candidates");

const vortexSweep = extractFunction(vortex, "_damage_swept_targets");
assert(!vortexSweep.includes("get_nodes_in_group"), "ScorchingVortex swept damage must not scan the enemies group");

const vortexCluster = extractFunction(vortex, "_find_dense_cluster_center");
assert(!vortexCluster.includes("get_nodes_in_group"), "ScorchingVortex cluster targeting must not scan the enemies group");

assert(manager.includes("class_name AreaEffectManager"), "AreaEffectManager must declare class_name AreaEffectManager");
assert(manager.includes("register_area"), "AreaEffectManager must register active AoEs");
assert(manager.includes("unregister_area"), "AreaEffectManager must unregister active AoEs");
assert(manager.includes("request_tick"), "AreaEffectManager must gate AoE tick scheduling");
assert(manager.includes("tick_bucket"), "AreaEffectManager must expose tick bucket information");
assert(manager.includes("record_tick"), "AreaEffectManager must record AoE tick attribution");
assert(manager.includes("candidate_count"), "AreaEffectManager stats must include candidate_count");
assert(manager.includes("hit_count"), "AreaEffectManager stats must include hit_count");
assert(manager.includes("status_apply_count"), "AreaEffectManager stats must include status_apply_count");

assert(profiler.includes("area_effect_tick_stats"), "RealFullRunProfiler must write area_effect_tick_stats");
assert(profiler.includes("avg_candidate_count"), "Profiler AoE stats must include avg_candidate_count");
assert(profiler.includes("avg_hit_count"), "Profiler AoE stats must include avg_hit_count");
assert(profiler.includes("status_apply_count"), "Profiler AoE stats must include status_apply_count");

console.log("AoE tick candidate cache contract verified.");
