const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const targetExtensions = new Set([".gd", ".tscn"]);
const forbidden = "CPUParticles2D";
const ignoredDirectories = new Set([".git", ".godot", "node_modules"]);

function walk(directory, files = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name)) {
        walk(path.join(directory, entry.name), files);
      }
      continue;
    }
    if (entry.isFile() && targetExtensions.has(path.extname(entry.name))) {
      files.push(path.join(directory, entry.name));
    }
  }
  return files;
}

const failures = [];
for (const filePath of walk(root)) {
  const text = readTextFile(filePath);
  if (!text.includes(forbidden)) continue;
  const relativePath = path.relative(root, filePath).replace(/\\/g, "/");
  const lines = text.split(/\r?\n/);
  lines.forEach((line, index) => {
    if (line.includes(forbidden)) {
      failures.push(`${relativePath}:${index + 1}`);
    }
  });
}

if (failures.length > 0) {
  console.error("[verify_no_cpu_particles_project_wide] FAIL");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("[verify_no_cpu_particles_project_wide] PASS");
