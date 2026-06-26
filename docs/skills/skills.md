下面所有数值使用统一缩写：
| 缩写 | 含义 |
| --- | --- |
| **P** | 当前技能强度，建议等于 `角色攻击力 × 技能倍率 × 通用伤害修正` |
| **R** | 半径，建议 1R = 84px 或 1 个游戏单位 |
| **s** | 秒 |
| **tick** | 持续伤害结算间隔，默认 0.5s |
| **ICD** | 内置冷却，防止同一效果过高频触发 |

---

# 一、技能系统核心模型

## 1\. SkillDefinition 技能定义

建议每个技能都是一个配置对象，不要把技能逻辑硬写死。

```json
{
  "id": "fire_attack_searing",
  "name": "灼热攻击",
  "school": "fire",
  "fusion_school": null,
  "type": "attack",
  "rarity": "normal",
  "max_level": 5,
  "exclusive_group": "attack_school",
  "tags": ["attack", "fire", "status_burning", "ground_path"],
  "mechanic_family": "attack_status_ground_path",
  "offer_rule": {
    "required_schools": ["fire"],
    "required_skills": [],
    "blocked_by_exclusive_group": ["attack_school"]
  },
  "trigger_rules": [],
  "effects": []
}
```

## 2\. 字段说明

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | string | 技能唯一 ID |
| name | string | 显示名称 |
| school | enum | 主神系：fire / frost / thunder / curse / holy / chaos |
| fusion_school | enum / null | 联动副神系，没有则为 null |
| type | enum | attack / dash / cast / summon / passive / power / core / fusion |
| rarity | enum | normal / rare / epic / legendary |
| max_level | int | 基础技能 5，联动技能 3，神系质变 1 |
| exclusive_group | string / null | 普攻、冲刺、神系质变需要排他 |
| tags | string[] | 用于筛选、被动加成、联动判断 |
| mechanic_family | string | 用于避免同构技能重复堆叠 |
| offer_rule | object | 技能进入升级池的条件 |
| trigger_rules | array | 触发规则 |
| effects | array | 实际效果 |

---

# 二、技能类型枚举

```ts
enum SkillType {
  Attack = "attack",
  Dash = "dash",
  Cast = "cast",
  Summon = "summon",
  Passive = "passive",
  Power = "power",
  Core = "core",
  Fusion = "fusion"
}
```

| 类型 | 说明 |
| --- | --- |
| attack | 普攻替换 / 普攻强化，有且仅有一个 |
| dash | 冲刺强化，有且仅有一个 |
| cast | 自动释放技能 |
| summon | 召唤物 |
| passive | 被动加成 |
| power | 特殊能力 / 触发能力 |
| core | 神系质变，有且仅有一个 |
| fusion | 双神联动技能 |

---

# 三、神系枚举

```ts
enum SkillSchool {
  Fire = "fire",
  Frost = "frost",
  Thunder = "thunder",
  Curse = "curse",
  Holy = "holy",
  Chaos = "chaos"
}
```

---

# 四、状态系统模型

这版只保留你已经使用的核心状态，不再额外加命中率、恐惧、眩晕、沉默、易伤等杂状态。

## 1\. StatusDefinition

```json
{
  "id": "burning",
  "name": "Burning",
  "duration": 4.0,
  "max_stacks": 5,
  "tick_interval": 0.5,
  "on_tick_effects": [
    {
      "type": "damage",
      "damage_type": "fire",
      "power_scale": 0.18
    }
  ]
}
```

## 2\. 核心状态数值

| 状态 | 持续时间 | 最大层数 | 效果 |
| --- | --- | --- | --- |
| Burning | 4s | 5 | 每 0.5s 造成 `0.18P × 层数` 火焰伤害 |
| Chilled | 6s | 7 | 每层降低敌人移动速度 6%；达到 7 层后转为 Frozen |
| Frozen | 普通 1.2s / 精英 0.5s / Boss 0.15s | 1 | 敌人停止移动；Boss 只短暂打断当前行为 |
| Conductive | 5s | 5 | 每层使目标受到雷电伤害 +6%；达到 5 层触发 Overload |
| Overload | 即时 | 1 | 雷爆事件，不作为持续状态保留 |
| Cursed | 3s | 3 | 结束时造成 `0.75P × 层数` 诅咒伤害 |
| Judgment | 6s | 5 | 达到 5 层触发神罚 |
| Instability | 6s | 4 | 达到 4 层触发裂变 |

## 3\. 状态触发事件

```ts
enum StatusEvent {
  Applied = "status_applied",
  Tick = "status_tick",
  Expired = "status_expired",
  MaxStackReached = "status_max_stack_reached",
  Removed = "status_removed"
}
```

---

# 五、通用数值公式

## 1\. 等级成长
| 技能类别 | 默认最大等级 | 伤害成长 | 范围成长 | 持续时间成长 | 冷却成长 |
| --- | --- | --- | --- | --- | --- |
| 普攻 | 5 | 每级 +8% | 每级 +3% | 每级 +5% | 不变 |
| 冲刺 | 5 | 每级 +10% | 每级 +4% | 每级 +5% | 不变 |
| 技能类 | 5 | 每级 +12% | 每级 +5% | 每级 +6% | 每级 -4% |
| 召唤类 | 5 | 每级 +10% | 不变 | 每级 +6% | 攻击间隔每级 -3% |
| 被动类 | 5 | 每级提升基础效果的 20% | 按效果决定 | 按效果决定 | 不变 |
| 特殊能力 | 5 | 每级 +12% | 每级 +5% | 每级 +5% | 每级 -3% |
| 联动技能 | 2 | 每级 +15% | 每级 +5% | 每级 +5% | 每级 -3% |
| 神系质变 | 1 | 固定 | 固定 | 固定 | 固定 |

## 2\. 稀有度倍率

| 稀有度 | 倍率 |
| --- | --- |
| normal | 1.00 |
| rare | 1.25 |
| epic | 1.55 |
| legendary | 1.95 |

---

# 六、Effect 效果模型

所有技能都应该拆成这些基础 Effect，Codex 实现时不要为每个技能写一个类。

```ts
type Effect =
  | DamageEffect
  | ApplyStatusEffect
  | SpawnAreaEffect
  | SpawnProjectileEffect
  | SpawnSummonEffect
  | AddModifierEffect
  | GrantShieldEffect
  | HealEffect
  | PullEffect
  | KnockbackEffect
  | RepeatSkillEffect
  | TransformAreaEffect
  | TransferStatusEffect;
```

## 1\. DamageEffect

```json
{
  "type": "damage",
  "damage_type": "fire",
  "source_type": "cast",
  "power_scale": 1.2,
  "radius": 1.5
}
```

## 2\. ApplyStatusEffect

```json
{
  "type": "apply_status",
  "status": "burning",
  "stacks": 1,
  "duration": 4.0
}
```

## 3\. SpawnAreaEffect

```json
{
  "type": "spawn_area",
  "area_id": "fire_path",
  "radius": 1.0,
  "duration": 3.0,
  "tick_interval": 0.5,
  "effects_on_tick": [
    {
      "type": "damage",
      "damage_type": "fire",
      "power_scale": 0.16
    },
    {
      "type": "apply_status",
      "status": "burning",
      "stacks": 1
    }
  ]
}
```

## 4\. SpawnProjectileEffect

```json
{
  "type": "spawn_projectile",
  "projectile_id": "ice_shard",
  "count": 4,
  "speed": 9.0,
  "pierce": 1,
  "bounce": 0,
  "damage": {
    "damage_type": "frost",
    "power_scale": 0.45
  },
  "on_hit": [
    {
      "type": "apply_status",
      "status": "chilled",
      "stacks": 1
    }
  ]
}
```

## 5\. TriggerRule

```json
{
  "trigger": "on_enemy_death",
  "conditions": [
    {
      "target_has_status": "burning"
    }
  ],
  "cooldown": 0.2,
  "max_triggers_per_second": 5,
  "effects": []
}
```

---

# 七、基础神系技能数值表：84 个

## 火焰神系

| 技能名 | 类型 | 触发 / 冷却 | 基础数值 | 状态 / 资源 |
| --- | --- | --- | --- | --- |
| 灼热攻击 | 普攻 | 攻击命中 | 攻击伤害 +20%；每第 4 次命中生成火焰路径，R0.8，持续 2.5s，tick `0.12P` | Burning +1 |
| 烈焰疾行 | 冲刺 | 冲刺时 | 路径伤害 `0.8P`；火焰路径持续 3s，tick `0.14P` | Burning +1 |
| 流星火雨 | 技能 | CD 6.5s | 3 枚陨石；每枚 `2.2P`，R1.6；落点燃烧地面持续 3s | Burning +1 |
| 熔岩裂涌 | 技能 | CD 5.5s | 裂缝长 6，宽 0.8；总伤害 `1.6P`；持续 1.5s | Burning +1 |
| 焚风旋涡 | 技能 | CD 7s | 玩家周围 R2.2 火焰旋涡，持续 4s；每 0.5s `0.25P` | Burning +1 |
| 赤焰龙 | 召唤 | 攻击间隔 3s | 1 条龙；锥形龙息，长 4，角度 45°，伤害 `1.4P` | Burning +1 |
| 余烬狐群 | 召唤 | 每施加 8 次 Burning | 召唤 2 只火狐；每只冲撞 `0.6P`，爆裂 R1.2，伤害 `0.8P` | Burning +1 |
| 炽燃专注 | 被动 | 常驻 | Burning 伤害 +25%，持续时间 +20% | 强化 Burning |
| 过热施法 | 被动 | 受伤触发，CD 12s | 5s 内技能类伤害 +30%，范围 +15% | 无 |
| 焦土亲和 | 被动 | 敌人在火焰地面上 | 该敌人受到 Burning 伤害 +35% | 强化地面火 |
| 燃爆连锁 | 特殊 | 每击杀 12 个 Burning 敌人 | 最后目标爆炸，R2.2，伤害 `2.4P`；爆炸击杀最多连锁 3 次 | Burning 死亡收益 |
| 余烬附着 | 特殊 | Burning 敌人死亡，ICD 0.2s | 生成余烬弹，伤害 `0.45P`，飞向最近敌人 | Burning +1 |
| 引燃核心 | 特殊 | 技能命中 Burning 敌人，ICD 0.4s | 消耗 1s Burning，产生 R1.2 爆发，伤害 `0.9P` | 消耗 Burning |
| 炼狱循环 | 神系质变 | 常驻 | Burning 敌人死亡必定小爆裂，R1.4，`0.8P`；每 20 次爆裂额外召唤 1 枚陨石 | Burning 自循环 |

---

## 寒霜神系

| 技能名 | 类型 | 触发 / 冷却 | 基础数值 | 状态 / 资源 |
| --- | --- | --- | --- | --- |
| 寒霜攻击 | 普攻 | 攻击命中 | 攻击伤害 +15%；每第 4 次命中已 Chilled 目标额外 +1 层 | Chilled +1 |
| 冰片突袭 | 冲刺 | 冲刺时 | 向周围发射 4 枚冰片；每枚 `0.45P`，穿透 1 | Chilled +1 |
| 冰霜领域 | 技能 | CD 6s | R2.0，持续 4s；每 0.5s `0.22P` | 每 1s Chilled +1 |
| 极寒冰矛 | 技能 | CD 5s | 1 枚冰矛，伤害 `1.8P`，穿透 4；命中 Frozen 敌人溅射 R1.5，`0.8P` | Chilled +2 |
| 暴雪云团 | 技能 | CD 8s | R2.6，持续 5s；每 0.5s `0.16P`，缓慢移动 | 每 1s Chilled +1 |
| 霜狼 | 召唤 | 攻击间隔 1.4s | 2 只霜狼；每次攻击 `0.45P` | Chilled +1 |
| 冰晶守卫 | 召唤 | 持续 10s，脉冲 1.5s | 1 个守卫；脉冲 R2.0，伤害 `0.5P` | Chilled +1 |
| 碎冰处决 | 被动 | 生命阈值检测 | 普通怪低于 12% 生命直接碎裂；精英 4%；Boss 不直接处决 | 需要 Chilled / Frozen |
| 冰封易伤 | 被动 | 目标 Frozen 时 | Frozen 敌人受到伤害 +25% | 强化 Frozen |
| 寒意延展 | 被动 | 常驻 | Chilled / Frozen 持续时间 +20%；冰霜区域持续时间 +20% | 强化冰系持续 |
| 霜环反冲 | 特殊 | 附近敌人 ≥8 或冲刺结束，CD 6s | 释放 R2.2 冰环，伤害 `0.9P` | Chilled +3；普通怪直接 Frozen |
| 冰裂连锁 | 特殊 | Frozen 敌人被技能命中，ICD 0.5s | 释放 6 枚碎冰片，每枚 `0.35P` | Chilled +1 |
| 冰雾护身 | 特殊 | 每冻结 10 个敌人 | 获得 8% 最大生命值护盾；护盾破裂时释放 R1.8 冰爆 | Chilled +3 |
| 绝对零度 | 神系质变 | 常驻 | Frozen 所需 Chilled 层数从 7 降为 5；每 6s 全屏敌人 Chilled +1；Frozen 碎裂生成 R1.3 冰霜领域 2s | 冰冻循环 |

---

## 雷霆神系

| 技能名 | 类型 | 触发 / 冷却 | 基础数值 | 状态 / 资源 |
| --- | --- | --- | --- | --- |
| 雷鸣攻击 | 普攻 | 攻击命中 | 攻击伤害 +15%；每第 4 次攻击释放电弧，命中 2 个目标，每跳 `0.5P` | Conductive +1 |
| 球状闪电 | 冲刺 | 冲刺时 | 路径伤害 `0.8P`；终点生成雷球 2.5s，每 0.5s `0.18P` | Conductive +1 |
| 连锁闪电 | 技能 | CD 3.5s | 初始伤害 `1.0P`，弹射 4 次，每跳伤害 -15% | Conductive +1 |
| 雷暴法阵 | 技能 | CD 7s | 持续 4s；每 0.6s 落雷一次，每次 R0.8，`0.8P` | Conductive +1 |
| 电磁脉冲 | 技能 | CD 6.5s | 玩家周围 R2.8，伤害 `1.2P`；对 Conductive 目标伤害 +50% | 打断当前行为 |
| 雷兽猞猁 | 召唤 | 攻击间隔 1.2s | 1 只雷兽；跳跃攻击 `0.45P`，最多跳 3 个敌人 | Conductive +1 |
| 风暴乌鸦 | 召唤 | 攻击间隔 2s | 2 只乌鸦；远程落雷 `0.7P` | Conductive +1 |
| 高频放电 | 被动 | 常驻 | 雷电技能冷却 -15% | 强化频率 |
| 超导体 | 被动 | 目标 Conductive 时 | 目标受到雷电伤害 +20%；雷电弹射距离 +15% | 强化 Conductive |
| 静电蓄能 | 被动 | 每 18 次雷电命中 | 获得 4s 静电爆发：攻速 +20%，技能冷却 -10% | 雷击命中转爆发 |
| 过载爆破 | 特殊 | Conductive 达到 5 层 | 触发 R1.8 雷爆，伤害 `1.5P`；向 4 个附近敌人传递 2 层 Conductive | Overload |
| 二重落雷 | 特殊 | 每 3 次雷电命中 | 追加一次小落雷，伤害 `0.45P` | Conductive +1 |
| 雷磁牵引 | 特殊 | 雷电命中 Conductive 敌人，ICD 0.5s | 小范围牵引 R1.2 内轻型敌人，并造成 `0.25P` | 聚怪 |
| 雷暴中枢 | 神系质变 | 每 60 次雷电命中 | 触发全屏雷暴，8 次落雷，每次 `0.9P`；Overload 后保留 2 层 Conductive | 雷电循环 |

---

## 诅咒神系

| 技能名 | 类型 | 触发 / 冷却 | 基础数值 | 状态 / 资源 |
| --- | --- | --- | --- | --- |
| 诅咒攻击 | 普攻 | 攻击命中 | 攻击伤害 +18%；低生命敌人额外 Cursed 伤害 +20% | Cursed +1 |
| 魂链疾行 | 冲刺 | 冲刺时 | 连接最多 3 个 Cursed 敌人；每个 `0.6P` | 每个目标恢复 1% 最大生命 |
| 黑蛇追猎 | 技能 | CD 4.5s | 召唤 2 条黑蛇；每条命中 `0.65P` | Cursed +1 |
| 死镰回旋 | 技能 | CD 6s | 镰刀飞出与返回各造成 `1.0P`；对 Cursed 目标 +30% | 无 |
| 终末法阵 | 技能 | CD 7.5s | 延迟 1.2s 后爆发，R2.2，基础 `2.0P`；每层 Cursed 额外 `0.6P` | 消耗 Cursed |
| 亡骸仆从 | 召唤 | 每 5 个 Cursed 敌人死亡 | 召唤 1 个骷髅，持续 12s；攻击间隔 1.2s，`0.35P` | 无 |
| 魂鸦 | 召唤 | 每 3 个 Cursed 敌人死亡 | 发射灵魂弹，伤害 `0.8P` | 无 |
| 吸血仪式 | 被动 | Cursed 伤害 / 击杀 | Cursed 击杀恢复 1% 最大生命；Cursed tick 恢复 0.15% 最大生命，ICD 0.5s | 续航 |
| 疫咒扩散 | 被动 | Cursed 敌人死亡 | 向 R2.5 内最多 3 个敌人传播 1 层 Cursed | Cursed 传播 |
| 临终加深 | 被动 | 目标生命越低 | Cursed 结算伤害最高 +40%；Boss 只吃 30% 效果 | 斩杀 |
| 恐惧低语 | 特殊 | Cursed 敌人靠近玩家，CD 1.5s | 推开最多 3 个敌人，并造成 `0.3P` | 不作为状态，只是位移 |
| 灵魂收割 | 特殊 | 每击杀 12 个 Cursed 敌人 | 下一次技能类伤害 +35% | 击杀储能 |
| 死亡契约 | 特殊 | CD 8s | 给最高生命敌人施加 2 层 Cursed；若 5s 内死亡，R2.0 爆炸 `1.8P` | 契约处决 |
| 万咒归棺 | 神系质变 | 常驻 | Cursed 敌人死亡传播自身已有核心状态；30% 未结算 Cursed 转为灵魂债务；债务满 20 点释放 10 发灵魂弹，每发 `0.5P` | 诅咒循环 |

---

## 神圣神系

| 技能名 | 类型 | 触发 / 冷却 | 基础数值 | 状态 / 资源 |
| --- | --- | --- | --- | --- |
| 裁决攻击 | 普攻 | 攻击命中 | 攻击伤害 +16%；命中 Judgment 目标获得 0.5% 最大生命护盾，ICD 0.2s | Judgment +1 |
| 天翼冲刺 | 冲刺 | 冲刺时 | 获得 8% 最大生命护盾 1.2s；路径伤害 `0.7P` | Judgment +1 |
| 圣光射线 | 技能 | CD 5.5s | 降下 3 道圣光；每道 R0.7，伤害 `0.9P` | Judgment +1 |
| 神圣结界 | 技能 | CD 10s | R2.3，持续 5s；每 0.5s `0.18P`；每秒恢复 1% 最大生命护盾 | Judgment +1 |
| 审判圣锤 | 技能 | CD 7s | 命中最高生命目标，R1.4，伤害 `2.4P` | Judgment +2，打断当前行为 |
| 炽天使 | 召唤 | 攻击间隔 1.3s | 1 个炽天使；圣光弹 `0.5P`；每 5s 给玩家 2% 最大生命护盾 | Judgment +1 |
| 圣盾卫士 | 召唤 | 反击 CD 2s | 格挡一次最多 10% 最大生命伤害；反击 `0.6P` | Judgment +1 |
| 庇护 | 被动 | 常驻 | 护盾上限 +20%，护盾恢复 +20%；有护盾时神圣伤害 +15% | 强化护盾 |
| 虔诚 | 被动 | 护盾溢出时 | 护盾溢出转化为 4s 伤害 +20% | 防御转输出 |
| 弱化审判 | 被动 | 目标带 Judgment | 每层 Judgment 使目标造成伤害 -3%，受到神圣伤害 +5% | Judgment 强化 |
| 神罚 | 特殊 | Judgment 达到 5 层 | R1.2 圣光打击，伤害 `1.6P`，清空 Judgment | Judgment 爆发 |
| 反击圣印 | 特殊 | 护盾破裂 / 受重击，CD 8s | R2.2 圣光冲击，伤害 `1.2P` | Judgment +1 |
| 赦免之光 | 特殊 | Judgment 敌人死亡 | 恢复 2% 最大生命护盾；若护盾已满，R1.4 爆炸 `0.8P` | 护盾收益 |
| 终裁神域 | 神系质变 | 常驻 | 神罚后保留 2 层 Judgment；每次神罚给玩家 3% 最大生命护盾，并向附近敌人施加 Judgment +1 | 神罚循环 |

---

## 混沌神系

| 技能名 | 类型 | 触发 / 冷却 | 基础数值 | 状态 / 资源 |
| --- | --- | --- | --- | --- |
| 混沌攻击 | 普攻 | 攻击命中 | 攻击伤害 +14%；每 3 次命中按顺序触发分裂 / 折返 / 追加弱化命中 | Instability +1 |
| 裂隙步 | 冲刺 | 冲刺时 | 起点和终点生成裂隙，持续 4s；每 0.5s `0.12P` | 每秒 Instability +1 |
| 虚空裂缝 | 技能 | CD 8s | R2.5，持续 4s；牵引敌人；每 0.5s `0.16P` | 每秒 Instability +1 |
| 奇点弹幕 | 技能 | CD 5s | 发射 5 个混沌球；每个 `0.5P`，弹跳 3 次；命中 Instability 目标分裂一次 | Instability +1 |
| 异变脉冲 | 技能 | CD 7s | 玩家周围 R3.0 脉冲，伤害 `0.9P` | Instability +2；满层直接裂变 |
| 混沌分身 | 召唤 | 持续 8s | 复制最近一次普攻或技能，造成 35% 伤害，每 2s 执行一次 | 无 |
| 虚空巨口 | 召唤 | CD 12s，持续 6s | R2.0，牵引敌人；每 0.5s `0.2P`；普通怪低于 8% 生命被吞噬 | Instability +1 |
| 熵增 | 被动 | Instability 裂变后 | 轮流获得伤害 / 范围 / 冷却 / 移速强化之一，持续 5s，数值 +12% | 裂变成长 |
| 几何失衡 | 被动 | 弹体生成时 | 弹体按顺序获得分裂 / 回旋 / 弹跳；单发伤害 -10% | 弹道变化 |
| 反常稳定 | 被动 | 每 5 次混沌效果 | 下一次混沌效果触发最高收益版本 | 混沌保底 |
| 裂变爆发 | 特殊 | Instability 达到 4 层 | R1.8 爆发，伤害 `1.4P`；原地生成小裂隙 2s | Instability 裂变 |
| 回声施法 | 特殊 | 每释放 4 次技能类 | 重复上一次技能，造成 40% 伤害 | 技能复制 |
| 混沌交换 | 特殊 | CD 6s | 交换两个 Instability 敌人位置；路径造成 `0.8P` | 空间换位 |
| 混沌奇点 | 神系质变 | 每 25 次裂变 | 生成 R6.0 奇点，吸附 2s；复制最近一次非混沌技能 50% 效果；结束爆发 `3.0P` | 裂变终局爆发 |

---

# 八、60 个联动技能基础数值

联动技能默认：
| 参数 | 数值 |
| --- | --- |
| max_level | 2 |
| 解锁条件 | 同时拥有神系技能总数 ≥2 个技能 |
| 伤害成长 | 每级 +15% |
| 范围成长 | 每级 +5% |
| 持续成长 | 每级 +5% |
| 冷却成长 | 每级 -3% |

| 技能名 | 融合神系 | 触发 / 冷却 | 基础数值 |
| --- | --- | --- | --- |
| 蒸灼雾域 | 火焰 × 寒霜 | Burning 敌人进入冰霜区域，ICD 1s | 生成 R2.0 蒸汽区 3s；每 0.5s `0.14P`；每 1s Chilled +1 |
| 碎冰余烬 | 火焰 × 寒霜 | Frozen 敌人被火焰击杀 / 碎裂，ICD 0.3s | 6 枚碎冰 `0.25P`，4 枚余烬 `0.3P`，散射 R3.5 |
| 等离子火径 | 火焰 × 雷霆 | 雷电命中火焰地面，ICD 0.8s | 火焰地面额外放电 3s；每 0.5s `0.12P` 雷伤 |
| 雷燃流星 | 火焰 × 雷霆 | 火焰技能命中 Conductive 目标 | 向 3 个 Conductive 目标释放电弧；每跳 `0.45P` |
| 灰烬咒文 | 火焰 × 诅咒 | Burning tick 命中 Cursed 目标 | 每次 tick 缩短 Cursed 0.25s；Cursed 结算后生成 R1.2 火地 2s |
| 黑焰蛇群 | 火焰 × 诅咒 | 诅咒弹体命中 Burning 目标 | 留下黑焰路径 2.5s；tick `0.12P`；经过敌人 Cursed +1 |
| 圣焰赦免 | 火焰 × 神圣 | Judgment 触发神罚且目标 Burning | 消耗 1.5s Burning；获得 4% 最大生命护盾；释放长 4 光束 `1.1P` |
| 燃光结界 | 火焰 × 神圣 | 神圣结界存在时 | 结界边缘每 0.5s `0.1P`；Burning 敌人在内死亡恢复 1% 护盾 |
| 余烬回声 | 火焰 × 混沌 | 火焰路径穿过裂隙，ICD 2s | 1s 后反向重放路径，持续 2s，tick `0.13P` |
| 熔火分裂 | 火焰 × 混沌 | 火焰弹体命中 Instability 目标，ICD 0.3s | 分裂 2 枚小火弹，每枚 `0.35P`，可 Burning +1 |
| 凝火成晶 | 寒霜 × 火焰 | 冰霜区域覆盖火焰路径 | 交界处生成 5 个冰晶尖刺，每个 `0.35P`，Chilled +1 |
| 霜燃碎片 | 寒霜 × 火焰 | Burning 敌人被 Frozen 后受到冰伤 | 喷出 8 枚霜燃碎片，每枚 `0.22P`；命中 Burning 目标额外 `0.15P` |
| 雷击冰柱 | 寒霜 × 雷霆 | 雷电命中 Frozen 目标，ICD 1s | 生成冰柱 3s，R0.7；每 1s 对 R1.8 敌人 `0.25P`，Chilled +1 |
| 极光导霜 | 寒霜 × 雷霆 | Conductive 敌人在冰区内 | 向另一 Conductive 目标释放寒光，路径伤害 `0.5P`，沿途 Chilled +1 |
| 冰棺咒爆 | 寒霜 × 诅咒 | Cursed 目标被冻结 | 暂停 Cursed；解冻时立即结算，并释放 R1.6 冰冲击 `0.8P` |
| 寒镰收割 | 寒霜 × 诅咒 | 诅咒弹体命中 Frozen 目标 | 释放 6 枚冰片，每枚 `0.3P`，优先飞向 Cursed 目标 |
| 圣霜锚点 | 寒霜 × 神圣 | Judgment 敌人进入冰区 | 该敌人成为锚点 3s；每 1s R2.0 扩散 Chilled +1；每命中 3 人给 1% 护盾 |
| 审判冰矛 | 寒霜 × 神圣 | 极寒冰矛释放 | 优先 Judgment 最高目标；若目标 Frozen，额外圣光 `0.9P` |
| 裂隙雪崩 | 寒霜 × 混沌 | Frozen 敌人在裂隙附近碎裂 | 裂隙喷出扇形冰雪，长 4，伤害 `0.9P`，Chilled +2 |
| 反相冰片 | 寒霜 × 混沌 | 冰片进入裂隙 | 从远处敌人背后飞出，伤害 +20%，Chilled +1 |
| 轰燃电弧 | 雷霆 × 火焰 | 连锁闪电命中 Burning 目标 | 沿最近火焰路径额外跳转 1 次，伤害 `0.55P` |
| 雷火回路 | 雷霆 × 火焰 | 雷电命中燃烧地面 | 地面储存一次放电；敌人进入时 `0.7P`，Conductive +1 |
| 破冰雷鸣 | 雷霆 × 寒霜 | Overload 在 Frozen 目标触发 | 目标直接碎裂；雷电跳向 4 个 Chilled 目标，每跳 `0.5P` |
| 极寒电容 | 雷霆 × 寒霜 | 雷电命中 Chilled 目标，ICD 0.5s | 将 Conductive +1 传播给附近 1 个 Chilled 目标 |
| 咒雷回跳 | 雷霆 × 诅咒 | 连锁闪电命中 Cursed 目标 | 下一跳优先 Cursed；若无目标，当前 Cursed 剩余时间 -0.5s |
| 黑雷收束 | 雷霆 × 诅咒 | 雷暴每第 5 次落雷 | 连续劈击 1 个 Cursed 目标 3 次，每次 `0.55P`；最后一次立即结算 Cursed |
| 审判导线 | 雷霆 × 神圣 | 雷电命中 Judgment 目标 | 与另一个 Judgment 目标生成雷线 2s；穿线敌人每 0.5s `0.2P` |
| 护盾电容 | 雷霆 × 神圣 | 获得护盾 / 护盾破裂 | 获得护盾后下一次雷电 +1 小落雷 `0.45P`；护盾破裂触发最近目标 Overload |
| 分形电弧 | 雷霆 × 混沌 | 雷电弹射到 Instability 目标 | 下一跳从裂隙出现并分裂 2 道，每道 `0.35P` |
| 裂隙雷球 | 雷霆 × 混沌 | 雷球进入裂隙 | 传送到远处怪群，持续放电 3s；每 0.5s `0.18P` |
| 灰烬魂契 | 诅咒 × 火焰 | Burning tick 命中 Cursed 目标 | 当前目标下一次 Cursed 结算伤害 +8%，最多叠 5 次 |
| 燃魂仆从 | 诅咒 × 火焰 | Cursed + Burning 敌人死亡 | 召唤 1 个燃魂仆从 10s；首次攻击 `0.6P` 并 Burning +1 |
| 冰棺契约 | 诅咒 × 寒霜 | Cursed 目标 Frozen | Frozen 内不结算；若 Frozen 中死亡，Cursed 转移给最高生命附近敌人 |
| 寒镰追魂 | 诅咒 × 寒霜 | 死镰命中 Frozen 目标 | 额外飞向最近 Cursed 目标，造成 `0.75P` |
| 雷咒反噬 | 诅咒 × 雷霆 | Overload 在 Cursed 目标触发 | Cursed 立即结算；雷电跳向未 Cursed 敌人，伤害 `0.6P`，Conductive +1 |
| 黑蛇导电 | 诅咒 × 雷霆 | 黑蛇寻敌 | 黑蛇优先 Conductive 方向；命中 Conductive 后向 R2.0 内 2 人传播 Cursed +1 |
| 告解诅印 | 诅咒 × 神圣 | Judgment + Cursed 敌人准备攻击 | 打断当前攻击；Cursed 立即结算；玩家获得 1.5% 护盾 |
| 赦罪收割 | 诅咒 × 神圣 | Judgment + Cursed 敌人死亡 | 获得 2% 护盾；若死于 Cursed，额外圣光 `0.7P` |
| 悖论咒印 | 诅咒 × 混沌 | Cursed 敌人触发 Instability 裂变 | Cursed 复制到远处 1 个敌人；复制版伤害 60%，持续 2s |
| 裂隙葬礼 | 诅咒 × 混沌 | Cursed 敌人在裂隙附近死亡 | 裂隙发射诅咒弹，`0.5P`，Cursed +1 |
| 圣焰净化 | 神圣 × 火焰 | 圣光命中 Burning 敌人 | 消耗 1s Burning；获得 2% 护盾；额外 `0.4P` 圣光伤害 |
| 太阳圣锤 | 神圣 × 火焰 | 审判圣锤命中 Burning 目标 | 生成十字圣焰路径 3s；路径 tick `0.14P`；Judgment +1，Burning +1 |
| 冰晶庇护 | 神圣 × 寒霜 | Frozen + Judgment 敌人死亡 | 获得 3% 护盾；护盾满时生成 R1.5 冰区 2s |
| 圣霜光束 | 神圣 × 寒霜 | 圣光射线命中 Chilled 目标 | 沿轨迹留下冰霜路径 2s；命中 Frozen 目标时射线持续 +0.7s |
| 雷盾祷告 | 神圣 × 雷霆 | 获得护盾 / 护盾破裂 | 获得护盾时最近 Conductive 目标受 `0.45P` 落雷；破裂时 R2.0 Judgment +1 |
| 圣雷裁决 | 神圣 × 雷霆 | 神罚命中 Conductive 目标 | 额外触发 Overload；Overload 命中目标 Judgment +1 |
| 净罪锁链 | 神圣 × 诅咒 | 圣光命中 Cursed 目标 | 跳向另一个 Cursed 目标，最多 3 跳；每跳 `0.45P`，恢复 0.8% 护盾 |
| 忏悔结界 | 神圣 × 诅咒 | 神圣结界内有 Cursed 敌人 | 每 1s 缩短 Cursed 0.3s；Cursed 敌人死亡使结界持续 +0.5s |
| 神域裂隙 | 神圣 × 混沌 | 神圣结界覆盖裂隙 | 裂隙每 1s 释放 R2.0 圣光脉冲，`0.4P`，Judgment +1 |
| 裁决回声 | 神圣 × 混沌 | Judgment 在 Instability 目标触发神罚 | 从最近裂隙额外释放一次 50% 伤害神罚 |
| 裂火分叉 | 混沌 × 火焰 | 火焰弹体经过裂隙 | 分成 2 枚小火弹，每枚 `0.35P`，角度 ±25° |
| 熔岩折返 | 混沌 × 火焰 | 熔岩裂缝触碰裂隙 | 从裂隙另一侧反向延伸 3 单位，造成 `0.8P` |
| 零度裂隙 | 混沌 × 寒霜 | 冰霜区域生成在裂隙附近 | 复制 50% 半径冰区到远处敌人脚下，持续 2s |
| 碎冰折跃 | 混沌 × 寒霜 | Frozen 碎裂产生冰片 | 冰片进入裂隙后从远处飞出，伤害 `0.3P`，Chilled +1 |
| 量子过载 | 混沌 × 雷霆 | Instability 目标触发 Overload | 原地与远处敌群各释放一次 R1.6 雷爆，每次 `1.0P` |
| 跃迁雷球 | 混沌 × 雷霆 | 雷球接触裂隙 | 传送到远处怪群中心，持续时间刷新为 3s |
| 咒文回声 | 混沌 × 诅咒 | Cursed 结算且目标 Instability | 从最近裂隙重复一次 50% 伤害诅咒冲击 |
| 裂隙换咒 | 混沌 × 诅咒 | 每 4s | 裂隙寻找 1 个 Cursed 敌人，将 Cursed +1 复制给远处 1 个敌人 |
| 虚空圣盾 | 混沌 × 神圣 | 玩家获得护盾，ICD 1s | 最近裂隙释放 R2.0 冲击，`0.35P`，Judgment +1 |
| 回响裁决 | 混沌 × 神圣 | 神罚命中 Instability 目标 | 1s 后从另一个裂隙再次降下 50% 伤害神罚 |

---

# 九、技能进入升级池规则

## 1\. 基础神系技能

```json
{
  "required_schools": ["fire"],
  "required_skills": [],
  "blocked_by_exclusive_group": []
}
```

## 2\. 普攻 / 冲刺 / 质变排他

| 类型 | exclusive_group |
| --- | --- |
| 普攻类 | attack_school |
| 冲刺类 | dash_school |
| 神系质变 | core_school |

玩家拿了 `fire_attack_searing` 后，其他神系的 attack 类不再进入池。

## 3\. 联动技能进入池

```json
{
  "required_schools": ["fire", "frost"],
  "required_min_skill_count": {
    "fire": 2,
    "frost": 1
  }
}
```

建议规则：

| 条件 | 结果 |
| --- | --- |
| 神系种类 ≥2 | 开启该神系联动 |
| 联动技能 ≥ 1 | 禁止出现神系联动技能 |
| 已拥有神系质变 | 对应神系联动权重 +30% |

---

# 十、Godot 实现建议

如果你用 Godot，实现可以这样分层。

## 1\. 核心节点 / 类

```text
SkillSystem
├── SkillDatabase
├── SkillRuntime
├── SkillOfferService
├── TriggerRouter
├── EffectExecutor
├── StatusSystem
├── ProjectileSpawner
├── AreaSpawner
├── SummonSystem
└── ModifierSystem
```

## 2\. 推荐职责

| 类 | 负责内容 |
| --- | --- |
| SkillDatabase | 读取 JSON / CSV 技能配置 |
| SkillRuntime | 保存玩家已拥有技能、等级、冷却、计数器 |
| SkillOfferService | 升级时筛选候选技能 |
| TriggerRouter | 接收战斗事件并分发给技能 |
| EffectExecutor | 执行 damage / status / spawn 等效果 |
| StatusSystem | 管理 Burning、Chilled、Frozen 等状态 |
| ModifierSystem | 处理被动加成、数值倍率、条件增伤 |
| ProjectileSpawner | 生成弹体 |
| AreaSpawner | 生成地面区域 |
| SummonSystem | 管理召唤物 |

---

# 十一、战斗事件模型

```ts
enum CombatEventType {
  AttackHit = "attack_hit",
  DashStart = "dash_start",
  DashEnd = "dash_end",
  CastSkill = "cast_skill",
  ProjectileHit = "projectile_hit",
  AreaTick = "area_tick",
  EnemyDeath = "enemy_death",
  StatusApplied = "status_applied",
  StatusTick = "status_tick",
  StatusExpired = "status_expired",
  StatusMaxStack = "status_max_stack",
  ShieldGained = "shield_gained",
  ShieldBroken = "shield_broken",
  SummonAttackHit = "summon_attack_hit"
}
```

每个事件建议结构：

```json
{
  "type": "enemy_death",
  "source": "player",
  "target": "enemy_001",
  "position": [120, 240],
  "source_skill_id": "fire_attack_searing",
  "tags": ["fire", "burning"],
  "payload": {
    "damage": 100,
    "status": "burning"
  }
}
```

---

# 十二、给 Codex 的实现 Prompt

你可以直接把下面这段丢给 Codex：

```text
请基于 Godot 4 实现一个数据驱动的 Roguelike 技能系统。

要求：
1. 技能不硬编码，使用 JSON 配置 SkillDefinition。
2. SkillDefinition 包含：
   id, name, school, fusion_school, type, rarity, max_level,
   exclusive_group, tags, mechanic_family, offer_rule, trigger_rules, effects。
3. 实现 SkillDatabase 读取技能 JSON。
4. 实现 SkillRuntime 保存玩家已拥有技能、等级、冷却、触发计数器。
5. 实现 TriggerRouter，接收 AttackHit、DashStart、DashEnd、ProjectileHit、AreaTick、EnemyDeath、StatusApplied、StatusMaxStack、ShieldGained、ShieldBroken 等事件。
6. 实现 EffectExecutor，支持：
   damage, apply_status, spawn_area, spawn_projectile, spawn_summon,
   add_modifier, grant_shield, heal, pull, knockback, repeat_skill,
   transform_area, transfer_status。
7. 实现 StatusSystem，只包含：
   Burning, Chilled, Frozen, Conductive, Overload, Cursed, Judgment, Instability。
8. 实现排他规则：
   attack_school、dash_school、core_school 三类只能拥有一个。
9. 实现联动技能进入池规则：
   主神系技能数量 >= 2，副神系技能数量 >= 1。
10. 实现 SkillOfferService，根据 offer_rule、exclusive_group、required_schools、required_min_skill_count 生成升级候选。
11. 所有数值使用 power_scale，不直接写死伤害。
12. 支持技能等级成长和稀有度倍率。
13. 输出完整 GDScript 类结构和一个 fire_attack_searing、frost_cast_frost_zone、fusion_fire_frost_steam_mist 的 JSON 示例。
```

---

# 十三、最小可运行版本建议

第一版不要一次性把 144 个技能全做完。最稳的实现顺序是：

| 阶段 | 目标 |
| --- | --- |
| 第 1 步 | 实现 SkillDefinition / SkillDatabase |
| 第 2 步 | 实现 StatusSystem |
| 第 3 步 | 实现 damage / apply_status / spawn_area / spawn_projectile |
| 第 4 步 | 实现普攻、冲刺、技能类 |
| 第 5 步 | 实现被动 ModifierSystem |
| 第 6 步 | 实现召唤物 |
| 第 7 步 | 实现联动技能筛选 |
| 第 8 步 | 实现复杂联动效果：路径回放、裂隙搬运、状态转移、技能复制 |

这套模型可以支撑你前面设计的 **84 个基础技能 + 60 个联动技能**，而且不会把每个技能都写成一坨 if/else。