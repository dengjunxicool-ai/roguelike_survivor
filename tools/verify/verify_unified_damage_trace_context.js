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
  const traceContext = read("scripts/debug/damage_trace_context.gd");
  const skillEventBus = read("scripts/skills/skill_event_bus.gd");
  const packetBuilder = read("scripts/combat/damage_packet_builder.gd");
  const projectile = read("scripts/combat/projectile.gd");
  const areaEffect = read("scripts/combat/area_effect.gd");
  const orbitObject = read("scripts/combat/orbit_object.gd");
  const enemyHealthStage = read("scripts/combat/application_stages/enemy_health_application_stage.gd");
  const enemyRewardController = read("scripts/enemies/enemy_reward_controller.gd");
  const specialHandler = read("scripts/skills/special_damage_rule_handler.gd");

  assert(traceContext.includes("class_name DamageTraceContext"), "DamageTraceContext helper must exist");
  for (const method of [
    "static func normalize_event_context",
    "static func apply_to_packet",
    "static func apply_to_status_params",
    "static func apply_to_node_meta",
    "static func persist_last_damage_trace",
    "static func get_trace_id",
  ]) {
    assert(traceContext.includes(method), `DamageTraceContext must expose ${method}`);
  }

  assert(skillEventBus.includes("DamageTraceContextScript.normalize_event_context"), "SkillEventBus must normalize every skill event context");
  assert(packetBuilder.includes("DamageTraceContextScript.apply_to_packet(packet, context)"), "DamagePacketBuilder must apply trace context for skill action packets");
  assert(packetBuilder.includes("DamageTraceContextScript.apply_to_packet(packet, args)"), "DamagePacketBuilder must apply trace context for non-skill packet args");
  assert(projectile.includes("DamageTraceContextScript.apply_to_node_meta(self, params)"), "Projectile setup must persist trace through node meta");
  assert(projectile.includes("DamageTraceContextScript.normalize_event_context({"), "Projectile hit events must inherit trace through normalized context");
  assert(areaEffect.includes("DamageTraceContextScript.apply_to_node_meta(self, params)"), "AreaEffect setup must persist trace through node meta");
  assert(areaEffect.includes("DamageTraceContextScript.normalize_event_context({"), "AreaEffect hit events must inherit trace through normalized context");
  assert(orbitObject.includes("DamageTraceContextScript.apply_to_node_meta(self, params)"), "OrbitObject setup must persist trace through node meta");
  assert(orbitObject.includes("DamageTraceContextScript.normalize_event_context({"), "OrbitObject hit events must inherit trace through normalized context");
  assert(enemyHealthStage.includes("DamageTraceContextScript.persist_last_damage_trace"), "Enemy damage application must persist last damage trace context centrally");
  assert(enemyRewardController.includes("DamageTraceContextScript.get_last_damage_trace_id"), "Enemy death events must inherit last damage trace context centrally");
  assert(!specialHandler.includes("static func _copy_debug_trace"), "SpecialDamageRuleHandler must not keep local debug trace copy helper");
  assert(!specialHandler.includes("static func _with_debug_trace"), "SpecialDamageRuleHandler must not keep local debug trace wrapper");
  assert(!specialHandler.includes("_copy_debug_trace(packet, context)"), "SpecialDamageRuleHandler must not manually copy trace into packets");

  console.log("Unified damage trace context verified.");
}

main();
