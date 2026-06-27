const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function main() {
  const enemyHealthStage = read("scripts/combat/application_stages/enemy_health_application_stage.gd");
  const enemyRewardController = read("scripts/enemies/enemy_reward_controller.gd");
  const specialHandler = read("scripts/skills/special_damage_rule_handler.gd");
  const deathExplosionStart = specialHandler.indexOf("func execute_burning_target_death_explosion");
  const deathExplosionEnd = specialHandler.indexOf("\n\nstatic func spawn_ground_fire_or_lava", deathExplosionStart);
  assert(deathExplosionStart >= 0 && deathExplosionEnd > deathExplosionStart, "Burst fireball death explosion function must exist");
  const deathExplosionHandler = specialHandler.slice(deathExplosionStart, deathExplosionEnd);
  const specialRuleExecutor = read("scripts/skills/skill_special_rule_executor.gd");
  const synergyData = JSON.parse(read("data/synergies.json"));
  const synergyManager = read("scripts/skills/synergy_manager.gd");

  assert(
    enemyHealthStage.includes("DamageTraceContextScript.persist_last_damage_trace"),
    "EnemyHealthApplicationStage must persist the killing damage trace context centrally"
  );
  assert(
    enemyRewardController.includes('"debug_attack_trace_id": DamageTraceContextScript.get_last_damage_trace_id(_owner)'),
    "EnemyRewardController must forward the killing damage trace context into on_enemy_killed"
  );
  assert(
    deathExplosionHandler.includes("packet = DamageTraceContextScript.apply_to_packet(packet, context)") && deathExplosionHandler.includes('"damage_packet": packet'),
    "Burst fireball death explosion must copy the enemy-kill debug trace id into its damage packet"
  );
  assert(
    deathExplosionHandler.includes('"source_id": &"fireball_burning_death_explosion"'),
    "Burst fireball death explosion area must expose fireball_burning_death_explosion as its area source id"
  );
  assert(
    deathExplosionHandler.includes('"area_id": &"generic_explosion_area"') &&
      deathExplosionHandler.includes('"radius": radius') &&
      deathExplosionHandler.includes('record_explosion(root, parent, position, radius, "fireball_burning_death_explosion"'),
    "Burst fireball death explosion must draw a circular explosion area with the same radius used for damage and debug trace"
  );
  assert(
    deathExplosionHandler.includes("DebugCombatTraceScript.record_explosion"),
    "Burst fireball death explosion must create a debug explosion record"
  );
  assert(
    deathExplosionHandler.includes('DamageIntentScript.create(target, packet, &"area_direct").call("apply")') &&
      deathExplosionHandler.includes('"damage": 0') &&
      deathExplosionHandler.includes('packet["source_type"] = "explosion"'),
    "Burst fireball death explosion must apply traced damage directly and leave AreaEffect as a visual/debug area"
  );
  assert(
    specialRuleExecutor.includes("DamageTraceContextScript") &&
      specialRuleExecutor.includes("DamageTraceContextScript.apply_to_status_params") &&
      specialRuleExecutor.includes("_apply_explosion_burn_rules"),
    "Burst fireball explosion burn must preserve debug trace id so burn DOT kills can trigger traceable fireball_burning_death_explosion records"
  );
  const debugPanel = read("scripts/debug/dev_debug_panel.gd");
  assert(
    debugPanel.includes('source_skill_id.find("fireball_burning_death_explosion")') && debugPanel.includes('return "爆裂小爆炸"'),
    "DevDebugPanel must label fireball_burning_death_explosion damage records"
  );

  assert(
    !synergyData.synergies.some((synergy) => synergy.id === "burn_explosion"),
    "Legacy burn_explosion synergy must not coexist with burst fireball Lv5 death explosion"
  );
  assert(
    !synergyManager.includes("burn_explosion") && !synergyManager.includes("_spawn_burn_explosion"),
    "SynergyManager must not emit legacy burn_explosion damage records"
  );
  assert(
    !synergyManager.includes('_build_reaction_source_packet(&"death_explosion"'),
    "SynergyManager must not trigger the legacy generic death_explosion reaction for burning deaths"
  );

  console.log("Burst fireball death explosion debug trace verified.");
}

main();
