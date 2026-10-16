const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

fs.mkdirSync("E:/codex/developer", { recursive: true });
const fixture = fs.mkdtempSync("E:/codex/developer/cpu-particle-guard-");
try {
  const verifier = path.join(fixture, "tools/verify/verify_no_cpu_particles_project_wide.js");
  fs.mkdirSync(path.dirname(verifier), { recursive: true });
  fs.mkdirSync(path.join(fixture, "tools/lib"), { recursive: true });
  fs.mkdirSync(path.join(fixture, "scripts"));
  fs.mkdirSync(path.join(fixture, "scenes"));
  fs.copyFileSync(path.join(__dirname, "verify_no_cpu_particles_project_wide.js"), verifier);
  fs.copyFileSync(path.join(__dirname, "../lib/json_file.js"), path.join(fixture, "tools/lib/json_file.js"));
  const run = () => spawnSync(process.execPath, [verifier], { encoding: "utf8", cwd: fixture });
  fs.writeFileSync(path.join(fixture, "tools/verify/visual.gd"), 'assert(not child is CPUParticles2D, "no CPU particles")\n');
  let result = run();
  assert.strictEqual(result.status, 0, "development visual assertions must not count as production CPU particles: " + result.stderr);
  const scriptPath = path.join(fixture, "scripts/effect.gd");
  fs.writeFileSync(scriptPath, "extends Node\nfunc make_effect():\n\treturn CPUParticles2D.new()\n");
  result = run();
  assert.strictEqual(result.status, 1, "production scripts creating CPU particles must fail");
  assert.match(result.stderr, /scripts\/effect\.gd:3/);
  fs.unlinkSync(scriptPath);
  fs.writeFileSync(path.join(fixture, "scenes/effect.tscn"), '[gd_scene format=3]\n[node name="Particles" type="CPUParticles2D"]\n');
  result = run();
  assert.strictEqual(result.status, 1, "production scenes containing CPU particles must fail");
  assert.match(result.stderr, /scenes\/effect\.tscn:2/);
  console.log("[verify_no_cpu_particles_guard] PASS tools assertions allowed; production scripts and scenes rejected");
} finally {
  if (!path.resolve(fixture).replace(/\\/g, "/").startsWith("E:/codex/developer/")) throw new Error("unsafe fixture path");
  fs.rmSync(fixture, { recursive: true, force: true });
}
