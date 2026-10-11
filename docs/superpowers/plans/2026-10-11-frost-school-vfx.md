# Frost School VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Ship distinct, readable visuals for all 14 base frost skills using the approved blizzard style.

**Architecture:** Extend the existing presentation scene hooks on combat objects and summons. Procedural effects expose configuration and clock APIs; combat stays authoritative. A presentation listener observes confirmed skill events for hits and shield changes.

**Tech Stack:** Godot 4.6.3, GDScript, canvas shaders, GPUParticles2D, JSON definitions.

**Spec:** docs/superpowers/specs/2026-10-11-frost-school-vfx.md

## Global Constraints

- No C: writes; all generated test data and logs under E:/codex.
- No changes to damage, status, targeting, duration, cooldown, or movement rules.
- Preserve unrelated checkout edits; no commits of others' work.
- No CPUParticles2D; effects use bounded GPU particles/procedural geometry.

## Review Focus

- Cross-style pool reuse must not retain old geometry or emission.
- Short-lived rings must reach visible peak before combat expires.
- Frozen bosses/control conversion must reflect actual status, not proposed status.
- Shield depletion must reflect actual ice_mist stacks, including mixed shield types.
- Pause and changing radii/durations must synchronize presentation with authoritative clocks.

### Task 1: Projectile presentation

**Files:** scripts/combat/projectile.gd; scripts/effects/frost_projectile_effect.gd; scenes/effects/frost_projectile_effect.tscn; resources/effects/frost_projectile.gdshader; tools/verify/verify_frost_projectile_visual.gd.

**Interfaces:** configure_projectile(params: Dictionary), update_projectile(age: float), deactivate(). Ice shard, glacial lance and ice crack shard use exported scene visual profiles. Host drives age.

- [x] Add and run failing lifecycle/direction/profile/budget/pool tests.
- [x] Implement faceted projectile and short trail, call hooks from host without changing collision.
- [x] Verify lifecycle, changed direction, pause clock and cross-style cleanup.

### Task 2: Summon presentation

**Files:** scripts/summons/summon_controller.gd; scripts/effects/frost_summon_effect.gd; scenes/effects/frost_wolf_effect.tscn; scenes/effects/ice_crystal_guard_effect.tscn; tools/verify/verify_frost_summon_visual.gd.

**Interfaces:** visual.effect_scene selects presentation; configure_summon(visual: Dictionary), update_summon(delta: float, motion: Vector2, remaining: float), face_direction(direction: Vector2), play_attack(). Controller calls attack cue only when real attack is performed.

- [x] Add and run failing scene/motion/attack/expiry tests.
- [x] Build crystal wolf silhouette and hovering guard, wire generic hooks.
- [x] Verify normal summons retain existing visuals and frost summons show no placeholder sprite.

### Task 3: Areas, state and confirmed feedback

**Files:** new frost_area effect scenes/script/shader; scripts/combat/status_effect_manager.gd; new frost state effect and feedback listener; frost entries in combat/summon/status definitions; tools/verify/verify_frost_school_visual.gd.

**Interfaces:** Area effects retain configure(radius: float,duration: float,phase: float), update_state(radius: float,age: float,duration: float), set_effect_radius(radius: float), deactivate(). Status effect.configure_status(snapshot: Dictionary) reads authoritative values. Listener subscribes to existing event bus.

- [x] Add and run failing canonical coverage/area lifetime/status/shield tests.
- [x] Build frost field/path/ring/shatter/absolute-zero distinct profiles; map existing definitions.
- [x] Wire chilled/frozen overlays and bounded confirmed hit/shield feedback. Test mixed shields and rejected executes.
- [x] Verify actual factory/runtime all 14 skills, pooled paths, independent material state and pause.

### Task 4: Production verification and documentation

**Files:** tools/verify/verify_frost_school_rendered.gd; docs/FROST_SCHOOL_VFX.md; package.json.

- [x] Run GPU rendered real gameplay captures, pause pixel comparison and stress sample.
- [x] Run encoding/config/modifier/enemy validation and relevant frost/status/shield/summon/projectile regressions with isolated E: save data.
- [x] Request independent code review, address defects, rerun affected checks.
- [x] Document skill mapping, interface, budgets and measured hardware limits; deliver verified screenshots.

### Follow-up: Live workload performance

The live 8-area / 16-target / repeated projectile workload exposed frame spikes that the held showcase cannot measure. Canvas visibility A/B retains the same gameplay and confirms both inherited damage pipeline cost and presentation overhead. Keep the optimization within VFX ownership.

- [x] Reuse compatible projectile effect nodes/materials on pool return, retain loaded scene, verify reset and cross-style behavior.
- [x] Cache persistent area ice geometry; continue redrawing transient profiles and changing radii/duration category.
- [x] Rerun affected regressions, GPU pause/appearance, and live A/B; document measured limits without promising a hardware-independent frame rate.
