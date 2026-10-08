const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const diagnostics = {
  "damage_trace_context.gd": "uid://ckpwp6fa2lp3o",
  "debug_combat_trace.gd": "uid://chrfnu1b15mc7",
  "player_debug_overlay.gd": "uid://bhhuafkblfxt6",
  "debug_explosion_site_overlay.gd": "uid://35xlhm0c2lg1",
};

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function filesIn(relativePath) {
  const files = [];
  for (const entry of fs.readdirSync(path.join(root, relativePath), { withFileTypes: true })) {
    const relative = `${relativePath}/${entry.name}`;
    if (entry.isDirectory()) files.push(...filesIn(relative));
    else files.push(relative);
  }
  return files;
}

for (const relative of filesIn("scripts")) {
  if (!relative.endsWith(".gd") || relative.startsWith("scripts/debug/")) continue;
  const text = readTextFile(path.join(root, relative));
  const dependencies = [...text.matchAll(/\b(?:preload|load)\s*\(\s*["'](res:\/\/scripts\/debug\/[^"']+)["']/g)];
  for (const dependency of dependencies) {
    assert(
      relative === "scripts/ui/ui_manager.gd" && dependency[1] === "res://scripts/debug/dev_debug_panel.gd",
      `${relative} must not depend on debug tools: ${dependency[1]}`
    );
  }
}

for (const [file, uid] of Object.entries(diagnostics)) {
  const canonical = `scripts/runtime/${file}`;
  const former = `scripts/${"debug"}/${file}`;
  assert(fs.existsSync(path.join(root, canonical)), `${canonical} must exist`);
  assert(readTextFile(path.join(root, `${canonical}.uid`)).trim() === uid, `${canonical} must preserve its UID`);
  assert(!fs.existsSync(path.join(root, former)), `${former} must be removed`);
  assert(!fs.existsSync(path.join(root, `${former}.uid`)), `${former}.uid must be removed`);
  for (const relative of [...filesIn("scripts"), ...filesIn("tools"), ...filesIn("scenes")]) {
    if (!/\.(?:gd|js|tscn|tres)$/.test(relative)) continue;
    assert(!readTextFile(path.join(root, relative)).includes(former), `${relative} retains the former diagnostic path ${former}`);
  }
}

console.log("[verify_runtime_dependency_boundary] PASS");
