const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const expected = [
  ["fusion_fire_frost_steam_mist", "蒸灼雾域", "fire", "frost", "Burning 敌人进入冰霜区域时，在区域边缘生成蒸汽伤害区；区域内敌人持续受到火焰伤害，并被施加 Chilled"],
  ["fusion_fire_frost_shattered_ember", "碎冰余烬", "fire", "frost", "Frozen 敌人被火焰技能击杀或碎裂时，向周围喷出碎冰与余烬；碎冰施加 Chilled，余烬施加 Burning"],
  ["fusion_fire_thunder_plasma_fire_path", "等离子火径", "fire", "thunder", "雷电技能经过火焰路径、燃烧地面或熔岩裂缝时，使该区域短暂放电；区域内敌人同时受到火焰伤害和雷电伤害"],
  ["fusion_fire_thunder_thunderburn_meteor", "雷燃流星", "fire", "thunder", "流星、熔岩类技能命中 Conductive 敌人时，从落点向附近 Conductive 敌人释放电弧；电弧命中 Burning 敌人会延长 Burning 持续时间"],
  ["fusion_fire_curse_ash_curse_rune", "灰烬咒文", "fire", "curse", "Burning 每次造成伤害时，缩短目标身上 Cursed 的剩余结算时间；Cursed 结算时若目标仍在 Burning，则留下燃烧地面"],
  ["fusion_fire_curse_blackflame_serpents", "黑焰蛇群", "fire", "curse", "黑蛇、诅咒弹体类技能命中 Burning 敌人后，拖出黑焰路径；路径造成火焰伤害，并对经过敌人施加 Cursed"],
  ["fusion_fire_holy_holy_flame_absolution", "圣焰赦免", "fire", "holy", "Judgment 触发神罚时，若目标带有 Burning，则消耗部分 Burning 持续时间，为玩家生成护盾，并向前释放圣焰光束"],
  ["fusion_fire_holy_burning_light_barrier", "燃光结界", "fire", "holy", "神圣结界存在时，结界边缘会点燃敌人；Burning 敌人在结界内死亡时，为玩家恢复少量护盾"],
  ["fusion_fire_chaos_ember_echo", "余烬回声", "fire", "chaos", "火焰路径穿过虚空裂隙时，裂隙记录路径轨迹；短暂延迟后，沿反方向重放一次火焰路径"],
  ["fusion_fire_chaos_molten_split", "熔火分裂", "fire", "chaos", "火焰弹体命中带有 Instability 的敌人时，弹体分裂成两个较小火弹，分别飞向附近不同敌人"],
  ["fusion_frost_fire_crystalized_flame", "凝火成晶", "frost", "fire", "冰霜区域覆盖火焰路径时，在交界处生成冰晶尖刺；尖刺造成伤害并施加 Chilled，同时保留原本火焰路径"],
  ["fusion_frost_fire_frostburn_shards", "霜燃碎片", "frost", "fire", "Burning 敌人被 Frozen 后，下一次受到冰系技能伤害时喷出霜燃碎片；碎片施加 Chilled，命中 Burning 敌人时造成额外火焰伤害"],
  ["fusion_frost_thunder_lightning_ice_pillar", "雷击冰柱", "frost", "thunder", "雷电命中 Frozen 敌人时，在其位置生成短暂冰柱；冰柱阻挡小怪移动，并周期性对周围敌人施加 Chilled"],
  ["fusion_frost_thunder_aurora_frost_channel", "极光导霜", "frost", "thunder", "Conductive 敌人站在冰霜区域内时，冰霜区域会向另一个 Conductive 敌人释放寒光脉冲，沿途敌人获得 Chilled"],
  ["fusion_frost_curse_ice_coffin_curse_burst", "冰棺咒爆", "frost", "curse", "Cursed 敌人被冻结时，Cursed 的结算暂停；冻结结束时，Cursed 立即结算，并在目标位置释放冰霜冲击"],
  ["fusion_frost_curse_cold_scythe_harvest", "寒镰收割", "frost", "curse", "镰刀、黑蛇、诅咒弹体命中 Frozen 敌人时，额外释放一圈冰片；冰片优先飞向 Cursed 敌人"],
  ["fusion_frost_holy_holy_frost_anchor", "圣霜锚点", "frost", "holy", "带有 Judgment 的敌人进入冰霜区域后，该区域以它为中心周期性扩散 Chilled；每次扩散命中敌人，玩家获得少量护盾"],
  ["fusion_frost_holy_judgment_ice_lance", "审判冰矛", "frost", "holy", "极寒冰矛优先攻击 Judgment 层数最高的敌人；若目标被 Frozen，冰矛命中后额外降下一道圣光"],
  ["fusion_frost_chaos_rift_avalanche", "裂隙雪崩", "frost", "chaos", "Frozen 敌人在虚空裂隙附近碎裂时，裂隙喷出一波冰雪，对扇形区域敌人施加 Chilled"],
  ["fusion_frost_chaos_inverted_ice_shard", "反相冰片", "frost", "chaos", "冰片进入虚空裂隙后，会从另一个裂隙或远处敌人背后飞出；飞出后的冰片仍施加 Chilled"],
  ["fusion_thunder_fire_arc_ignition", "轰燃电弧", "thunder", "fire", "连锁闪电命中 Burning 敌人时，沿最近的火焰路径额外跳转一次；跳转目标优先为 Conductive 敌人"],
  ["fusion_thunder_fire_thunderfire_circuit", "雷火回路", "thunder", "fire", "燃烧地面被雷电命中后，暂存一次放电；下一批敌人进入该地面时，立即受到雷电伤害并获得 Conductive"],
  ["fusion_thunder_frost_shatter_thunder", "破冰雷鸣", "thunder", "frost", "Overload 在 Frozen 敌人身上触发时，直接碎裂目标，并把雷电跳转到附近 Chilled 敌人"],
  ["fusion_thunder_frost_cryo_capacitor", "极寒电容", "thunder", "frost", "雷电命中 Chilled 敌人时，把 Conductive 传播给附近另一个 Chilled 敌人；同一目标短时间内只触发一次"],
  ["fusion_thunder_curse_curse_lightning_rebound", "咒雷回跳", "thunder", "curse", "连锁闪电命中 Cursed 敌人后，下一跳优先寻找另一个 Cursed 敌人；若没有目标，则缩短当前 Cursed 的结算时间"],
  ["fusion_thunder_curse_black_thunder_convergence", "黑雷收束", "thunder", "curse", "雷暴云每隔数次落雷，锁定一个 Cursed 敌人连续劈击；最后一次劈击会让 Cursed 立即结算"],
  ["fusion_thunder_holy_judgment_wire", "审判导线", "thunder", "holy", "雷电命中 Judgment 敌人时，与另一个 Judgment 敌人之间生成短暂雷线；穿过雷线的敌人受到雷电伤害"],
  ["fusion_thunder_holy_shield_capacitor", "护盾电容", "thunder", "holy", "玩家获得护盾时，下一次雷电技能附带额外一次小落雷；护盾破裂时，立即对最近 Conductive 敌人触发 Overload"],
  ["fusion_thunder_chaos_fractal_arc", "分形电弧", "thunder", "chaos", "雷电弹射到带有 Instability 的敌人时，下一次弹射会从附近虚空裂隙重新出现，并分裂成两道较弱电弧"],
  ["fusion_thunder_chaos_rift_lightning_orb", "裂隙雷球", "thunder", "chaos", "雷球进入虚空裂隙后，会在远处怪群中重新出现，并围绕该区域持续放电"],
  ["fusion_curse_fire_ash_soul_pact", "灰烬魂契", "curse", "fire", "Burning 每次造成伤害时，提高下一次 Cursed 结算伤害；该提升只作用于当前目标，不额外生成新状态"],
  ["fusion_curse_fire_burning_soul_minion", "燃魂仆从", "curse", "fire", "Cursed 且 Burning 的敌人死亡时，召唤物优先从该位置出现；亡骸仆从首次攻击附带 Burning"],
  ["fusion_curse_frost_ice_coffin_contract", "冰棺契约", "curse", "frost", "Cursed 敌人被冻结期间不会结算；若其在 Frozen 中死亡，则 Cursed 转移给附近生命最高的敌人"],
  ["fusion_curse_frost_cold_scythe_soul_chase", "寒镰追魂", "curse", "frost", "死镰类技能命中 Frozen 敌人后，额外飞向最近的 Cursed 敌人；若没有 Cursed 目标，则对原目标施加 Cursed"],
  ["fusion_curse_thunder_curse_lightning_backlash", "雷咒反噬", "curse", "thunder", "Overload 在 Cursed 敌人身上触发时，Cursed 立即结算；结算后雷电跳向最近未被 Cursed 的敌人并施加 Conductive"],
  ["fusion_curse_thunder_black_serpent_conduction", "黑蛇导电", "curse", "thunder", "黑蛇优先沿 Conductive 敌人的方向移动；命中 Conductive 敌人时，额外向附近敌人传播 Cursed"],
  ["fusion_curse_holy_confession_curse_seal", "告解诅印", "curse", "holy", "同时带有 Judgment 和 Cursed 的敌人准备攻击玩家时，被短暂打断；打断结束时 Cursed 立即结算"],
  ["fusion_curse_holy_absolution_harvest", "赦罪收割", "curse", "holy", "Cursed 且 Judgment 的敌人死亡时，玩家获得护盾；如果死亡来自 Cursed 结算，额外释放一道短距离圣光"],
  ["fusion_curse_chaos_paradox_curse_mark", "悖论咒印", "curse", "chaos", "Cursed 敌人触发 Instability 裂变时，Cursed 复制到远处一个敌人；复制版本持续时间更短，伤害较低"],
  ["fusion_curse_chaos_rift_funeral", "裂隙葬礼", "curse", "chaos", "Cursed 敌人在虚空裂隙附近死亡时，裂隙向远处敌人发射一枚诅咒弹体，命中后施加 Cursed"],
  ["fusion_holy_fire_holy_flame_purification", "圣焰净化", "holy", "fire", "圣光技能命中 Burning 敌人时，消耗部分 Burning 持续时间，并为玩家恢复护盾；被消耗的 Burning 不触发火焰爆炸"],
  ["fusion_holy_fire_solar_hammer", "太阳圣锤", "holy", "fire", "审判圣锤命中 Burning 敌人时，在落点生成十字形圣焰路径；路径施加 Burning 和 Judgment"],
  ["fusion_holy_frost_crystal_shelter", "冰晶庇护", "holy", "frost", "Frozen 且带有 Judgment 的敌人死亡时，玩家获得护盾；若护盾已满，则在死亡位置生成小型冰霜区域"],
  ["fusion_holy_frost_holy_frost_beam", "圣霜光束", "holy", "frost", "圣光射线命中 Chilled 敌人时，沿射线轨迹留下短暂冰霜路径；命中 Frozen 敌人时，射线持续时间延长"],
  ["fusion_holy_thunder_thunder_shield_prayer", "雷盾祷告", "holy", "thunder", "每次玩家获得护盾时，最近的 Conductive 敌人受到一次小落雷；护盾破裂时，附近敌人获得 Judgment"],
  ["fusion_holy_thunder_holy_thunder_judgment", "圣雷裁决", "holy", "thunder", "神罚命中 Conductive 敌人时，额外引发一次 Overload；Overload 命中的敌人获得 Judgment"],
  ["fusion_holy_curse_purifying_chain", "净罪锁链", "holy", "curse", "圣光技能命中 Cursed 敌人后，跳向另一个 Cursed 敌人；每次跳跃为玩家恢复少量护盾"],
  ["fusion_holy_curse_penitence_barrier", "忏悔结界", "holy", "curse", "神圣结界内的 Cursed 敌人移动速度降低；它们死亡时，结界持续时间延长"],
  ["fusion_holy_chaos_divine_domain_rift", "神域裂隙", "holy", "chaos", "神圣结界覆盖虚空裂隙时，裂隙周期性向外释放圣光脉冲，施加 Judgment"],
  ["fusion_holy_chaos_judgment_echo", "裁决回声", "holy", "chaos", "Judgment 在带有 Instability 的敌人身上触发神罚时，从最近裂隙处额外释放一次较弱神罚"],
  ["fusion_chaos_fire_riftfire_fork", "裂火分叉", "chaos", "fire", "火焰弹体经过虚空裂隙时，分成两枚较小火弹，从裂隙两侧飞出；小火弹仍可施加 Burning"],
  ["fusion_chaos_fire_lava_refraction", "熔岩折返", "chaos", "fire", "熔岩裂缝触碰虚空裂隙后，从裂隙另一侧反向延伸一段较短裂缝"],
  ["fusion_chaos_frost_zero_rift", "零度裂隙", "chaos", "frost", "冰霜区域生成在虚空裂隙附近时，裂隙把一部分冰霜区域复制到远处敌人脚下"],
  ["fusion_chaos_frost_shattered_ice_warp", "碎冰折跃", "chaos", "frost", "Frozen 敌人碎裂产生的冰片优先进入附近裂隙，并从远处敌群旁飞出"],
  ["fusion_chaos_thunder_quantum_overload", "量子过载", "chaos", "thunder", "带有 Instability 的敌人触发 Overload 时，在当前位置和远处敌群之间各释放一次雷电爆发"],
  ["fusion_chaos_thunder_warp_lightning_orb", "跃迁雷球", "chaos", "thunder", "雷球接触虚空裂隙后，传送到远处怪群中心，并继续持续放电"],
  ["fusion_chaos_curse_curse_rune_echo", "咒文回声", "chaos", "curse", "Cursed 结算时，如果目标带有 Instability，则从最近裂隙处重复一次较弱诅咒冲击"],
  ["fusion_chaos_curse_rift_curse_exchange", "裂隙换咒", "chaos", "curse", "虚空裂隙每隔一段时间寻找一个 Cursed 敌人，把它身上的 Cursed 复制给远处未被 Cursed 的敌人"],
  ["fusion_chaos_holy_void_holy_shield", "虚空圣盾", "chaos", "holy", "玩家获得护盾时，最近虚空裂隙向外释放一次冲击，命中敌人施加 Judgment"],
  ["fusion_chaos_holy_echoing_judgment", "回响裁决", "chaos", "holy", "神罚命中带有 Instability 的敌人后，短暂延迟从另一个裂隙处再次降下较弱神罚"],
];

const skillsData = readJson("data/skills.json");
const combatObjects = new Set((readJson("data/combat_objects.json").combat_objects || []).map((object) => object.id));
const summons = new Set((readJson("data/summons.json").summons || []).map((summon) => summon.id));
const fusionSkills = (skillsData.skills || []).filter((skill) => skill.type === "fusion" || skill.fusion_school);

assert(expected.length === 60, `contract must define 60 expected fusions, got ${expected.length}`);
assert(fusionSkills.length === 60, `expected 60 fusion skills, got ${fusionSkills.length}`);

const byId = new Map(fusionSkills.map((skill) => [skill.id, skill]));
for (const [id, name, school, fusionSchool, description] of expected) {
  const skill = byId.get(id);
  assert(skill, `missing fusion skill ${id}`);
  assert(skill.name === name, `${id} name mismatch`);
  assert(skill.school === school, `${id} school mismatch`);
  assert(skill.fusion_school === fusionSchool, `${id} fusion_school mismatch`);
  assert(skill.type === "fusion", `${id} type must be fusion`);
  assert(skill.max_level === 2, `${id} max_level must be 2`);
  assert(skill.description === description, `${id} description mismatch`);
  assert(Array.isArray(skill.tags) && skill.tags.includes("fusion"), `${id} tags must include fusion`);
  assert(skill.tags.includes(school) && skill.tags.includes(fusionSchool), `${id} tags must include both schools`);
  assert(skill.offer_rule && Array.isArray(skill.offer_rule.required_schools), `${id} must have required_schools`);
  assert(skill.offer_rule.required_schools.includes(school) && skill.offer_rule.required_schools.includes(fusionSchool), `${id} required_schools mismatch`);
  const minCount = skill.offer_rule.required_min_skill_count || {};
  assert(minCount[school] === 2, `${id} main school required_min_skill_count must be 2`);
  assert(minCount[fusionSchool] === 1, `${id} fusion school required_min_skill_count must be 1`);
  assert(Array.isArray(skill.trigger_rules) && skill.trigger_rules.length > 0, `${id} must have runtime trigger rules`);
  assert(Array.isArray(skill.effects), `${id} must have effects array`);
}

const expectedIds = new Set(expected.map(([id]) => id));
for (const skill of fusionSkills) {
  assert(expectedIds.has(skill.id), `unexpected fusion skill ${skill.id}`);
  for (const reference of collectReferences(skill)) {
    if (reference.kind === "summon") {
      assert(summons.has(reference.id), `${skill.id} references missing summon ${reference.id}`);
    } else {
      assert(combatObjects.has(reference.id), `${skill.id} references missing combat object ${reference.id}`);
    }
  }
}

function collectReferences(value) {
  const result = [];
  visit(value);
  return result;

  function visit(node) {
    if (Array.isArray(node)) {
      node.forEach(visit);
      return;
    }
    if (!node || typeof node !== "object") {
      return;
    }
    if (typeof node.area_id === "string") {
      result.push({ kind: "combat_object", id: node.area_id });
    }
    if (typeof node.projectile_id === "string") {
      result.push({ kind: "combat_object", id: node.projectile_id });
    }
    if (typeof node.summon_definition_id === "string") {
      result.push({ kind: "summon", id: node.summon_definition_id });
    } else if (typeof node.summon_id === "string" && node.type === "spawn_summon") {
      result.push({ kind: "summon", id: node.summon_id });
    }
    Object.values(node).forEach(visit);
  }
}

console.log("[verify_fusion_skill_system_contract] PASS");
