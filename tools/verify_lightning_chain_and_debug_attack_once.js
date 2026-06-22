const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function main() {
  const primaryAttacks = readJson("data/primary_attack.json").primary_attacks || [];
  const lightningOrb = primaryAttacks.find((attack) => attack.id === "lightning_orb");
  assert(lightningOrb, "lightning_orb primary attack must exist");
  const baseRules = lightningOrb.base_special_rules || {};
  const bounceRule = baseRules.lightning_chain_bounce || {};
  assert(Object.keys(bounceRule).length > 0, "base lightning_orb must define lightning_chain_bounce");
  assert(Number(bounceRule.bounce_count) === 2, "base lightning_orb bounce_count must be 2");
  assert(Number(bounceRule.range) === 260, "base lightning_orb bounce range must be 260");
  assert(Number(bounceRule.bounce_damage_multiplier) === 0.75, "base lightning_orb bounce multiplier must be 0.75");

  const handler = readText("scripts/skills/special_damage_rule_handler.gd");
  assert(handler.includes('rule.get("bounce_count"'), "lightning chain handler must read base bounce_count");
  assert(handler.includes('rule.get("range"'), "lightning chain handler must read base range");

  const debugPanel = readText("scripts/debug/dev_debug_panel.gd");
  const attackOnceIndex = debugPanel.indexOf("func _attack_once_player_skills() -> void:");
  assert(attackOnceIndex >= 0, "DevDebugPanel must expose attack once");
  const attackOnceBody = debugPanel.slice(attackOnceIndex, debugPanel.indexOf("\n\nfunc _clear_attack_trace", attackOnceIndex));
  assert(attackOnceBody.includes("_cast_player_skills_once(trace_id)"), "Attack once must cast real player skills with trace id");
  assert(!attackOnceBody.includes("_emit_weapon_hit_once(trace_id)"), "Attack once must not bypass runtime combat objects with a simulated hit fallback");
  assert(debugPanel.includes("func _cast_player_skills_once(trace_id: int = 0) -> int:"), "debug cast helper must accept trace id");

  const skillExecutor = readText("scripts/skills/skill_executor.gd");
  assert(skillExecutor.includes("func debug_cast_all_skills(debug_attack_trace_id: int = 0) -> int:"), "SkillExecutor debug cast must accept trace id");
  assert(skillExecutor.includes('"debug_attack_trace_id": debug_attack_trace_id'), "SkillExecutor must pass trace id into skill context");

  console.log("Lightning chain and debug attack once verified.");
}

main();
