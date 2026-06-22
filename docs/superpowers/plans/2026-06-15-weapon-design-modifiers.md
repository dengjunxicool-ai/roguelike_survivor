# Weapon Design Modifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 13 个武器设计配置补齐每条分支 Lv2-Lv5 的升级修正器数据。

**Architecture:** 不修改运行时 `data/*.json`，只增强 `docs/weapon_design_configs/*.json`。每个分支新增 `level_path`，每级包含当前工程可消费的 `runtime_modifiers`、设计侧 `design_modifiers`、机制规则 `special_rules`、以及后续落运行时需要补的 `runtime_requirements`。

**Tech Stack:** JSON design configs, Node.js JSON parse validation, existing text encoding checker.

---

### Task 1: Add Level Modifier Blocks

**Files:**
- Modify: `docs/weapon_design_configs/*.json`

- [x] **Step 1: Add `level_path` to every branch**

For each branch object, add:

```json
"level_path": {
  "2": {
    "summary": "方向提示与基础取舍。",
    "runtime_modifiers": {},
    "design_modifiers": {},
    "special_rules": {},
    "runtime_requirements": []
  },
  "3": {
    "summary": "核心机制启动。",
    "runtime_modifiers": {},
    "design_modifiers": {},
    "special_rules": {},
    "runtime_requirements": []
  },
  "4": {
    "summary": "效率提升。",
    "runtime_modifiers": {},
    "design_modifiers": {},
    "special_rules": {},
    "runtime_requirements": []
  },
  "5": {
    "summary": "闭环成型。",
    "runtime_modifiers": {},
    "design_modifiers": {},
    "special_rules": {},
    "runtime_requirements": [],
    "enable_evolution_check": true
  }
}
```

- [x] **Step 2: Use archetype templates for numeric values**

Use `coverage_clear`, `precision_hunt`, `status_reaction`, and `survival_control` templates. Keep `runtime_modifiers` to current whitelist keys from `tools/weapon_config_contracts.js`, and put unsupported but needed keys under `design_modifiers`.

- [x] **Step 3: Validate JSON**

Run:

```powershell
node -e "const fs=require('fs');const path='docs/weapon_design_configs';for(const f of fs.readdirSync(path).filter(f=>f.endsWith('.json'))){JSON.parse(fs.readFileSync(path+'/'+f,'utf8'));console.log('OK '+f)}"
```

Expected: all 13 files print `OK`.

- [x] **Step 4: Validate text encoding**

Run:

```powershell
node tools\check_text_encoding.js --strict-mojibake
```

Expected: encoding check passes.
