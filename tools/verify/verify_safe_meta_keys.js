const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const ROOT = process.cwd();
const SEARCH_DIRS = ["scripts", "tools"];
const META_CALL_RE = /\b(get_meta|set_meta|has_meta|remove_meta)\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\b/g;
const VAR_RE = /\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]+)?=\s*(.+)$/;
const DIRECT_LITERAL_META_RE = /\b(get_meta|set_meta|has_meta|remove_meta)\s*\(\s*"([^"]+)"/g;
const VALID_IDENTIFIER_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;

function walk(dir, result = []) {
  if (!fs.existsSync(dir)) {
    return result;
  }
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

function hasUnsafeStringLiteral(expression) {
  const stringMatches = expression.matchAll(/"([^"]*)"/g);
  for (const match of stringMatches) {
    const literal = match[1];
    if (literal.includes(":")) {
      return true;
    }
  }
  return false;
}

function expressionIsSanitized(expression) {
  return expression.includes("_metadata_key(") || expression.includes("_metadata_identifier(");
}

function expressionCanProduceUnsafeMetaKey(expression) {
  if (expressionIsSanitized(expression)) {
    return false;
  }
  if (hasUnsafeStringLiteral(expression)) {
    return true;
  }
  if (expression.includes("modifier_namespace") || expression.includes("source_namespace")) {
    return true;
  }
  if (/String\s*\(\s*rules\.get\s*\(/.test(expression)) {
    return true;
  }
  return false;
}

function findVariableDefinition(lines, fromLineIndex, variableName) {
  for (let i = fromLineIndex; i >= 0; i -= 1) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith("func ") || trimmed.startsWith("static func ") || trimmed.startsWith("class_name ")) {
      return null;
    }
    const match = trimmed.match(VAR_RE);
    if (match && match[1] === variableName) {
      return { line: i + 1, expression: match[2], source: lines[i].trim() };
    }
  }
  return null;
}

function auditFile(filePath) {
  const relPath = path.relative(ROOT, filePath).replace(/\\/g, "/");
  const lines = readTextFile(filePath).split(/\r?\n/);
  const issues = [];

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];

    for (const directMatch of line.matchAll(DIRECT_LITERAL_META_RE)) {
      const literalKey = directMatch[2];
      if (!VALID_IDENTIFIER_RE.test(literalKey)) {
        issues.push(`${relPath}:${i + 1}: direct metadata key is not a valid ASCII identifier: "${literalKey}"`);
      }
    }

    for (const metaMatch of line.matchAll(META_CALL_RE)) {
      const variableName = metaMatch[2];
      const definition = findVariableDefinition(lines, i, variableName);
      if (definition != null && expressionCanProduceUnsafeMetaKey(definition.expression)) {
        issues.push(`${relPath}:${definition.line}: ${definition.source}`);
      }
    }
  }

  return issues;
}

const files = SEARCH_DIRS.flatMap((dir) => walk(path.join(ROOT, dir)));
const issues = files.flatMap(auditFile);

if (issues.length > 0) {
  console.error("Unsafe Godot metadata key expressions found:");
  for (const issue of issues) {
    console.error(`- ${issue}`);
  }
  process.exit(1);
}

console.log("verify_safe_meta_keys: PASS");
