const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const primaryAttackPath = path.join(root, "data", "primary_attack.json");
const primaryAttackDocument = readJsonFile(primaryAttackPath);
const primaryAttacks = primaryAttackDocument.primary_attacks || [];
const weaponBranchesPath = path.join(root, "data", "weapon_branches.json");
const weaponBranchDocument = readJsonFile(weaponBranchesPath);
const weaponBranches = weaponBranchDocument.branches || [];

function findAttack(id) {
  return primaryAttacks.find((attack) => attack.id === id);
}

function getProjectileHitEvent(attack, sourceId) {
  return (attack.events || []).find((event) => {
    return event.trigger === "on_projectile_hit" && event.source_id === sourceId;
  });
}

function findBranch(id) {
  return weaponBranches.find((branch) => branch.id === id);
}

function getLevelConfig(branch, level) {
  const levelPath = branch.level_path || {};
  return levelPath[String(level)] || {};
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function hasModifierEffect(modifiers, expected) {
  return findModifierEffect(modifiers, expected) !== null;
}

function findModifierEffect(modifiers, expected) {
  for (const modifier of (Array.isArray(modifiers) ? modifiers : [])) {
    if (!modifier || typeof modifier !== "object") continue;
    if (modifier.stat !== expected.stat || modifier.op !== expected.op) continue;
    const scope = modifier.scope || {};
    let matches = true;
    for (const [key, value] of Object.entries(expected.scope || {})) {
      const actual = scope[key];
      if (Array.isArray(value)) {
        if (!Array.isArray(actual) || value.some((item) => !actual.includes(item))) {
          matches = false;
          break;
        }
      } else if (actual !== value) {
        matches = false;
        break;
      }
    }
    if (matches) return modifier;
  }
  return null;
}

function assertApprox(actual, expected, message, tolerance = 0.0001) {
  if (Math.abs(Number(actual) - expected) > tolerance) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

const baseFireball = findAttack("fireball");
assert(baseFireball, "Missing primary attack: fireball");
assert(!(baseFireball.tags || []).includes("explosion"), "Base fireball must not have explosion tag before choosing burst branch");

const baseFireballHitEvent = getProjectileHitEvent(baseFireball, "fireball_projectile");
assert(baseFireballHitEvent, "Base fireball must handle fireball_projectile hits");
const baseFireballHitActions = (baseFireballHitEvent.actions || []).map((action) => action.type);
assert(baseFireballHitActions.includes("deal_damage"), "Base fireball hit must include direct primary attack damage");
assert(!baseFireballHitActions.includes("create_explosion"), "Base fireball must not include explosion damage before choosing burst branch");

const burstBranch = findBranch("fire_staff_branch_burst");
assert(burstBranch, "Missing weapon branch: fire_staff_branch_burst");

const branchLevel2 = getLevelConfig(burstBranch, 2);
const branchLevel2Actions = ((branchLevel2.events_added || [])[0] || {}).actions || [];
assert(branchLevel2Actions.some((action) => action.type === "create_explosion"), "Burst branch level 2 must add explosion on selection");
const branchLevel2Explosion = branchLevel2Actions.find((action) => action.type === "create_explosion");
const branchLevel2ExplosionParams = branchLevel2Explosion.params || {};
assert(Number(branchLevel2ExplosionParams.damage_multiplier || 0) > 0, "Burst branch level 2 explosion damage_multiplier must be positive");
assert(branchLevel2ExplosionParams.damage_origin === "reaction", "Burst branch level 2 explosion must use reaction origin");
assert(branchLevel2ExplosionParams.damage_type === "area_direct", "Burst branch level 2 explosion must use area_direct damage_type");
assert(Number(branchLevel2ExplosionParams.max_targets || 0) === 4, "Burst branch level 2 explosion must start with 4 max targets");
assert((branchLevel2.tags_added || []).includes("explosion"), "Burst branch level 2 must add explosion tag on selection");
assert(hasModifierEffect(branchLevel2.modifiers, {
  stat: "radius",
  op: "multiplier_add",
  scope: { domain: "object", object_type: ["explosion"] },
}), "Burst branch level 2 must expose explosion radius multiplier effect");

const branchLevel3 = getLevelConfig(burstBranch, 3);
const branchLevel3Radius = findModifierEffect(branchLevel3.modifiers, {
  stat: "radius",
  op: "multiplier_add",
  scope: { domain: "object", object_type: ["explosion"] },
});
assert(branchLevel3Radius, "Burst branch level 3 must expose explosion radius multiplier effect");
assertApprox(branchLevel3Radius.value, 0.10, "Burst branch level 3 explosion radius multiplier must match design");
const branchLevel3Damage = findModifierEffect(branchLevel3.modifiers, {
  stat: "damage",
  op: "multiplier_add",
  scope: { domain: "object", object_type: ["explosion"] },
});
assert(branchLevel3Damage, "Burst branch level 3 must expose explosion damage multiplier effect");
assertApprox(branchLevel3Damage.value, 0.18, "Burst branch level 3 explosion damage multiplier must match design");
const branchLevel3AttackSpeed = findModifierEffect(branchLevel3.modifiers, {
  stat: "attack_speed",
  op: "multiplier_add",
  scope: { domain: "skill" },
});
assert(branchLevel3AttackSpeed, "Burst branch level 3 must expose attack interval tradeoff");
assertApprox(branchLevel3AttackSpeed.value, -0.0741, "Burst branch level 3 attack speed penalty must produce about +8% cooldown");
assert(!branchLevel3.special_rules || !branchLevel3.special_rules.direct_hit_extra_explosion_bonus, "Burst branch level 3 must not keep table-external direct hit explosion bonus");

const branchLevel4 = getLevelConfig(burstBranch, 4);
const branchLevel4Radius = findModifierEffect(branchLevel4.modifiers, {
  stat: "radius",
  op: "multiplier_add",
  scope: { domain: "object", object_type: ["explosion"] },
});
assert(branchLevel4Radius, "Burst branch level 4 must expose explosion radius multiplier effect");
assertApprox(branchLevel4Radius.value, 0.15, "Burst branch level 4 explosion radius multiplier must match design");
const branchLevel4MaxTargets = findModifierEffect(branchLevel4.modifiers, {
  stat: "max_targets",
  op: "add",
  scope: { domain: "object", object_type: ["explosion"] },
});
assert(branchLevel4MaxTargets, "Burst branch level 4 must expose explosion max target increase");
assertApprox(branchLevel4MaxTargets.value, 2, "Burst branch level 4 explosion max target increase must match design");

const branchLevel5 = getLevelConfig(burstBranch, 5);
const deathExplosion = (((branchLevel5.special_rules || {}).burning_target_death_explosion) || {});
assert(deathExplosion.enabled === true, "Burst branch level 5 must enable burning target death explosion");
assertApprox(deathExplosion.damage_multiplier, 0.35, "Burst branch level 5 death explosion damage multiplier must match design");
assert(Number(deathExplosion.max_targets || 0) === 6, "Burst branch level 5 death explosion must cap at 6 targets");
assertApprox(deathExplosion.same_source_cooldown, 0.25, "Burst branch level 5 death explosion cooldown must match design");
assert(deathExplosion.can_trigger_self === false, "Burst branch level 5 death explosion must not recurse");

console.log("Primary attack config checks passed.");
