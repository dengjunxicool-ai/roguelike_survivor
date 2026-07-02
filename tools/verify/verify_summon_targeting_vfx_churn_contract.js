const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}
function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const targeting = read("scripts/summons/summon_targeting_component.gd");
assert(
  /func\s+update\s*\([^\)]*current_target\s*:\s*Variant/.test(targeting),
  "SummonTargetingComponent.update must accept current_target as Variant so freed Object references do not fail typed argument binding."
);
assert(
  /func\s+is_target_valid\s*\([^\)]*target\s*:\s*Variant/.test(targeting),
  "SummonTargetingComponent.is_target_valid must validate target as Variant before casting to Node2D."
);
assert(
  targeting.includes("target as Node2D"),
  "SummonTargetingComponent must cast only after the instance validity checks."
);

const controller = read("scripts/summons/summon_controller.gd");
assert(
  controller.includes("_get_valid_target()"),
  "SummonController must normalize possibly stale target references before targeting, attack, and movement use."
);
assert(
  !controller.includes("target = _targeting.update(delta, self, target,"),
  "SummonController must not pass the raw cached target directly into targeting update."
);

const executor = read("scripts/skills/skill_action_executor.gd");
assert(
  executor.includes("_restart_summon_particles"),
  "SkillActionExecutor must reuse the legacy summon spawn VFX node instead of creating SummonParticles every trigger."
);
assert(
  executor.includes('get_node_or_null("SummonParticles")'),
  "Legacy summon VFX must look up the existing SummonParticles child before allocating."
);
assert(
  !/func\s+_restart_summon_particles[\s\S]*?Callable\(particles,\s*"queue_free"\)/.test(executor),
  "Legacy summon spawn VFX must not schedule SummonParticles for destruction after every trigger."
);

console.log("[verify_summon_targeting_vfx_churn_contract] PASS");
