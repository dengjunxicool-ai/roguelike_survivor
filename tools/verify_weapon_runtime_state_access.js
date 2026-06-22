const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const scriptsDir = path.join(root, "scripts");
const forbiddenReads = [
  'runtime.get("selected_branch_id")',
];
const forbiddenSnippets = [
  {
    file: path.normalize("scripts/player/player_controller.gd"),
    snippet: "func reset_for_run(",
    message: "Player/loadout flow must use reset_for_loadout(RunLoadout), not reset_for_run.",
  },
  {
    file: path.normalize("scripts/ui/ui_manager.gd"),
    snippet: '"character_id": _selected_character_id',
    message: "Run start context must pass RunLoadout only, not legacy character_id.",
  },
  {
    file: path.normalize("scripts/ui/ui_manager.gd"),
    snippet: '"weapon_id": _selected_weapon_id',
    message: "Run start context must pass RunLoadout only, not legacy weapon_id.",
  },
  {
    file: path.normalize("scripts/weapons/weapon_skill_binding.gd"),
    snippet: 'runtime.has_method("get_equipped_weapon_skill_id")',
    message: "Weapon runtime APIs are required; do not probe get_equipped_weapon_skill_id.",
  },
  {
    file: path.normalize("scripts/weapons/weapon_branch_system.gd"),
    snippet: 'runtime.has_method("get_selected_weapon_branch_id")',
    message: "Weapon runtime APIs are required; do not probe get_selected_weapon_branch_id.",
  },
  {
    file: path.normalize("scripts/upgrades/upgrade_pool.gd"),
    snippet: 'runtime.has_method("get_equipped_weapon_id")',
    message: "Weapon runtime APIs are required; do not probe get_equipped_weapon_id.",
  },
  {
    file: path.normalize("scripts/upgrades/upgrade_pool.gd"),
    snippet: 'runtime.has_method("get_equipped_weapon_skill_id")',
    message: "Weapon runtime APIs are required; do not probe get_equipped_weapon_skill_id.",
  },
];

function walk(dir, result = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, result);
    } else if (entry.isFile() && entry.name.endsWith(".gd")) {
      result.push(fullPath);
    }
  }
  return result;
}

function main() {
  const errors = [];
  for (const filePath of walk(scriptsDir)) {
    const relativePath = path.normalize(path.relative(root, filePath));
    const text = fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
    for (const forbiddenRead of forbiddenReads) {
      let index = text.indexOf(forbiddenRead);
      while (index !== -1) {
        const line = text.slice(0, index).split(/\r?\n/).length;
        errors.push(`${relativePath}:${line} directly reads ${forbiddenRead}; use CharacterRuntime accessors.`);
        index = text.indexOf(forbiddenRead, index + forbiddenRead.length);
      }
    }
    for (const { file, snippet, message } of forbiddenSnippets) {
      if (relativePath !== file) {
        continue;
      }
      const index = text.indexOf(snippet);
      if (index !== -1) {
        const line = text.slice(0, index).split(/\r?\n/).length;
        errors.push(`${relativePath}:${line} ${message}`);
      }
    }
  }

  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log("Weapon runtime state access verified.");
}

main();
