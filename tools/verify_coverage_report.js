#!/usr/bin/env node

const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { readJsonFile, readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");
const toolPath = path.join(root, "tools", "coverage_report.js");

function write(filePath, text) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, text, "utf8");
}

function runCoverage(fixtureRoot, args = []) {
  return spawnSync(process.execPath, [
    toolPath,
    "--root", fixtureRoot,
    "--source", "scripts",
    "--tests", "tests",
    "--json-out", "reports/coverage/coverage-summary.json",
    "--md-out", "reports/coverage/coverage-report.md",
    ...args,
  ], {
    cwd: root,
    encoding: "utf8",
  });
}

function main() {
  assert.ok(fs.existsSync(toolPath), "coverage_report.js should exist");

  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "coverage-report-fixture-"));
  write(path.join(fixtureRoot, "scripts", "player.gd"), [
    "extends Node",
    "",
    "func covered_func() -> int:",
    "\treturn 1",
    "",
    "func uncovered_func() -> int:",
    "\treturn 2",
    "",
  ].join("\n"));
  write(path.join(fixtureRoot, "scripts", "enemy.gd"), [
    "extends Node",
    "",
    "func enemy_func() -> int:",
    "\treturn 3",
    "",
  ].join("\n"));
  write(path.join(fixtureRoot, "tests", "player_check.gd"), [
    "extends SceneTree",
    "",
    "const PlayerScript = preload(\"res://scripts/player.gd\")",
    "",
    "func _init() -> void:",
    "\tvar player = PlayerScript.new()",
    "\tplayer.covered_func()",
    "\tquit(0)",
    "",
  ].join("\n"));

  const failingGate = runCoverage(fixtureRoot, ["--min-functions", "75", "--min-files", "50"]);
  assert.notStrictEqual(failingGate.status, 0, "coverage gate should fail when function coverage is below threshold");
  assert.match(failingGate.stdout + failingGate.stderr, /function coverage/i, "failure output should mention function coverage");

  const passingGate = runCoverage(fixtureRoot, ["--min-functions", "30", "--min-files", "50"]);
  assert.strictEqual(passingGate.status, 0, passingGate.stdout + passingGate.stderr);

  const summaryPath = path.join(fixtureRoot, "reports", "coverage", "coverage-summary.json");
  const reportPath = path.join(fixtureRoot, "reports", "coverage", "coverage-report.md");
  assert.ok(fs.existsSync(summaryPath), "coverage summary JSON should be written");
  assert.ok(fs.existsSync(reportPath), "coverage Markdown report should be written");

  const summary = readJsonFile(summaryPath);
  assert.strictEqual(summary.totals.functions.total, 3, "should count all source functions");
  assert.strictEqual(summary.totals.functions.covered, 1, "should count referenced source functions");
  assert.strictEqual(summary.totals.files.total, 2, "should count all source files");
  assert.strictEqual(summary.totals.files.covered, 1, "should count files with at least one covered function");
  assert.ok(summary.uncovered.functions.some((item) => item.name === "uncovered_func"), "should list uncovered function");
  assert.ok(summary.uncovered.functions.some((item) => item.name === "enemy_func"), "should list uncovered function from uncovered file");

  const report = readTextFile(reportPath);
  assert.match(report, /Function Coverage/, "Markdown report should include function coverage");
  assert.match(report, /uncovered_func/, "Markdown report should include uncovered function names");

  console.log("Coverage report verification passed.");
}

main();
