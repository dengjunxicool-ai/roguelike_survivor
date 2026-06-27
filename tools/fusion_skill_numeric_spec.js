const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function readJson(relativePath) {
  return JSON.parse(readText(relativePath));
}

function parseFusionNumericRows() {
  const text = readText("docs/skills/skills.md");
  const start = text.indexOf("联动技能默认");
  const end = text.indexOf("# 九、", start);
  if (start < 0 || end < 0) {
    throw new Error("Unable to locate fusion numeric table in docs/skills/skills.md");
  }
  const rows = [];
  for (const line of text.slice(start, end).split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("|") || trimmed.includes("---")) {
      continue;
    }
    const parts = trimmed.slice(1, -1).split("|").map((part) => part.trim());
    if (parts.length !== 4 || parts[0] === "技能名" || parts[0] === "参数") {
      continue;
    }
    if (["max_level", "解锁条件", "伤害成长", "范围成长", "持续成长", "冷却成长"].includes(parts[0])) {
      continue;
    }
    rows.push({
      name: parts[0],
      fusion: parts[1],
      triggerText: parts[2],
      numericText: parts[3],
    });
  }
  if (rows.length !== 60) {
    throw new Error(`Expected 60 fusion numeric rows, got ${rows.length}`);
  }
  return rows;
}

function flatten(value, result = []) {
  if (Array.isArray(value)) {
    for (const item of value) {
      flatten(item, result);
    }
    return result;
  }
  if (!value || typeof value !== "object") {
    return result;
  }
  result.push(value);
  for (const child of Object.values(value)) {
    flatten(child, result);
  }
  return result;
}

function numbersByKey(skill, key) {
  return flatten(skill).flatMap((node) => {
    if (!Object.prototype.hasOwnProperty.call(node, key)) {
      return [];
    }
    const value = node[key];
    return typeof value === "number" ? [value] : [];
  });
}

function powerScales(skill) {
  return flatten(skill).flatMap((node) => {
    const values = [];
    if (typeof node.power_scale === "number") {
      values.push(node.power_scale);
    }
    if (node.damage && typeof node.damage === "object" && typeof node.damage.power_scale === "number") {
      values.push(node.damage.power_scale);
    }
    return values;
  });
}

function collectRegexNumbers(text, regex) {
  const values = [];
  let match;
  while ((match = regex.exec(text)) !== null) {
    values.push(Number(match[1]));
  }
  return values;
}

function extractNumericSpec(row) {
  const combined = `${row.triggerText}；${row.numericText}`;
  return {
    cooldowns: [
      ...collectRegexNumbers(row.triggerText, /ICD\s*([0-9.]+)s/g),
      ...collectRegexNumbers(row.triggerText, /^每\s*([0-9.]+)s$/g),
    ],
    radii: collectRegexNumbers(row.numericText, /R([0-9.]+)/g),
    durations: collectRegexNumbers(row.numericText, /(?:持续|刷新为|锚点|冰柱|路径|放电|结界|裂隙|冰区|火地|蒸汽区|雷线)\s*([0-9.]+)s/g),
    tickIntervals: collectRegexNumbers(row.numericText, /每\s*([0-9.]+)s/g),
    powers: collectRegexNumbers(row.numericText, /`([0-9.]+)P`/g),
    statusAdds: collectStatusAdds(row.numericText),
    shieldRatios: collectRegexNumbers(row.numericText, /([0-9.]+)%[^；|]*护盾/g).map((value) => value / 100.0),
    consumeDurations: collectConsumeDurations(combined),
    counts: collectCounts(row.numericText),
  };
}

function collectStatusAdds(text) {
  const result = [];
  const regex = /(Burning|Chilled|Conductive|Cursed|Judgment|Instability)\s*\+([0-9]+)/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    result.push({ status: match[1].toLowerCase(), stacks: Number(match[2]) });
  }
  return result;
}

function collectConsumeDurations(text) {
  const result = [];
  const consume = /消耗\s*([0-9.]+)s\s*(Burning|Cursed|Chilled|Frozen|Conductive|Judgment|Instability)/g;
  const shorten = /缩短\s*(Burning|Cursed|Chilled|Frozen|Conductive|Judgment|Instability)\s*([0-9.]+)s/g;
  let match;
  while ((match = consume.exec(text)) !== null) {
    result.push({ status: match[2].toLowerCase(), duration: Number(match[1]) });
  }
  while ((match = shorten.exec(text)) !== null) {
    result.push({ status: match[1].toLowerCase(), duration: Number(match[2]) });
  }
  return result;
}

function collectCounts(text) {
  const result = [];
  const regex = /([0-9]+)\s*(枚|个|道|次|跳|人|目标|发)/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const value = Number(match[1]);
    if (value > 1) {
      result.push(value);
    }
  }
  return [...new Set(result)];
}

function hasClose(values, expected, epsilon = 0.0001) {
  return values.some((value) => Math.abs(Number(value) - expected) <= epsilon);
}

function hasStatusAdd(skill, expected) {
  return flatten(skill).some((node) => {
    if (node.type !== "apply_status" || String(node.status || node.status_id || "").toLowerCase() !== expected.status) {
      return false;
    }
    return Number(node.stacks ?? node.stack ?? 1) === expected.stacks;
  });
}

function hasConsumeDuration(skill, expected) {
  return flatten(skill).some((node) => {
    if (node.type !== "consume_status_duration" || String(node.status || node.status_id || "").toLowerCase() !== expected.status) {
      return false;
    }
    return Math.abs(Number(node.duration ?? 0) - expected.duration) <= 0.0001;
  });
}

function hasCount(skill, expected) {
  const keys = ["count", "projectile_count", "max_targets", "repeat_count", "chain_count", "chains", "burst_count", "shard_count"];
  return flatten(skill).some((node) => keys.some((key) => Number(node[key] ?? 0) === expected));
}

module.exports = {
  extractNumericSpec,
  flatten,
  hasClose,
  hasConsumeDuration,
  hasCount,
  hasStatusAdd,
  numbersByKey,
  parseFusionNumericRows,
  powerScales,
  readJson,
};
