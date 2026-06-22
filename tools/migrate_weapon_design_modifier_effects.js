const fs = require("fs");
const path = require("path");

const DESIGN_CONFIG_DIR = path.resolve("docs", "weapon_design_configs");

function main() {
  const files = fs
    .readdirSync(DESIGN_CONFIG_DIR)
    .filter((name) => name.endsWith(".json"))
    .sort();

  for (const fileName of files) {
    const filePath = path.join(DESIGN_CONFIG_DIR, fileName);
    const document = JSON.parse(fs.readFileSync(filePath, "utf8"));
    const migratedCount = migrateNode(document);
    fs.writeFileSync(filePath, `${JSON.stringify(document, null, 2)}\n`, "utf8");
    console.log(`[weapon-design-modifier-migration] ${fileName}: ${migratedCount} runtime_modifiers blocks`);
  }
}

function migrateNode(value) {
  if (Array.isArray(value)) {
    return value.reduce((count, item) => count + migrateNode(item), 0);
  }
  if (!isObject(value)) {
    return 0;
  }

  let migratedCount = 0;
  for (const key of Object.keys(value)) {
    if (key === "runtime_modifiers") {
      value[key] = convertRuntimeModifiers(value[key]);
      migratedCount += 1;
      continue;
    }
    migratedCount += migrateNode(value[key]);
  }
  return migratedCount;
}

function convertRuntimeModifiers(value) {
  if (Array.isArray(value)) {
    return value.map((effect) => {
      if (!isObject(effect) || !effect.stat || !effect.op || !effect.scope) {
        throw new Error(`runtime_modifiers array contains a non-effect item: ${JSON.stringify(effect)}`);
      }
      return effect;
    });
  }
  if (!isObject(value)) {
    return [];
  }
  return Object.entries(value).map(([legacyKey, legacyValue]) => mapLegacyModifier(legacyKey, legacyValue));
}

function mapLegacyModifier(key, value) {
  switch (key) {
    case "attack_speed_multiplier_add":
      return effect("attack_speed", "multiplier_add", value, { domain: "skill" });
    case "damage_multiplier_add":
      return effect("damage", "multiplier_add", value, { domain: "skill" });
    case "direct_damage_multiplier_add":
      return effect("damage", "multiplier_add", value, {
        domain: "damage",
        damage_origin: ["primary_attack"],
      });
    case "projectile_speed_multiplier_add":
      return effect("projectile_speed", "multiplier_add", value, { domain: "skill" });
    case "skill_area_multiplier_add":
      return effect("radius", "multiplier_add", value, { domain: "skill" });
    default:
      throw new Error(`No weapon design runtime modifier mapping for '${key}'`);
  }
}

function effect(stat, op, value, scope) {
  return { stat, op, value, scope };
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

main();
