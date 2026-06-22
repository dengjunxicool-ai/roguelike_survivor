# Fire Tornado Reference VFX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the debug-only fire tornado VFX so it resembles the reference image with a dense column, bright spiral ribbons, erupting base, embers, and smoky outer motion.

**Architecture:** Keep the existing `FireTornadoEffect` scene and debug-panel spawn path. Add richer procedural drawing methods for tornado body, spiral ribbons, and base eruption, then add two optional `CPUParticles2D` layers for smoke wisps and outer embers. Verification remains static plus Godot runtime scene instantiation.

**Tech Stack:** Godot 4 GDScript, `Node2D._draw()`, `CPUParticles2D`, Node.js verification scripts.

---

### Task 1: Red-Green Visual Contract

**Files:**
- Modify: `tools/verify_fire_tornado_debug_vfx.js`

- [ ] Add assertions that `fire_tornado_effect.gd` contains `_draw_spiral_fire_ribbons`, `_draw_tornado_body`, `_draw_base_eruption`, `_draw_smoke_wisps`, and `_draw_ember_streaks`.
- [ ] Add assertions that `fire_tornado_effect.tscn` contains `SmokeWisps` and `OuterEmbers`.
- [ ] Run `node tools\verify_fire_tornado_debug_vfx.js`; expected failure is a missing new visual method or node.

### Task 2: Implement Reference-Inspired VFX

**Files:**
- Modify: `scripts/effects/fire_tornado_effect.gd`
- Modify: `scenes/effects/fire_tornado_effect.tscn`

- [ ] Add `SmokeWisps` and `OuterEmbers` `CPUParticles2D` children to the scene.
- [ ] Retune existing particles for denser base sparks, rising ribbons, and ember spray.
- [ ] Add procedural drawing helpers for a tapered fire column, multiple animated spiral ribbons, base eruption arcs, smoke wisps, and ember streaks.
- [ ] Ensure there is still no `visibility_rect` usage.
- [ ] Run `node tools\verify_fire_tornado_debug_vfx.js`; expected pass.

### Task 3: Verify Runtime

**Files:**
- Test only.

- [ ] Run `node tools\validate_weapon_authoring_pipeline.js`; expected pass.
- [ ] Run `D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify_fire_tornado_effect_runtime.gd`; expected pass.
- [ ] Run `D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --check-only --script res://scripts/effects/fire_tornado_effect.gd`; expected pass.
- [ ] Since this workspace is not a git repository, run `git rev-parse --is-inside-work-tree`; expected non-git failure and no commit.

## Self-Review

- Spec coverage: The plan updates the VFX script and scene only, keeps debug button behavior unchanged, and preserves visual-only behavior.
- Placeholder scan: No unfinished placeholders remain.
- Type consistency: New method and node names match across verifier and implementation tasks.
