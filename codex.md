# Codex Development Rules

后续 Codex 在本项目中进行任何开发、重构、清理或新增内容时，必须先以以下文档作为工程准则：

1. `docs/PROJECT_ENGINEERING_GUIDELINES.md`
2. `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`

## 必须遵守的原则

- 先阅读上述两份文档，再判断改动属于哪个系统边界。
- 不为了架构好看而重写系统；优先保留当前可运行的实现。
- 不修改玩法、数值、战斗表现、UI 表现和资源表现，除非用户明确要求。
- 新增角色、技能、怪物、状态、装备、UI 页面或配置字段时，必须按工程规范中的新增流程执行。
- 涉及伤害、状态、技能执行、怪物死亡、掉落、存档、结算的改动属于高风险改动，必须小步推进并运行对应验证。
- 不确定是否废弃的代码只标记为疑似废弃，不删除。
- 删除文件或逻辑前必须提供明确证据：无引用、无调用、无配置引用、无场景引用，或已被新系统完全替代。
- 新资源路径、配置 ID、技能引用、状态引用、场景引用必须可验证。
- Debug/DevTools 只能服务开发期，不应成为正式 runtime 的反向依赖。

## 开发前检查

每次开始实现前先确认：

1. 本次改动属于哪个系统：角色、技能、伤害、状态、怪物、掉落/升级、UI、配置、Debug 或工具。
2. 是否已有文档规定的入口和边界。
3. 是否会触碰 `PROJECT_STABILITY_AND_BOUNDARY_REPORT.md` 标记的高风险区域。
4. 是否需要新增或更新 `tools/validate/`、`tools/verify/` 中的验证。

## 完成前验证

提交或声明完成前，至少运行与改动范围匹配的验证。通用文档或配置改动至少运行：

```powershell
node tools/validate/check_text_encoding.js
```

涉及配置或运行逻辑时，按影响范围增加：

```powershell
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:coverage-report
```

涉及核心 gameplay、技能、状态、伤害、怪物、UI 或场景引用时，必须运行对应 `package.json` 中的 `verify:*` 脚本；高风险或跨系统改动应运行全部 `verify:*`。

## 指令优先级

用户最新明确指令优先于本文档。若用户要求与工程规范冲突，Codex 必须说明冲突点、影响范围和验证方式，再按用户指令推进。

