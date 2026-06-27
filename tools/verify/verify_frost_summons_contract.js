const path = require("path");
const { readJsonFile, readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function findSummon(summons, id) {
  const summon = summons.find((entry) => entry && entry.id === id);
  assert(summon, `${id} summon definition must exist`);
  return summon;
}

function hasChilledEffect(summon) {
  return ((summon.attack || {}).on_hit_effects || []).some((effect) => {
    return effect && effect.type === "apply_status" && (effect.status === "chilled" || effect.status_id === "chilled");
  });
}

const summons = readJson("data/summons.json").summons || [];
const frostWolf = findSummon(summons, "summon_frost_wolf");
assert(frostWolf.scene_path === "res://scenes/summon_controller.tscn", "frost wolf must reuse summon controller scene");
assert(hasChilledEffect(frostWolf), "frost wolf must apply chilled on hit");
assert((frostWolf.targeting || {}).target_priority === "frozen_first_then_nearest", "frost wolf must prefer Frozen targets before nearest enemies");

const iceCrystalGuard = findSummon(summons, "ice_crystal_guard");
assert(iceCrystalGuard.scene_path === "res://scenes/summon_controller.tscn", "ice crystal guard must reuse summon controller scene");
assert((iceCrystalGuard.movement || {}).movement_mode === "stationary", "ice crystal guard must use stationary movement mode");
assert((iceCrystalGuard.attack || {}).attack_type === "area_pulse", "ice crystal guard must use area pulse attacks");
assert(Number((iceCrystalGuard.attack || {}).pulse_radius) > 0, "ice crystal guard must define pulse_radius");
assert((iceCrystalGuard.attack || {}).pulse_area_id === "frost_ring", "ice crystal guard must spawn a visible frost pulse area");
assert(hasChilledEffect(iceCrystalGuard), "ice crystal guard pulse must apply chilled");

const targeting = read("scripts/summons/summon_targeting_component.gd");
assert(targeting.includes("frozen_first_then_nearest"), "SummonTargetingComponent must support frozen_first_then_nearest");
const movement = read("scripts/summons/summon_movement_component.gd");
assert(movement.includes("movement_mode") && movement.includes("stationary"), "SummonMovementComponent must support stationary movement mode");
const attack = read("scripts/summons/summon_attack_component.gd");
assert(attack.includes("area_pulse") && attack.includes("pulse_radius"), "SummonAttackComponent must support area pulse attacks");

console.log("[verify_frost_summons_contract] PASS");
