const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.resolve(__dirname, '../..');
const content = JSON.parse(fs.readFileSync(path.join(root, 'data/upgrades/upgrades.json'), 'utf8'));
const definitions = new Set(Object.values(content).filter(Array.isArray).flat().map(x => x.id).filter(Boolean));
const source = fs.readFileSync(path.join(root, 'scripts/upgrades/run_reward_pool.gd'), 'utf8');
const refs = [...source.matchAll(/"upgrade_id"\s*:\s*&?"([^"]+)"/g)].map(x => x[1]);
assert(refs.length > 0, 'fixed reward references must be checked');
function validateReferences(knownDefinitions) {
  for (const id of refs) assert(knownDefinitions.has(id), `fixed reward references missing upgrade ${id}`);
}
validateReferences(definitions);
const missingDefinition = new Set(definitions);
missingDefinition.delete('boss_damage');
assert.throws(() => validateReferences(missingDefinition), /missing upgrade boss_damage/);
console.log(`[qa-reward-references] PASS ${refs.length} code-generated references; missing Boss upgrade rejected`);
