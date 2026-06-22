const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const errors = [];

function rel(filePath) {
  return path.relative(root, filePath).replaceAll(path.sep, "/");
}

function walk(dir, result = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === ".godot" || entry.name === ".codegraph") continue;
    const filePath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(filePath, result);
    } else if (entry.isFile()) {
      result.push(filePath);
    }
  }
  return result;
}

function fail(where, message) {
  errors.push(`${where}: ${message}`);
}

function scanJson(value, where) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => scanJson(item, `${where}[${index}]`));
    return;
  }
  if (value === null || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    if (key === "enable_evolution_check") {
      fail(`${where}.${key}`, "Lv5 evolution check marker is no longer allowed");
    }
    scanJson(child, `${where}.${key}`);
  }
}

function main() {
  const evolutionsPath = path.join(root, "data", "weapon_evolutions.json");
  if (fs.existsSync(evolutionsPath)) {
    const evolutions = readJsonFile(evolutionsPath).evolutions || [];
    if (evolutions.length > 0) {
      fail("data/weapon_evolutions.json", `must not contain active evolution configs, found ${evolutions.length}`);
    }
  }

  const primaryAttacks = readJsonFile(path.join(root, "data", "primary_attack.json")).primary_attacks || [];
  for (const attack of primaryAttacks) {
    const attackId = String(attack.id || "");
    if (attackId.endsWith("_evolved") || attackId.includes("_evolved_")) {
      fail(`data/primary_attack.json.${attackId}`, "evolved primary attack definitions are no longer allowed");
    }
    const displayText = `${attack.display_name || ""} ${attack.description || ""}`;
    if (
      displayText.includes("\u7ec8\u5f0f") ||
      displayText.includes("缁堝紡") ||
      displayText.toLowerCase().includes("evolution")
    ) {
      fail(`data/primary_attack.json.${attackId}`, "terminal evolution display text is no longer allowed");
    }
  }

  scanJson(readJsonFile(path.join(root, "data", "weapon_branches.json")), "data/weapon_branches.json");

  const designDir = path.join(root, "docs", "weapon_design_configs");
  for (const name of fs.readdirSync(designDir).filter((item) => item.endsWith(".json"))) {
    scanJson(readJsonFile(path.join(designDir, name)), `docs/weapon_design_configs/${name}`);
  }

  const bannedSourcePatterns = [
    { pattern: "WeaponEvolutionSystem", message: "WeaponEvolutionSystem runtime hook remains" },
    { pattern: "weapon_evolution_system.gd", message: "weapon evolution script reference remains" },
    { pattern: "get_available_evolution", message: "evolution availability check remains" },
    { pattern: "apply_evolution", message: "evolution application remains" },
    { pattern: "get_weapon_evolution", message: "weapon evolution data accessor remains" },
    { pattern: "get_weapon_evolution_pool", message: "weapon evolution pool accessor remains" },
    { pattern: "get_weapon_evolution_definitions", message: "weapon evolution definitions accessor remains" },
    { pattern: "mark_weapon_evolved", message: "weapon evolved state mutation remains" },
    { pattern: "is_equipped_weapon_evolved", message: "weapon evolved state query remains" },
    { pattern: "evolution:", message: "evolution upgrade option id remains" },
    { pattern: "enable_evolution_check", message: "Lv5 evolution check marker remains" },
  ];

  const sourceExtensions = new Set([".gd", ".js"]);
  for (const filePath of walk(root)) {
    const relative = rel(filePath);
    if (relative === "tools/validate_no_weapon_evolution.js") continue;
    if (relative.startsWith("tools/archive/")) continue;
    if (!sourceExtensions.has(path.extname(filePath))) continue;
    const text = fs.readFileSync(filePath, "utf8");
    for (const check of bannedSourcePatterns) {
      if (text.includes(check.pattern)) {
        fail(relative, check.message);
      }
    }
  }

  for (const error of errors) console.error(`ERROR ${error}`);
  if (errors.length > 0) {
    process.exitCode = 1;
    return;
  }
  console.log("Weapon evolution removal validation passed.");
}

main();
