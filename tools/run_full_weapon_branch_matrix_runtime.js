const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const reportDir = path.join(root, "reports", "combat-scene-checks");
const mode = String(process.argv[2] || "smoke").trim();
const godotBin = process.env.GODOT_BIN || "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe";

const consoleLogs = {
  smoke: path.join(reportDir, "full_weapon_branch_matrix_smoke_console.log"),
  rules: path.join(reportDir, "full_weapon_branch_matrix_rules_console.log"),
};

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (!Object.prototype.hasOwnProperty.call(consoleLogs, mode)) {
  fail(`Unsupported full weapon branch matrix mode: ${mode}`);
}

fs.mkdirSync(reportDir, { recursive: true });

const result = spawnSync(godotBin, [
  "--headless",
  "--path",
  ".",
  "--script",
  "res://scripts/debug/full_weapon_branch_matrix_check.gd",
  "--",
  `--mode=${mode}`,
], {
  cwd: root,
  encoding: "utf8",
  windowsHide: true,
  maxBuffer: 64 * 1024 * 1024,
});

const output = `${result.stdout || ""}${result.stderr || ""}`;
fs.writeFileSync(consoleLogs[mode], output, "utf8");

const reportPath = path.join(reportDir, `full_weapon_branch_matrix_${mode}.json`);
if (fs.existsSync(reportPath)) {
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  const summary = report.summary || {};
  console.log(`${mode} ${summary.passed_cases || 0}/${summary.total_cases || 0} failed=${summary.failed_cases || 0}`);
}

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status || 0);
