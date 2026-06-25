#!/usr/bin/env node

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const root = path.resolve(__dirname, "..");
const codegraphDir = path.join(root, ".codegraph");
const dbPath = path.join(codegraphDir, "codegraph.db");
const indexJsonPath = path.join(codegraphDir, "godot-index.json");
const summaryPath = path.join(codegraphDir, "GODOT_INDEX.md");
const now = Date.now();

const EXCLUDED_DIRS = new Set([".git", ".godot", ".codegraph"]);
const BUILTIN_CALLS = new Set([
  "abs", "add_child", "append", "as", "bool", "call", "call_deferred", "ceil", "ceili",
  "clamp", "clampf", "clampi", "clear", "connect", "cos", "duplicate", "emit", "emit_signal",
  "find_child", "float", "floor", "floori", "get", "get_child", "get_meta", "get_node",
  "get_node_or_null", "get_tree", "has", "has_method", "has_signal", "int", "is_empty",
  "len", "load", "max", "maxf", "maxi", "min", "minf", "mini", "new", "pop_back",
  "pow", "preload", "print", "push_error", "push_warning", "queue_free", "range", "remove_at",
  "round", "roundi", "set", "set_meta", "sin", "size", "str", "String", "StringName",
  "Vector2", "Vector2i", "Rect2", "Color", "Callable", "NodePath"
]);

function rel(filePath) {
  return path.relative(root, filePath).replaceAll(path.sep, "/");
}

function hash(value) {
  return crypto.createHash("sha1").update(value).digest("hex");
}

function id(kind, qualifiedName) {
  return hash(`${kind}:${qualifiedName}`);
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (EXCLUDED_DIRS.has(entry.name)) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, out);
    } else {
      out.push(fullPath);
    }
  }
  return out;
}

function countIndent(line) {
  const match = line.match(/^\s*/);
  return match ? match[0].replace(/\t/g, "    ").length : 0;
}

function collectDoc(lines, index) {
  const docs = [];
  for (let i = index - 1; i >= 0; i -= 1) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith("##")) {
      docs.unshift(trimmed.replace(/^#+\s?/, ""));
    } else if (trimmed === "") {
      continue;
    } else {
      break;
    }
  }
  return docs.join("\n") || null;
}

function lineEndForBlock(lines, startIndex, startIndent) {
  for (let i = startIndex + 1; i < lines.length; i += 1) {
    const line = lines[i];
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#")) continue;
    if (countIndent(line) <= startIndent && /^(func|class|class_name|signal|const|var|@export)/.test(trimmed)) {
      return i;
    }
  }
  return lines.length;
}

function makeFileNode(filePath, language) {
  const fileRel = rel(filePath);
  return {
    id: id("file", fileRel),
    kind: "file",
    name: path.basename(fileRel),
    qualified_name: fileRel,
    file_path: fileRel,
    language,
    start_line: 1,
    end_line: Math.max(fs.readFileSync(filePath, "utf8").split(/\r?\n/).length, 1),
    start_column: 0,
    end_column: 0,
    docstring: null,
    signature: null,
    visibility: "public",
    is_exported: 0,
    is_async: 0,
    is_static: 0,
    is_abstract: 0,
    decorators: "[]",
    type_parameters: "[]",
    updated_at: now
  };
}

function parseGdscript(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const lines = text.split(/\r?\n/);
  const fileRel = rel(filePath);
  const fileNode = makeFileNode(filePath, "unknown");
  const moduleName = fileRel.replace(/\.gd$/, "").replaceAll("/", ".");
  const classNameMatch = text.match(/^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)/m);
  const extendsMatch = text.match(/^\s*extends\s+([A-Za-z_][A-Za-z0-9_]*)/m);
  const className = classNameMatch ? classNameMatch[1] : path.basename(fileRel, ".gd");
  const classNode = {
    ...fileNode,
    id: id("class", `${fileRel}::${className}`),
    kind: "class",
    name: className,
    qualified_name: `${fileRel}::${className}`,
    docstring: extendsMatch ? `extends ${extendsMatch[1]}` : null,
    signature: classNameMatch ? `class_name ${className}` : `script ${className}`
  };

  const nodes = [fileNode, classNode];
  const edges = [{ source: fileNode.id, target: classNode.id, kind: "contains", line: 1, col: 0, provenance: "heuristic" }];
  const functions = [];
  const preloads = [];

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const trimmed = line.trim();
    const lineNo = i + 1;

    for (const match of line.matchAll(/preload\("res:\/\/([^"]+)"\)/g)) {
      preloads.push({ target: match[1], line: lineNo });
    }

    let match = trimmed.match(/^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*(\([^)]*\)(?:\s*->\s*[^:]+)?):/);
    if (match) {
      const fnName = match[1];
      const fnNode = {
        ...fileNode,
        id: id("method", `${fileRel}::${className}.${fnName}`),
        kind: "method",
        name: fnName,
        qualified_name: `${fileRel}::${className}.${fnName}`,
        start_line: lineNo,
        end_line: lineEndForBlock(lines, i, countIndent(line)),
        start_column: line.indexOf("func"),
        end_column: line.length,
        docstring: collectDoc(lines, i),
        signature: `func ${fnName}${match[2]}`
      };
      nodes.push(fnNode);
      functions.push({ node: fnNode, startIndex: i, endIndex: fnNode.end_line - 1 });
      edges.push({ source: classNode.id, target: fnNode.id, kind: "contains", line: lineNo, col: fnNode.start_column, provenance: "heuristic" });
      continue;
    }

    match = trimmed.match(/^signal\s+([A-Za-z_][A-Za-z0-9_]*)\b(.*)$/);
    if (match) {
      const sigNode = {
        ...fileNode,
        id: id("property", `${fileRel}::${className}.${match[1]}`),
        kind: "property",
        name: match[1],
        qualified_name: `${fileRel}::${className}.${match[1]}`,
        start_line: lineNo,
        end_line: lineNo,
        start_column: line.indexOf("signal"),
        end_column: line.length,
        signature: `signal ${match[1]}${match[2]}`
      };
      nodes.push(sigNode);
      edges.push({ source: classNode.id, target: sigNode.id, kind: "contains", line: lineNo, col: sigNode.start_column, provenance: "heuristic" });
      continue;
    }

    match = trimmed.match(/^(?:@export[^\n]*\s+)?(?:var|const)\s+([A-Za-z_][A-Za-z0-9_]*)\b(.*)$/);
    if (match && countIndent(line) === 0) {
      const isConst = trimmed.includes("const ");
      const varNode = {
        ...fileNode,
        id: id(isConst ? "constant" : "field", `${fileRel}::${className}.${match[1]}`),
        kind: isConst ? "constant" : "field",
        name: match[1],
        qualified_name: `${fileRel}::${className}.${match[1]}`,
        start_line: lineNo,
        end_line: lineNo,
        start_column: line.search(/(?:var|const)\s+/),
        end_column: line.length,
        signature: trimmed
      };
      nodes.push(varNode);
      edges.push({ source: classNode.id, target: varNode.id, kind: "contains", line: lineNo, col: varNode.start_column, provenance: "heuristic" });
    }
  }

  return { file: fileRel, nodes, edges, functions, preloads, source: text };
}

function parseJsonData(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const fileRel = rel(filePath);
  const fileNode = makeFileNode(filePath, "unknown");
  const nodes = [fileNode];
  const edges = [];
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    return { file: fileRel, nodes, edges, error: error.message };
  }

  for (const [key, value] of Object.entries(parsed)) {
    if (!Array.isArray(value)) continue;
    for (const item of value) {
      if (!item || typeof item !== "object" || !item.id) continue;
      const name = String(item.id);
      const dataNode = {
        ...fileNode,
        id: id("constant", `${fileRel}::${key}.${name}`),
        kind: "constant",
        name,
        qualified_name: `${fileRel}::${key}.${name}`,
        docstring: String(item.display_name || item.name || item.description || key),
        signature: `${key}: ${name}`
      };
      nodes.push(dataNode);
      edges.push({ source: fileNode.id, target: dataNode.id, kind: "contains", line: 1, col: 0, provenance: "heuristic" });
    }
  }
  return { file: fileRel, nodes, edges, parsed };
}

function parseScene(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const fileRel = rel(filePath);
  const fileNode = makeFileNode(filePath, "unknown");
  const nodes = [fileNode];
  const edges = [];
  for (const match of text.matchAll(/\[ext_resource[^\]]*path="res:\/\/([^"]+)"[^\]]*\]/g)) {
    const targetName = match[1];
    const resourceNode = {
      ...fileNode,
      id: id("import", `${fileRel}::${targetName}`),
      kind: "import",
      name: path.basename(targetName),
      qualified_name: `${fileRel}::${targetName}`,
      signature: `ext_resource res://${targetName}`
    };
    nodes.push(resourceNode);
    edges.push({ source: fileNode.id, target: resourceNode.id, kind: "contains", line: 1, col: 0, provenance: "heuristic" });
  }
  return { file: fileRel, nodes, edges };
}

function fileRecord(filePath, nodeCount) {
  const stat = fs.statSync(filePath);
  const text = fs.readFileSync(filePath);
  return {
    path: rel(filePath),
    content_hash: hash(text),
    language: "unknown",
    size: stat.size,
    modified_at: Math.floor(stat.mtimeMs),
    indexed_at: now,
    node_count: nodeCount,
    errors: "[]"
  };
}

function buildIndex() {
  const files = walk(root);
  const gdFiles = files.filter((file) => file.endsWith(".gd"));
  const jsonFiles = files.filter((file) => rel(file).startsWith("data/") && file.endsWith(".json"));
  const sceneFiles = files.filter((file) => file.endsWith(".tscn"));

  const parsedGd = gdFiles.map(parseGdscript);
  const parsedJson = jsonFiles.map(parseJsonData);
  const parsedScenes = sceneFiles.map(parseScene);
  const parsed = [...parsedGd, ...parsedJson, ...parsedScenes];
  const allNodes = parsed.flatMap((entry) => entry.nodes);
  const allEdges = parsed.flatMap((entry) => entry.edges);
  const functionNameToNodes = new Map();
  const filePathToFileNode = new Map();

  for (const node of allNodes) {
    if (node.kind === "file") filePathToFileNode.set(node.file_path, node);
    if (node.kind === "method") {
      const bucket = functionNameToNodes.get(node.name) || [];
      bucket.push(node);
      functionNameToNodes.set(node.name, bucket);
    }
  }

  for (const entry of parsedGd) {
    const sourceLines = entry.source.split(/\r?\n/);
    const sourceFileNode = filePathToFileNode.get(entry.file);
    for (const preload of entry.preloads) {
      const normalizedTarget = preload.target.replaceAll("\\", "/");
      const targetFileNode = filePathToFileNode.get(normalizedTarget);
      if (sourceFileNode && targetFileNode) {
        allEdges.push({
          source: sourceFileNode.id,
          target: targetFileNode.id,
          kind: "imports",
          metadata: JSON.stringify({ path: normalizedTarget }),
          line: preload.line,
          col: 0,
          provenance: "heuristic"
        });
      }
    }

    for (const fn of entry.functions) {
      const body = sourceLines.slice(fn.startIndex, fn.endIndex).join("\n");
      const seenTargets = new Set();
      for (const match of body.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)) {
        const callName = match[1];
        if (callName === fn.node.name || BUILTIN_CALLS.has(callName)) continue;
        const targets = functionNameToNodes.get(callName) || [];
        if (targets.length !== 1) continue;
        const target = targets[0];
        if (seenTargets.has(target.id)) continue;
        seenTargets.add(target.id);
        allEdges.push({
          source: fn.node.id,
          target: target.id,
          kind: "calls",
          metadata: JSON.stringify({ call: callName }),
          line: fn.node.start_line,
          col: 0,
          provenance: "heuristic"
        });
      }
    }
  }

  return {
    gdFiles,
    jsonFiles,
    sceneFiles,
    parsed,
    nodes: allNodes,
    edges: allEdges
  };
}

function writeDatabase(index) {
  fs.mkdirSync(codegraphDir, { recursive: true });
  const db = new DatabaseSync(dbPath);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA foreign_keys = ON");

  const transaction = db.prepare(`
    INSERT OR REPLACE INTO files (path, content_hash, language, size, modified_at, indexed_at, node_count, errors)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const insertNode = db.prepare(`
    INSERT OR REPLACE INTO nodes (
      id, kind, name, qualified_name, file_path, language, start_line, end_line, start_column, end_column,
      docstring, signature, visibility, is_exported, is_async, is_static, is_abstract, decorators,
      type_parameters, updated_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const insertEdge = db.prepare(`
    INSERT OR IGNORE INTO edges (source, target, kind, metadata, line, col, provenance)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
  const upsertMetadata = db.prepare(`
    INSERT OR REPLACE INTO project_metadata (key, value, updated_at)
    VALUES (?, ?, ?)
  `);

  db.exec("BEGIN");
  try {
    db.exec("DELETE FROM edges");
    db.exec("DELETE FROM unresolved_refs");
    db.exec("DELETE FROM nodes");
    db.exec("DELETE FROM files");

    const nodeCountsByFile = new Map();
    for (const node of index.nodes) {
      nodeCountsByFile.set(node.file_path, (nodeCountsByFile.get(node.file_path) || 0) + 1);
    }
    for (const filePath of [...index.gdFiles, ...index.jsonFiles, ...index.sceneFiles]) {
      const record = fileRecord(filePath, nodeCountsByFile.get(rel(filePath)) || 0);
      transaction.run(record.path, record.content_hash, record.language, record.size, record.modified_at, record.indexed_at, record.node_count, record.errors);
    }
    for (const node of index.nodes) {
      insertNode.run(
        node.id, node.kind, node.name, node.qualified_name, node.file_path, node.language,
        node.start_line, node.end_line, node.start_column, node.end_column, node.docstring,
        node.signature, node.visibility, node.is_exported, node.is_async, node.is_static,
        node.is_abstract, node.decorators, node.type_parameters, node.updated_at
      );
    }
    for (const edge of index.edges) {
      insertEdge.run(edge.source, edge.target, edge.kind, edge.metadata || null, edge.line || null, edge.col || null, edge.provenance || "heuristic");
    }
    upsertMetadata.run("godot_codegraph_generator", "tools/generate_godot_codegraph.js", now);
    upsertMetadata.run("godot_codegraph_generated_at", new Date(now).toISOString(), now);
    db.exec("COMMIT");
  } catch (error) {
    db.exec("ROLLBACK");
    throw error;
  } finally {
    db.close();
  }
}

function summarizeData(index) {
  const dataSummary = {};
  for (const entry of index.parsed) {
    if (!entry.parsed) continue;
    const summary = {};
    for (const [key, value] of Object.entries(entry.parsed)) {
      if (Array.isArray(value)) summary[key] = value.length;
    }
    dataSummary[entry.file] = summary;
  }
  const scriptSummary = index.parsed
    .filter((entry) => entry.file.endsWith(".gd"))
    .map((entry) => ({
      file: entry.file,
      symbols: entry.nodes
        .filter((node) => node.kind !== "file")
        .map((node) => ({
          kind: node.kind,
          name: node.name,
          line: node.start_line,
          signature: node.signature
        })),
      preloads: entry.preloads || []
    }));
  return {
    generatedAt: new Date(now).toISOString(),
    projectRoot: root,
    counts: {
      gdFiles: index.gdFiles.length,
      jsonFiles: index.jsonFiles.length,
      sceneFiles: index.sceneFiles.length,
      nodes: index.nodes.length,
      edges: index.edges.length
    },
    dataSummary,
    scripts: scriptSummary
  };
}

function writeSummary(index, summary) {
  fs.writeFileSync(indexJsonPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
  const lines = [
    "# Godot CodeGraph Index",
    "",
    `Generated: ${summary.generatedAt}`,
    "",
    "This project uses GDScript, which is not currently parsed by the installed CodeGraph CLI. This file and the SQLite entries in `codegraph.db` are generated by `tools/generate_godot_codegraph.js` as a Godot-specific heuristic index.",
    "",
    "## Counts",
    "",
    `- GDScript files: ${summary.counts.gdFiles}`,
    `- Data JSON files: ${summary.counts.jsonFiles}`,
    `- Scene files: ${summary.counts.sceneFiles}`,
    `- CodeGraph nodes: ${summary.counts.nodes}`,
    `- CodeGraph edges: ${summary.counts.edges}`,
    "",
    "## Refresh",
    "",
    "```powershell",
    "node tools/generate_godot_codegraph.js",
    "codegraph status .",
    "```",
    "",
    "Do not use `codegraph sync` for this Godot project unless GDScript support is added upstream; the stock scanner treats `.gd` files as unsupported and will remove the custom Godot entries.",
    "",
    "## Data Files",
    ""
  ];
  for (const [file, counts] of Object.entries(summary.dataSummary)) {
    const parts = Object.entries(counts).map(([key, value]) => `${key}: ${value}`).join(", ");
    lines.push(`- ${file}: ${parts}`);
  }
  lines.push("", "## Main Script Areas", "");
  for (const folder of ["scripts/core", "scripts/player", "scripts/skills", "scripts/enemies", "scripts/ui", "scripts/maps", "scripts/game"]) {
    const count = summary.scripts.filter((entry) => entry.file.startsWith(`${folder}/`)).length;
    lines.push(`- ${folder}: ${count} scripts`);
  }
  fs.writeFileSync(summaryPath, `${lines.join("\n")}\n`, "utf8");
}

const index = buildIndex();
writeDatabase(index);
const summary = summarizeData(index);
writeSummary(index, summary);

console.log(`Godot CodeGraph generated: ${index.nodes.length} nodes, ${index.edges.length} edges`);
console.log(`Wrote ${rel(indexJsonPath)} and ${rel(summaryPath)}`);
