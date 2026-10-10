const fs = require('fs');
const assert = require('assert');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const data = JSON.parse(fs.readFileSync(path.join(root, 'data/skills/skills.json'), 'utf8'));
const skills = data.skills;
const rows = JSON.parse(fs.readFileSync(path.join(root, 'docs/skills/skill_rebalance_coverage.json'), 'utf8')).skills;
assert.equal(skills.length, 144);
assert.equal(new Set(skills.map(s => s.id)).size, 144);
const base = skills.filter(s => s.skill_type !== 'fusion');
const fusion = skills.filter(s => s.skill_type === 'fusion');
assert.equal(base.length, 84); assert.equal(fusion.length, 60);
const school = s => s.school || s.god_id;
const schools = ['fire', 'frost', 'thunder', 'curse', 'holy', 'chaos'];
for (const god of schools) assert.equal(base.filter(s => school(s) === god).length, 14, god);
for (let i = 0; i < 6; i++) for (let j = i + 1; j < 6; j++) {
  const pair = [schools[i], schools[j]].sort().join(':');
  assert.equal(fusion.filter(s => [school(s), s.fusion_school].sort().join(':') === pair).length, 4, pair);
}
const spec = fs.readFileSync(path.join(root, 'docs/superpowers/specs/2026-10-09-skill-system-rebalance-design.md'), 'utf8');
const casts = [...new Set(spec.match(/(?:fire|frost|thunder|curse|holy|chaos)_cast_\w+/g))];
assert.equal(casts.length, 18); for (const id of casts) assert(skills.some(s => s.id === id), id);
assert.equal(rows.length, 144); assert.equal(new Set(rows.map(s => s.id)).size, 144);
for (const s of skills) {
  const row = rows.find(r => r.id === s.id); assert(row, s.id);
  assert.equal(row.school, school(s)); assert.equal(row.skill_type, s.skill_type);
  assert(['baseline', 'proven', 'migrating', 'accepted'].includes(row.status));
  assert(Array.isArray(row.semantic_cases) && Array.isArray(row.legacy_assertions));
}
console.log('[verify_skill_rebalance_inventory] PASS 144 IDs, 84 base, 60 fusion, 18 cast milestones');
