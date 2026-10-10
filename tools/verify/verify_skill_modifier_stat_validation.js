const assert = require('assert');
const {loadAndValidate, validateDocuments} = require('../validate/validate_content_configs');
const result = loadAndValidate();
assert.deepEqual(result.errors, []);
const documents = structuredClone(result.documents);
documents['res://data/skills/skills.json'].skills[0].effects[0].stat = 'misspelled_nonexistent_damage';
const errors = validateDocuments(documents, result.schema, () => true);
assert(errors.some(e => e.includes('unknown modifier stat')), 'unknown stat must reject content publication');
console.log('[verify_skill_modifier_stat_validation] PASS');
