# 武器分支设计对齐说明

本文记录 `全武器流派分支` 附件与当前配置的对齐方式，后续修改分支技能时应先跑校验再提交。

## 来源

- 设计来源：`C:/Users/dengj/.codex/attachments/ce4a2962-6c60-4b4e-9e8c-b5df19eebf43/pasted-text.txt`
- 覆盖武器：13 把武器，每把固定 4 条流派分支。
- 分支顺序：覆盖清潮流、精准猎杀流、状态反应流、生存控制流。

## 已同步范围

- `data/weapon_branches.json`
  - 分支 `display_name`
  - 分支 `role` / `description`
  - Lv2-Lv5 的 `display_name` / `description`
- `data/weapons.json`
  - 每把武器的 `branch_ids` 顺序改为设计文档四流派顺序。
- `docs/weapon_design_configs/*.json`
  - 武器 `display_name`
  - 分支 `display_name`
  - 分支 `levels`
  - 分支规则描述：`damage_ownership`、`boss_rule`、`limits`、`ui_feedback`
  - `level_path.*.summary`
  - `level_path.*.ui_feedback.readable_effect`
- `data/primary_attack.json`
  - 为 65 个主攻击配置补齐 `category: "active"`，使武器配置总流水线通过。

## 校验入口

- `node tools/validate_branch_design_alignment.js`
  - 校验附件设计与 `data/weapon_branches.json`、`data/weapons.json`、`docs/weapon_design_configs/*.json` 是否一致。
- `node tools/sync_branch_design_alignment.js`
  - 从附件重新同步分支名、等级描述、文档规则描述和分支顺序。
- `node tools/validate_weapon_authoring_pipeline.js`
  - 已接入分支设计对齐校验，作为完整武器配置校验入口。

## 边界

本次对齐不伪装 runtime 尚未实现的机制。

例如“最大命中目标 +2”“每第 4 次命中触发”“同源 CD”“不递归”“玩家受伤生成区域”等，如果当前 runtime 没有对应执行器，本次只同步为设计描述和文档规则，不强行写成会生效的 `modifiers` 或事件。

后续要落地具体机制时，应按以下顺序处理：

1. 在 runtime 增加明确执行能力或通用 action / modifier。
2. 将对应分支等级从设计描述映射到结构化 `modifiers`、`events_added` 或受校验支持的 `special_rules`。
3. 扩展 `tools/validate_weapon_graph.js` / `tools/weapon_config_contracts.js` 的契约。
4. 跑 `node tools/validate_weapon_authoring_pipeline.js`。
