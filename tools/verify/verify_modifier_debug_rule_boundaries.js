const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
for (const family of ['fire', 'frost', 'lightning', 'arcane', 'hunter', 'holy', 'toxic', 'oil', 'acid', 'movement']) {
  const p = `scripts/skills/special_rules/${family}_rule_family.gd`;
  assert(fs.existsSync(path.join(root, p)), `behavior module exists: ${family}`);
  assert(read(p).includes('func '), `${family} contains behavior`);
}
const executor = read('scripts/skills/skill_special_rule_executor.gd');
for (const dead of ['_get_chill_status_params', '_get_charge_status_params', '_get_arcane_mark_status_params']) assert(!executor.includes(dead), `no-op removed: ${dead}`);
for (const page of ['run_setup', 'runtime', 'skill_cards', 'enemy_spawn', 'status', 'utility']) {
  const p = `scripts/debug/pages/dev_debug_${page}_page.gd`;
  assert(fs.existsSync(path.join(root, p)), `page module exists: ${page}`);
  assert(read(p).includes('func _build_'), `${page} owns layout`);
}
const source = read('scripts/debug/dev_debug_data_source.gd');
assert(!source.includes('JsonDataLoader'), 'debug queries configuration owner');
assert(!source.includes('skill.get("god_id"'), 'debug has no old skill field');
const modifiers = read('scripts/modifiers/modifier_source.gd');
assert(!modifiers.includes('to_source_blocks'), 'mixed wrapper parser removed');
console.log('[verify_modifier_debug_rule_boundaries] PASS');
