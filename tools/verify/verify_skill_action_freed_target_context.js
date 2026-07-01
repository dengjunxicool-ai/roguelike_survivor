const { spawnSync } = require("child_process");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const godot = "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe";
const result = spawnSync(godot, [
  "--headless",
  "--path",
  ".",
  "--script",
  "res://tools/verify/verify_skill_action_freed_target_context.gd",
], {
  cwd: root,
  encoding: "utf8",
});

const output = `${result.stdout || ""}${result.stderr || ""}`;
process.stdout.write(output);

if (result.status !== 0) {
  process.exit(result.status || 1);
}

if (output.includes("Trying to cast a freed object") || output.includes("SCRIPT ERROR")) {
  throw new Error("freed target context verification must not emit script errors");
}

if (!output.includes("[verify_skill_action_freed_target_context] PASS")) {
  throw new Error("freed target context verification did not report PASS");
}
