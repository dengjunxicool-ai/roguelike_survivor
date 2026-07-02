const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const projectile = read("scripts/combat/projectile.gd");
const factory = read("scripts/combat/combat_object_factory.gd");

assert(
  !/^\s*monitoring\s*=\s*true/m.test(projectile),
  "Projectile.setup must not synchronously set monitoring=true; use set_deferred while physics queries may be flushing."
);
assert(
  !/^\s*monitorable\s*=\s*true/m.test(projectile),
  "Projectile.setup must not synchronously set monitorable=true; use set_deferred while physics queries may be flushing."
);
assert(
  projectile.includes('set_deferred("monitoring", true)') &&
    projectile.includes('set_deferred("monitorable", true)'),
  "Projectile.setup must enable monitoring/monitorable with set_deferred."
);
assert(
  factory.includes("Engine.is_in_physics_frame()") &&
    (factory.includes('parent.call_deferred("add_child", projectile)') || factory.includes('parent.call_deferred("add_child", node)')),
  "CombatObjectFactory projectile spawn path must defer add_child during physics frame to avoid flushing-query Area2D errors."
);
assert(
  factory.includes('projectile.call(&"prepare_for_pool_spawn", object_params)') || factory.includes('projectile.call(&"setup", object_params)'),
  "CombatObjectFactory.create_projectile must configure projectiles through prepare_for_pool_spawn/setup."
);

console.log("Projectile physics flush safety verified.");
