# Weapon Attack Area Visuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add readable programmatic attack visuals for every current weapon while keeping art replacement data-driven.

**Architecture:** `data/combat_objects.json` declares semantic `visual_style` and colors for each spawned combat object. `Projectile` and `AreaEffect` read those fields and draw lightweight fallback shapes when configured, while the existing `visual` resource path stays available for future art.

**Tech Stack:** Godot 4 GDScript, JSON data configs, Node verification scripts.

---

### Task 1: Verification Contract

**Files:**
- Create: `tools/verify_weapon_attack_visuals.js`
- Modify: `tools/validate_weapon_authoring_pipeline.js`

- [ ] **Step 1: Write the failing verification**

Create `tools/verify_weapon_attack_visuals.js` to assert that every primary attack spawn object has `visual_style`, `visual_color`, and `visual_ring_color`, and that `Projectile` and `AreaEffect` contain the expected programmatic style keys.

- [ ] **Step 2: Run verification to confirm RED**

Run: `node tools\verify_weapon_attack_visuals.js`

Expected: fails because current combat object definitions do not all declare top-level `visual_style`.

- [ ] **Step 3: Add verification to the pipeline**

Add `["weapon attack visuals", "tools/verify_weapon_attack_visuals.js"]` to `CHECKS` in `tools/validate_weapon_authoring_pipeline.js`.

### Task 2: Programmatic Projectile Fallbacks

**Files:**
- Modify: `scripts/combat/projectile.gd`

- [ ] **Step 1: Add style fields**

Add `_visual_style`, `_visual_color`, `_visual_ring_color`, and `_visual_seed` fields. Read `visual_style`, `visual_color`, and `visual_ring_color` during `setup`.

- [ ] **Step 2: Add `_draw` styles**

Draw named styles for fireball, hail, lightning orb, arcane page, throwing knife, hunter arrow, and poison bottle. Use simple circles, arcs, polygons, and lines only.

- [ ] **Step 3: Preserve art replacement**

Keep `VisualConfigApplier` support intact. Programmatic drawing is a fallback and may hide generic icon sprites when a `visual_style` is configured.

### Task 3: Programmatic Area Fallbacks

**Files:**
- Modify: `scripts/combat/area_effect.gd`

- [ ] **Step 1: Generalize style redraw**

Replace hard-coded style checks with `_uses_programmatic_visual()`.

- [ ] **Step 2: Add new styles**

Add frost patch, elemental burst, trap, holy field, holy shield pulse, hammer shockwave, and keep existing poison, lava, smoke, and acid cone.

- [ ] **Step 3: Preserve collision behavior**

Do not change `_body_in_effect_shape`, tick timing, max targets, or damage packet logic.

### Task 4: Combat Object Data

**Files:**
- Modify: `data/combat_objects.json`

- [ ] **Step 1: Add projectile styles**

Add style and color fields to fireball, hailstorm, lightning orb, arcane page, throwing knife, hunter arrow, and poison bottle projectile objects.

- [ ] **Step 2: Add area styles**

Add style and color fields to generic explosion, bear trap, holy field, poison cloud, fire oil, smoke cloud, and acid spray cone objects.

- [ ] **Step 3: Keep replaceable art config**

Do not remove existing `visual` blocks.

### Task 5: Verification

**Files:**
- Test: `tools/verify_weapon_attack_visuals.js`
- Test: existing Godot and authoring checks

- [ ] **Step 1: Run focused verification**

Run: `node tools\verify_weapon_attack_visuals.js`

Expected: passes.

- [ ] **Step 2: Run authoring pipeline**

Run: `node tools\validate_weapon_authoring_pipeline.js`

Expected: passes.

- [ ] **Step 3: Run Godot checks**

Run:
- `& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/visual_config_check.gd`
- `& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --quit`

Expected: both exit 0. Existing warnings may remain if unrelated to this visual change.
