const fs = require("fs");
const path = require("path");

const DATA_FILES = [
  "data/upgrades.json",
  "data/relics.json",
  "data/characters.json",
  "data/weapon_branches.json",
  "data/challenges.json",
];

const MODIFIER_CONTAINER_KEYS = new Set([
  "modifiers",
  "modifiers_per_stack",
  "full_stack_modifiers",
  "active_modifiers",
  "penalty_modifiers",
  "base_modifiers",
  "base_penalties",
  "shield_active_modifiers",
  "skill_modifiers",
  "negative_modifier",
  "positive_modifier",
  "effect",
]);

function main() {
  for (const relativePath of DATA_FILES) {
    const absolutePath = path.resolve(relativePath);
    const document = JSON.parse(fs.readFileSync(absolutePath, "utf8"));
    migrateNode(document, [relativePath], relativePath);
    fs.writeFileSync(absolutePath, `${JSON.stringify(document, null, "\t")}\n`, "utf8");
    console.log(`[modifier-migration] migrated ${relativePath}`);
  }
}

function migrateNode(value, jsonPath, filePath) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => migrateNode(item, jsonPath.concat(String(index)), filePath));
    return;
  }
  if (!isObject(value)) {
    return;
  }

  for (const key of Object.keys(value)) {
    const childPath = jsonPath.concat(key);
    if (key === "level_modifiers" && Array.isArray(value[key])) {
      value[key] = value[key].map((entry, index) =>
        convertModifierValue(entry, childPath.concat(String(index)), filePath)
      );
      continue;
    }
    if (MODIFIER_CONTAINER_KEYS.has(key)) {
      value[key] = convertModifierValue(value[key], childPath, filePath);
      continue;
    }
    migrateNode(value[key], childPath, filePath);
  }
}

function convertModifierValue(value, jsonPath, filePath) {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => convertModifierValue(item, jsonPath.concat(String(index)), filePath));
  }
  if (!isObject(value)) {
    return [];
  }
  if (Object.prototype.hasOwnProperty.call(value, "stat") && Object.prototype.hasOwnProperty.call(value, "value")) {
    return [convertLegacyEntry(value.stat, value.value, jsonPath, filePath, value)];
  }
  return Object.entries(value).flatMap(([legacyKey, legacyValue]) => {
    if (legacyValue === null || legacyValue === undefined) {
      return [];
    }
    return [convertLegacyEntry(legacyKey, legacyValue, jsonPath, filePath)];
  });
}

function convertLegacyEntry(legacyKey, value, jsonPath, filePath, source = {}) {
  const effect = mapLegacyKey(String(legacyKey), value, jsonPath, filePath);
  for (const preservedKey of ["source", "id", "display_name", "description"]) {
    if (Object.prototype.hasOwnProperty.call(source, preservedKey)) {
      effect[preservedKey] = source[preservedKey];
    }
  }
  return effect;
}

function mapLegacyKey(key, value, jsonPath, filePath) {
  const scope = defaultScope(jsonPath, filePath);
  const effect = (stat, op = "add", extraScope = {}, extra = {}) => ({
    stat,
    op,
    value,
    scope: cleanupScope({ ...scope, ...extraScope }),
    ...extra,
  });

  const exact = {
    max_hp_add: () => effect("max_hp"),
    armor_add: () => effect("armor"),
    attack_speed_multiplier_add: () => effect("attack_speed", "multiplier_add"),
    move_speed_multiplier_add: () => effect("move_speed", "multiplier_add", { domain: "player" }),
    pickup_radius_add: () => effect("pickup_radius"),
    pickup_radius_multiplier_add: () => effect("pickup_radius", "multiplier_add"),
    crit_chance_add: () => effect("crit_chance"),
    luck_add: () => effect("luck"),
    main_progression_weight_add: () => effect("main_progression_weight", "add", { domain: "progression" }),
    pre_boss_blessing_options_add: () => effect("pre_boss_blessing_options", "add", { domain: "progression" }),
    heal: () => effect("heal"),
    coin_gain_multiplier_add: () => effect("coin_gain", "multiplier_add", { domain: "economy" }),
    soul_gain_multiplier_add: () => effect("soul_gain", "multiplier_add", { domain: "economy" }),
    enemy_spawn_count_multiplier_add: () => effect("enemy_spawn_count", "multiplier_add", { domain: "enemy_spawn" }),
    boss_hp_multiplier_add: () => effect("boss_hp", "multiplier_add", { domain: "enemy_spawn" }),
    damage_taken_multiplier_add: () => effect("damage_taken", "multiplier_add", { domain: "player" }),
    status_duration_multiplier_add: () => effect("status_duration", "multiplier_add", { domain: "player" }),
    skill_area_multiplier_add: () => effect("radius", "multiplier_add", { domain: "player" }),
    projectile_speed_multiplier_add: () => effect("projectile_speed", "multiplier_add", { domain: "skill" }),
    projectile_count_add: () => effect("projectile_count", "add", { domain: "skill" }),
    trap_interval_multiplier_add: () => effect("trap_interval", "multiplier_add", { domain: "skill", tag: ["trap"] }),
    damage_multiplier_add: () => effect("damage", "multiplier_add", inferredDamageScope(jsonPath, filePath)),
    equipped_weapon_damage_add: () => effect("damage", "multiplier_add", { domain: "damage", damage_origin: ["primary_attack"] }),
    direct_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", damage_origin: ["primary_attack"] }),
    dot_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", damage_origin: ["status_dot"] }),
    reaction_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", damage_origin: ["reaction"] }),
    boss_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", target_type: ["boss"] }),
    fire_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", element: ["fire"] }),
    poison_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", element: ["poison"] }),
    acid_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "damage", element: ["acid"] }),
    explosion_damage_multiplier_add: () => effect("damage", "multiplier_add", { domain: "object", object_type: ["explosion"] }),
    explosion_radius_multiplier_add: () => effect("radius", "multiplier_add", { domain: "object", object_type: ["explosion"] }),
    burn_damage_multiplier_add: () => effect("status_damage", "multiplier_add", { domain: "status", status_id: ["burn"] }),
    burn_duration_add: () => effect("status_duration", "add", { domain: "status", status_id: ["burn"] }),
    burn_max_stacks_add: () => effect("status_max_stacks", "add", { domain: "status", status_id: ["burn"] }),
    boss_burn_max_stacks_add: () => effect("status_max_stacks", "add", { domain: "status", status_id: ["burn"], target_type: ["boss"] }),
    burn_move_speed_multiplier_add_per_stack: () =>
      effect("status_move_speed", "multiplier_add", { domain: "status", status_id: ["burn"] }, { application: "per_stack" }),
    lava_duration_add: () => effect("duration", "add", { domain: "object", object_type: ["lava"] }),
    lava_radius_multiplier_add: () => effect("radius", "multiplier_add", { domain: "object", object_type: ["lava"] }),
  };

  if (!exact[key]) {
    throw new Error(`No modifier mapping for '${key}' at ${jsonPath.join(".")}`);
  }
  return exact[key]();
}

function defaultScope(jsonPath, filePath) {
  const pathText = jsonPath.join(".");
  if (filePath.includes("weapon_branches")) {
    return { domain: "skill" };
  }
  if (pathText.includes(".skill_modifiers")) {
    return { domain: "skill" };
  }
  if (filePath.includes("relics") && pathText.endsWith(".modifiers")) {
    return { domain: "skill" };
  }
  return { domain: "player" };
}

function inferredDamageScope(jsonPath, filePath) {
  if (filePath.includes("weapon_branches") || jsonPath.join(".").includes(".skill_modifiers")) {
    return { domain: "skill" };
  }
  return { domain: "damage" };
}

function cleanupScope(scope) {
  return Object.fromEntries(
    Object.entries(scope).filter(([, value]) => {
      if (Array.isArray(value)) {
        return value.length > 0;
      }
      return value !== "" && value !== null && value !== undefined;
    })
  );
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

main();
