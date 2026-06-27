const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const scriptsRoot = path.join(root, "scripts");
const ignoredDirectories = new Set([".git", ".godot", "node_modules"]);

const patterns = [
  {
    label: "take_damage numeric argument",
    regex: /\btake_damage\s*\(\s*[-+]?\d+(?:\.\d+)?\b/,
  },
  {
    label: "call(\"take_damage\", numeric argument)",
    regex: /\bcall\s*\(\s*&?["']take_damage["']\s*,\s*[-+]?\d+(?:\.\d+)?\b/,
  },
  {
    label: "DamageSystem.calculate numeric argument",
    regex: /\bDamageSystemScript\.calculate(?:_result)?\s*\(\s*[-+]?\d+(?:\.\d+)?\b/,
  },
  {
    label: "DamageApplicationService numeric argument",
    regex: /\bDamageApplicationServiceScript\.apply(?:_player|_enemy)?_damage\s*\([^,\n]+,\s*[-+]?\d+(?:\.\d+)?\b/,
  },
];

function walk(directory, files = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name)) {
        walk(path.join(directory, entry.name), files);
      }
      continue;
    }
    if (entry.isFile() && entry.name.endsWith(".gd")) {
      files.push(path.join(directory, entry.name));
    }
  }
  return files;
}

const failures = [];
for (const filePath of walk(scriptsRoot)) {
  const relativePath = path.relative(root, filePath).replace(/\\/g, "/");
  const lines = readTextFile(filePath).split(/\r?\n/);
  lines.forEach((line, index) => {
    for (const pattern of patterns) {
      if (pattern.regex.test(line)) {
        failures.push(`${relativePath}:${index + 1} ${pattern.label}: ${line.trim()}`);
      }
    }
  });
}

if (failures.length > 0) {
  console.error("[verify_no_numeric_damage_inputs] FAIL");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("[verify_no_numeric_damage_inputs] PASS");
