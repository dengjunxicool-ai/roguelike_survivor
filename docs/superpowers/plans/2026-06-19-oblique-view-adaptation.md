# Oblique View Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt the run map, actor visuals, weapon display, and combat visuals to the existing 2D oblique top-down presentation without changing gameplay math.

**Architecture:** Add a small visual-only adapter for oblique projection and actor sprite anchoring. Keep collision, targeting, movement, and debug ranges in normal world coordinates. Extend the existing oblique runtime check so regressions fail before visual-only changes ship.

**Tech Stack:** Godot 4.6 GDScript, existing Node2D/CanvasItem drawing, existing Node/Node2D scene structure, Node.js static validation.

---

### Task 1: Oblique Validation Contract

**Files:**
- Modify: `scripts/debug/oblique_perspective_check.gd`

- [ ] **Step 1: Add failing runtime checks**

Add assertions that require:
- `ObliquePresentation` exposes a richer oblique floor API.
- Player and enemy visual nodes carry oblique adaptation metadata.
- `WeaponVisual` exposes direction-aware hand placement.
- `AreaEffect` exposes oblique projection helpers.

- [ ] **Step 2: Run the check and confirm it fails**

Run: `& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://scripts/debug/oblique_perspective_check.gd`

Expected: FAIL on missing oblique visual adaptation.

### Task 2: Shared Visual Adapter

**Files:**
- Create: `scripts/visual/oblique_visual_adapter.gd`
- Modify: `scripts/player/player_visual_controller.gd`
- Modify: `scripts/enemies/enemy_visual_controller.gd`

- [ ] **Step 1: Implement visual-only helpers**

Create helpers for actor visual config adjustment and ground projection.

- [ ] **Step 2: Apply to player and enemy visuals**

Player and enemy controllers should adapt visual config before passing it to `VisualConfigApplier`.

### Task 3: Map Presentation

**Files:**
- Modify: `scripts/maps/oblique_presentation.gd`

- [ ] **Step 1: Add richer oblique floor drawing**

Draw tilted floor bands, stone seams, depth falloff, and foreground framing.

### Task 4: Weapon Visual

**Files:**
- Modify: `scripts/weapons/weapon_visual.gd`
- Modify: `scripts/player/player_controller.gd`

- [ ] **Step 1: Add direction-aware hand placement**

Weapon visual should expose and update an oblique hand slot based on movement direction.

### Task 5: Combat Visual Projection

**Files:**
- Modify: `scripts/combat/area_effect.gd`
- Modify: `scripts/combat/projectile.gd`

- [ ] **Step 1: Project programmatic area visuals**

Draw visual circles/arcs as ground ellipses while keeping collision circles unchanged.

- [ ] **Step 2: Keep projectile shadows ground-aligned**

Ensure projectile bodies remain readable while shadows stay unrotated on the ground plane.

### Task 6: Verification

**Files:**
- Modify: `scripts/debug/oblique_perspective_check.gd`

- [ ] **Step 1: Run focused checks**

Run:
- `& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://scripts/debug/oblique_perspective_check.gd`
- `& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit`
- `node tools\validate_weapon_authoring_pipeline.js`

Expected: all commands exit 0.
