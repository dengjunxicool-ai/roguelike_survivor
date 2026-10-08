// Explicit offline migration. Production readers never accept these aliases.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
function canonicalSkill(skill) {
  const result = structuredClone(skill);
  result.display_name = result.display_name ?? result.name;
  result.school = result.school ?? result.god_id;
  result.skill_type = result.skill_type ?? result.type ?? (result.category === 'active' ? 'cast' : result.category);
  result.slot_category = result.slot_category ?? (result.skill_type === 'passive' ? 'passive' : 'active');
  if (result.replaces_starting_skill != null) result.replaces_skill = result.replaces_starting_skill;
  for (const field of ['name', 'god_id', 'type', 'category', 'replaces_starting_skill']) delete result[field];
  return result;
}
if (require.main === module) {
  const file = path.join(root, 'data/skills/skills.json');
  const document = JSON.parse(fs.readFileSync(file, 'utf8'));
  // The starting projectile is an explicit attack method, not a generic cast.
  document.starting_skills = document.starting_skills.map(s => canonicalSkill({...s, skill_type: s.skill_type ?? 'attack'}));
  document.skills = document.skills.map(canonicalSkill);
  fs.writeFileSync(file, JSON.stringify(document, null, '\t') + '\n');
}
module.exports = {canonicalSkill};
