const {
  ACTION_CONTRACTS,
  COMPONENT_CONTRACTS,
  DAMAGE_ORIGINS,
  EVENT_TRIGGERS,
  MODIFIER_KEYS,
  SPECIAL_RULE_KEYS,
  TARGETING_MODES,
  TARGETING_RULE_IDS,
} = require("./weapon_config_contracts");

function printList(title, items) {
  console.log(`\n## ${title}`);
  for (const item of items) {
    console.log(`- ${item}`);
  }
}

function printContracts(title, contracts) {
  console.log(`\n## ${title}`);
  for (const [name, contract] of Object.entries(contracts)) {
    const allowed = contract.allowedParams || [];
    const required = contract.requiredParams || [];
    const requiredAny = contract.requiredAnyParams || [];
    console.log(`\n### ${name}`);
    console.log(`allowed params: ${allowed.length ? allowed.join(", ") : "<none>"}`);
    if (required.length) {
      console.log(`required params: ${required.join(", ")}`);
    }
    for (const group of requiredAny) {
      console.log(`required one of: ${group.join(", ")}`);
    }
  }
}

console.log("# Weapon Config Contracts");
printContracts("Actions", ACTION_CONTRACTS);
printContracts("Components", COMPONENT_CONTRACTS);
printList("Event Triggers", EVENT_TRIGGERS);
printList("Targeting Modes", TARGETING_MODES);
printList("Targeting Rule Ids", TARGETING_RULE_IDS);
printList("Damage Origins", DAMAGE_ORIGINS);
printList("Modifier Keys", MODIFIER_KEYS);
printList("Special Rule Keys", SPECIAL_RULE_KEYS);
