const operations = { _multiplier_add: 'multiplier_add', _multiplier: 'multiply', _override: 'override', _add: 'add' };

// Offline migration only. Runtime never guesses operations from configuration keys.
function canonicalEffectList(value, source) {
  if (Array.isArray(value)) {
    return value.map(effect => ({ ...effect, op: effect.op === 'multiplier' ? 'multiply' : effect.op === 'set' ? 'override' : effect.op, scope: effect.scope ?? {}, source: effect.source ?? source }));
  }
  return Object.entries(value ?? {}).map(([key, amount]) => {
    const suffix = Object.keys(operations).find(candidate => key.endsWith(candidate));
    return { stat: suffix ? key.slice(0, -suffix.length) : key, op: operations[suffix] ?? 'raw', value: amount, scope: {}, source };
  });
}

function migrateModifierFields(value, source) {
  if (!value || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(item => migrateModifierFields(item, source));
  const result = {};
  for (const [key, entry] of Object.entries(value)) {
    if (key === 'level_modifiers') result[key] = entry.map(level => canonicalEffectList(level, source));
    else if (key === 'negative_modifier' || key === 'modifiers' || key === 'base_penalties' || key.endsWith('_modifiers') || key.startsWith('modifiers_')) result[key] = canonicalEffectList(entry, source);
    else result[key] = migrateModifierFields(entry, source);
  }
  return result;
}
module.exports = { canonicalEffectList, migrateModifierFields };
