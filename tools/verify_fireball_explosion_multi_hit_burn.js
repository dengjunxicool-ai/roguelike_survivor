const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function main() {
  const areaEffect = read("scripts/combat/area_effect.gd");
  const executor = read("scripts/skills/skill_special_rule_executor.gd");
  const branches = JSON.parse(read("data/weapon_branches.json"));
  const burstBranch = branches.branches.find((branch) => branch.id === "fire_staff_branch_burst");
  assert(burstBranch, "fire_staff_branch_burst must exist");
  const burstLevel2Events = burstBranch.level_path?.["2"]?.events_added ?? [];
  const burstExplosionAction = burstLevel2Events
    .flatMap((event) => event.actions ?? [])
    .find((action) => action.type === "create_explosion");
  assert(burstExplosionAction, "Burst fireball Lv2 must create an explosion");
  assert(
    burstExplosionAction.params?.event_on_hit === "on_projectile_hit",
    "Burst fireball explosion must emit on_projectile_hit so explosion_multi_hit_burn can run for explosion targets"
  );

  assert(areaEffect.includes("_collect_tick_damage_targets"), "AreaEffect must collect all tick targets before applying area damage");
  assert(areaEffect.includes("_current_tick_targets_hit"), "AreaEffect must store current tick target count while emitting hit events");
  assert(areaEffect.includes('"explosion_targets_hit": _current_tick_targets_hit'), "AreaEffect hit event context must include explosion_targets_hit");
  assert(areaEffect.indexOf("var targets: Array[Node] = _collect_tick_damage_targets()") < areaEffect.indexOf("for body: Node in targets:"), "AreaEffect must compute hit count before per-target damage events");

  assert(executor.includes('context.get("explosion_targets_hit"'), "SkillSpecialRuleExecutor must read explosion_targets_hit for burst fireball burn");
  assert(executor.includes("explosion_multi_hit_burn"), "SkillSpecialRuleExecutor must keep burst fireball multi-hit burn rule");

  console.log("Fireball explosion multi-hit burn wiring verified.");
}

main();
