const fs = require('node:fs');
const path = require('node:path');

function readDebugPanelSources(root) {
  const directory = path.join(root, 'scripts/debug/pages');
  return fs.readdirSync(directory).filter(name => /^dev_debug_.*_page\.gd$/.test(name)).map(name => fs.readFileSync(path.join(directory, name), 'utf8')).join('\n') + '\n' + fs.readFileSync(path.join(root, 'scripts/debug/dev_debug_panel.gd'), 'utf8');
}

function readSpecialRuleSources(root) {
  const directory = path.join(root, 'scripts/skills/special_rules');
  return fs.readFileSync(path.join(root, 'scripts/skills/skill_special_rule_executor.gd'), 'utf8') + '\n' + fs.readdirSync(directory).filter(name => name.endsWith('_rule_family.gd')).map(name => fs.readFileSync(path.join(directory, name), 'utf8')).join('\n');
}

module.exports = { readDebugPanelSources, readSpecialRuleSources };

function readActionSources(root) {
  const names = ["skill_action_executor.gd", "skill_action_support.gd", ...["projectile", "area", "status", "summon", "modifier"].map(f => `skill_action_${f}_executor.gd`)];
  return names.map(name => fs.readFileSync(path.join(root, "scripts/skills", name), "utf8")).join("\n");
}
module.exports.readActionSources = readActionSources;
