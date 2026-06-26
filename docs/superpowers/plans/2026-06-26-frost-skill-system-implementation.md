# Frost Skill System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first playable frost god skill set with 14 skills, Chilled/Frozen runtime effects, frost combat objects, and summon reuse.

**Architecture:** Keep the implementation data-driven. Add frost data to `data/gods.json`, `data/skills.json`, `data/combat_objects.json`, and `data/summons.json`, then add small generic runtime extensions for summon target priority, stationary summons, and area pulse attacks. Use existing skill trigger rules, `SkillActionExecutor`, combat object factory, status effect manager, HUD, and DevTools paths instead of parallel frost-specific systems.

**Integration Lessons:** Before applying this plan or adding another god school, read `docs/skills/god_skill_integration_lessons.md`. It records the fire/frost integration failures and the prevention checklist for attack replacement, runtime target resolution, status ticks, area expiry context, summon cleanup, visuals, HUD, DevTools, and regression coverage.

**Tech Stack:** Godot 4 GDScript, JSON data files, Node.js static verification scripts, existing Godot headless smoke tests.

---

### Task 1: Frost Data Contract

**Files:**
- Create: `tools/verify_frost_skill_system_contract.js`
- Modify: `package.json`
- Modify: `data/gods.json`
- Modify: `data/skills.json`
- Modify: `data/combat_objects.json`

- [ ] **Step 1: Write the failing static contract**

Create `tools/verify_frost_skill_system_contract.js` to assert:
- `frost` god is implemented and no longer tagged only as planned.
- All 14 frost skills exist with exact names and descriptions from the design doc.
- `frost_attack_frostbite` uses `type: "attack"` and `exclusive_group: "attack_school"`.
- `frost_dash_ice_shard_assault` uses `type: "dash"` and `exclusive_group: "dash_school"`.
- `frost_core_absolute_zero` uses `type: "core"` and `exclusive_group: "core_school"`.
- All frost skills use `description`, not `effect_description`.
- Frost combat object IDs exist.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `node tools\verify_frost_skill_system_contract.js`
Expected: FAIL because frost is still not implemented and frost skills are missing.

- [ ] **Step 3: Add frost god, skills, and combat object data**

Update JSON data with the 14 frost skill cards and first-version combat objects. Keep action definitions compatible with existing `SkillActionExecutor` action names.

- [ ] **Step 4: Run the contract and verify it passes**

Run: `node tools\verify_frost_skill_system_contract.js`
Expected: PASS.

### Task 2: Frost Summon Reuse Contract

**Files:**
- Create: `tools/verify_frost_summons_contract.js`
- Modify: `package.json`
- Modify: `data/summons.json`
- Modify: `scripts/summons/summon_targeting_component.gd`
- Modify: `scripts/summons/summon_movement_component.gd`
- Modify: `scripts/summons/summon_attack_component.gd`

- [ ] **Step 1: Write the failing summon contract**

Create `tools/verify_frost_summons_contract.js` to assert:
- `summon_frost_wolf` exists and applies `chilled`.
- `summon_frost_wolf.targeting.target_priority` is `frozen_first_then_nearest`.
- `ice_crystal_guard` exists, uses `res://scenes/summon_controller.tscn`, has `movement.movement_mode: "stationary"`, and has `attack.attack_type: "area_pulse"`.
- Summon components contain generic support for `frozen_first_then_nearest`, `stationary`, and `area_pulse`.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `node tools\verify_frost_summons_contract.js`
Expected: FAIL because frost wolf target priority and ice crystal guard are not implemented.

- [ ] **Step 3: Add generic summon extensions**

Implement target-priority, stationary movement, and area pulse behavior as generic Summon component options.

- [ ] **Step 4: Run the contract and verify it passes**

Run: `node tools\verify_frost_summons_contract.js`
Expected: PASS.

### Task 3: Frost Regression Guard

**Files:**
- Create: `tools/verify_frost_no_fire_regression_contract.js`
- Modify: `package.json`

- [ ] **Step 1: Write the failing/passable regression guard**

Create a static guard for the fire lessons:
- No frost implementation should use `effect_description`.
- Frost data must include runtime `trigger_rules` or `effects`.
- Frost attack must replace the attack school and must not define multiple attack damage multipliers.
- Frost dash must use dash trigger rules and not alter player collision flags.
- Shared GDScript files must not introduce known bad `String(skill.get(...))` patterns.

- [ ] **Step 2: Run the guard**

Run: `node tools\verify_frost_no_fire_regression_contract.js`
Expected before data: FAIL because frost data is missing; after data/runtime: PASS.

### Task 4: Runtime Smoke And Existing Regressions

**Files:**
- Modify or create focused Godot smoke tests only where needed.

- [ ] **Step 1: Run frost static tests**

Run:
```powershell
npm run verify:frost-skill-system-contract
npm run verify:frost-summons-contract
npm run verify:frost-no-fire-regression-contract
```

- [ ] **Step 2: Run existing regressions**

Run:
```powershell
npm run verify:skill-definition-schema
npm run verify:fire-status-contract
npm run verify:attack-skill-replacement
npm run verify:player-dash
npm run verify:run-hud-skill-slots
npm run verify:summon-system-contract
npm run verify:summon-system-behavior
npm run verify:fire-skill-runtime-smoke
```

- [ ] **Step 3: Fix failures with minimal code**

Only change shared runtime when a failing test proves the need.
