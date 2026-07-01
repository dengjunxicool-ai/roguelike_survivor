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
const burning = statuses.find((item) => item.id === "burning");

assert(!burn, "legacy burn status must be removed; use burning");
assert(burning, "burning status must exist");
assert(burning.type === "dot", "burning must be a DOT status");
assertApprox(burning.duration, 4, "burning duration");
assertApprox(burning.tick_interval, 0.5, "burning tick interval");
assert(burning.max_stacks === 5, "burning max stacks must be 5");
assert(burning.consume_stack_on_tick === true, "burning must consume one stack per tick");
assert(burning.damage_type === "status_dot", "burning damage_type must be status_dot");
assert(burning.element === "fire", "burning element must be fire");
assert(burning.can_crit === false, "burning must not crit");
assert(burning.refresh_rule === "refresh_duration", "burning must refresh duration when stacked");
assert(statusManagerSource.includes('"ignore_target_class_origin_modifier": _is_boss() or _is_elite()'), "status DOT ticks must mark target-class modifier as already applied for elite/Boss");
assert(packetBuilderSource.includes('"ignore_target_class_origin_modifier"'), "status DOT packets must preserve ignore_target_class_origin_modifier");
assert(mitigationSource.includes('packet.get("ignore_target_class_origin_modifier"') && mitigationSource.includes('packet_value", "ignore_target_class_origin_modifier"'), "damage target mitigation must honor ignore_target_class_origin_modifier");

console.log("Burning status table verified.");
