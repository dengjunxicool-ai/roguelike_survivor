const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const attacks = readJsonFile(path.join(root, "data", "primary_attack.json")).primary_attacks || [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertClose(actual, expected, message, epsilon = 0.0001) {
  assert(Math.abs(Number(actual) - expected) <= epsilon, `${message}: expected ${expected}, got ${actual}`);
}

const hailstorm = attacks.find((entry) => entry.id === "hailstorm");
assert(hailstorm, "hailstorm primary attack must exist");
const castEvent = (hailstorm.events || []).find((event) => event.trigger === "on_cast");
assert(castEvent, "hailstorm must have on_cast event");
const action = (castEvent.actions || []).find((entry) => entry.type === "spawn_projectiles_at_targets");
assert(action, "hailstorm must spawn projectiles at targets");

const sequence = action.params?.damage_multiplier_sequence || [];
assert(Array.isArray(sequence), "hailstorm damage_multiplier_sequence must be an array");
assert(sequence.length === 3, "hailstorm must define three projectile damage multipliers");
assertClose(sequence[0], 1.0, "hailstorm first projectile multiplier");
assertClose(sequence[1], 0.7, "hailstorm second projectile multiplier");
assertClose(sequence[2], 0.5, "hailstorm third projectile multiplier");

console.log("Hailstorm damage sequence config verified.");
