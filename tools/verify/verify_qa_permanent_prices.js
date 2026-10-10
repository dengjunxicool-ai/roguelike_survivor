const assert = require('node:assert/strict');
const {loadAndValidate, validateDocuments} = require('../validate/validate_content_configs');
const {schema, documents} = loadAndValidate();
for (const field of ['cost_base', 'cost_growth']) {
  let invalid = structuredClone(documents);
  delete invalid['res://data/upgrades/upgrades.json'].permanent_upgrades[0][field];
  assert(validateDocuments(invalid, schema).some(e => e.includes(field)), `missing ${field} rejected`);
  for (const value of [0, -1, '100', Infinity, NaN]) {
    invalid = structuredClone(documents);
    invalid['res://data/upgrades/upgrades.json'].permanent_upgrades[0][field] = value;
    assert(validateDocuments(invalid, schema).some(e => e.includes(field)), `invalid ${field}=${value} rejected`);
  }
}
const invalid = structuredClone(documents);
invalid['res://data/upgrades/upgrades.json'].permanent_upgrades[0].cost_growth = 0.5;
assert(validateDocuments(invalid, schema).some(e => e.includes('cost_growth')), 'shrinking growth rejected');
assert.deepEqual(loadAndValidate().errors, [], 'canonical content validates');
console.log('Permanent upgrade pricing validation passed.');
