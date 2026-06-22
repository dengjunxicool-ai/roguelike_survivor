const fs = require("fs");
const os = require("os");
const path = require("path");

const DEFAULT_DESIGN_DOC_PATH = path.join(
  os.homedir(),
  ".codex",
  "attachments",
  "ce4a2962-6c60-4b4e-9e8c-b5df19eebf43",
  "pasted-text.txt"
);

const WEAPON_IDS_BY_SECTION = [
  "fire_staff",
  "frost_staff",
  "lightning_whip",
  "spellbook",
  "throwing_knife_belt",
  "hunter_bow",
  "trap_kit",
  "holy_shield",
  "warhammer",
  "cross_relic",
  "toxic_vial",
  "fire_oil_canister",
  "acid_sprayer",
];

function splitTableRow(line) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
}

function isSeparatorRow(cells) {
  return cells.every((cell) => /^:?-{3,}:?$/.test(cell));
}

function parseMarkdownTable(block) {
  const rows = block
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith("|") && line.endsWith("|"))
    .map(splitTableRow)
    .filter((cells) => !isSeparatorRow(cells));

  if (rows.length < 2) return null;
  return {
    headers: rows[0],
    rows: rows.slice(1),
  };
}

function parseMarkdownTables(sectionText) {
  const tables = [];
  let current = [];

  for (const rawLine of sectionText.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.startsWith("|") && line.endsWith("|")) {
      current.push(line);
      continue;
    }

    if (current.length > 0) {
      const table = parseMarkdownTable(current.join("\n"));
      if (table) tables.push(table);
      current = [];
    }
  }

  if (current.length > 0) {
    const table = parseMarkdownTable(current.join("\n"));
    if (table) tables.push(table);
  }

  return tables;
}

function getCell(row, index) {
  return row && row[index] ? row[index].trim() : "";
}

function parseWeaponSection(weaponId, sectionHeading, sectionText) {
  const tables = parseMarkdownTables(sectionText);
  const levelTableIndex = tables.findIndex(
    (table) => table.headers.includes("Lv2") && table.headers.includes("Lv5")
  );

  if (levelTableIndex < 1) {
    throw new Error(`Cannot find branch level table for ${weaponId}`);
  }

  const summaryTable = tables[levelTableIndex - 1];
  const levelTable = tables[levelTableIndex];
  const ruleTable = tables[levelTableIndex + 1] || { rows: [] };

  const branches = levelTable.rows.map((levelRow, index) => {
    const summaryRow = summaryTable.rows[index] || [];
    const ruleRow = ruleTable.rows[index] || [];
    return {
      name: getCell(levelRow, 0),
      archetypeLabel: getCell(summaryRow, 1),
      coreExperience: getCell(summaryRow, 2),
      cost: getCell(summaryRow, 3),
      levels: {
        2: getCell(levelRow, 1),
        3: getCell(levelRow, 2),
        4: getCell(levelRow, 3),
        5: getCell(levelRow, 4),
      },
      damageOwnership: getCell(ruleRow, 1),
      bossRule: getCell(ruleRow, 2),
      triggerLimit: getCell(ruleRow, 3),
      uiFeedback: getCell(ruleRow, 4),
    };
  });

  return {
    weaponId,
    displayName: sectionHeading,
    branches,
  };
}

function parseBranchDesignDocument(filePath = process.env.BRANCH_DESIGN_DOC || DEFAULT_DESIGN_DOC_PATH) {
  const text = fs.readFileSync(filePath, "utf8");
  const headingMatches = [...text.matchAll(/^##\s+\d+\.\d+\s+(.+)$/gm)];
  if (headingMatches.length < WEAPON_IDS_BY_SECTION.length) {
    throw new Error(
      `Expected at least ${WEAPON_IDS_BY_SECTION.length} weapon sections, found ${headingMatches.length}`
    );
  }

  const sections = [];
  for (let index = 0; index < WEAPON_IDS_BY_SECTION.length; index += 1) {
    const match = headingMatches[index];
    const nextMatch = headingMatches[index + 1];
    const sectionText = text.slice(match.index, nextMatch ? nextMatch.index : text.length);
    sections.push(parseWeaponSection(WEAPON_IDS_BY_SECTION[index], match[1].trim(), sectionText));
  }
  return sections;
}

module.exports = {
  DEFAULT_DESIGN_DOC_PATH,
  WEAPON_IDS_BY_SECTION,
  parseBranchDesignDocument,
};
