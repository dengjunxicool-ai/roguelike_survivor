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

const factory = read("scripts/combat/combat_object_factory.gd");
const pool = read("scripts/runtime/runtime_object_pool.gd");
const areaEffect = read("scripts/combat/area_effect.gd");
const projectile = read("scripts/combat/projectile.gd");
const damageArea = read("scripts/combat/damage_area.gd");
const enemyActionExecutor = read("scripts/enemies/enemy_action_executor.gd");
const enemyActionRegistry = read("scripts/enemies/actions/enemy_action_registry.gd");

const createArea = extractFunction(factory, "create_area_effect");
const createProjectile = extractFunction(factory, "create_projectile");
const executorEnemyProjectile = extractFunction(enemyActionExecutor, "spawn_enemy_projectile");
const executorDamageArea = extractFunction(enemyActionExecutor, "spawn_damage_area_at");
const registryEnemyProjectile = extractFunction(enemyActionRegistry, "_execute_projectile");
const registryDamageArea = extractFunction(enemyActionRegistry, "_execute_damage_area");

assert(factory.includes("RuntimePoolRegistry"), "CombatObjectFactory must resolve RuntimePoolRegistry for combat scene-root pooling.");
assert(factory.includes("_spawn_pooled_combat_node"), "CombatObjectFactory must use a shared scene-root pool spawn helper.");
assert(createArea.includes("_spawn_pooled_combat_node"), "create_area_effect() must spawn whole area scene roots through the pool helper.");
assert(createProjectile.includes("_spawn_pooled_combat_node"), "create_projectile() must spawn whole projectile scene roots through the pool helper.");
assert(!createArea.includes("area_effect_scene.instantiate()"), "create_area_effect() must not directly instantiate the area root.");
assert(!createProjectile.includes("projectile_scene.instantiate()"), "create_projectile() must not directly instantiate the projectile root.");
assert(factory.includes("Engine.is_in_physics_frame()") && factory.includes('call_deferred("add_child"'), "Pooled combat scene spawn must preserve deferred add_child in physics frames.");
assert(factory.includes("prepare_for_pool_spawn"), "Factory must call prepare_for_pool_spawn() on pooled scene roots.");

for (const [label, body] of [
  ["EnemyActionExecutor.spawn_enemy_projectile", executorEnemyProjectile],
  ["EnemyActionExecutor.spawn_damage_area_at", executorDamageArea],
  ["EnemyActionRegistry._execute_projectile", registryEnemyProjectile],
  ["EnemyActionRegistry._execute_damage_area", registryDamageArea],
]) {
  assert(body.includes("_spawn_pooled_combat_node"), `${label} must use scene-root pooling.`);
  assert(!body.includes(".instantiate()"), `${label} must not directly instantiate pooled combat scene roots.`);
}

for (const [label, source] of [
  ["AreaEffect", areaEffect],
  ["Projectile", projectile],
  ["DamageArea", damageArea],
]) {
  assert(source.includes("func prepare_for_pool_spawn"), `${label} must implement prepare_for_pool_spawn().`);
  assert(source.includes("func prepare_for_pool_despawn"), `${label} must implement prepare_for_pool_despawn().`);
  assert(source.includes("func despawn_or_free"), `${label} must implement despawn_or_free().`);
  assert(source.includes("runtime_pool_owner") && source.includes("runtime_pool_key"), `${label} must fall back safely when no runtime pool owner/key metadata exists.`);
}

const areaFinish = extractFunction(areaEffect, "_finish_damage_window");
assert(areaFinish.includes("despawn_or_free()"), "AreaEffect normal finish must despawn_or_free() instead of queue_free().");
assert(extractFunction(areaEffect, "_on_visual_animation_finished").includes("despawn_or_free()"), "AreaEffect visual finish must despawn_or_free().");
assert(extractFunction(areaEffect, "_enforce_max_active").includes("despawn_or_free"), "AreaEffect max-active eviction must despawn_or_free().");

assert(extractFunction(projectile, "_physics_process").includes("despawn_or_free()"), "Projectile lifetime expiry must despawn_or_free().");
assert(extractFunction(projectile, "_play_hit_visual_then_free").includes("despawn_or_free()"), "Projectile hit finish fallback must despawn_or_free().");
assert(extractFunction(projectile, "_free_when_hit_visual_finishes").includes("despawn_or_free()"), "Projectile hit visual setup fallback must despawn_or_free().");
assert(extractFunction(projectile, "_on_hit_visual_finished").includes("despawn_or_free()"), "Projectile hit visual finish must despawn_or_free().");
assert(extractFunction(projectile, "_update_curve_trajectory").includes("despawn_or_free()"), "Projectile curve completion must despawn_or_free().");

assert(extractFunction(damageArea, "_physics_process").includes("despawn_or_free()"), "DamageArea expiry must despawn_or_free().");

assert(pool.includes("runtime_pool_owner"), "RuntimeObjectPool must tag spawned roots with their pool owner.");
assert(
  pool.indexOf("not is_instance_valid(candidate)") >= 0 &&
    pool.indexOf("not is_instance_valid(candidate)") < pool.indexOf("candidate is Node"),
  "RuntimeObjectPool must validate pooled candidates before any `is Node` type check, because freed references can error on `is`."
);

console.log("[verify_pr3_combat_scene_pool_contract] PASS");
