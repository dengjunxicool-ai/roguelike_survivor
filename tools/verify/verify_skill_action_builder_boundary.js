const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const projectileBuilder = readTextFile(path.join(root, "scripts", "skills", "skill_action_projectile_builder.gd"));
const areaBuilder = readTextFile(path.join(root, "scripts", "skills", "skill_action_area_builder.gd"));
const executor = readTextFile(path.join(root, "scripts", "skills", "skill_action_executor.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name) {
  const start = source.indexOf(`func ${name}(`);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

function staticFunctionBody(source, name) {
  const start = source.indexOf(`static func ${name}(`);
  if (start < 0) return "";
  const next = source.indexOf("\nstatic func ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

assert(
  executor.includes('const SkillActionProjectileBuilderScript: Script = preload("res://scripts/skills/skill_action_projectile_builder.gd")'),
  "SkillActionExecutor must preload SkillActionProjectileBuilder.",
);
assert(
  executor.includes('const SkillActionAreaBuilderScript: Script = preload("res://scripts/skills/skill_action_area_builder.gd")'),
  "SkillActionExecutor must preload SkillActionAreaBuilder.",
);

for (const method of [
  "resolve_same_target_spawn_delay",
  "build_same_target_hit_params",
  "filter_damage_actions",
  "normalize_status_ids",
  "build_runtime_data",
]) {
  assert(staticFunctionBody(projectileBuilder, method) !== "", `SkillActionProjectileBuilder.${method} must exist.`);
}

const projectileDelegates = new Map([
  ["_same_target_projectile_spawn_delay", "resolve_same_target_spawn_delay"],
  ["_projectile_params_for_same_target_hit", "build_same_target_hit_params"],
  ["_damage_only_actions", "filter_damage_actions"],
  ["_build_projectile_runtime_data", "build_runtime_data"],
  ["_get_projectile_runtime_statuses_on_hit", "normalize_status_ids"],
]);

const forbiddenProjectileAlgorithmMarkers = new Map([
  ["_same_target_projectile_spawn_delay", ["same_target_hit_index <= 0"]],
  ["_projectile_params_for_same_target_hit", ["same_target_repeat_damage_only", "duplicate(true)"]],
  ["_damage_only_actions", ["action_variant", 'action.get("type"']],
  ["_build_projectile_runtime_data", ["StringName(str(projectile_stats"]],
  ["_get_projectile_runtime_statuses_on_hit", ["statuses.append"]],
]);

for (const [executorMethod, builderMethod] of projectileDelegates) {
  const body = functionBody(executor, executorMethod);
  assert(body !== "", `SkillActionExecutor.${executorMethod} must remain as a compatibility helper.`);
  assert(body.includes(`SkillActionProjectileBuilderScript.${builderMethod}`), `${executorMethod} must delegate to ${builderMethod}.`);
  for (const marker of forbiddenProjectileAlgorithmMarkers.get(executorMethod) || []) {
    assert(!body.includes(marker), `${executorMethod} must not retain moved algorithm marker: ${marker}`);
  }
}

const executeAction = functionBody(executor, "execute_action");
assert(executeAction.includes('"spawn_projectile"'), "execute_action must retain spawn_projectile dispatch.");
assert(executeAction.includes('"spawn_projectiles_at_targets"'), "execute_action must retain spawn_projectiles_at_targets dispatch.");
assert(executeAction.includes('"spawn_area"'), "execute_action must retain spawn_area dispatch.");
assert(executeAction.includes('"instant_area_hit"'), "execute_action must retain instant_area_hit dispatch.");

assert(
  staticFunctionBody(areaBuilder, "build_instant_hit_visual_params") !== "",
  "SkillActionAreaBuilder.build_instant_hit_visual_params must exist.",
);

const instantVisual = functionBody(executor, "_instant_area_hit_visual_params");
assert(instantVisual !== "", "SkillActionExecutor._instant_area_hit_visual_params must remain as a compatibility helper.");
assert(
  instantVisual.includes("SkillActionAreaBuilderScript.build_instant_hit_visual_params"),
  "_instant_area_hit_visual_params must delegate to SkillActionAreaBuilder.",
);
for (const marker of ["var visual_params", 'params.has(key)', 'definition.has(key)']) {
  assert(!instantVisual.includes(marker), `_instant_area_hit_visual_params must not retain moved algorithm marker: ${marker}`);
}

console.log("[verify_skill_action_builder_boundary] PASS");
