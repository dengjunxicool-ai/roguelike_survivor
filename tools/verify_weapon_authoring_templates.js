const { ACTION_CONTRACTS, COMPONENT_CONTRACTS } = require("./weapon_config_contracts");
const { buildWeaponScaffold, listArchetypes } = require("./weapon_authoring_templates");

function validateParams(params, contract, label, errors) {
  const allowed = new Set(contract.allowedParams || []);
  for (const key of Object.keys(params || {})) {
    if (!allowed.has(key)) {
      errors.push(`${label} uses unsupported param: ${key}`);
    }
  }
  for (const key of contract.requiredParams || []) {
    if (!params || !params[key]) {
      errors.push(`${label} is missing required param: ${key}`);
    }
  }
  for (const group of contract.requiredAnyParams || []) {
    if (!group.some((key) => params && params[key])) {
      errors.push(`${label} must define one of: ${group.join(", ")}`);
    }
  }
}

function validateAction(action, label, errors) {
  const actionType = String(action.type || "");
  const contract = ACTION_CONTRACTS[actionType];
  if (!contract) {
    errors.push(`${label} uses unsupported action type: ${actionType || "<empty>"}`);
    return;
  }
  validateParams(action.params || {}, contract, label, errors);
  for (const [index, nestedAction] of (action.params && action.params.actions ? action.params.actions : []).entries()) {
    validateAction(nestedAction, `${label}.actions[${index}]`, errors);
  }
}

function validateAttack(attack, label, errors) {
  for (const [index, component] of (attack.components || []).entries()) {
    const componentType = String(component.type || "");
    const contract = COMPONENT_CONTRACTS[componentType];
    if (!contract) {
      errors.push(`${label}.components[${index}] uses unsupported component type: ${componentType || "<empty>"}`);
      continue;
    }
    validateParams(component.params || {}, contract, `${label}.components[${index}]`, errors);
  }

  for (const [eventIndex, event] of (attack.events || []).entries()) {
    for (const [actionIndex, action] of (event.actions || []).entries()) {
      validateAction(action, `${label}.events[${eventIndex}].actions[${actionIndex}]`, errors);
    }
  }
}

function validateScaffold(archetype, errors) {
  const scaffold = buildWeaponScaffold({
    weaponId: `template_${archetype}`,
    characterId: "mage",
    displayName: `Template ${archetype}`,
    archetype,
    element: "arcane",
  });

  if (scaffold.branches.length !== 4) errors.push(`${archetype} must generate 4 branches.`);
  if (Object.prototype.hasOwnProperty.call(scaffold, "evolutions")) errors.push(`${archetype} must not generate evolutions.`);
  if (Object.prototype.hasOwnProperty.call(scaffold, "evolvedPrimaryAttacks")) errors.push(`${archetype} must not generate evolved attacks.`);
  validateAttack(scaffold.primaryAttack, `${archetype}.primaryAttack`, errors);
}

function main() {
  const errors = [];
  for (const archetype of listArchetypes()) {
    validateScaffold(archetype, errors);
  }

  if (errors.length) {
    for (const error of errors) console.error(`ERROR ${error}`);
    process.exitCode = 1;
    return;
  }

  console.log(`Weapon authoring templates verified. archetypes=${listArchetypes().length}`);
}

main();
