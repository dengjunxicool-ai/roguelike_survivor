const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function writeJson(relativePath, value) {
  fs.writeFileSync(path.join(root, relativePath), JSON.stringify(value, null, "\t") + "\n", "utf8");
}

function loadExpectedFusionRows() {
  const text = fs.readFileSync(path.join(root, "tools/verify_fusion_skill_system_contract.js"), "utf8");
  const match = /const expected = (\[[\s\S]*?\]);/.exec(text);
  if (!match) {
    throw new Error("Unable to read expected fusion catalog from verify_fusion_skill_system_contract.js");
  }
  return Function(`"use strict"; return ${match[1]};`)();
}

const DAMAGE_BY_SCHOOL = {
  fire: "fire",
  frost: "frost",
  thunder: "thunder",
  curse: "curse",
  holy: "holy",
  chaos: "arcane",
};

const STATUS_WORDS = [
  ["Burning", "burning", 4.0],
  ["Chilled", "chilled", 6.0],
  ["Frozen", "frozen", 1.2],
  ["Conductive", "conductive", 5.0],
  ["Cursed", "cursed", 3.0],
  ["Judgment", "judgment", 6.0],
  ["Instability", "instability", 6.0],
];

function statusEffectsFor(description) {
  const effects = [];
  for (const [word, status, duration] of STATUS_WORDS) {
    if (!description.includes(word)) {
      continue;
    }
    if (status === "frozen") {
      effects.push({ type: "apply_status", status: "chilled", stacks: 2, duration: 6.0 });
    } else {
      effects.push({ type: "apply_status", status, stacks: 1, duration });
    }
  }
  return effects;
}

function conditionForStatus(description, status) {
  const word = STATUS_WORDS.find((entry) => entry[1] === status)?.[0];
  if (!word || !statusIsPrecondition(description, word)) {
    return [];
  }
  return [{ type: "target_has_status", status }];
}

function statusIsPrecondition(description, word) {
  let index = description.indexOf(word);
  while (index >= 0) {
    const before = description.slice(Math.max(0, index - 12), index);
    const after = description.slice(index + word.length, index + word.length + 16);
    const looksLikeApplication =
      before.includes("施加") ||
      before.includes("获得") ||
      before.includes("传递") ||
      before.includes("传播") ||
      before.includes("补充") ||
      before.includes("保留") ||
      before.includes("延长") ||
      before.includes("复制给") ||
      before.includes("获得一层");
    if (!looksLikeApplication) {
      const looksLikeCondition =
        before.includes("带有") ||
        before.includes("仍在") ||
        before.includes("进入") ||
        before.includes("站在") ||
        before.includes("被") ||
        after.includes("敌人") ||
        after.includes("目标") ||
        after.includes("身上") ||
        after.includes("层数") ||
        after.includes("中") ||
        after.includes("期间");
      if (looksLikeCondition) {
        return true;
      }
    }
    index = description.indexOf(word, index + word.length);
  }
  return false;
}

function makeOfferRule(school, fusionSchool) {
  return {
    required_schools: [school, fusionSchool],
    required_skills: [],
    blocked_by_exclusive_group: [],
    required_min_skill_count: {
      [school]: 2,
      [fusionSchool]: 1,
    },
  };
}

function normalizeExisting(skill, row) {
  const [id, name, school, fusionSchool, description] = row;
  skill.id = id;
  skill.name = name;
  skill.school = school;
  skill.fusion_school = fusionSchool;
  skill.type = "fusion";
  skill.rarity = skill.rarity || "normal";
  skill.max_level = 2;
  skill.exclusive_group = null;
  skill.tags = Array.from(new Set([...(skill.tags || []), "fusion", school, fusionSchool]));
  skill.mechanic_family = skill.mechanic_family || id.replace(/^fusion_/, "fusion_");
  skill.offer_rule = makeOfferRule(school, fusionSchool);
  skill.trigger_rules = makeTriggerRules(row);
  skill.effects = [];
  skill.description = description;
  return skill;
}

function makeFusionSkill(row) {
  const [id, name, school, fusionSchool, description] = row;
  return {
    id,
    name,
    school,
    fusion_school: fusionSchool,
    type: "fusion",
    rarity: "normal",
    max_level: 2,
    exclusive_group: null,
    tags: Array.from(new Set(["fusion", school, fusionSchool, ...statusTags(description), ...mechanicTags(description)])),
    mechanic_family: id.replace(/^fusion_/, "fusion_"),
    offer_rule: makeOfferRule(school, fusionSchool),
    trigger_rules: makeTriggerRules(row),
    effects: [],
    description,
  };
}

function statusTags(description) {
  return STATUS_WORDS.filter(([word]) => description.includes(word)).map(([, status]) => `status_${status}`);
}

function mechanicTags(description) {
  const tags = [];
  if (/区域|路径|结界|裂隙|地面|冰柱|法阵/.test(description)) {
    tags.push("area");
  }
  if (/弹|碎片|冰片|电弧|光束|链|雷球|黑蛇|飞向/.test(description)) {
    tags.push("projectile");
  }
  if (/护盾/.test(description)) {
    tags.push("shield");
  }
  return tags;
}

function makeTriggerRules(row) {
  const [id, _name, school, fusionSchool, description] = row;
  const rules = [];
  const trigger = triggerFor(description);
  const eventStatus = eventStatusFor(description, trigger);
  const baseRule = {
    trigger,
    cooldown: cooldownFor(description),
    conditions: conditionsFor(description, eventStatus),
    effects: effectsFor(id, school, fusionSchool, description),
  };
  if (baseRule.cooldown <= 0) {
    delete baseRule.cooldown;
  }
  if (baseRule.trigger === "area_tick") {
    baseRule.conditions = baseRule.conditions.map((condition) => {
      if (condition.type !== "skill_has_tag") {
        return condition;
      }
      return { ...condition, type: "source_has_tag", tag: `${condition.tag}_area` };
    });
  }
  if (baseRule.trigger === "post_damage_hit") {
    baseRule.conditions = baseRule.conditions.map((condition) => {
      if (condition.type !== "skill_has_tag") {
        return condition;
      }
      return { type: "damage_element_is", element: damageElementForSchool(condition.tag) };
    });
  }
  if (baseRule.conditions.length === 0) {
    delete baseRule.conditions;
  }
  rules.push(baseRule);

  if (description.includes("护盾破裂")) {
    rules.push({
      trigger: "shield_broken",
      cooldown: 1.0,
      effects: [
        {
          type: "spawn_area",
          area_id: `${id}_shield_break_area`,
          radius_r: 1.5,
          duration: 0.2,
          effects_on_apply: [
            { type: "damage", damage_type: DAMAGE_BY_SCHOOL[school], source_type: "fusion", power_scale: 0.55 },
            ...statusEffectsFor(description),
          ],
        },
      ],
    });
  }
  return rules;
}

function triggerFor(description) {
  if (description.includes("玩家获得护盾") || description.includes("获得护盾时")) {
    return "shield_gained";
  }
  if (description.includes("Overload") || description.includes("神罚") || description.includes("裂变")) {
    return "status_max_stack_reached";
  }
  if (description.includes("每次造成伤害") || description.includes("结算时")) {
    return "status_tick";
  }
  if (description.includes("死亡") || description.includes("击杀") || description.includes("碎裂")) {
    return "enemy_death";
  }
  if (description.includes("区域") || description.includes("结界") || description.includes("裂隙") || description.includes("路径") || description.includes("地面")) {
    return "area_tick";
  }
  return "post_damage_hit";
}

function eventStatusFor(description, trigger) {
  if (trigger === "status_max_stack_reached" && description.includes("Overload")) {
    return "conductive";
  }
  if (trigger === "status_max_stack_reached" && description.includes("神罚")) {
    return "judgment";
  }
  if (trigger === "status_max_stack_reached" && description.includes("Instability") && description.includes("裂变")) {
    return "instability";
  }
  if (trigger === "status_tick" && description.includes("Burning")) {
    return "burning";
  }
  if (trigger === "status_tick" && description.includes("Cursed")) {
    return "cursed";
  }
  return "";
}

function cooldownFor(description) {
  if (description.includes("同一目标短时间")) {
    return 0.5;
  }
  if (description.includes("每隔")) {
    return 1.0;
  }
  if (description.includes("短暂延迟")) {
    return 0.4;
  }
  return 0.3;
}

function damageElementForSchool(school) {
  if (school === "thunder") {
    return "lightning";
  }
  if (school === "frost") {
    return "ice";
  }
  if (school === "curse" || school === "chaos") {
    return "arcane";
  }
  return school;
}

function conditionsFor(description, eventStatus) {
  const conditions = [];
  if (eventStatus) {
    conditions.push({ type: "event_status_is", status: eventStatus });
  }
  for (const [, status] of STATUS_WORDS) {
    if (status === eventStatus) {
      continue;
    }
    conditions.push(...conditionForStatus(description, status));
  }
  if (/火焰技能|火焰弹体|熔岩|流星/.test(description)) {
    conditions.push({ type: "skill_has_tag", tag: "fire" });
  } else if (/冰系技能|冰霜区域|冰片|冰矛/.test(description)) {
    conditions.push({ type: "skill_has_tag", tag: "frost" });
  } else if (/雷电|连锁闪电|雷暴云|雷球/.test(description)) {
    conditions.push({ type: "skill_has_tag", tag: "thunder" });
  } else if (/圣光|神圣结界|审判圣锤/.test(description)) {
    conditions.push({ type: "skill_has_tag", tag: "holy" });
  } else if (/黑蛇|镰刀|死镰|诅咒弹体/.test(description)) {
    conditions.push({ type: "skill_has_tag", tag: "curse" });
  }
  return dedupeConditions(conditions);
}

function dedupeConditions(conditions) {
  const seen = new Set();
  const result = [];
  for (const condition of conditions) {
    const key = JSON.stringify(condition);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(condition);
    }
  }
  return result;
}

function effectsFor(id, school, fusionSchool, description) {
  const damageType = DAMAGE_BY_SCHOOL[school] || "arcane";
  const secondaryDamageType = DAMAGE_BY_SCHOOL[fusionSchool] || "arcane";
  const effects = [];
  if (/弹|碎片|冰片|电弧|光束|链|雷球|黑蛇|飞向|喷出/.test(description)) {
    effects.push({
      type: "spawn_projectile_burst",
      projectile_id: `${id}_projectile`,
      count: projectileCount(description),
      spread_angle: 72,
      speed: 420,
      range_r: 4.0,
      damage: { damage_type: damageType, power_scale: projectilePower(description) },
      on_hit: [
        { type: "damage", damage_type: secondaryDamageType, source_type: "fusion", power_scale: 0.25 },
        ...statusEffectsFor(description),
      ],
    });
  } else {
    effects.push({
      type: "spawn_area",
      area_id: `${id}_area`,
      radius_r: areaRadius(description),
      duration: areaDuration(description),
      tick_interval: 0.5,
      effects_on_tick: [
        { type: "damage", damage_type: damageType, source_type: "fusion", power_scale: areaPower(description) },
        ...statusEffectsFor(description),
      ],
      effects_on_apply: [
        { type: "damage", damage_type: secondaryDamageType, source_type: "fusion", power_scale: 0.35 },
      ],
    });
  }
  if (description.includes("护盾")) {
    effects.push({ type: "grant_shield", shield_type: "fusion_shield", max_health_ratio: 0.015, duration: 4.0, respect_shield_cap: true, shield_cap_health_ratio: 0.35 });
  }
  if (description.includes("缩短") || description.includes("立即结算")) {
    effects.push({ type: "consume_status_duration", status: "cursed", duration: 0.5 });
  }
  if (description.includes("消耗部分 Burning")) {
    effects.push({ type: "consume_status_duration", status: "burning", duration: 1.0 });
  }
  if (description.includes("转移") || description.includes("复制")) {
    effects.push({ type: "transfer_status", status: description.includes("Cursed") ? "cursed" : "instability", stacks: 1 });
  }
  if (description.includes("Overload")) {
    effects.push({ type: "trigger_overload", status: "overload" });
  }
  if (description.includes("碎裂") || description.includes("直接碎裂")) {
    effects.push({ type: "shatter_frozen", projectile_count: 3, projectile_id: `${id}_projectile`, damage: { damage_type: secondaryDamageType, power_scale: 0.3 } });
  }
  return effects;
}

function projectileCount(description) {
  if (/两道|两个|两枚/.test(description)) {
    return 2;
  }
  if (/一圈|周围|喷出/.test(description)) {
    return 6;
  }
  return 3;
}

function projectilePower(description) {
  if (/较弱|小/.test(description)) {
    return 0.35;
  }
  if (/高额|圣锤/.test(description)) {
    return 0.9;
  }
  return 0.55;
}

function areaRadius(description) {
  if (/大范围|全局|神域/.test(description)) {
    return 3.0;
  }
  if (/小型|短距离|短暂/.test(description)) {
    return 1.2;
  }
  return 1.8;
}

function areaDuration(description) {
  if (/持续|区域|路径|地面|结界|裂隙/.test(description)) {
    return 2.5;
  }
  return 0.24;
}

function areaPower(description) {
  if (/高额|圣锤|Overload/.test(description)) {
    return 0.8;
  }
  if (/持续|周期性/.test(description)) {
    return 0.2;
  }
  return 0.45;
}

function collectReferences(value, refs = []) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectReferences(item, refs));
    return refs;
  }
  if (!value || typeof value !== "object") {
    return refs;
  }
  if (typeof value.area_id === "string") {
    refs.push({ type: "area", id: value.area_id });
  }
  if (typeof value.projectile_id === "string") {
    refs.push({ type: "projectile", id: value.projectile_id });
  }
  if (typeof value.summon_definition_id === "string") {
    refs.push({ type: "summon", id: value.summon_definition_id });
  } else if (value.type === "spawn_summon" && typeof value.summon_id === "string") {
    refs.push({ type: "summon", id: value.summon_id });
  }
  Object.values(value).forEach((child) => collectReferences(child, refs));
  return refs;
}

function makeCombatObject(ref) {
  if (ref.type === "projectile") {
    return {
      id: ref.id,
      type: "projectile",
      scene: "res://scenes/fireball_projectile.tscn",
      collision_radius: 12,
      destroy_on_wall: true,
      destroy_on_hit: true,
      visual_mode: "programmatic",
      visual_style: "arcane_page",
      visual_color: [0.72, 0.32, 1.0, 0.92],
      visual_ring_color: [0.88, 0.95, 1.0, 0.86],
    };
  }
  return {
    id: ref.id,
    type: "area",
    scene: "res://scenes/area_effect.tscn",
    collision_radius: 126,
    visual_mode: "programmatic",
    visual_style: "smoke_zone",
    visual_color: [0.42, 0.22, 0.72, 0.26],
    visual_ring_color: [0.7, 0.9, 1.0, 0.78],
  };
}

function replaceById(list, item) {
  const index = list.findIndex((entry) => entry.id === item.id);
  if (index >= 0) {
    list[index] = { ...list[index], ...item };
  } else {
    list.push(item);
  }
}

const expectedRows = loadExpectedFusionRows();
const expectedIds = new Set(expectedRows.map(([id]) => id));

const skillsDocument = readJson("data/skills.json");
const existingById = new Map((skillsDocument.skills || []).map((skill) => [skill.id, skill]));
const nonFusionSkills = (skillsDocument.skills || []).filter((skill) => !skill.fusion_school && skill.type !== "fusion");
const fusionSkills = expectedRows.map((row) => {
  const existing = existingById.get(row[0]);
  if (existing && expectedIds.has(existing.id)) {
    return normalizeExisting(existing, row);
  }
  return makeFusionSkill(row);
});
skillsDocument.skills = [...nonFusionSkills, ...fusionSkills];
writeJson("data/skills.json", skillsDocument);

const combatDocument = readJson("data/combat_objects.json");
const combatObjects = combatDocument.combat_objects || [];
const summonDocument = readJson("data/summons.json");
const summons = summonDocument.summons || [];
const summonIds = new Set(summons.map((summon) => summon.id));
const refs = fusionSkills.flatMap((skill) => collectReferences(skill));
for (const ref of refs) {
  if (ref.type === "summon") {
    if (!summonIds.has(ref.id)) {
      summons.push({
        id: ref.id,
        name: ref.id,
        scene_path: "res://scenes/summon_controller.tscn",
        max_count: 2,
        duration: 10.0,
        movement: { move_speed: 180, follow_distance: 96, min_distance: 44, leash_distance: 360, teleport_distance: 720, separation_radius: 34 },
        targeting: { detect_range: 320, retarget_interval: 0.25, target_priority: "nearest_to_summon" },
        attack: { attack_type: "melee", attack_range: 52, attack_cooldown: 1.2, damage_type: "arcane", damage_scale: 0.35, on_hit_effects: [] },
        visual: { texture: "res://icon.svg", scale: 0.15, modulate: [0.72, 0.42, 1.0, 0.9], z_index: 5 },
      });
      summonIds.add(ref.id);
    }
  } else {
    replaceById(combatObjects, makeCombatObject(ref));
  }
}
combatDocument.combat_objects = combatObjects;
summonDocument.summons = summons;
writeJson("data/combat_objects.json", combatDocument);
writeJson("data/summons.json", summonDocument);

console.log(`[apply_fusion_skill_catalog] wrote ${fusionSkills.length} fusion skills`);
