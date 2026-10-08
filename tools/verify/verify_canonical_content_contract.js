const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const load = p => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8'));
const skills = load('data/skills/skills.json');
for (const skill of [...skills.starting_skills, ...skills.skills]) {
  for (const alias of ['name', 'god_id', 'type', 'category', 'replaces_starting_skill']) {
    assert(!Object.hasOwn(skill, alias), `${skill.id}: obsolete skill field ${alias}`);
  }
  assert.equal(typeof skill.display_name, 'string', `${skill.id}: display_name`);
  assert.equal(typeof skill.school, 'string', `${skill.id}: school`);
  assert.equal(typeof skill.skill_type, 'string', `${skill.id}: skill_type`);
  assert(['active', 'passive'].includes(skill.slot_category), `${skill.id}: explicit slot_category`);
}
const facade = fs.readFileSync(path.join(root, 'scripts/game/game_data.gd'), 'utf8');
assert(!facade.includes('_document_cache'), 'GameData must not own a second cache');
assert(!facade.includes('JsonDataLoader'), 'GameData must not load JSON');
assert(!facade.includes('learn_fire_skill_'), 'old learn prefix must be absent');
assert(!facade.includes('get_primary_attack('), 'unused primary attack config alias must be removed');
console.log('Canonical skill fields and single-owner boundary passed.');
