const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const pool = read("scripts/runtime/runtime_object_pool.gd");
const registry = read("scripts/runtime/runtime_pool_registry.gd");
const damageNumber = read("scripts/combat/damage_number_popup.gd");
const statusManager = read("scripts/combat/status_effect_manager.gd");

for (const method of ["prewarm", "spawn", "despawn", "get_stats"]) {
  assert(pool.includes(`func ${method}`), `RuntimeObjectPool must expose ${method}().`);
}
assert(pool.includes("factory.call()"), "RuntimeObjectPool.spawn must instantiate through the supplied factory fallback.");
assert(pool.includes("_find_available_for_parent"), "RuntimeObjectPool must reuse nodes from the requested parent instead of reparenting pooled nodes.");
assert(!pool.includes("remove_child(node)"), "RuntimeObjectPool.despawn must not remove pooled nodes from the scene tree because profiler counts that as destruction churn.");
assert(pool.includes("set_meta(\"runtime_pool_key\"") || pool.includes("set_meta(&\"runtime_pool_key\"") || pool.includes("set_meta(POOL_KEY_META"), "RuntimeObjectPool must tag pooled nodes with their pool key.");

assert(registry.includes("runtime_pool_registry") || registry.includes("RuntimePoolRegistry"), "RuntimePoolRegistry must use a discoverable root metadata/child name.");
assert(registry.includes("get_or_create") && registry.includes("RuntimeObjectPool"), "RuntimePoolRegistry must create or resolve a RuntimeObjectPool without project autoload settings.");
assert(registry.includes("has_meta(ROOT_META_KEY)") && !registry.includes("get_meta(ROOT_META_KEY, null)"), "RuntimePoolRegistry must guard get_meta(ROOT_META_KEY) with has_meta().");

assert(damageNumber.includes("RuntimePoolRegistry") || damageNumber.includes("runtime_pool_registry"), "DamageNumberPopup must resolve the runtime pool registry.");
assert(damageNumber.includes("spawn(&\"DamageNumber\"") || damageNumber.includes("spawn(StringName(\"DamageNumber\")"), "DamageNumberPopup must spawn enemy damage labels from the runtime pool.");
assert(damageNumber.includes("spawn(&\"PlayerDamageNumber\"") || damageNumber.includes("spawn(StringName(\"PlayerDamageNumber\")"), "DamageNumberPopup must spawn player damage labels from the runtime pool.");
assert(damageNumber.includes("_reset_label") && damageNumber.includes("_release_label"), "DamageNumberPopup must reset and release pooled labels.");
assert(damageNumber.includes("has_meta(&\"damage_number_tween\")"), "DamageNumberPopup must guard damage_number_tween metadata reads with has_meta().");
assert(!damageNumber.includes("tween.tween_callback(label.queue_free)"), "DamageNumberPopup tween completion must return labels to the pool instead of queue_free().");

assert(statusManager.includes("_hide_status_visual") && statusManager.includes("visible = false"), "Status visual overlay must be hidden for reuse.");
assert(!/func _hide_status_visual\(\)[\s\S]*?queue_free\(\)/m.test(statusManager), "Status visual overlay must not be queue_free()'d during normal status clear.");

console.log("[verify_pr2_runtime_pool_contract] PASS");
