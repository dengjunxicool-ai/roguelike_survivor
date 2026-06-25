const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const effectAdapter = read("scripts/skills/skill_effect_adapter.gd");
const triggerAdapter = read("scripts/skills/skill_trigger_rule_adapter.gd");
const eventBus = read("scripts/skills/skill_event_bus.gd");
const actionExecutor = read("scripts/skills/skill_action_executor.gd");
const areaEffect = read("scripts/combat/area_effect.gd");
const projectile = read("scripts/combat/projectile.gd");
const playerController = read("scripts/player/player_controller.gd");

for (const effectType of [
  "damage",
  "apply_status",
  "spawn_area",
  "spawn_projectile",
  "spawn_summon",
  "add_modifier",
  "grant_shield",
  "heal",
  "pull",
  "knockback",
  "repeat_skill",
  "transform_area",
  "transfer_status",
  "consume_status_duration",
  "trigger_overload",
  "shatter_frozen",
  "spawn_projectile_burst",
  "repeat_area_path",
  "spawn_area_from_existing_area",
]) {
  assert(effectAdapter.includes(`"${effectType}"`), `SkillEffectAdapter must map ${effectType}`);
}

for (const trigger of ["attack_hit", "enemy_death", "status_max_stack_reached", "projectile_hit", "area_tick", "player_damage_taken"]) {
  assert(triggerAdapter.includes(`"${trigger}"`), `SkillTriggerRuleAdapter must normalize ${trigger}`);
}

assert(effectAdapter.includes("power_scale"), "SkillEffectAdapter must normalize power_scale");
assert(effectAdapter.includes("actions_on_tick"), "SkillEffectAdapter must adapt nested tick effects");
assert(triggerAdapter.includes("counter_key"), "SkillTriggerRuleAdapter must support counters");
assert(triggerAdapter.includes("cooldown"), "SkillTriggerRuleAdapter must support cooldown");
assert(triggerAdapter.includes("_normalize_conditions"), "SkillTriggerRuleAdapter must normalize flat conditions");
assert(triggerAdapter.includes('"enemy_death": &"on_enemy_killed"'), "enemy_death must map to existing kill event");
assert(triggerAdapter.includes('"player_damage_taken": &"on_player_damaged"'), "player_damage_taken must map to existing player damage event");
assert(eventBus.includes("SkillTriggerRuleAdapterScript"), "SkillEventBus must use SkillTriggerRuleAdapter");
assert(eventBus.includes("can_execute_rule_event"), "SkillEventBus must apply rule counter/cooldown guards");
assert(eventBus.includes("get_all_skills"), "SkillEventBus must evaluate owned trigger rules");
assert(eventBus.includes("execute_adapted_actions"), "SkillEventBus must expose inline adapted action execution");
assert(playerController.includes('emit_skill_event", &"on_player_damaged"'), "Player damage must emit skill rule events");
assert(playerController.includes('"skip_fire_passive_runtime"'), "Player damage rule event must avoid FireSkillRuntime double-run");
assert(playerController.includes('"target": self'), "Player damage rule context must expose the player as target");
for (const actionField of ["actions_on_apply", "actions_on_tick", "actions_on_hit", "actions_on_expire", "actions_on_death"]) {
  assert(areaEffect.includes(actionField), `AreaEffect must store ${actionField}`);
  assert(areaEffect.includes(`_execute_adapted_actions(${actionField}`), `AreaEffect must consume ${actionField}`);
}
assert(areaEffect.includes("func _execute_apply_actions") && areaEffect.includes("impact_target"), "AreaEffect apply actions must run with a concrete target");
assert(areaEffect.includes("actions_on_tick.is_empty()") && areaEffect.includes("actions_on_hit.is_empty()") && areaEffect.includes("actions_on_death.is_empty()"), "AreaEffect tick path must not skip action-only areas");
assert(projectile.includes("actions_on_hit") && projectile.includes("_execute_adapted_actions(actions_on_hit"), "Projectile must consume nested hit actions");
for (const existingAction of ["deal_damage", "apply_status", "spawn_area", "spawn_projectile", "spawn_summon", "heal_owner", "knockback", "add_temporary_modifier"]) {
  assert(actionExecutor.includes(`"${existingAction}"`), `SkillActionExecutor must support existing action ${existingAction}`);
}

console.log("[verify_skill_rule_adapters] PASS");
