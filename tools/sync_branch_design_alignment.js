const fs = require("fs");
const path = require("path");
const { parseBranchDesignDocument } = require("./branch_design_doc");
const { readJsonFile, writeJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const docsDir = path.join(root, "docs", "weapon_design_configs");

function dataPath(fileName) {
  return path.join(root, "data", fileName);
}

function runtimeBranchIdForDocBranch(docBranch) {
  return String(docBranch.current_runtime_branch_id || docBranch.branch_id || "");
}

function levelSummary(designBranch, level) {
  return `${designBranch.archetypeLabel} Lv${level}: ${designBranch.levels[level]}`;
}

function branchDescription(designBranch) {
  const parts = [];
  if (designBranch.coreExperience) parts.push(designBranch.coreExperience);
  if (designBranch.cost) parts.push(`主要代价：${designBranch.cost}`);
  return parts.length > 0 ? parts.join("；") : `${designBranch.name}方向成长。`;
}

function updateDocBranch(docBranch, designBranch) {
  docBranch.display_name = designBranch.name;
  docBranch.levels = {
    2: designBranch.levels[2],
    3: designBranch.levels[3],
    4: designBranch.levels[4],
    5: designBranch.levels[5],
  };
  docBranch.damage_ownership = designBranch.damageOwnership;
  docBranch.boss_rule = designBranch.bossRule;
  docBranch.limits = designBranch.triggerLimit;
  docBranch.ui_feedback = designBranch.uiFeedback;

  const levelPath = docBranch.level_path || {};
  for (const level of ["2", "3", "4", "5"]) {
    const entry = levelPath[level];
    if (!entry) continue;
    entry.summary = levelSummary(designBranch, level);
    if (!entry.ui_feedback || typeof entry.ui_feedback !== "object" || Array.isArray(entry.ui_feedback)) {
      entry.ui_feedback = {};
    }
    entry.ui_feedback.hint = designBranch.uiFeedback;
    entry.ui_feedback.level_label = `Lv${level}`;
    entry.ui_feedback.readable_effect = designBranch.levels[level];
  }
}

function updateRuntimeBranch(runtimeBranch, designBranch) {
  runtimeBranch.display_name = designBranch.name;
  runtimeBranch.role = designBranch.archetypeLabel
    ? `${designBranch.archetypeLabel}：${designBranch.coreExperience}`
    : runtimeBranch.role;
  runtimeBranch.description = branchDescription(designBranch);

  const levelPath = runtimeBranch.level_path || {};
  for (const level of ["2", "3", "4", "5"]) {
    const entry = levelPath[level];
    if (!entry) continue;
    entry.display_name = `${designBranch.name} Lv${level}`;
    entry.description = designBranch.levels[level];
  }
}

function main() {
  const designWeapons = parseBranchDesignDocument();
  const weaponsDocument = readJsonFile(dataPath("weapons.json"));
  const branchesDocument = readJsonFile(dataPath("weapon_branches.json"));
  const weaponsById = new Map((weaponsDocument.weapons || []).map((weapon) => [String(weapon.id), weapon]));
  const runtimeBranchesById = new Map((branchesDocument.branches || []).map((branch) => [String(branch.id), branch]));

  let docBranchCount = 0;
  let runtimeBranchCount = 0;
  let levelCount = 0;
  let reorderedWeaponCount = 0;

  for (const designWeapon of designWeapons) {
    const docPath = path.join(docsDir, `${designWeapon.weaponId}.json`);
    const designConfig = readJsonFile(docPath);
    designConfig.display_name = designWeapon.displayName;

    const runtimeIdsInDesignOrder = [];
    for (let index = 0; index < designWeapon.branches.length; index += 1) {
      const designBranch = designWeapon.branches[index];
      const docBranch = (designConfig.branches || [])[index];
      if (!docBranch) {
        throw new Error(`${designWeapon.weaponId}.branches[${index}] is missing`);
      }

      updateDocBranch(docBranch, designBranch);
      docBranchCount += 1;
      levelCount += 4;

      const runtimeBranchId = runtimeBranchIdForDocBranch(docBranch);
      runtimeIdsInDesignOrder.push(runtimeBranchId);
      const runtimeBranch = runtimeBranchesById.get(runtimeBranchId);
      if (!runtimeBranch) {
        throw new Error(`${designWeapon.weaponId}.branches[${index}] maps to missing runtime branch ${runtimeBranchId}`);
      }
      updateRuntimeBranch(runtimeBranch, designBranch);
      runtimeBranchCount += 1;
    }

    const weapon = weaponsById.get(designWeapon.weaponId);
    if (!weapon) {
      throw new Error(`Missing runtime weapon ${designWeapon.weaponId}`);
    }
    if (JSON.stringify(weapon.branch_ids || []) !== JSON.stringify(runtimeIdsInDesignOrder)) {
      weapon.branch_ids = runtimeIdsInDesignOrder;
      reorderedWeaponCount += 1;
    }

    writeJsonFile(docPath, designConfig);
  }

  writeJsonFile(dataPath("weapons.json"), weaponsDocument);
  writeJsonFile(dataPath("weapon_branches.json"), branchesDocument);

  console.log(
    `Branch design sync complete. docs=${docBranchCount} runtime=${runtimeBranchCount} levels=${levelCount} reordered_weapons=${reorderedWeaponCount}`
  );
}

main();
