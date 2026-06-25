const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
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
    factory.includes('parent.call_deferred("add_child", projectile)'),
  "CombatObjectFactory.create_projectile must defer add_child during physics frame to avoid flushing-query Area2D errors."
);
assert(
  factory.indexOf('projectile.call(&"setup", object_params)') < factory.indexOf('parent.call_deferred("add_child", projectile)'),
  "CombatObjectFactory.create_projectile must setup projectiles before deferred add_child so physics state is configured off-tree."
);

console.log("Projectile physics flush safety verified.");
