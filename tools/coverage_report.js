#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_SOURCE_DIRS = ["scripts"];
const DEFAULT_TEST_DIRS = ["tools", "scripts/debug"];
const SOURCE_EXTENSIONS = new Set([".gd", ".js"]);
const TEST_EXTENSIONS = new Set([".gd", ".js"]);
const EXCLUDED_DIRS = new Set([".git", ".godot", ".codegraph", "node_modules", "docs", "data", "assets", "reports"]);
const EXCLUDED_SOURCE_PATTERNS = [
  /(^|\/)scripts\/debug\/.*_check\.gd$/u,
  /(^|\/)scripts\/debug\/full_flow_autoplay\.gd$/u,
];
const BUILTIN_CALLS = new Set([
  "abs", "add_child", "append", "as", "assert", "bool", "call", "call_deferred", "ceil", "ceili",
  "clamp", "clampf", "clampi", "clear", "connect", "const", "continue", "cos", "duplicate",
  "elif", "else", "emit_signal", "false", "find_child", "float", "floor", "floori", "for", "func",
  "get", "get_child", "get_meta", "get_node", "get_node_or_null", "get_tree", "has", "has_method",
  "has_signal", "if", "in", "int", "is", "is_empty", "is_instance_valid", "len", "load", "match",
  "max", "maxf", "maxi", "min", "minf", "mini", "new", "not", "null", "or", "pass", "pop_back",
  "pow", "preload", "print", "push_error", "push_warning", "queue_free", "range", "return",
  "remove_at", "round", "roundi", "self", "set", "set_meta", "sin", "size", "static", "str",
  "super", "true", "var", "void", "while",
  "Array", "Callable", "Color", "Dictionary", "Node", "Node2D", "NodePath", "Object", "PackedScene",
  "Rect2", "RefCounted", "Resource", "SceneTree", "Script", "String", "StringName", "Vector2", "Vector2i",
]);

function parseArgs(argv) {
  const options = {
    root: path.resolve(__dirname, ".."),
    sourceDirs: [...DEFAULT_SOURCE_DIRS],
    testDirs: [...DEFAULT_TEST_DIRS],
    minFunctions: 95,
    minFiles: 95,
    jsonOut: "reports/coverage/coverage-summary.json",
    mdOut: "reports/coverage/coverage-report.md",
  };

  let sourceSpecified = false;
  let testsSpecified = false;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];
    switch (arg) {
      case "--root":
        options.root = path.resolve(requireValue(arg, next));
        index += 1;
        break;
      case "--source":
        if (!sourceSpecified) {
          options.sourceDirs = [];
          sourceSpecified = true;
        }
        options.sourceDirs.push(...splitList(requireValue(arg, next)));
        index += 1;
        break;
      case "--tests":
        if (!testsSpecified) {
          options.testDirs = [];
          testsSpecified = true;
        }
        options.testDirs.push(...splitList(requireValue(arg, next)));
        index += 1;
        break;
      case "--min-functions":
        options.minFunctions = Number(requireValue(arg, next));
        index += 1;
        break;
      case "--min-files":
        options.minFiles = Number(requireValue(arg, next));
        index += 1;
        break;
      case "--json-out":
        options.jsonOut = requireValue(arg, next);
        index += 1;
        break;
      case "--md-out":
        options.mdOut = requireValue(arg, next);
        index += 1;
        break;
      case "--help":
        printHelp();
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return options;
}

function requireValue(arg, value) {
  if (value == null || value.startsWith("--")) {
    throw new Error(`${arg} requires a value`);
  }
  return value;
}

function splitList(value) {
  return value.split(",").map((item) => item.trim()).filter(Boolean);
}

function printHelp() {
  console.log([
    "Usage: node tools/coverage_report.js [options]",
    "",
    "Options:",
    "  --root <dir>             Project root. Defaults to repository root.",
    "  --source <dir[,dir]>     Source directories. Repeatable. Defaults to scripts.",
    "  --tests <dir[,dir]>      Test directories. Repeatable. Defaults to tools,scripts/debug.",
    "  --min-functions <n>      Minimum static function coverage percent. Defaults to 95.",
    "  --min-files <n>          Minimum static file coverage percent. Defaults to 95.",
    "  --json-out <path>        JSON report path relative to root unless absolute.",
    "  --md-out <path>          Markdown report path relative to root unless absolute.",
  ].join("\n"));
}

function walk(dir, extensions, out = []) {
  if (!fs.existsSync(dir)) {
    return out;
  }
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!EXCLUDED_DIRS.has(entry.name)) {
        walk(fullPath, extensions, out);
      }
      continue;
    }
    if (entry.isFile() && extensions.has(path.extname(entry.name).toLowerCase())) {
      out.push(fullPath);
    }
  }
  return out;
}

function rel(root, filePath) {
  return path.relative(root, filePath).replaceAll(path.sep, "/");
}

function shouldExcludeSource(relativePath) {
  return EXCLUDED_SOURCE_PATTERNS.some((pattern) => pattern.test(relativePath));
}

function collectFiles(root, dirs, extensions, excludeSource = false) {
  const files = [];
  for (const dir of dirs) {
    const absoluteDir = path.resolve(root, dir);
    for (const filePath of walk(absoluteDir, extensions)) {
      const relativePath = rel(root, filePath);
      if (!excludeSource || !shouldExcludeSource(relativePath)) {
        files.push(filePath);
      }
    }
  }
  return [...new Set(files)].sort();
}

function countIndent(line) {
  const match = line.match(/^\s*/u);
  return match ? match[0].replace(/\t/gu, "    ").length : 0;
}

function parseFunctions(root, filePath) {
  const relativePath = rel(root, filePath);
  const text = fs.readFileSync(filePath, "utf8");
  const lines = text.split(/\r?\n/u);
  const functions = [];

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const gdMatch = line.match(/^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/u);
    const jsMatch = line.match(/^\s*(?:async\s+)?function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/u);
    const arrowMatch = line.match(/^\s*(?:const|let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>/u);
    const match = gdMatch || jsMatch || arrowMatch;
    if (!match) {
      continue;
    }

    const startLine = index + 1;
    const startIndent = countIndent(line);
    const endIndex = lineEndForBlock(lines, index, startIndent);
    const body = lines.slice(index, endIndex).join("\n");
    const name = match[1];
    functions.push({
      id: `${relativePath}::${name}:${startLine}`,
      file: relativePath,
      name,
      startLine,
      endLine: endIndex,
      calls: extractCalls(body),
      covered: false,
      coveredBy: [],
    });
  }
  return functions;
}

function lineEndForBlock(lines, startIndex, startIndent) {
  for (let index = startIndex + 1; index < lines.length; index += 1) {
    const line = lines[index];
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#") || trimmed.startsWith("//")) {
      continue;
    }
    if (countIndent(line) <= startIndent && isBlockBoundary(trimmed)) {
      return index;
    }
  }
  return lines.length;
}

function isBlockBoundary(trimmed) {
  return /^(?:static\s+)?func\s+/u.test(trimmed)
    || /^(?:async\s+)?function\s+/u.test(trimmed)
    || /^(?:const|let|var)\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*(?:async\s*)?\([^)]*\)\s*=>/u.test(trimmed)
    || /^(?:class|class_name|extends|signal|const|var|@export)\b/u.test(trimmed);
}

function extractCalls(text) {
  const calls = new Set();
  for (const match of text.matchAll(/\bcall\(\s*&?["']([A-Za-z_][A-Za-z0-9_]*)["']/gu)) {
    addCall(calls, match[1]);
  }
  for (const match of text.matchAll(/\.([A-Za-z_][A-Za-z0-9_]*)\s*\(/gu)) {
    addCall(calls, match[1]);
  }
  for (const match of text.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/gu)) {
    addCall(calls, match[1]);
  }
  return [...calls].sort();
}

function addCall(calls, name) {
  if (!BUILTIN_CALLS.has(name)) {
    calls.add(name);
  }
}

function markCovered(functions, testFiles, root) {
  const byName = new Map();
  for (const fn of functions) {
    if (!byName.has(fn.name)) {
      byName.set(fn.name, []);
    }
    byName.get(fn.name).push(fn);
  }

  const queue = [];
  for (const testFile of testFiles) {
    const testRel = rel(root, testFile);
    const text = fs.readFileSync(testFile, "utf8");
    const referencedNames = extractCalls(text);
    for (const name of referencedNames) {
      const matches = byName.get(name) || [];
      for (const fn of matches) {
        if (markFunction(fn, testRel)) {
          queue.push(fn);
        }
      }
    }

    for (const fn of functions) {
      if (text.includes(fn.file) && text.includes(fn.name) && markFunction(fn, testRel)) {
        queue.push(fn);
      }
    }
  }

  while (queue.length > 0) {
    const fn = queue.shift();
    for (const callName of fn.calls) {
      const matches = byName.get(callName) || [];
      for (const callee of matches) {
        if (markFunction(callee, `${fn.file}:${fn.startLine}`)) {
          queue.push(callee);
        }
      }
    }
  }
}

function markFunction(fn, coveredBy) {
  if (!fn.coveredBy.includes(coveredBy)) {
    fn.coveredBy.push(coveredBy);
  }
  if (fn.covered) {
    return false;
  }
  fn.covered = true;
  return true;
}

function buildSummary(root, sourceFiles, testFiles, functions, options) {
  const files = sourceFiles.map((filePath) => {
    const file = rel(root, filePath);
    const fileFunctions = functions.filter((fn) => fn.file === file);
    const coveredFunctions = fileFunctions.filter((fn) => fn.covered);
    return {
      file,
      functions: {
        total: fileFunctions.length,
        covered: coveredFunctions.length,
        percent: percent(coveredFunctions.length, fileFunctions.length),
      },
      covered: fileFunctions.length > 0 && coveredFunctions.length > 0,
    };
  });

  const coveredFunctions = functions.filter((fn) => fn.covered);
  const coveredFiles = files.filter((file) => file.covered);
  const summary = {
    generatedAt: new Date().toISOString(),
    type: "static-reference-coverage",
    thresholds: {
      functions: options.minFunctions,
      files: options.minFiles,
    },
    scope: {
      sources: options.sourceDirs,
      tests: options.testDirs,
      sourceFileCount: sourceFiles.length,
      testFileCount: testFiles.length,
    },
    totals: {
      functions: {
        total: functions.length,
        covered: coveredFunctions.length,
        percent: percent(coveredFunctions.length, functions.length),
      },
      files: {
        total: files.length,
        covered: coveredFiles.length,
        percent: percent(coveredFiles.length, files.length),
      },
    },
    files,
    uncovered: {
      files: files.filter((file) => !file.covered).map((file) => file.file),
      functions: functions.filter((fn) => !fn.covered).map((fn) => ({
        file: fn.file,
        name: fn.name,
        line: fn.startLine,
      })),
    },
    covered: {
      functions: coveredFunctions.map((fn) => ({
        file: fn.file,
        name: fn.name,
        line: fn.startLine,
        coveredBy: fn.coveredBy,
      })),
    },
  };
  summary.passed = summary.totals.functions.percent >= options.minFunctions
    && summary.totals.files.percent >= options.minFiles;
  return summary;
}

function percent(covered, total) {
  if (total <= 0) {
    return 100;
  }
  return Number(((covered / total) * 100).toFixed(2));
}

function writeJson(root, outputPath, summary) {
  const absolutePath = resolveOutput(root, outputPath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  fs.writeFileSync(absolutePath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
}

function writeMarkdown(root, outputPath, summary) {
  const absolutePath = resolveOutput(root, outputPath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  fs.writeFileSync(absolutePath, renderMarkdown(summary), "utf8");
}

function resolveOutput(root, outputPath) {
  return path.isAbsolute(outputPath) ? outputPath : path.resolve(root, outputPath);
}

function renderMarkdown(summary) {
  const lines = [
    "# Static Coverage Report",
    "",
    `Generated: ${summary.generatedAt}`,
    "",
    "> This is static reference coverage. It proves test scripts reference source entry points and reachable callees; it is not runtime line coverage.",
    "",
    "## Summary",
    "",
    `- Function Coverage: ${summary.totals.functions.covered}/${summary.totals.functions.total} (${summary.totals.functions.percent}%)`,
    `- File Coverage: ${summary.totals.files.covered}/${summary.totals.files.total} (${summary.totals.files.percent}%)`,
    `- Thresholds: functions >= ${summary.thresholds.functions}%, files >= ${summary.thresholds.files}%`,
    `- Result: ${summary.passed ? "PASS" : "FAIL"}`,
    "",
    "## Lowest File Coverage",
    "",
    "| File | Covered Functions | Total Functions | Percent |",
    "| --- | ---: | ---: | ---: |",
  ];
  for (const file of [...summary.files].sort((a, b) => a.functions.percent - b.functions.percent).slice(0, 50)) {
    lines.push(`| ${file.file} | ${file.functions.covered} | ${file.functions.total} | ${file.functions.percent}% |`);
  }
  lines.push("", "## Uncovered Functions", "");
  for (const fn of summary.uncovered.functions.slice(0, 200)) {
    lines.push(`- ${fn.file}:${fn.line} ${fn.name}`);
  }
  if (summary.uncovered.functions.length > 200) {
    lines.push(`- ... ${summary.uncovered.functions.length - 200} more`);
  }
  lines.push("");
  return `${lines.join("\n")}\n`;
}

function printSummary(summary) {
  console.log(`Static coverage: functions ${summary.totals.functions.covered}/${summary.totals.functions.total} (${summary.totals.functions.percent}%), files ${summary.totals.files.covered}/${summary.totals.files.total} (${summary.totals.files.percent}%)`);
  if (!summary.passed) {
    if (summary.totals.functions.percent < summary.thresholds.functions) {
      console.error(`FAIL function coverage ${summary.totals.functions.percent}% < ${summary.thresholds.functions}%`);
    }
    if (summary.totals.files.percent < summary.thresholds.files) {
      console.error(`FAIL file coverage ${summary.totals.files.percent}% < ${summary.thresholds.files}%`);
    }
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const sourceFiles = collectFiles(options.root, options.sourceDirs, SOURCE_EXTENSIONS, true);
  const testFiles = collectFiles(options.root, options.testDirs, TEST_EXTENSIONS, false);
  const functions = sourceFiles.flatMap((filePath) => parseFunctions(options.root, filePath));
  markCovered(functions, testFiles, options.root);
  const summary = buildSummary(options.root, sourceFiles, testFiles, functions, options);
  writeJson(options.root, options.jsonOut, summary);
  writeMarkdown(options.root, options.mdOut, summary);
  printSummary(summary);
  process.exitCode = summary.passed ? 0 : 1;
}

try {
  main();
} catch (error) {
  console.error(error.stack || error.message);
  process.exitCode = 1;
}
