const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");

const VALID_OPS = new Set(["add", "multiplier_add", "multiplier", "override"]);
const VALID_DOMAINS = new Set([
  "player",
  "skill",
  "damage",
  "status",
  "object",
  "economy",
  "enemy_spawn",
  "progression",
]);
const VALID_SCOPE_KEYS = new Set([
  "domain",
  "skill_id",
  "source_origin_id",
  "object_type",
  "damage_origin",
  "element",
  "target_type",
  "status_id",
  "tag",
]);
const VALID_STATS = new Set([
  "armor",
  "attack_speed",
  "boss_hp",
  "break_damage",
  "coin_gain",
  "crit_chance",
  "crit_damage",
  "damage",
  "damage_taken",
  "dot_damage",
  "duration",
  "enemy_spawn_count",
  "heal",
  "luck",
  "main_progression_weight",
  "max_targets",
  "max_hp",
  "max_active_traps",
  "move_speed",
  "pickup_radius",
  "pierce",
  "pre_boss_blessing_options",
  "projectile_count",
  "projectile_speed",
  "radius",
  "range",
  "shield_value",
  "soul_gain",
  "status_damage",
  "status_duration",
  "status_max_stacks",
  "status_move_speed",
  "trap_interval",
]);

const LEGACY_MODIFIER_KEY_PATTERN = /(?:_add|_multiplier|_multiplier_add|_override)$/;
const MODIFIER_CONTAINER_KEYS = new Set([
  "modifiers",
  "modifiers_per_stack",
  "full_stack_modifiers",
  "active_modifiers",
  "penalty_modifiers",
  "base_modifiers",
  "shield_active_modifiers",
  "skill_modifiers",
  "runtime_modifiers",
  "negative_modifier",
  "positive_modifier",
]);

const errors = [];

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function error(where, message) {
  errors.push(`${where}: ${message}`);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function checkModifierEffect(where, effect) {
  if (!isObject(effect)) {
    error(where, "modifier effect must be an object");
    return;
  }
  const stat = String(effect.stat || "");
  const op = String(effect.op || "");
  const scope = effect.scope;
  if (!VALID_STATS.has(stat)) {
    error(where, `invalid stat '${stat}'`);
  }
  if (!VALID_OPS.has(op)) {
    error(where, `invalid op '${op}'`);
  }
  if (typeof effect.value !== "number") {
    error(where, "value must be a number");
  }
  if (!isObject(scope)) {
    error(where, "scope must be an object");
  } else {
    for (const key of Object.keys(scope)) {
      if (!VALID_SCOPE_KEYS.has(key)) {
        error(where, `invalid scope key '${key}'`);
      }
    }
    const domain = String(scope.domain || "");
    if (!VALID_DOMAINS.has(domain)) {
      error(where, `invalid scope.domain '${domain}'`);
    }
  }
}

function checkModifierContainer(where, value) {
  if (!Array.isArray(value)) {
    error(where, "must be an array of structured modifier effects");
    return;
  }
  value.forEach((effect, index) => checkModifierEffect(`${where}[${index}]`, effect));
}

function walk(value, where) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => walk(item, `${where}[${index}]`));
    return;
  }
  if (!isObject(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const childWhere = `${where}.${key}`;
    if (MODIFIER_CONTAINER_KEYS.has(key)) {
      checkModifierContainer(childWhere, child);
      continue;
    }
    if (key === "level_modifiers") {
      if (!Array.isArray(child)) {
        error(childWhere, "must be an array of structured modifier effect arrays");
      } else {
        child.forEach((entry, index) => checkModifierContainer(`${childWhere}[${index}]`, entry));
      }
      continue;
    }
    walk(child, childWhere);
  }
}

function jsonFiles(dir) {
  const result = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      result.push(...jsonFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".json")) {
      result.push(fullPath);
    }
  }
  return result;
}

function main() {
  for (const filePath of jsonFiles(dataDir).sort()) {
    const relativePath = path.relative(root, filePath).replace(/\\/g, "/");
    walk(readJsonFile(filePath), relativePath);
  }

  for (const issue of errors) {
    console.error(`ERROR ${issue}`);
  }
  if (errors.length > 0) {
    process.exitCode = 1;
    return;
  }
  console.log("Modifier effect validation passed.");
}

main();
