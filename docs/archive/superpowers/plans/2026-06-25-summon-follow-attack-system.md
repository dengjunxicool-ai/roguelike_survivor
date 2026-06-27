# Summon Follow Attack System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a data-driven summon combat unit system with owner following, target acquisition, attack cooldowns, duration, max count, and formation separation.

**Architecture:** Add focused `Summon*` scripts under `scripts/summons/` and a reusable `SummonController` scene. `SkillActionExecutor._spawn_summon` will route summon definitions through `SummonManager` while preserving the existing fallback summon behavior for older skills.

**Tech Stack:** Godot 4 GDScript, JSON configuration in `data/summons.json`, existing `SkillActionExecutor`, `DamagePacketBuilder`, and status application methods.

---

### Task 1: Contract And Behavior Tests

**Files:**
- Create: `tools/verify_summon_system_contract.js`
- Create: `tools/verify_summon_system_behavior.gd`
- Modify: `package.json`

- [ ] **Step 1: Write failing tests**

Create tests that assert `SummonDefinition`, `SummonManager`, `SummonController`, `SummonTargetingComponent`, `SummonMovementComponent`, `SummonAttackComponent`, and `SummonFormationService` exist, `data/summons.json` contains `summon_frost_wolf` and `crimson_dragon`, and runtime behavior covers follow, chase, attack, return, teleport, max count, duration, and separation.

- [ ] **Step 2: Run tests to verify red**

Run `npm run verify:summon-system-contract` and `npm run verify:summon-system-behavior`; expected failures are missing scripts/data.

### Task 2: Summon Definition And Manager

**Files:**
- Create: `scripts/summons/summon_definition.gd`
- Create: `scripts/summons/summon_manager.gd`
- Create: `data/summons.json`
- Modify: `scripts/skills/skill_action_executor.gd`

- [ ] **Step 1: Implement definition parsing**

`SummonDefinition` normalizes inline dictionaries or `data/summons.json` entries into `movement`, `targeting`, `attack`, visual, duration, and max count dictionaries with documented defaults.

- [ ] **Step 2: Implement manager spawning**

`SummonManager` creates `SummonController`, sets owner/player power/definition/context, enforces `max_count`, and removes expired summons.

### Task 3: Summon Controller And Components

**Files:**
- Create: `scripts/summons/summon_controller.gd`
- Create: `scripts/summons/summon_targeting_component.gd`
- Create: `scripts/summons/summon_movement_component.gd`
- Create: `scripts/summons/summon_attack_component.gd`
- Create: `scripts/summons/summon_formation_service.gd`
- Create: `scenes/summon_controller.tscn`

- [ ] **Step 1: Implement state machine**

`SummonController` owns states `FOLLOW`, `CHASE`, `ATTACK`, `RETURN`, and `EXPIRED`, and delegates targeting, movement, and attacks to components.

- [ ] **Step 2: Implement movement and formation**

Movement follows owner at `follow_distance`, respects `min_distance`, returns beyond `leash_distance`, teleports beyond `teleport_distance`, and applies formation/separation offsets.

- [ ] **Step 3: Implement targeting**

Targeting searches `enemies` no more frequently than `retarget_interval`, validates live targets, and defaults to nearest-to-summon priority.

- [ ] **Step 4: Implement attacks**

Attack component supports melee and projectile configuration. The first implementation covers melee damage/status effects; projectile uses existing `spawn_projectile` action when configured.

### Task 4: Migrate Crimson Dragon

**Files:**
- Modify: `data/summons.json`
- Modify: `data/skills.json`
- Modify: `tools/verify_crimson_dragon_summon_behavior.gd`

- [ ] **Step 1: Move crimson dragon to data-driven summon config**

Use `crimson_dragon` in `data/summons.json`, set activity/leash range to player attack range fallback `540`, breath range `336`, Burning on hit, and existing dragon visual.

- [ ] **Step 2: Keep existing fire skill smoke tests passing**

Run fire runtime smoke and contract tests after migration.
