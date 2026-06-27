const fs = require("fs");
const path = require("path");
const { TextDecoder } = require("util");

const root = path.resolve(__dirname, "../..");
const decoder = new TextDecoder("utf-8", { fatal: true });
const strictMojibake = process.argv.includes("--strict-mojibake");

const EXCLUDED_DIRS = new Set([
  ".git",
  ".godot",
  ".codegraph",
  ".tmp",
  ".tmp_fire_tornado_gif",
  "node_modules",
  "reports",
  "tmp",
]);
const TEXT_EXTENSIONS = new Set([
  ".cfg",
  ".gd",
  ".godot",
  ".import",
  ".js",
  ".json",
  ".md",
  ".svg",
  ".tres",
  ".tscn",
  ".txt",
  ".uid",
]);

const REPLACEMENT_MARKERS = [
  { label: "unicode replacement character", pattern: /\uFFFD/u },
  { label: "gbk replacement marker", pattern: /\u951F[\uFFFD?]/u },
];

const MOJIBAKE_HINTS = [
  { label: "latin1/utf8 mojibake", pattern: /(?:\u00C3|\u00C2|\u00E2[\u0080-\u00BF])/u },
  { label: "common Chinese mojibake", pattern: /(?:\u00E6|\u00E7|\u00E8|\u00E9)[\u0080-\u00FF]/u },
  { label: "CJK mojibake phrase", pattern: /(?:閰嶇疆|璇存槑|鏈枃|瀛楁|涓€|鐨勯|鎬昏|绗|鍙茶|楠烽|铦欒)/u },
  { label: "possible question-mark replacement", pattern: /\?{3,}/u },
];

function walk(dir) {
  const result = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!EXCLUDED_DIRS.has(entry.name) && !entry.name.startsWith("data_")) {
        result.push(...walk(path.join(dir, entry.name)));
      }
      continue;
    }
    if (entry.isFile() && TEXT_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) {
      result.push(path.join(dir, entry.name));
    }
  }
  return result;
}

function rel(filePath) {
  return path.relative(root, filePath).replaceAll(path.sep, "/");
}

function lineForOffset(text, offset) {
  return text.slice(0, offset).split(/\n/).length;
}

function firstMatch(text, checks) {
  for (const check of checks) {
    const match = check.pattern.exec(text);
    if (match) {
      return {
        label: check.label,
        index: match.index,
      };
    }
  }
  return null;
}

function main() {
  const fatalIssues = [];
  const warnings = [];

  for (const filePath of walk(root)) {
    const bytes = fs.readFileSync(filePath);
    let text = "";
    try {
      text = decoder.decode(bytes);
    } catch (error) {
      fatalIssues.push(`${rel(filePath)}: invalid UTF-8 (${error.message})`);
      continue;
    }

    const replacement = firstMatch(text, REPLACEMENT_MARKERS);
    if (replacement != null) {
      fatalIssues.push(`${rel(filePath)}:${lineForOffset(text, replacement.index)}: ${replacement.label}`);
      continue;
    }

    const shouldCheckMojibake = rel(filePath) !== "tools/validate/check_text_encoding.js";
    const mojibake = shouldCheckMojibake ? firstMatch(text, MOJIBAKE_HINTS) : null;
    if (mojibake != null) {
      warnings.push(`${rel(filePath)}:${lineForOffset(text, mojibake.index)}: possible ${mojibake.label}`);
    }
  }

  for (const issue of fatalIssues) {
    console.error(`ERROR ${issue}`);
  }

  const warningLimit = 20;
  for (const warning of warnings.slice(0, warningLimit)) {
    console.warn(`WARN  ${warning}`);
  }
  if (warnings.length > warningLimit) {
    console.warn(`WARN  ... ${warnings.length - warningLimit} more possible mojibake locations`);
  }

  if (fatalIssues.length > 0 || (strictMojibake && warnings.length > 0)) {
    process.exitCode = 1;
    return;
  }

  console.log(`Encoding check passed: ${walk(root).length} text files are valid UTF-8.`);
  if (warnings.length > 0) {
    console.log("Mojibake warnings are non-fatal unless --strict-mojibake is passed.");
  }
}

main();
