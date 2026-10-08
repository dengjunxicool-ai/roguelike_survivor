const fs = require('fs');
const assert = require('assert');
const read = p => fs.readFileSync(p, 'utf8');
const system = read('scripts/combat/damage_system.gd');
assert.match(system, /static func calculate\(packet: DamagePacket, target: Node\) -> DamageResult/);
for (const p of ['scripts/combat/damage_packet.gd', 'scripts/combat/damage_system.gd', 'scripts/combat/damage_application_context.gd', 'scripts/combat/damage_application_pipeline.gd', 'scripts/combat/damage_intent.gd']) {
  assert(!/legacy_damage_type|from_any|amount_or_packet/.test(read(p)), `${p}: compatibility damage input remains`);
}
for (const p of ['scripts/player/player_controller.gd', 'scripts/enemies/enemy_base.gd']) {
  assert.match(read(p), /func take_damage\(packet: DamagePacket\) -> void/);
}
const dispatch = read('scripts/skills/skill_action_executor.gd');
const modifierQuery = read('scripts/modifiers/modifier_query.gd');
const damageQuery = read('scripts/modifiers/damage_modifier_query.gd');
assert.match(modifierQuery, /static func for_damage\(packet: DamagePacket/);
assert.match(damageQuery, /static func make\(packet: DamagePacket/);
assert(!/for_damage_any|_packet_value|_resolve_target_type|has_method/.test(modifierQuery + damageQuery), 'damage modifier query must not accept duck inputs');
assert(!/for_damage_any/.test(read('scripts/skills/skill_action_support.gd')));
assert(system.includes('DamageModifierQueryScript.make(calculation_context.packet, calculation_context.attacker, calculation_context.target_profile)'), 'calculation query reads explicit typed context fields');
assert(!/packet\.get\("source_skill_id", packet\.get|packet\.get\("source_instance_id", packet\.get/.test(read('scripts/combat/damage_source_context.gd')), 'source identity must not fall back to legacy aliases');
for (const family of ['projectile', 'area', 'status', 'summon', 'modifier']) {
  assert(dispatch.includes(`skill_action_${family}_executor.gd`));
}
console.log('[verify_damage_strict_interfaces] PASS');
