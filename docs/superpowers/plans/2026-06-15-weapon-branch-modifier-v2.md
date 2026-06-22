# Weapon Branch Modifier V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将所有武器分支升级配置统一为 `weapon_branch_design_v2` 结构。

**Architecture:** 只修改 `docs/weapon_design_configs/*.json` 和该目录说明文档，不修改运行时 `data/*.json`。每个 `level_path.<level>` 使用同一字段集合：`upgrade_role`、`summary`、`runtime_modifiers`、`design_modifiers`、`damage_profile`、`trigger_rules`、`special_rules`、`boss_rules`、`limits`、`runtime_requirements`、`ui_feedback`、`enable_evolution_check`、`modifier_source`。

**Tech Stack:** JSON design configs, Node.js migration/validation, existing text encoding checker.

---

### Task 1: Migrate Design Configs

**Files:**
- Modify: `docs/weapon_design_configs/*.json`

- [x] **Step 1: Upgrade top-level schema**

Set every weapon design file to:

```json
"schema": "weapon_branch_design_v2"
```

- [x] **Step 2: Normalize `level_path` entries**

For every branch level `2` to `5`, ensure the entry contains:

```json
{
  "upgrade_role": "direction",
  "summary": "",
  "runtime_modifiers": {},
  "design_modifiers": {},
  "damage_profile": {},
  "trigger_rules": [],
  "special_rules": {},
  "boss_rules": {},
  "limits": {},
  "runtime_requirements": [],
  "ui_feedback": {},
  "enable_evolution_check": false,
  "modifier_source": ""
}
```

- [x] **Step 3: Validate structure**

Run a Node validation that checks 13 files, 52 branches, 208 level blocks, all required fields, and all `runtime_modifiers` keys against `tools/weapon_config_contracts.js`.

- [x] **Step 4: Validate encoding**

Run:

```powershell
node tools\check_text_encoding.js --strict-mojibake
```

Expected: encoding check passes.
