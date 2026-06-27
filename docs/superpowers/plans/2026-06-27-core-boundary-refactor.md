# Core Boundary Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the seven requested core boundary refactor stages without changing gameplay, numeric values, UI behavior, resource references, or public runtime contracts.

**Architecture:** Keep existing public entry points stable and extract focused helper classes around large files. Each stage must preserve current method names used by scenes, tests, and other scripts, while moving pure lookup, builder, selection, query, or policy logic into adjacent helper scripts.

**Tech Stack:** Godot 4.6 GDScript, JSON config files under `data/`, Node.js validation scripts under `tools/validate` and `tools/verify`.

---

### Task 1: Dev Debug Panel Boundary

**Files:**
- Create: `scripts/debug/dev_debug_data_source.gd`
- Modify: `scripts/debug/dev_debug_panel.gd`
- Verify: `npm run verify:devtools-god-skill-cards-static`, `npm run verify:fire-skill-dev-tools-entry-static`, `npm run verify:devtools-clear-skills`

- [ ] Extract JSON-backed debug lookup helpers from `DevDebugPanel` into `DevDebugDataSource`.
- [ ] Keep existing panel methods as wrappers so tests and call sites keep working.
- [ ] Run the listed devtools checks.
- [ ] Commit this task if checks pass.

### Task 2: Skill Action Projectile And Area Builders

**Files:**
- Create: `scripts/skills/skill_action_projectile_builder.gd`
- Create: `scripts/skills/skill_action_area_builder.gd`
- Modify: `scripts/skills/skill_action_executor.gd`
- Verify: projectile and area checks in `package.json`: `verify:area-effect-motion`, `verify:area-effect-max-targets`, `verify:area-effect-visual-mode`, `verify:curved-projectile-spawn-angles`, `verify:homing-projectile-swept-hit`, `verify:projectile-factory-physics-frame`, `verify:projectile-physics-flush-safe`

- [ ] Move pure projectile spawn dictionary construction and target-sequence helpers behind `SkillActionProjectileBuilder`.
- [ ] Move pure area spawn dictionary construction behind `SkillActionAreaBuilder`.
- [ ] Leave `SkillActionExecutor.execute_action()` and existing private wrapper method names intact.
- [ ] Run the listed projectile/area checks.
- [ ] Commit this task if checks pass.

### Task 3: Upgrade Pool Selection And Learn Skill Boundaries

**Files:**
- Create: `scripts/upgrades/upgrade_selection_helper.gd`
- Create: `scripts/upgrades/skill_learn_definition_repository.gd`
- Modify: `scripts/upgrades/upgrade_pool.gd`
- Verify: `verify:fire-skill-offer-rules`, `verify:fire-skill-upgrade-pool`, `verify:upgrade-pool-missing-rarity`, `verify:frost-devtools-skill-card-entry`

- [ ] Extract weighted selection, shuffle, and take helpers into `UpgradeSelectionHelper`.
- [ ] Extract skill learn definition filtering and synthetic learn-upgrade data into `SkillLearnDefinitionRepository`.
- [ ] Preserve generated option IDs, weights, rarity defaults, and debug god skill behavior.
- [ ] Run the listed upgrade checks.
- [ ] Commit this task if checks pass.

### Task 4: Status Effect Query And Runtime Helpers

**Files:**
- Create: `scripts/combat/status_effect_query.gd`
- Create: `scripts/combat/status_effect_tick_helper.gd`
- Modify: `scripts/combat/status_effect_manager.gd`
- Verify: `verify:burn-status-runtime`, `verify:burning-status-stack-devtools`, `verify:fire-status-runtime`, `verify:frost-frozen-vulnerability-runtime`, `verify:skill-card-effect-summary`

- [ ] Extract read-only status query helpers into `StatusEffectQuery`.
- [ ] Extract status tick damage calculation helpers into `StatusEffectTickHelper`.
- [ ] Keep public methods on `StatusEffectManager` as the stable facade.
- [ ] Run the listed status checks.
- [ ] Commit this task if checks pass.

### Task 5: Data Access Boundary

**Files:**
- Create: `scripts/core/game_data_access.gd`
- Modify: `scripts/game/game_data.gd`
- Modify: `scripts/core/data_manager.gd` only if a missing accessor is required
- Verify: `node tools/validate/check_text_encoding.js`, `node tools/validate/validate_enemy_configs.js`, `node tools/validate/validate_modifier_effects.js`, `npm run verify:gods-and-skills-contract`, `npm run verify:skill-definition-schema`

- [ ] Extract DataManager lookup and JSON fallback helpers from `GameData` into `GameDataAccess`.
- [ ] Do not change returned dictionary duplication behavior.
- [ ] Do not add or remove config fields.
- [ ] Run the listed data/config checks.
- [ ] Commit this task if checks pass.

### Task 6: Skill Special Rule Boundary

**Files:**
- Create focused helper scripts under `scripts/skills/special_rules/` as needed.
- Modify: `scripts/skills/skill_special_rule_executor.gd`
- Modify: `scripts/skills/special_damage_rule_handler.gd`
- Verify: skill system contract and runtime smoke checks for fire, frost, thunder, curse, holy, chaos, fusion, plus `verify:damage-formula`

- [ ] Extract only pure or self-contained rule-family helpers; keep `execute_event()` and packet adjustment entry points intact.
- [ ] Prefer helper scripts for repeated cooldown/status/target utilities before moving high-risk formula code.
- [ ] Run the listed skill and damage checks.
- [ ] Commit this task if checks pass.

### Task 7: High-Risk Core Boundary Micro-Refactor

**Files:**
- Modify `scripts/combat/damage_system.gd`, `scripts/enemies/enemy_base.gd`, or `scripts/enemies/enemy_spawner.gd` only for small facade/helper extraction where behavior is provably identical.
- Verify: all `verify:*` scripts, all `tools/validate` scripts, and literal `res://` path scan.

- [ ] Review remaining high-risk files after Tasks 1-6.
- [ ] Make only minimal boundary-preserving helper extraction if the verification surface is strong.
- [ ] If no safe extraction exists, document the no-touch decision instead of forcing architecture churn.
- [ ] Run the full validation matrix.
- [ ] Commit this task if checks pass.

