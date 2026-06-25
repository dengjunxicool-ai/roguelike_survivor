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

for (const effectType of ["damage", "apply_status", "spawn_area", "spawn_projectile", "spawn_summon", "grant_shield", "pull", "transfer_status"]) {
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
assert(eventBus.includes("SkillTriggerRuleAdapterScript"), "SkillEventBus must use SkillTriggerRuleAdapter");
assert(eventBus.includes("can_execute_rule_event"), "SkillEventBus must apply rule counter/cooldown guards");

console.log("[verify_skill_rule_adapters] PASS");
