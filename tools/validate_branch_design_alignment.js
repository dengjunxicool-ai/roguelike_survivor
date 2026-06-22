const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const docsDir = path.join(root, "docs", "weapon_design_configs");

function jsonPath(fileName) {
  return path.join(root, "data", fileName);
}

function loadRuntimeBranches() {
  const document = readJsonFile(jsonPath("weapon_branches.json"));
  return new Map((document.branches || []).map((branch) => [String(branch.id), branch]));
}

function loadWeapons() {
  const document = readJsonFile(jsonPath("weapons.json"));
  return new Map((document.weapons || []).map((weapon) => [String(weapon.id), weapon]));
}

function runtimeBranchIdForDocBranch(docBranch) {
  return String(docBranch.current_runtime_branch_id || docBranch.branch_id || "");
}

function assertEqual(errors, where, actual, expected) {
  if (actual !== expected) {
    errors.push(`${where}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function main() {
	const errors = [];
	const runtimeBranches = loadRuntimeBranches();
	const weapons = loadWeapons();
	const designWeapons = fs
		.readdirSync(docsDir)
		.filter((fileName) => fileName.endsWith(".json"))
		.map((fileName) => String(fileName).replace(/\.json$/, ""));

	for (const weaponId of designWeapons) {
		const docPath = path.join(docsDir, `${weaponId}.json`);
		if (!fs.existsSync(docPath)) {
			errors.push(`docs/weapon_design_configs/${weaponId}.json is missing`);
			continue;
		}

		const designConfig = readJsonFile(docPath);
		const docBranches = designConfig.branches || [];
		const runtimeIdsInDesignOrder = [];

		for (let index = 0; index < docBranches.length; index += 1) {
			const docBranch = docBranches[index];
			if (!docBranch) {
				errors.push(`${weaponId}.branches[${index}] is missing in design config`);
				continue;
			}

			const runtimeBranchId = runtimeBranchIdForDocBranch(docBranch);
			runtimeIdsInDesignOrder.push(runtimeBranchId);
			const runtimeBranch = runtimeBranches.get(runtimeBranchId);
			if (!runtimeBranch) {
				errors.push(`${weaponId}.branches[${index}] maps to missing runtime branch ${runtimeBranchId}`);
				continue;
			}

			assertEqual(
				errors,
				`data/weapon_branches.${runtimeBranchId}.display_name`,
				runtimeBranch.display_name,
				docBranch.display_name
			);

			for (const level of ["2", "3", "4", "5"]) {
				assertEqual(
					errors,
					`data/weapon_branches.${runtimeBranchId}.level_path.${level}.description`,
					runtimeBranch.level_path && runtimeBranch.level_path[level] && runtimeBranch.level_path[level].description,
					docBranch.levels && docBranch.levels[level]
				);
			}
		}

		const weapon = weapons.get(weaponId);
		if (!weapon) {
			errors.push(`data/weapons.${weaponId} is missing`);
			continue;
		}
		assertEqual(
			errors,
			`data/weapons.${weaponId}.branch_ids`,
			JSON.stringify(weapon.branch_ids || []),
			JSON.stringify(runtimeIdsInDesignOrder)
		);
  }

  for (const error of errors) {
    console.error(`ERROR ${error}`);
  }
  if (errors.length > 0) {
    process.exitCode = 1;
    return;
  }
	console.log(`Branch design alignment passed. weapons=${designWeapons.length}`);
}

main();
