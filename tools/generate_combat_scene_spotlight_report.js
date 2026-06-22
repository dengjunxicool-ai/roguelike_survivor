const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const reportDir = path.join(root, "reports", "combat-scene-checks");
const outPath = path.join(reportDir, "combat_scene_spotlights.md");

const SPOTLIGHTS = [
  {
    title: "法师 + 火焰法杖 + 爆裂火球 Lv2",
    casePrefix: "mage__fire_staff__fire_staff_branch_burst__lv2",
    focus: "attack once 小史莱姆，校验爆裂分支的范围/多目标现场、伤害来源、特殊规则载荷。",
  },
  {
    title: "游侠 + 陷阱包 + 连环夹 Lv5",
    casePrefix: "ranger__trap_kit__trap_kit_branch_toxic_spike__lv5",
    focus: "校验陷阱分支在 stack_conversion 现场中的状态前置、转换规则和运行时触发。",
  },
  {
    title: "圣骑 + 圣盾 + 冲击 Lv3",
    casePrefix: "paladin__holy_shield__holy_shield_branch_charge__lv3",
    focus: "校验防御型武器的护盾运行时载荷、场地/反应现场和非即时伤害规则。",
  },
  {
    title: "圣骑 + 战锤 + 地裂 Lv5",
    casePrefix: "paladin__warhammer__warhammer_branch_quake__lv5",
    focus: "校验 every-n-casts 现场、地裂场伤害、source_weapon_id/source_skill_id 追踪。",
  },
];

function readJson(fileName) {
  const filePath = path.join(reportDir, fileName);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing report: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function findCase(report, prefix) {
  return (report.cases || []).find((item) => String(item.id || "").startsWith(prefix)) || null;
}

function formatSummary(label, report) {
  const summary = report.summary || {};
  return `${label}: ${summary.passed_cases || 0}/${summary.total_cases || 0} passed, failed=${summary.failed_cases || 0}`;
}

function formatAssertions(assertions) {
  return (assertions || []).map((assertion) => {
    const mark = assertion.pass ? "PASS" : "FAIL";
    return `- ${mark} ${assertion.name}: expected=${JSON.stringify(assertion.expected)} actual=${JSON.stringify(assertion.actual)} source=${assertion.source}`;
  }).join("\n");
}

function formatTrace(traceSummary) {
  const trace = traceSummary || [];
  if (trace.length === 0) return "- 无 damage trace；该现场依赖运行时对象/状态/防御载荷校验。";
  return trace.map((line) => `- ${line}`).join("\n");
}

function renderSpotlight(spotlight, smokeReport, rulesReport) {
  const smokeCase = findCase(smokeReport, spotlight.casePrefix);
  const rulesCase = findCase(rulesReport, spotlight.casePrefix);
  if (!smokeCase || !rulesCase) {
    throw new Error(`Missing spotlight case for ${spotlight.casePrefix}`);
  }

  return [
    `## ${spotlight.title}`,
    "",
    `- Case: \`${rulesCase.id}\``,
    `- Template: \`${rulesCase.template}\``,
    `- Focus: ${spotlight.focus}`,
    `- Smoke: \`${smokeCase.status}\``,
    `- Rules: \`${rulesCase.status}\``,
    "",
    "### Rules Assertions",
    formatAssertions(rulesCase.assertions),
    "",
    "### Runtime Trace",
    formatTrace(rulesCase.trace_summary),
    "",
  ].join("\n");
}

function renderReport(smokeReport, rulesReport) {
  const lines = [
    "# Combat Scene Spotlights",
    "",
    "> Generated from full weapon branch matrix smoke/rules reports.",
    "",
    `- ${formatSummary("Smoke", smokeReport)}`,
    `- ${formatSummary("Rules", rulesReport)}`,
    "",
  ];
  for (const spotlight of SPOTLIGHTS) {
    lines.push(renderSpotlight(spotlight, smokeReport, rulesReport));
  }
  return `${lines.join("\n")}\n`;
}

function main() {
  const smokeReport = readJson("full_weapon_branch_matrix_smoke.json");
  const rulesReport = readJson("full_weapon_branch_matrix_rules.json");
  fs.mkdirSync(reportDir, { recursive: true });
  fs.writeFileSync(outPath, renderReport(smokeReport, rulesReport), "utf8");
  console.log(`Combat scene spotlight report written: ${outPath}`);
}

main();
