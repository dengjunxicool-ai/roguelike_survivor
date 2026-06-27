const {
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
} = require("../fusion_skill_numeric_spec");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const rows = parseFusionNumericRows();
const skills = readJson("data/skills/skills.json").skills || [];
const byName = new Map(skills.map((skill) => [skill.name, skill]));

for (const row of rows) {
  const skill = byName.get(row.name);
  assert(skill, `missing fusion skill named ${row.name}`);
  assert(skill.type === "fusion", `${skill.id} must use fusion type`);
  assert(skill.max_level === 2, `${skill.id} max_level must match docs`);
  assert(Array.isArray(skill.trigger_rules) && skill.trigger_rules.length > 0, `${skill.id} must have runtime trigger rules`);

  const spec = extractNumericSpec(row);
  const cooldowns = numbersByKey(skill, "cooldown");
  for (const expected of spec.cooldowns) {
    assert(hasClose(cooldowns, expected), `${skill.id} must encode cooldown/ICD ${expected}s from docs`);
  }

  const radii = [...numbersByKey(skill, "radius_r"), ...numbersByKey(skill, "range_r"), ...numbersByKey(skill, "length_r")];
  for (const expected of spec.radii) {
    assert(hasClose(radii, expected), `${skill.id} must encode R${expected} from docs`);
  }

  const durations = numbersByKey(skill, "duration");
  for (const expected of spec.durations) {
    assert(hasClose(durations, expected), `${skill.id} must encode duration ${expected}s from docs`);
  }

  const tickIntervals = numbersByKey(skill, "tick_interval");
  for (const expected of spec.tickIntervals) {
    assert(hasClose(tickIntervals, expected), `${skill.id} must encode tick interval ${expected}s from docs`);
  }

  const powers = powerScales(skill);
  for (const expected of spec.powers) {
    assert(hasClose(powers, expected), `${skill.id} must encode power_scale ${expected}P from docs`);
  }

  for (const expected of spec.statusAdds) {
    assert(hasStatusAdd(skill, expected), `${skill.id} must apply ${expected.status} +${expected.stacks} from docs`);
  }

  const shieldRatios = numbersByKey(skill, "max_health_ratio");
  for (const expected of spec.shieldRatios) {
    assert(hasClose(shieldRatios, expected), `${skill.id} must encode shield ratio ${expected} from docs`);
  }

  for (const expected of spec.consumeDurations) {
    assert(hasConsumeDuration(skill, expected), `${skill.id} must consume/shorten ${expected.status} by ${expected.duration}s from docs`);
  }

  for (const expected of spec.counts) {
    assert(hasCount(skill, expected), `${skill.id} must encode count ${expected} from docs`);
  }

  assert(flatten(skill).some((node) => typeof node.type === "string" && node.type !== ""), `${skill.id} must have executable effect payload`);
}

console.log("[verify_fusion_skill_numeric_contract] PASS");
