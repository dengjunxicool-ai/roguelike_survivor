const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function approx(actual, expected, message) {
  assert(Math.abs(Number(actual) - expected) <= 0.0001, `${message}: expected ${expected}, got ${actual}`);
}

const statuses = readJson("data/combat/status_effects.json").statuses || [];
const byId = new Map();
for (const status of statuses) {
  assert(status && typeof status === "object" && !Array.isArray(status), "every status must be an object");
  assert(typeof status.id === "string" && status.id.length > 0, "every status must have an id");
  assert(!byId.has(status.id), `duplicate status ${status.id}`);
  byId.set(status.id, status);
}

const requiredIds = ["burning", "chilled", "frozen", "conductive", "overload", "cursed", "judgment", "instability"];
for (const id of requiredIds) {
  assert(byId.has(id), `missing status ${id}`);
}

const burning = byId.get("burning");
assert(burning.type === "dot", "burning must be dot");
approx(burning.duration, 4.0, "burning duration");
approx(burning.tick_interval, 0.5, "burning tick interval");
assert(burning.max_stacks === 5, "burning max_stacks");
assert(burning.consume_stack_on_tick === true, "burning must consume one stack per tick");
assert(burning.damage_type === "status_dot", "burning damage_type");
assert(burning.element === "fire", "burning element");
assert(burning.can_crit === false, "burning can_crit");
assert(burning.visual && burning.visual.sprite_frames === "res://assets/effect/burn/burn.tres", "burning visual sprite_frames");
assert(Array.isArray(burning.on_tick_effects), "burning must use on_tick_effects");
assert(
  burning.on_tick_effects.some((effect) =>
    effect.type === "damage" &&
    effect.damage_type === "fire" &&
    effect.source_type === "status" &&
    effect.power_scale === 0.18
  ),
  "burning must tick 0.18P fire status damage"
);

const chilled = byId.get("chilled");
approx(chilled.duration, 6.0, "chilled duration");
assert(chilled.max_stacks === 7, "chilled max_stacks");
assert(chilled.effect && chilled.effect.move_slow_per_stack === 0.06, "chilled move slow per stack");
assert(chilled.max_stack_status === "frozen", "chilled must convert to frozen at max stack");

const frozen = byId.get("frozen");
assert(frozen.type === "hard_control", "frozen must be hard_control");
assert(frozen.max_stacks === 1, "frozen max_stacks");
approx(frozen.duration, 1.2, "frozen duration");
approx(frozen.elite_duration, 0.5, "frozen elite duration");
approx(frozen.boss_duration, 0.15, "frozen boss duration");
assert(frozen.effect && frozen.effect.move_slow_per_stack === 1.0, "frozen must lock movement");

const conductive = byId.get("conductive");
approx(conductive.duration, 5.0, "conductive duration");
assert(conductive.max_stacks === 5, "conductive max_stacks");
assert(
  conductive.effect && conductive.effect.lightning_damage_taken_multiplier_add_per_stack === 0.06,
  "conductive lightning vulnerability per stack"
);
assert(conductive.max_stack_status === "overload", "conductive must create overload at max stack");

const overload = byId.get("overload");
assert(overload.type === "instant", "overload must be instant");
assert(overload.max_stacks === 1, "overload max_stacks");

const cursed = byId.get("cursed");
approx(cursed.duration, 3.0, "cursed duration");
assert(cursed.max_stacks === 3, "cursed max_stacks");
assert(Array.isArray(cursed.on_expire), "cursed must define expiration effects");
assert(
  cursed.on_expire.some((effect) =>
    effect.type === "damage" &&
    effect.damage_type === "curse" &&
    effect.source_type === "status" &&
    effect.power_scale_per_stack === 0.75
  ),
  "cursed must expire for 0.75P curse damage per stack"
);

const judgment = byId.get("judgment");
approx(judgment.duration, 6.0, "judgment duration");
assert(judgment.max_stacks === 5, "judgment max_stacks");
assert(judgment.max_stack_event === "divine_punishment", "judgment max stack event");

const instability = byId.get("instability");
approx(instability.duration, 6.0, "instability duration");
assert(instability.max_stacks === 4, "instability max_stacks");
assert(instability.max_stack_event === "fission", "instability max stack event");

console.log("[verify_fire_status_contract] PASS");
