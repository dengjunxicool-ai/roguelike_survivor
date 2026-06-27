const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertApprox(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(Number(actual) - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}

const statuses = readJson("data/combat/status_effects.json").statuses || [];
const statusManagerSource = readTextFile(path.join(root, "scripts", "combat", "status_effect_manager.gd"));
const packetBuilderSource = readTextFile(path.join(root, "scripts", "combat", "damage_packet_builder.gd"));
const mitigationSource = readTextFile(path.join(root, "scripts", "combat", "damage_target_mitigation.gd"));
const burn = statuses.find((item) => item.id === "burn");

assert(burn, "burn status must exist");
assert(burn.type === "dot", "burn must be a DOT status");
assertApprox(burn.duration, 3, "burn duration");
assertApprox(burn.tick_interval, 0.5, "burn tick interval");
assert(burn.max_stacks === 5, "burn max stacks must be 5");
assertApprox(burn.damage, 1.6, "burn single-stack tick damage");
assert(burn.damage_origin === "status_dot", "burn damage_origin must be status_dot");
assert(burn.damage_type === "status_dot", "burn damage_type must be status_dot");
assert(burn.element === "fire", "burn element must be fire");
assert(burn.can_crit === false, "burn must not crit");
assertApprox(burn.boss_modifiers?.dot_damage_multiplier, 0.65, "burn Boss DOT multiplier");
assert(burn.refresh_rule === "refresh_duration", "burn must refresh duration when stacked");
assert(statusManagerSource.includes('"ignore_target_class_origin_modifier": _is_boss() or _is_elite()'), "status DOT ticks must mark target-class modifier as already applied for elite/Boss");
assert(packetBuilderSource.includes('"ignore_target_class_origin_modifier"'), "status DOT packets must preserve ignore_target_class_origin_modifier");
assert(mitigationSource.includes('packet.get("ignore_target_class_origin_modifier"') && mitigationSource.includes('packet_value", "ignore_target_class_origin_modifier"'), "damage target mitigation must honor ignore_target_class_origin_modifier");

console.log("Burn status table verified.");
